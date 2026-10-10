class_name FieldRules
extends SimRules

## The player's fields: plots and the grid, tilling, planting, watering,
## harvesting - and what tomorrow brings them.
## A part of FarmSimulation (SimRules): simulation.fields.

## The grid's size (FarmView reads it).
var grid_width: int
var grid_height: int
var _crop_registry: Dictionary = {} # crop_id: String -> CropData

func get_plot(plot_id: int) -> PlotState:
	return state.plots.get(plot_id)

## Plots are addressed by (cell, world zone) - see FarmState.DEFAULT_ZONE.
func get_plot_id_at(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> int:
	return state.get_plot_id_at(x, y, zone_id)

## The plot's cell in its zone's grid.
func get_plot_position(plot_id: int) -> Vector2i:
	return state.plot_positions.get(plot_id, Vector2i(-1, -1))

func get_plot_zone(plot_id: int) -> String:
	return state.get_plot_zone(plot_id)

func get_all_plot_ids() -> Array:
	return state.plots.keys()

## Grows the farm to at least new_width x new_height, filling in any missing
## plot inside that rectangle with a fresh empty one. Never shrinks or
## removes anything - use remove_tile()/clear_tile() for that.
func expand_grid(new_width: int, new_height: int) -> void:
	var target_width: int = max(new_width, grid_width)
	var target_height: int = max(new_height, grid_height)
	for y in range(target_height):
		for x in range(target_width):
			add_tile(x, y) # no-op if a plot is already there
	grid_width = target_width
	grid_height = target_height

## Adds a single empty, untilled plot at (x, y) of zone_id. Returns the new
## plot_id, or -1 if a plot already exists there.
func add_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> int:
	var plot_id := state.add_plot(x, y, zone_id)
	if plot_id != -1:
		sim.plot_added.emit(plot_id)
	return plot_id

## Permanently removes the plot at (x, y), including whatever crop was
## growing on it. Returns false if there was no plot there.
func remove_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	if plot_id == -1:
		return false
	state.remove_plot(plot_id)
	sim.plot_removed.emit(plot_id)
	return true

## Marks the plot at (x, y) as a paddy (or not) - see PlotState.flooded.
## Set from the zone's FarmFields each time they register. Returns false if
## there's no plot there.
func set_tile_flooded(x: int, y: int, flooded: bool, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	var plot := get_plot(plot_id)
	if plot == null:
		return false
	if plot.flooded != flooded:
		plot.flooded = flooded
		sim.plot_changed.emit(plot_id)
	return true

## Resets the plot at (x, y) to empty/untilled without removing it from the
## grid - for reorganizing without changing the grid's shape.
func clear_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	var plot := get_plot(plot_id)
	if plot == null:
		return false
	plot.reset()
	sim.plot_changed.emit(plot_id)
	return true

## The night: a day of growth for each crop that was watered (or is in a
## paddy); the soil dries.
func advance_plots() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.crop != null:
			plot.crop.days_total += 1
			if plot.watered or plot.flooded:
				plot.crop.days_watered += 1
				plot.crop.age += 1
		plot.watered = false
		sim.plot_changed.emit(plot_id)

## Rain: every tilled plot is watered for the day. Only tilled plots: wet
## soil is drawn as worked soil, and fallow land isn't.
func water_all_tilled() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.tilled and not plot.watered:
			plot.watered = true
			sim.plot_changed.emit(plot_id)

func get_crop_data(crop_id: String) -> CropData:
	return _crop_registry.get(crop_id)

func get_all_crop_ids() -> Array:
	return _crop_registry.keys()

## can_till()/can_plant()/can_water()/can_harvest() are read-only mirrors of
## each action's guard - lets callers (FarmingController walking the player
## up to the plot, tool animations) check eligibility before mutating.
func can_till(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop == null

func till(plot_id: int) -> bool:
	if not can_till(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.tilled = true
	sim.plot_changed.emit(plot_id)
	return true

func can_plant(plot_id: int, crop_id: String) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or not plot.tilled or plot.crop != null:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null or (plot.flooded and not crop_data.grows_in_paddy):
		return false
	return state.get_inventory_count(crop_id + "_seed") > 0

func plant(plot_id: int, crop_id: String) -> bool:
	if not can_plant(plot_id, crop_id):
		return false
	var plot := get_plot(plot_id)
	var crop_data := get_crop_data(crop_id)
	var seed_key := crop_id + "_seed"
	sim.add_item(seed_key, -1)
	plot.crop = CropState.new(crop_id, crop_data.growth_days)
	sim.plot_changed.emit(plot_id)
	return true

## A paddy is always irrigated: the watering can has nothing to do there.
func can_water(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null and not plot.flooded

func water(plot_id: int) -> bool:
	if not can_water(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.watered = true
	sim.plot_changed.emit(plot_id)
	return true

## Also what the harvest swing animation checks, since it must play before
## the crop is actually removed, not after.
func can_harvest(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null and plot.crop.is_mature()

func harvest(plot_id: int) -> bool:
	if not can_harvest(plot_id):
		return false
	var plot := get_plot(plot_id)
	var crop_id := plot.crop.crop_id
	var crop_data := get_crop_data(crop_id)
	var under_watered := plot.crop.get_watered_ratio() < crop_data.min_watered_ratio_for_quality
	var off_season := crop_data.ideal_season != CropData.Season.ALL_YEAR 			and int(crop_data.ideal_season) != state.clock.get_season()
	var quantity := _compute_harvest_quantity(crop_data, under_watered, off_season)
	if plot.fertilized:
		quantity = ceili(quantity * ZebuRules.MANURE_YIELD_MULTIPLIER)
		plot.fertilized = false
	if crop_id == ProjectRules.GRANARY_CROP and sim.projects.get_building_level("granary") >= 1:
		quantity = ceili(quantity * ProjectRules.GRANARY_RICE_MULTIPLIER)
	plot.crop = null
	plot.watered = false
	sim.add_item(crop_id, quantity)
	sim.plot_changed.emit(plot_id)
	day_log.add_harvest(crop_id, quantity)
	sim.crop_harvested.emit(plot_id, crop_id, quantity, under_watered, off_season)
	return true

## Base yield is a random amount in [yield_min, yield_max]. Watering the crop
## less than its min_watered_ratio_for_quality caps it a notch lower, and
## harvesting outside its ideal_season shrinks it further - both floored at 1
## so a successful harvest never returns nothing.
func _compute_harvest_quantity(crop_data: CropData, under_watered: bool, off_season: bool) -> int:
	var quantity := randi_range(crop_data.yield_min, crop_data.yield_max)
	if under_watered:
		quantity = max(1, quantity - 1)
	if off_season:
		quantity = max(1, int(round(quantity * crop_data.off_season_yield_multiplier)))
	return quantity

## Worked soil or a growing crop, not fertilized yet, and manure in hand.
func can_fertilize(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and not plot.fertilized and (plot.tilled or plot.crop != null) \
		and state.get_inventory_count(ZebuRules.MANURE_ITEM) > 0

func fertilize(plot_id: int) -> bool:
	if not can_fertilize(plot_id):
		return false
	get_plot(plot_id).fertilized = true
	sim.add_item(ZebuRules.MANURE_ITEM, -1)
	sim.plot_changed.emit(plot_id)
	return true

## Crops that will be ripe tomorrow morning: growing, watered today (or in a
## paddy), one day short. crop_id -> plots.
func get_ripening_tomorrow() -> Dictionary:
	var ripening := {}
	for plot: PlotState in state.plots.values():
		var crop := plot.crop
		if crop != null and not crop.is_mature() and (plot.watered or plot.flooded) and crop.age + 1 >= crop.growth_days:
			ripening[crop.crop_id] = int(ripening.get(crop.crop_id, 0)) + 1
	return ripening

## Growing crops not watered today: they won't grow tonight.
func get_unwatered_plots() -> int:
	return state.plots.values().filter(func(plot: PlotState) -> bool:
		return plot.crop != null and not plot.crop.is_mature() and not plot.watered and not plot.flooded).size()
