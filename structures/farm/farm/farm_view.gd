class_name FarmView
extends Node2D

const CELL_SIZE := PlotView.CELL_SIZE
## See get_plot_id_in_front_of(): 0.75 = "a cell entered by at most 1/4
## still counts as the target".
const TARGET_REACH := 0.75
const PlotViewScene := preload("res://structures/farm/farm/plot_view.tscn")
const PlotHighlightScript := preload("res://structures/farm/farm/plot_highlight.gd")

var grid_width: int
var grid_height: int

var _plot_views: Dictionary = {} # plot_id: int -> PlotView
var _plot_positions: Dictionary = {} # plot_id: int -> Vector2i
var _simulation: FarmSimulation
var _highlight: PlotHighlight
## The FarmField children, which draw the soil - FarmView itself only owns
## the crops (PlotViews), the target highlight and the grid math.
var _fields: Array[FarmField] = []
## The world zone this view stands in (ZoneData id): its plots are this
## zone's plots - FarmSimulation addresses plots by (cell, zone).
var _zone_id := FarmState.DEFAULT_ZONE
var _soil_dirty := false

## y-sorted so the player walks behind a crop's upper part and in front of
## its base (PlotViews sort by their bottom-center origin). The fields' soil
## sits below everything via their z_index since it isn't part of that ordering.
func _ready() -> void:
	y_sort_enabled = true
	for child in get_children():
		if child is FarmField:
			_fields.append(child)
			var tile_set: TileSet = child.tile_set
			if tile_set and Vector2(tile_set.tile_size) != Vector2(CELL_SIZE, CELL_SIZE):
				push_warning("FarmView.CELL_SIZE (%s) != %s's tile_size (%s) - soil and crops will be misaligned" % [CELL_SIZE, child.name, tile_set.tile_size])

func get_fields() -> Array[FarmField]:
	return _fields

func setup(simulation: FarmSimulation, zone_id := FarmState.DEFAULT_ZONE) -> void:
	_simulation = simulation
	_zone_id = zone_id
	simulation.crop_harvested.connect(_on_crop_harvested)
	grid_width = simulation.grid_width
	grid_height = simulation.grid_height
	_build_grid()
	simulation.plot_changed.connect(_on_plot_changed)
	simulation.plot_added.connect(_on_plot_added)
	simulation.plot_removed.connect(_on_plot_removed)
	_create_highlight()
	# Even with no plot at all, locked fields still need drawing.
	_queue_soil_redraw()

## Built in code rather than as a .tscn node - see WorldManager's fade
## overlay for why (avoids scene-file edits getting clobbered by a
## concurrently open editor).
func _create_highlight() -> void:
	_highlight = PlotHighlightScript.new()
	_highlight.visible = false
	add_child(_highlight)

## Shows the pulsing outline over plot_id - white if `can_act`, red if not -
## or hides it for -1. Called every frame by FarmingController with the same
## plot and the same eligibility check it uses when E is pressed, so the
## highlight never lies about what pressing E is about to do.
func show_highlight_for_plot(plot_id: int, can_use: bool, can_harvest: bool) -> void:
	if plot_id == -1:
		_highlight.visible = false
		return
	var grid_pos: Vector2i = _simulation.get_plot_position(plot_id)
	_highlight.position = Vector2(grid_pos.x, grid_pos.y) * CELL_SIZE
	_highlight.can_act = can_use or can_harvest
	_highlight.show_hand = can_harvest
	_highlight.visible = true

## "+3 Maïs" over the plot just harvested, with why it came out small if it
## did - the player sees the yield where it happened.
func _on_crop_harvested(plot_id: int, crop_id: String, quantity: int, under_watered: bool, off_season: bool) -> void:
	if _simulation.get_plot_zone(plot_id) != _zone_id:
		return
	var crop_data := _simulation.get_crop_data(crop_id)
	var notes: PackedStringArray = []
	if under_watered:
		notes.append(tr("peu arrosé"))
	if off_season:
		notes.append(tr("hors saison"))
	var rect := get_plot_global_rect(plot_id)
	HarvestPopup.spawn(get_parent(), Vector2(rect.get_center().x, rect.position.y - 4.0),
		crop_data.icon if crop_data else null,
		tr("+%d %s") % [quantity, tr(crop_data.display_name) if crop_data else crop_id],
		", ".join(notes))

## Plays the plot's feedback for an action that just succeeded on it - see
## PlotView.react().
func react_to_action(plot_id: int, action: FarmAction.Type) -> void:
	var plot_view: PlotView = _plot_views.get(plot_id)
	if plot_view:
		plot_view.react(action)

func hide_highlight() -> void:
	if _highlight:
		_highlight.visible = false

func _build_grid() -> void:
	for plot_id in _simulation.get_all_plot_ids():
		_create_plot_view(plot_id)

func _create_plot_view(plot_id: int) -> void:
	if _plot_views.has(plot_id):
		return
	if _simulation.get_plot_zone(plot_id) != _zone_id:
		return # another zone's plot
	var pos := _simulation.get_plot_position(plot_id)
	var plot_view: PlotView = PlotViewScene.instantiate()
	add_child(plot_view)
	# PlotView's origin is its cell's bottom-center - see PlotView.CELL_TOP_LEFT.
	plot_view.position = Vector2(pos.x, pos.y) * CELL_SIZE + Vector2(CELL_SIZE / 2.0, CELL_SIZE)
	_plot_views[plot_id] = plot_view
	_plot_positions[plot_id] = pos
	_refresh_plot_view(plot_view, plot_id)

func _on_plot_changed(plot_id: int) -> void:
	var plot_view: PlotView = _plot_views.get(plot_id)
	if plot_view:
		_refresh_plot_view(plot_view, plot_id)

func _refresh_plot_view(plot_view: PlotView, plot_id: int) -> void:
	var plot := _simulation.get_plot(plot_id)
	var crop_data: CropData = _simulation.get_crop_data(plot.crop.crop_id) if plot.crop != null else null
	plot_view.update_view(plot, crop_data)
	_queue_soil_redraw()

## One plot's autotile depends on its 8 neighbours, so each field's soil is
## repainted as a whole rather than cell by cell - batched to once per frame,
## since a save load or a new day changes every plot in a row.
func _queue_soil_redraw() -> void:
	if _soil_dirty:
		return
	_soil_dirty = true
	_redraw_soil.call_deferred()

## A field cell with a plot is owned (bought); one without is still locked.
func _redraw_soil() -> void:
	_soil_dirty = false
	if _simulation == null:
		return
	for field in _fields:
		var owned := {}
		var tilled: Array[Vector2i] = []
		var wet: Array[Vector2i] = []
		for cell in field.get_cells():
			var plot := _simulation.get_plot(_simulation.get_plot_id_at(cell.x, cell.y, _zone_id))
			if plot == null:
				continue
			owned[cell] = true
			if plot.tilled or plot.watered:
				tilled.append(cell)
			if plot.watered:
				wet.append(cell)
		field.show_soil(owned, tilled, wet)

## Fired for grid expansion (expand_grid()/add_tile()) and for every plot
## restored by a save load - either way, a PlotView needs to be created.
func _on_plot_added(plot_id: int) -> void:
	grid_width = _simulation.grid_width
	grid_height = _simulation.grid_height
	_create_plot_view(plot_id)

func _on_plot_removed(plot_id: int) -> void:
	var plot_view: PlotView = _plot_views.get(plot_id)
	if plot_view:
		plot_view.queue_free()
	_plot_views.erase(plot_id)
	_plot_positions.erase(plot_id)
	_queue_soil_redraw()

## The plot the player at world_pos is facing, or -1 if there's no plot
## there (outside the grid, or a hole left by remove_tile()). Diagonals snap
## to the dominant axis, ties going left/right to match the player's
## left/right-only tool animations.
##
## Probes TARGET_REACH of a cell ahead of the feet: while the feet are no
## more than a quarter of the way into a cell (from the side the player
## faces away from), the probe stays in that same cell and it's the target;
## any deeper and the probe lands in the next cell. So a player who just
## stepped onto a plot still works it, and one standing well inside a cell
## works the one in front - the player never has to stand on a plot's middle
## to work it, which is what lets crops be solid.
func get_plot_id_in_front_of(world_pos: Vector2, facing: Vector2) -> int:
	var probe := world_pos + Vector2(facing_step(facing)) * CELL_SIZE * TARGET_REACH
	var grid_pos := world_to_grid(probe)
	return _simulation.get_plot_id_at(grid_pos.x, grid_pos.y, _zone_id)

## `facing` snapped to one grid step: (±1, 0) or (0, ±1).
static func facing_step(facing: Vector2) -> Vector2i:
	if absf(facing.x) >= absf(facing.y):
		return Vector2i(int(signf(facing.x)), 0)
	return Vector2i(0, int(signf(facing.y)))

## The plot's cell in world coordinates.
func get_plot_global_rect(plot_id: int) -> Rect2:
	var grid_pos := _simulation.get_plot_position(plot_id)
	return Rect2(global_position + Vector2(grid_pos) * CELL_SIZE, Vector2.ONE * CELL_SIZE)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos := world_pos - global_position
	return Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))
