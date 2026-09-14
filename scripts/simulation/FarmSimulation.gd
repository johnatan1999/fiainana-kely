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

func get_all_crop_ids() -> Array:
	return _crop_registry.keys()

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
	var crop_data := get_crop_data(crop_id)
	var quantity := _compute_harvest_quantity(plot.crop, crop_data)
	state.add_inventory(crop_id, quantity)
	plot.crop = null
	plot.watered = false
	inventory_changed.emit(crop_id, state.get_inventory_count(crop_id))
	plot_changed.emit(plot_id)
	return true

## Base yield is a random amount in [yield_min, yield_max]. Watering the crop
## less than its min_watered_ratio_for_quality caps it a notch lower, and
## harvesting outside its ideal_season shrinks it further - both floored at 1
## so a successful harvest never returns nothing.
func _compute_harvest_quantity(crop: CropState, crop_data: CropData) -> int:
	var quantity := randi_range(crop_data.yield_min, crop_data.yield_max)
	if crop.get_watered_ratio() < crop_data.min_watered_ratio_for_quality:
		quantity = max(1, quantity - 1)
	var ideal_season := crop_data.ideal_season
	if ideal_season != CropData.Season.TOUTE_SAISON and int(ideal_season) != state.clock.get_season():
		quantity = max(1, int(round(quantity * crop_data.off_season_yield_multiplier)))
	return quantity

func advance_day() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.crop != null:
			plot.crop.days_total += 1
			if plot.watered:
				plot.crop.days_watered += 1
				plot.crop.age += 1
		plot.watered = false
		plot_changed.emit(plot_id)
	state.clock.advance_day()
	day_changed.emit(state.day)

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null:
		return false
	if state.day < crop_data.unlock_day:
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

## Generic purchase path for shop items that aren't crops (tools/food/animals):
## unlike buy_seed(), the caller supplies the price since these items have no
## entry in _crop_registry.
func buy_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0:
		return false
	var cost := unit_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	state.add_inventory(item_id, quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
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
