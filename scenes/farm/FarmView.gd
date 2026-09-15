class_name FarmView
extends Node2D

const CELL_SIZE := 64.0
const PlotViewScene := preload("res://scenes/farm/PlotView.tscn")

var grid_width: int
var grid_height: int

var _plot_views: Dictionary = {} # plot_id: int -> PlotView
var _simulation: FarmSimulation

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
	_refresh_plot_view(plot_view, plot_id)

func _on_plot_changed(plot_id: int) -> void:
	var plot_view: PlotView = _plot_views.get(plot_id)
	if plot_view:
		_refresh_plot_view(plot_view, plot_id)

func _refresh_plot_view(plot_view: PlotView, plot_id: int) -> void:
	var plot := _simulation.get_plot(plot_id)
	var crop_data: CropData = _simulation.get_crop_data(plot.crop.crop_id) if plot.crop != null else null
	plot_view.update_view(plot, crop_data)

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

## Returns the plot_id under the given world position, or -1 if there's no
## plot there (outside the grid, or a hole left by remove_tile()).
func get_plot_id_at(world_pos: Vector2) -> int:
	var local_pos := world_pos - global_position
	var grid_x := int(floor(local_pos.x / CELL_SIZE))
	var grid_y := int(floor(local_pos.y / CELL_SIZE))
	return _simulation.get_plot_id_at(grid_x, grid_y)
