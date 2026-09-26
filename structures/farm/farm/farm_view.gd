class_name FarmView
extends Node2D

const CELL_SIZE := PlotView.CELL_SIZE
## See get_plot_id_in_front_of(): 0.75 = "a cell entered by at most 1/4
## still counts as the target".
const TARGET_REACH := 0.75
const PlotViewScene := preload("res://structures/farm/farm/plot_view.tscn")
const PlotHighlightScript := preload("res://structures/farm/farm/plot_highlight.gd")

## Atlas coordinates in farm_tileset.tres (source id 0) for each soil state.
const TILE_SOURCE_ID := 0
const TILE_NORMAL := Vector2i(2, 2) # untilled ground, sparse grass
const TILE_TILLED_DRY := Vector2i(0, 0) # tilled, not watered today
const TILE_TILLED_WET := Vector2i(1, 1) # tilled and watered today

var grid_width: int
var grid_height: int

var _plot_views: Dictionary = {} # plot_id: int -> PlotView
var _plot_positions: Dictionary = {} # plot_id: int -> Vector2i
var _simulation: FarmSimulation
var _highlight: PlotHighlight

@onready var soil_layer: TileMapLayer = $SoilLayer

## y-sorted so the player walks behind a crop's upper part and in front of
## its base (PlotViews sort by their bottom-center origin). The soil is pushed
## below everything via z_index since it isn't part of that ordering.
func _ready() -> void:
	y_sort_enabled = true
	soil_layer.z_index = -1
	if soil_layer.tile_set == null:
		push_error("FarmView: SoilLayer has no tile_set - check that farm_tileset.tres and its texture are imported")
		return
	if Vector2(soil_layer.tile_set.tile_size) != Vector2(CELL_SIZE, CELL_SIZE):
		push_warning("FarmView.CELL_SIZE (%s) != tileset tile_size (%s) - soil and crops will be misaligned" % [CELL_SIZE, soil_layer.tile_set.tile_size])

func setup(simulation: FarmSimulation) -> void:
	_simulation = simulation
	grid_width = simulation.grid_width
	grid_height = simulation.grid_height
	_build_grid()
	simulation.plot_changed.connect(_on_plot_changed)
	simulation.plot_added.connect(_on_plot_added)
	simulation.plot_removed.connect(_on_plot_removed)
	_create_highlight()

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

func hide_highlight() -> void:
	if _highlight:
		_highlight.visible = false

func _build_grid() -> void:
	for plot_id in _simulation.get_all_plot_ids():
		_create_plot_view(plot_id)

func _create_plot_view(plot_id: int) -> void:
	if _plot_views.has(plot_id):
		return
	var plot_view: PlotView = PlotViewScene.instantiate()
	add_child(plot_view)
	var pos := _simulation.get_plot_position(plot_id)
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
	soil_layer.set_cell(_plot_positions[plot_id], TILE_SOURCE_ID, _soil_tile_for(plot))

## Single TileMapLayer shared by every plot - one draw call for the whole
## farm's soil instead of a Soil node per PlotView.
func _soil_tile_for(plot: PlotState) -> Vector2i:
	if plot.watered:
		return TILE_TILLED_WET
	if plot.tilled:
		return TILE_TILLED_DRY
	return TILE_NORMAL

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
	if _plot_positions.has(plot_id):
		soil_layer.erase_cell(_plot_positions[plot_id])
		_plot_positions.erase(plot_id)

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
	return _simulation.get_plot_id_at(grid_pos.x, grid_pos.y)

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
