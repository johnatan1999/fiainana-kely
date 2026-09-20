class_name FarmView
extends Node2D

const CELL_SIZE := 64.0
const PlotViewScene := preload("res://scenes/farm/PlotView.tscn")

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

@onready var soil_layer: TileMapLayer = $SoilLayer

func setup(simulation: FarmSimulation) -> void:
	_simulation = simulation
	grid_width = simulation.grid_width
	grid_height = simulation.grid_height
	_build_grid()
	simulation.plot_changed.connect(_on_plot_changed)
	simulation.plot_added.connect(_on_plot_added)
	simulation.plot_removed.connect(_on_plot_removed)

func _build_grid() -> void:
	for plot_id in _simulation.get_all_plot_ids():
		_create_plot_view(plot_id)

func _create_plot_view(plot_id: int) -> void:
	if _plot_views.has(plot_id):
		return
	var plot_view: PlotView = PlotViewScene.instantiate()
	add_child(plot_view)
	var pos := _simulation.get_plot_position(plot_id)
	plot_view.position = Vector2(pos.x, pos.y) * CELL_SIZE
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

## Returns the plot_id under the given world position, or -1 if there's no
## plot there (outside the grid, or a hole left by remove_tile()).
func get_plot_id_at(world_pos: Vector2) -> int:
	var local_pos := world_pos - global_position
	var grid_x := int(floor(local_pos.x / CELL_SIZE))
	var grid_y := int(floor(local_pos.y / CELL_SIZE))
	return _simulation.get_plot_id_at(grid_x, grid_y)
