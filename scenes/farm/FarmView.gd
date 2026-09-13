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

func _build_grid() -> void:
	for key in _simulation.state.plots.keys():
		var plot_id: int = key
		var plot_view: PlotView = PlotViewScene.instantiate()
		add_child(plot_view)
		var grid_x: int = plot_id % grid_width
		var grid_y: int = plot_id / grid_width
		plot_view.position = Vector2(grid_x, grid_y) * CELL_SIZE
		_plot_views[plot_id] = plot_view
		plot_view.update_view(_simulation.get_plot(plot_id))

func _on_plot_changed(plot_id: int) -> void:
	var plot_view: PlotView = _plot_views.get(plot_id)
	if plot_view:
		plot_view.update_view(_simulation.get_plot(plot_id))

## Returns the plot_id under the given world position, or -1 if outside the grid.
func get_plot_id_at(world_pos: Vector2) -> int:
	var local_pos := world_pos - global_position
	var grid_x := int(floor(local_pos.x / CELL_SIZE))
	var grid_y := int(floor(local_pos.y / CELL_SIZE))
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return -1
	return grid_y * grid_width + grid_x
