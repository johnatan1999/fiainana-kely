class_name FarmSimulation
extends RefCounted

## Owns FarmState and enforces every rule of the farm loop.
## Never touches Node2D/Sprite2D/UI - presentation only listens to the signals below.

signal money_changed(money: int)
signal day_changed(day: int)
signal plot_changed(plot_id: int)
signal inventory_changed(item_id: String, amount: int)

var state: FarmState
var grid_width: int
var grid_height: int

var _crop_registry: Dictionary = {} # crop_id: String -> CropData

func _init(p_grid_width: int, p_grid_height: int, crop_registry: Dictionary) -> void:
	grid_width = p_grid_width
	grid_height = p_grid_height
	_crop_registry = crop_registry
	state = FarmState.new(p_grid_width * p_grid_height)

func get_plot(plot_id: int) -> PlotState:
	return state.plots.get(plot_id)

func get_crop_data(crop_id: String) -> CropData:
	return _crop_registry.get(crop_id)

func till(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or plot.crop != null:
		return false
	plot.tilled = true
	plot_changed.emit(plot_id)
	return true

func plant(plot_id: int, crop_id: String) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or not plot.tilled or plot.crop != null:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null:
		return false
	var seed_key := crop_id + "_seed"
	if state.get_inventory_count(seed_key) <= 0:
		return false
	state.add_inventory(seed_key, -1)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	plot.crop = CropState.new(crop_id, crop_data.growth_days)
	plot_changed.emit(plot_id)
	return true

func water(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or plot.crop == null:
		return false
	plot.watered = true
	plot_changed.emit(plot_id)
	return true

func harvest(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or plot.crop == null or not plot.crop.is_mature():
		return false
	var crop_id := plot.crop.crop_id
	state.add_inventory(crop_id, 1)
	plot.crop = null
	plot.watered = false
	inventory_changed.emit(crop_id, state.get_inventory_count(crop_id))
	plot_changed.emit(plot_id)
	return true

func advance_day() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.crop != null:
			plot.crop.age += 1
		plot.watered = false
		plot_changed.emit(plot_id)
	state.day += 1
	day_changed.emit(state.day)

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null:
		return false
	var cost := crop_data.seed_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	var seed_key := crop_id + "_seed"
	state.add_inventory(seed_key, quantity)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	return true

func sell(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(item_id)
	if crop_data == null:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	state.add_inventory(item_id, -quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.money += crop_data.sell_price * quantity
	money_changed.emit(state.money)
	return true

func to_save_data() -> Dictionary:
	return state.to_dict()

## Restores state in-place and re-emits every signal so the presentation layer redraws itself.
func load_save_data(data: Dictionary) -> void:
	state.load_dict(data)
	money_changed.emit(state.money)
	day_changed.emit(state.day)
	for plot_id in state.plots:
		plot_changed.emit(plot_id)
	for item_id in state.inventory:
		inventory_changed.emit(item_id, state.inventory[item_id])
