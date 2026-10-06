extends SceneTree

## Headless test runner for the simulation layer.
## Run with: godot --headless --script res://tests/run_tests.gd

var _pass_count := 0
var _fail_count := 0

func _initialize() -> void:
	_run_all()
	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)

func _make_sim() -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var sim: FarmSimulation = FarmSimulation.new(4, 4, {"corn": corn})
	sim.rain_chance = {} # deterministic: no surprise rain
	return sim

## duplicate() so each test gets its own AnimalData instance - mutating
## breeding_chance for one test must never leak into another via the
## shared ResourceLoader cache.
func _make_sim_with_chicken(breeding_chance: float = 0.25) -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var chicken: AnimalData = load("res://data/animals/chicken.tres").duplicate()
	chicken.breeding_chance = breeding_chance
	var sim: FarmSimulation = FarmSimulation.new(4, 4, {"corn": corn}, {AnimalData.Species.CHICKEN: chicken})
	sim.rain_chance = {} # deterministic: no surprise rain
	return sim

## FarmLandManager extends Node but is never added to the tree in these tests -
## fine, since buy_zone()/buy_progressive_patch() never touch tree-dependent
## APIs. The village's FarmFields are registered by hand, at the cells
## player_village.tscn paints them.
const EAST_ORIGIN := Vector2i(8, 9)
const EAST_SIZE := Vector2i(4, 6)
const PROGRESSIVE_ORIGIN := Vector2i(0, 9)
const PROGRESSIVE_SIZE := Vector2i(8, 6)

func _make_farm_land_manager(simulation: FarmSimulation) -> FarmLandManager:
	var farm_land_manager := FarmLandManager.new()
	farm_land_manager.setup(simulation)
	farm_land_manager.register_field(FarmField.Kind.ZONE, _rect_cells(EAST_ORIGIN, EAST_SIZE), load("res://data/zones/zone_east.tres"))
	farm_land_manager.register_field(FarmField.Kind.PROGRESSIVE, _rect_cells(PROGRESSIVE_ORIGIN, PROGRESSIVE_SIZE))
	return farm_land_manager

## Listed column by column, so row-by-row ordering has to come from
## FarmLandManager, not from the input order.
const MANGO_TREE_ID := "village:TreeGroup/Manguier"

## Mango tree: fruits in Asara (days 1-30), every 4 days, 2 to 4 at a time.
func _make_sim_with_mango() -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var mango: TreeData = load("res://data/trees/mango_tree.tres")
	var decor := TreeData.new()
	decor.id = "decor_tree"
	var sim: FarmSimulation = FarmSimulation.new(4, 4, {"corn": corn}, {}, {mango.id: mango, decor.id: decor})
	sim.rain_chance = {} # deterministic: no surprise rain
	return sim

func _rect_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(origin + Vector2i(x, y))
	return cells

func _check(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("PASS: %s" % description)
	else:
		_fail_count += 1
		print("FAIL: %s" % description)

func _run_all() -> void:
	test_till_plot()
	test_plant_on_tilled_plot()
	test_crop_progresses_on_day_advance()
	test_harvest_mature_crop()
	test_harvest_quantity_within_yield_range()
	test_sell_increases_money()
	test_buy_decreases_money()
	test_cannot_plant_untilled_plot()
	test_cannot_harvest_immature_crop()
	test_cannot_buy_without_enough_money()
	test_cannot_buy_locked_crop()
	test_save_load_roundtrip()
	test_no_progress_without_watering()
	test_watering_is_consumed_each_day()
	test_low_watering_caps_harvest_below_max_yield()
	test_season_boundaries()
	test_build_coop_deducts_money()
	test_cannot_build_coop_twice()
	test_buy_chicken_adds_pending_animal()
	test_cannot_place_chicken_without_coop()
	test_place_chicken_creates_animal()
	test_place_chicken_respects_coop_capacity()
	test_feed_and_water_reset_hunger_and_thirst()
	test_unfed_animal_loses_hunger_on_advance_day()
	test_fed_animal_keeps_care_streak()
	test_product_ready_signal_fires_after_cycle()
	test_breeding_creates_offspring_when_guaranteed()
	test_no_breeding_when_chance_is_zero()
	test_sell_item_generic_path()
	test_animal_save_load_roundtrip()
	test_expand_grid_adds_new_plots()
	test_expand_grid_keeps_existing_plots_intact()
	test_add_tile_creates_a_plot()
	test_add_tile_is_noop_if_already_occupied()
	test_remove_tile_deletes_the_plot()
	test_remove_tile_discards_growing_crop()
	test_clear_tile_resets_without_removing()
	test_plot_added_and_removed_signals_fire()
	test_grid_survives_resize_and_save_load_roundtrip()
	test_buy_zone_unlocks_all_its_tiles()
	test_buy_zone_deducts_price()
	test_cannot_buy_zone_twice()
	test_cannot_buy_zone_without_enough_money()
	test_cannot_buy_unknown_zone()
	test_buy_progressive_patch_unlocks_next_tiles_in_order()
	test_buy_progressive_patch_second_purchase_continues_the_sequence()
	test_buy_progressive_patch_respects_capacity()
	test_buy_progressive_patch_fails_without_enough_money()
	test_zone_state_save_load_roundtrip()
	test_starter_field_registration_adds_its_plots()
	test_registering_an_owned_zone_restores_missing_plots()
	test_registering_a_locked_zone_adds_nothing()
	test_progressive_registration_restores_bought_cells_only()
	test_tree_discovered_in_season_starts_ripe()
	test_tree_discovered_out_of_season_starts_bare()
	test_harvest_tree_adds_fruit_and_resets()
	test_tree_ripens_after_its_cycle_in_season()
	test_tree_fruit_rots_at_season_end_and_waits_for_next_season()
	test_decorative_or_unknown_trees_are_not_registered()
	test_tree_save_load_roundtrip()
	test_paddy_plots_grow_without_watering()
	test_paddy_only_takes_paddy_crops()
	test_paddy_cannot_be_watered()
	test_paddy_flag_set_on_purchase_and_saved()
	test_time_of_day_advances_in_whole_minutes()
	test_time_stops_at_two_in_the_morning()
	test_sleeping_wakes_up_at_six()
	test_time_of_day_save_load_roundtrip()
	test_zones_have_separate_plot_grids()
	test_zone_plots_save_load_roundtrip()
	test_v5_save_migrates_plots_to_their_zone()
	test_harvest_reports_quantity_and_penalties()
	test_rain_waters_tilled_plots_only()
	test_crops_grow_on_a_rainy_day_without_watering()
	test_weather_save_load_roundtrip()
	test_rain_is_much_more_likely_in_asara()
	test_villager_routine_steps()

func test_till_plot() -> void:
	var sim := _make_sim()
	var ok := sim.till(0)
	_check(ok and sim.get_plot(0).tilled, "till() marks the plot as tilled")

func test_plant_on_tilled_plot() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	var ok := sim.plant(0, "corn")
	_check(ok and sim.get_plot(0).crop != null, "plant() succeeds on a tilled plot")

func test_crop_progresses_on_day_advance() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	sim.water(0)
	sim.advance_day()
	_check(sim.get_plot(0).crop.age == 1, "advance_day() ages a watered crop")

func test_no_progress_without_watering() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	sim.advance_day() # not watered
	_check(sim.get_plot(0).crop.age == 0, "advance_day() does not age an unwatered crop")

func test_watering_is_consumed_each_day() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	sim.water(0)
	sim.advance_day()
	sim.advance_day() # second day, not re-watered
	_check(sim.get_plot(0).crop.age == 1, "watering only carries the crop through a single day")

func test_harvest_mature_crop() -> void:
	var sim := _make_sim()
	var corn := sim.get_crop_data("corn")
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	for i in range(corn.growth_days):
		sim.water(0)
		sim.advance_day()
	var ok := sim.harvest(0)
	_check(ok and sim.get_plot(0).crop == null, "harvest() succeeds once the crop is mature")

func test_harvest_quantity_within_yield_range() -> void:
	var sim := _make_sim()
	var corn := sim.get_crop_data("corn")
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	for i in range(corn.growth_days):
		sim.water(0)
		sim.advance_day()
	sim.harvest(0)
	var quantity := sim.state.get_inventory_count("corn")
	_check(
		quantity >= corn.yield_min and quantity <= corn.yield_max,
		"harvest() adds a quantity within [yield_min, yield_max] for a fully-watered, in-season crop"
	)

func test_low_watering_caps_harvest_below_max_yield() -> void:
	var sim := _make_sim()
	var corn := sim.get_crop_data("corn")
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	# Water every other day: reaches maturity (growth_days waterings) but at a
	# watered_ratio of 0.5, below corn's 0.75 quality threshold.
	var days_elapsed := 0
	while not sim.get_plot(0).crop.is_mature():
		if days_elapsed % 2 == 0:
			sim.water(0)
		sim.advance_day()
		days_elapsed += 1
	sim.harvest(0)
	var quantity := sim.state.get_inventory_count("corn")
	_check(
		quantity >= 1 and quantity < corn.yield_max,
		"insufficient watering caps the harvest below the crop's max yield"
	)

func test_sell_increases_money() -> void:
	var corn: CropData = load("res://data/crops/corn.tres")
	var sim := _make_sim()
	sim.state.add_inventory("corn", 1)
	var money_before := sim.state.money
	var ok := sim.sell("corn", 1)
	_check(ok and sim.state.money == money_before + corn.sell_price, "sell() increases money by the sell price")

func test_buy_decreases_money() -> void:
	var corn: CropData = load("res://data/crops/corn.tres")
	var sim := _make_sim()
	var money_before := sim.state.money
	var ok := sim.buy_seed("corn", 1)
	_check(ok and sim.state.money == money_before - corn.seed_price, "buy_seed() decreases money by the seed price")

func test_cannot_plant_untilled_plot() -> void:
	var sim := _make_sim()
	sim.state.add_inventory("corn_seed", 1)
	var ok := sim.plant(0, "corn")
	_check(not ok and sim.get_plot(0).crop == null, "plant() fails on a non-tilled plot")

func test_cannot_harvest_immature_crop() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	var ok := sim.harvest(0)
	_check(not ok and sim.get_plot(0).crop != null, "harvest() fails on an immature crop")

func test_cannot_buy_without_enough_money() -> void:
	var sim := _make_sim()
	sim.state.money = 3
	var ok := sim.buy_seed("corn", 1)
	_check(not ok and sim.state.money == 3, "buy_seed() fails when money is insufficient")

func test_cannot_buy_locked_crop() -> void:
	var rice: CropData = load("res://data/crops/rice.tres")
	var sim := FarmSimulation.new(4, 4, {"corn": load("res://data/crops/corn.tres"), "rice": rice})
	sim.state.money = 100000
	var ok := sim.buy_seed("rice", 1)
	_check(
		not ok and sim.state.get_inventory_count("rice_seed") == 0,
		"buy_seed() fails before the crop's unlock_day even with enough money"
	)

func test_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	sim.water(0)
	sim.advance_day()
	sim.buy_seed("corn", 1)

	var data := sim.to_save_data()
	# JSON round-trip, exactly like the real save file on disk.
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)

	var plot := fresh_sim.get_plot(0)
	_check(
		fresh_sim.state.money == sim.state.money
		and fresh_sim.state.day == sim.state.day
		and fresh_sim.state.get_inventory_count("corn_seed") == sim.state.get_inventory_count("corn_seed")
		and plot.tilled
		and not plot.watered # advance_day() resets watered before the save happened
		and plot.crop != null
		and plot.crop.crop_id == "corn"
		and plot.crop.age == 1
		and plot.crop.days_watered == 1
		and plot.crop.days_total == 1,
		"load_save_data() restores money, day, inventory and plot/crop state (including watering history)"
	)

func test_season_boundaries() -> void:
	var clock := GameClock.new()
	clock.current_day = 1
	_check(clock.get_season() == GameClock.Season.ASARA, "day 1 is Asara")
	clock.current_day = 30
	_check(clock.get_season() == GameClock.Season.ASARA, "day 30 is still Asara")
	clock.current_day = 31
	_check(clock.get_season() == GameClock.Season.ASOTRY, "day 31 switches to Asotry")
	clock.current_day = 60
	_check(clock.get_season() == GameClock.Season.ASOTRY, "day 60 is still Asotry")
	clock.current_day = 61
	_check(clock.get_season() == GameClock.Season.ASARA, "day 61 returns to Asara")

func test_build_coop_deducts_money() -> void:
	var sim := _make_sim_with_chicken()
	var money_before := sim.state.money
	var ok := sim.build_coop()
	_check(
		ok and sim.state.money == money_before - FarmSimulation.COOP_COST and sim.state.has_coop,
		"build_coop() succeeds and deducts money"
	)

func test_cannot_build_coop_twice() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	var money_after_first := sim.state.money
	var ok := sim.build_coop()
	_check(not ok and sim.state.money == money_after_first, "build_coop() fails once a coop already exists")

func test_buy_chicken_adds_pending_animal() -> void:
	var sim := _make_sim_with_chicken()
	var money_before := sim.state.money
	var chicken_data := sim.get_animal_data(AnimalData.Species.CHICKEN)
	var ok := sim.buy_chicken(1)
	_check(
		ok and sim.state.money == money_before - chicken_data.purchase_price
		and sim.get_pending_count(AnimalData.Species.CHICKEN) == 1
		and sim.state.get_inventory_count("chicken_unplaced") == 0,
		"buy_chicken() deducts money and adds a chicken waiting to be settled (not an inventory item)"
	)

func test_cannot_place_chicken_without_coop() -> void:
	var sim := _make_sim_with_chicken()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	_check(id == "" and sim.get_all_animal_ids().is_empty(), "place_chicken() fails without a coop")

func test_place_chicken_creates_animal() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	_check(
		id != "" and sim.get_animal(id) != null and sim.get_animal(id).species == AnimalData.Species.CHICKEN
		and sim.get_pending_count(AnimalData.Species.CHICKEN) == 0,
		"place_chicken() settles a waiting chicken as a real animal"
	)

func test_place_chicken_respects_coop_capacity() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.state.coop_capacity = 1
	sim.state.money = 100000
	sim.buy_chicken(2)
	var first_id := sim.place_chicken()
	var second_id := sim.place_chicken()
	_check(
		first_id != "" and second_id == "" and sim.get_all_animal_ids().size() == 1,
		"place_chicken() refuses once the coop is at capacity"
	)

func test_feed_and_water_reset_hunger_and_thirst() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	sim.get_animal(id).hunger = 10.0
	sim.get_animal(id).thirst = 10.0
	sim.feed_animal(id)
	sim.water_animal(id)
	var animal := sim.get_animal(id)
	_check(
		animal.hunger == 100.0 and animal.thirst == 100.0 and animal.fed_today and animal.watered_today,
		"feed_animal()/water_animal() reset hunger/thirst and mark the day as cared-for"
	)

func test_unfed_animal_loses_hunger_on_advance_day() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	var chicken_data := sim.get_animal_data(AnimalData.Species.CHICKEN)
	sim.advance_day() # not fed/watered today
	_check(
		sim.get_animal(id).hunger == 100.0 - chicken_data.hunger_decay_per_day,
		"advance_day() decays hunger for an animal that wasn't fed"
	)

func test_fed_animal_keeps_care_streak() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	sim.feed_animal(id)
	sim.water_animal(id)
	sim.advance_day()
	_check(sim.get_animal(id).days_well_cared == 1, "advance_day() extends the well-cared streak when fed and watered")

func test_product_ready_signal_fires_after_cycle() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	var chicken_data := sim.get_animal_data(AnimalData.Species.CHICKEN)
	var received: Array = []
	sim.product_ready.connect(func(animal_id, product_id): received.append([animal_id, product_id]))
	for i in chicken_data.product_cycle_days:
		sim.feed_animal(id)
		sim.water_animal(id)
		sim.advance_day()
	_check(
		received.size() == 1 and received[0][0] == id and received[0][1] == "egg",
		"product_ready fires once an animal has been cared for through its product cycle"
	)

func test_breeding_creates_offspring_when_guaranteed() -> void:
	var sim := _make_sim_with_chicken(1.0) # force the roll to always succeed
	sim.build_coop()
	sim.state.money = 100000
	sim.buy_chicken(2)
	sim.place_chicken()
	sim.place_chicken()
	var chicken_data := sim.get_animal_data(AnimalData.Species.CHICKEN)
	for i in chicken_data.breeding_days_required:
		for id in sim.get_all_animal_ids():
			sim.feed_animal(id)
			sim.water_animal(id)
		sim.advance_day()
	_check(sim.get_all_animal_ids().size() == 3, "two well-cared adults breed a third chicken when the roll always succeeds")

func test_no_breeding_when_chance_is_zero() -> void:
	var sim := _make_sim_with_chicken(0.0)
	sim.build_coop()
	sim.state.money = 100000
	sim.buy_chicken(2)
	sim.place_chicken()
	sim.place_chicken()
	var chicken_data := sim.get_animal_data(AnimalData.Species.CHICKEN)
	for i in chicken_data.breeding_days_required:
		for id in sim.get_all_animal_ids():
			sim.feed_animal(id)
			sim.water_animal(id)
		sim.advance_day()
	_check(sim.get_all_animal_ids().size() == 2, "no breeding happens when breeding_chance is 0")

func test_sell_item_generic_path() -> void:
	var sim := _make_sim_with_chicken()
	sim.state.add_inventory("egg", 3)
	var money_before := sim.state.money
	var ok := sim.sell_item("egg", 6, 2)
	_check(
		ok and sim.state.money == money_before + 12 and sim.state.get_inventory_count("egg") == 1,
		"sell_item() sells a non-crop product at the given unit price"
	)

func test_animal_save_load_roundtrip() -> void:
	var sim := _make_sim_with_chicken()
	sim.build_coop()
	sim.buy_chicken(1)
	var id := sim.place_chicken()
	sim.feed_animal(id)
	sim.advance_day()

	var data := sim.to_save_data()
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim_with_chicken()
	fresh_sim.load_save_data(data)

	var animal := fresh_sim.get_animal(id)
	_check(
		fresh_sim.state.has_coop
		and animal != null
		and animal.species == AnimalData.Species.CHICKEN
		and animal.thirst < 100.0, # was not watered that day
		"load_save_data() restores coop status and animal state"
	)

func test_expand_grid_adds_new_plots() -> void:
	var sim := _make_sim() # starts at 4x4 = 16 plots
	sim.expand_grid(6, 4)
	_check(
		sim.grid_width == 6 and sim.grid_height == 4 and sim.get_all_plot_ids().size() == 24,
		"expand_grid() grows the grid and adds exactly the missing plots"
	)

func test_expand_grid_keeps_existing_plots_intact() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	sim.expand_grid(6, 6)
	var plot := sim.get_plot(0)
	_check(
		plot.tilled and plot.crop != null and plot.crop.crop_id == "corn",
		"expand_grid() never touches plots that already existed"
	)

func test_add_tile_creates_a_plot() -> void:
	var sim := _make_sim()
	var plot_id := sim.add_tile(10, 10)
	_check(
		plot_id != -1 and sim.get_plot_id_at(10, 10) == plot_id and sim.get_plot_position(plot_id) == Vector2i(10, 10),
		"add_tile() creates a plot at an arbitrary position, independent of grid_width"
	)

func test_add_tile_is_noop_if_already_occupied() -> void:
	var sim := _make_sim()
	var second_attempt := sim.add_tile(0, 0) # (0,0) already exists from the initial 4x4 grid
	_check(second_attempt == -1, "add_tile() refuses to overwrite an existing plot")

func test_remove_tile_deletes_the_plot() -> void:
	var sim := _make_sim()
	var ok := sim.remove_tile(0, 0)
	_check(
		ok and sim.get_plot_id_at(0, 0) == -1 and sim.get_all_plot_ids().size() == 15,
		"remove_tile() deletes the plot at that position"
	)

func test_remove_tile_discards_growing_crop() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	var ok := sim.remove_tile(0, 0)
	_check(ok and sim.get_plot(0) == null, "remove_tile() removes the plot even if a crop is growing on it")

func test_clear_tile_resets_without_removing() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	var ok := sim.clear_tile(0, 0)
	_check(
		ok and sim.get_plot(0) != null and not sim.get_plot(0).tilled and sim.get_plot(0).crop == null,
		"clear_tile() resets a plot to empty without removing it from the grid"
	)

func test_plot_added_and_removed_signals_fire() -> void:
	var sim := _make_sim()
	var added_ids: Array = []
	var removed_ids: Array = []
	sim.plot_added.connect(func(plot_id): added_ids.append(plot_id))
	sim.plot_removed.connect(func(plot_id): removed_ids.append(plot_id))

	var new_id := sim.add_tile(20, 20)
	sim.remove_tile(0, 0)

	_check(
		added_ids == [new_id] and removed_ids.size() == 1,
		"add_tile()/remove_tile() fire plot_added/plot_removed exactly once each"
	)

## The critical regression case for the old "id = y * width + x" scheme:
## resize the grid, remove a tile to create a hole, then round-trip through
## save/load and verify every plot lands back at its real (x, y) - not a
## position re-derived from a width that may have changed.
func test_grid_survives_resize_and_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.expand_grid(6, 4) # 4x4 -> 6x4, adds a new column (valid x: 0-5)
	sim.remove_tile(1, 1) # punch a hole
	var far_plot_id := sim.add_tile(6, 0) # one column beyond the expanded grid

	var data := sim.to_save_data()
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)

	_check(
		fresh_sim.get_plot_id_at(1, 1) == -1
		and fresh_sim.get_plot_position(far_plot_id) == Vector2i(6, 0)
		and fresh_sim.get_all_plot_ids().size() == sim.get_all_plot_ids().size(),
		"a resized grid with a hole in it round-trips through save/load at the correct positions"
	)

func test_buy_zone_unlocks_all_its_tiles() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var farm_land_manager := _make_farm_land_manager(sim)
	var ok := farm_land_manager.buy_zone("zone_east")

	var all_present := true
	for coordinates: Vector2i in farm_land_manager.get_zone_cells("zone_east"):
		if sim.get_plot_id_at(coordinates.x, coordinates.y) == -1:
			all_present = false
			break
	_check(
		ok and all_present and farm_land_manager.is_zone_unlocked("zone_east")
		and farm_land_manager.get_zone_tile_count("zone_east") == EAST_SIZE.x * EAST_SIZE.y,
		"buy_zone() unlocks every cell of the zone's field"
	)

func test_buy_zone_deducts_price() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var farm_land_manager := _make_farm_land_manager(sim)
	var zone_data := farm_land_manager.get_zone_data("zone_east")
	var money_before := sim.state.money

	farm_land_manager.buy_zone("zone_east")

	_check(sim.state.money == money_before - zone_data.price, "buy_zone() deducts the zone's price")

func test_cannot_buy_zone_twice() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var farm_land_manager := _make_farm_land_manager(sim)
	farm_land_manager.buy_zone("zone_east")
	var money_after_first := sim.state.money

	var ok := farm_land_manager.buy_zone("zone_east")

	_check(not ok and sim.state.money == money_after_first, "buy_zone() refuses to sell the same zone twice")

func test_cannot_buy_zone_without_enough_money() -> void:
	var sim := _make_sim()
	sim.state.money = 5
	var farm_land_manager := _make_farm_land_manager(sim)

	var ok := farm_land_manager.buy_zone("zone_east")

	_check(not ok and not farm_land_manager.is_zone_unlocked("zone_east"), "buy_zone() fails when money is insufficient")

func test_cannot_buy_unknown_zone() -> void:
	var sim := _make_sim()
	sim.state.money = 10000
	var farm_land_manager := _make_farm_land_manager(sim)

	var ok := farm_land_manager.buy_zone("does_not_exist")

	_check(not ok, "buy_zone() fails for an unknown zone id")

func test_buy_progressive_patch_unlocks_next_tiles_in_order() -> void:
	var sim := _make_sim()
	sim.state.money = 1000
	var farm_land_manager := _make_farm_land_manager(sim)

	var ok := farm_land_manager.buy_progressive_patch(9, 110)

	# The field is 8 wide, so the 9th tile (index 8) wraps into row y=10.
	_check(
		ok and farm_land_manager.get_progressive_unlocked_count() == 9
		and sim.get_plot_id_at(7, 9) != -1
		and sim.get_plot_id_at(0, 10) != -1
		and sim.get_plot_id_at(1, 10) == -1,
		"buy_progressive_patch() unlocks exactly patch_size tiles from the cursor, wrapping rows in fixed order"
	)

func test_buy_progressive_patch_second_purchase_continues_the_sequence() -> void:
	var sim := _make_sim()
	sim.state.money = 1000
	var farm_land_manager := _make_farm_land_manager(sim)

	farm_land_manager.buy_progressive_patch(1, 15)
	farm_land_manager.buy_progressive_patch(1, 15)

	_check(
		farm_land_manager.get_progressive_unlocked_count() == 2
		and sim.get_plot_id_at(0, 9) != -1
		and sim.get_plot_id_at(1, 9) != -1,
		"buying two single tiles unlocks the next two in sequence, never re-unlocking the same one"
	)

func test_buy_progressive_patch_respects_capacity() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var farm_land_manager := _make_farm_land_manager(sim)
	var capacity := farm_land_manager.get_progressive_capacity()

	var ok := farm_land_manager.buy_progressive_patch(capacity + 1, 999999)

	_check(
		not ok and farm_land_manager.get_progressive_unlocked_count() == 0,
		"buy_progressive_patch() refuses a patch bigger than the remaining capacity"
	)

func test_buy_progressive_patch_fails_without_enough_money() -> void:
	var sim := _make_sim()
	sim.state.money = 5
	var farm_land_manager := _make_farm_land_manager(sim)

	var ok := farm_land_manager.buy_progressive_patch(1, 15)

	_check(
		not ok and farm_land_manager.get_progressive_unlocked_count() == 0,
		"buy_progressive_patch() fails when money is insufficient"
	)

func test_zone_state_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var farm_land_manager := _make_farm_land_manager(sim)
	farm_land_manager.buy_zone("zone_east")
	farm_land_manager.buy_progressive_patch(9, 110)

	var data := sim.to_save_data()
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)
	var fresh_farm_land_manager := _make_farm_land_manager(fresh_sim)

	_check(
		fresh_farm_land_manager.is_zone_unlocked("zone_east")
		and fresh_farm_land_manager.get_progressive_unlocked_count() == 9
		and fresh_sim.get_plot_id_at(0, 9) != -1,
		"zone unlock state and progressive tile count survive a save/load roundtrip"
	)

func test_starter_field_registration_adds_its_plots() -> void:
	var sim := _make_sim()
	var farm_land_manager := _make_farm_land_manager(sim)
	var plots_before := sim.get_all_plot_ids().size()

	farm_land_manager.register_field(FarmField.Kind.STARTER, _rect_cells(Vector2i(20, 20), Vector2i(2, 2)))

	_check(
		sim.get_all_plot_ids().size() == plots_before + 4 and sim.get_plot_id_at(21, 21) != -1,
		"registering a STARTER field gives the player all its cells, no purchase needed"
	)

func test_registering_an_owned_zone_restores_missing_plots() -> void:
	var sim := _make_sim()
	sim.state.unlocked_zone_ids["zone_east"] = true # bought in a save, before the field grew

	_make_farm_land_manager(sim)

	_check(
		sim.get_plot_id_at(EAST_ORIGIN.x, EAST_ORIGIN.y) != -1
		and sim.get_plot_id_at(EAST_ORIGIN.x + EAST_SIZE.x - 1, EAST_ORIGIN.y + EAST_SIZE.y - 1) != -1,
		"registering an already-bought zone adds any of its cells that have no plot yet"
	)

func test_registering_a_locked_zone_adds_nothing() -> void:
	var sim := _make_sim()
	var plots_before := sim.get_all_plot_ids().size()

	_make_farm_land_manager(sim)

	_check(
		sim.get_all_plot_ids().size() == plots_before and sim.get_plot_id_at(EAST_ORIGIN.x, EAST_ORIGIN.y) == -1,
		"registering zones that aren't bought yet creates no plot"
	)

func test_progressive_registration_restores_bought_cells_only() -> void:
	var sim := _make_sim()
	sim.state.progressive_tiles_unlocked = 3 # from a save

	_make_farm_land_manager(sim)

	_check(
		sim.get_plot_id_at(2, 9) != -1 and sim.get_plot_id_at(3, 9) == -1,
		"registering the progressive field restores exactly its first bought cells, row by row"
	)

func test_tree_discovered_in_season_starts_ripe() -> void:
	var sim := _make_sim_with_mango() # day 1: Asara
	sim.register_tree(MANGO_TREE_ID, "mango_tree")
	_check(sim.can_harvest_tree(MANGO_TREE_ID), "a mango tree first seen in Asara starts with ripe fruit")

func test_tree_discovered_out_of_season_starts_bare() -> void:
	var sim := _make_sim_with_mango()
	sim.state.clock.current_day = 31 # Asotry
	sim.register_tree(MANGO_TREE_ID, "mango_tree")
	_check(
		not sim.can_harvest_tree(MANGO_TREE_ID) and sim.get_tree_days_until_fruit(MANGO_TREE_ID) == -1,
		"a mango tree first seen in Asotry has no fruit and none coming this season"
	)

func test_harvest_tree_adds_fruit_and_resets() -> void:
	var sim := _make_sim_with_mango()
	sim.register_tree(MANGO_TREE_ID, "mango_tree")
	var quantity := sim.harvest_tree(MANGO_TREE_ID)
	_check(
		quantity >= 2 and quantity <= 4
		and sim.state.get_inventory_count("mango") == quantity
		and not sim.can_harvest_tree(MANGO_TREE_ID)
		and sim.harvest_tree(MANGO_TREE_ID) == 0,
		"picking a ripe tree adds 2-4 mangoes, then it's bare until the next batch"
	)

func test_tree_ripens_after_its_cycle_in_season() -> void:
	var sim := _make_sim_with_mango()
	sim.register_tree(MANGO_TREE_ID, "mango_tree")
	sim.harvest_tree(MANGO_TREE_ID)
	for i in 3:
		sim.advance_day()
	var ripe_after_3 := sim.can_harvest_tree(MANGO_TREE_ID)
	var days_left := sim.get_tree_days_until_fruit(MANGO_TREE_ID)
	sim.advance_day()
	_check(
		not ripe_after_3 and days_left == 1 and sim.can_harvest_tree(MANGO_TREE_ID),
		"a picked mango tree is ripe again exactly fruit_cycle_days (4) days later"
	)

func test_tree_fruit_rots_at_season_end_and_waits_for_next_season() -> void:
	var sim := _make_sim_with_mango()
	sim.state.clock.current_day = 29
	sim.register_tree(MANGO_TREE_ID, "mango_tree") # ripe, not picked
	sim.advance_day() # -> day 30, last day of Asara
	var still_ripe_on_last_day := sim.can_harvest_tree(MANGO_TREE_ID)
	sim.advance_day() # -> day 31, Asotry
	var rotted := not sim.can_harvest_tree(MANGO_TREE_ID)
	for i in 30:
		sim.advance_day() # all of Asotry -> day 61, Asara again
	var bare_at_season_start := not sim.can_harvest_tree(MANGO_TREE_ID)
	for i in 4:
		sim.advance_day()
	_check(
		still_ripe_on_last_day and rotted and bare_at_season_start and sim.can_harvest_tree(MANGO_TREE_ID),
		"unpicked mangoes rot when Asara ends, nothing grows in Asotry, a new batch ripens 4 days into the next Asara"
	)

func test_decorative_or_unknown_trees_are_not_registered() -> void:
	var sim := _make_sim_with_mango()
	_check(
		not sim.register_tree("village:Decor", "decor_tree")
		and not sim.register_tree("village:Unknown", "baobab")
		and sim.state.trees.is_empty(),
		"fruitless or unregistered species are never tracked by the simulation"
	)

func test_tree_save_load_roundtrip() -> void:
	var sim := _make_sim_with_mango()
	sim.register_tree(MANGO_TREE_ID, "mango_tree")
	sim.harvest_tree(MANGO_TREE_ID)
	sim.advance_day()
	var data := sim.to_save_data()
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim_with_mango()
	fresh_sim.load_save_data(data)
	var tree := fresh_sim.get_tree_state(MANGO_TREE_ID)
	# Registering again (the zone loads after the save) must keep the saved state.
	fresh_sim.register_tree(MANGO_TREE_ID, "mango_tree")
	_check(
		tree != null and tree == fresh_sim.get_tree_state(MANGO_TREE_ID)
		and not tree.fruit_ready and tree.days_growing == 1,
		"tree ripeness survives a save/load, and re-registering on zone load keeps it"
	)

## Rice (grows_in_paddy) and corn, on a 4x4 grid whose plot 0 is a paddy.
func _make_sim_with_paddy() -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var rice: CropData = load("res://data/crops/rice.tres")
	var sim := FarmSimulation.new(4, 4, {"corn": corn, "rice": rice})
	sim.set_tile_flooded(0, 0, true)
	sim.rain_chance = {} # deterministic: no surprise rain
	return sim

func test_paddy_plots_grow_without_watering() -> void:
	var sim := _make_sim_with_paddy()
	sim.till(0)
	sim.state.add_inventory("rice_seed", 1)
	sim.plant(0, "rice")
	sim.advance_day()
	sim.advance_day()
	var crop := sim.get_plot(0).crop
	_check(crop.age == 2 and crop.days_watered == 2, "a paddy crop grows every day without the watering can")

func test_paddy_only_takes_paddy_crops() -> void:
	var sim := _make_sim_with_paddy()
	sim.till(0)
	sim.till(1)
	sim.state.add_inventory("corn_seed", 1)
	sim.state.add_inventory("rice_seed", 1)
	_check(
		not sim.can_plant(0, "corn") and sim.can_plant(0, "rice") and sim.can_plant(1, "rice") and sim.can_plant(1, "corn"),
		"a paddy only takes rice; dry land takes rice (upland rice) and everything else"
	)

func test_paddy_cannot_be_watered() -> void:
	var sim := _make_sim_with_paddy()
	sim.till(0)
	sim.state.add_inventory("rice_seed", 1)
	sim.plant(0, "rice")
	_check(not sim.can_water(0) and not sim.water(0), "the watering can does nothing on a paddy")

func test_paddy_flag_set_on_purchase_and_saved() -> void:
	var sim := _make_sim()
	var farm_land_manager := FarmLandManager.new()
	farm_land_manager.setup(sim)
	var cells := _rect_cells(Vector2i(100, 5), Vector2i(2, 2))
	farm_land_manager.register_field(FarmField.Kind.ZONE, cells, load("res://data/zones/riziere_haute.tres"), true)
	sim.state.money = 1000000
	farm_land_manager.buy_zone("riziere_haute")
	var plot_id := sim.get_plot_id_at(100, 5)
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)
	_check(
		sim.get_plot(plot_id).flooded and fresh_sim.get_plot(fresh_sim.get_plot_id_at(100, 5)).flooded
		and not fresh_sim.get_plot(fresh_sim.get_plot_id_at(0, 0)).flooded,
		"plots of a bought paddy field are flooded, and stay so after a save/load"
	)
	farm_land_manager.free()

func test_time_of_day_advances_in_whole_minutes() -> void:
	var sim := _make_sim()
	var emitted: Array = []
	sim.time_changed.connect(func(m: int): emitted.append(m))
	sim.advance_time(0.4)
	sim.advance_time(0.4) # 0.8: still no whole minute
	sim.advance_time(0.4) # 1.2 -> one minute
	sim.advance_time(2.0)
	_check(
		sim.state.clock.minute_of_day == 6 * 60 + 3 and emitted == [361, 363],
		"advance_time() adds up fractions and moves the clock (from 6:00) one whole minute at a time"
	)

func test_time_stops_at_two_in_the_morning() -> void:
	var sim := _make_sim()
	sim.advance_time(24 * 60)
	_check(
		sim.state.clock.minute_of_day == GameClock.LATEST_MINUTE and sim.state.clock.get_hour() == 2 and sim.state.day == 1,
		"time stops at 2:00 the night after, still the same day until the player sleeps"
	)

func test_sleeping_wakes_up_at_six() -> void:
	var sim := _make_sim()
	sim.advance_time(15 * 60)
	sim.advance_day()
	_check(sim.state.clock.minute_of_day == GameClock.DAY_START_MINUTE and sim.state.day == 2, "a new day starts at 6:00")

func test_time_of_day_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.advance_time(200)
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)
	data.erase("minute")
	var old_save_sim := _make_sim()
	old_save_sim.load_save_data(data)
	_check(
		fresh_sim.state.clock.minute_of_day == 6 * 60 + 200 and old_save_sim.state.clock.minute_of_day == GameClock.DAY_START_MINUTE,
		"the time of day survives a save/load; a save from before it wakes up at 6:00"
	)

func test_zones_have_separate_plot_grids() -> void:
	var sim := _make_sim()
	var village := sim.add_tile(20, 20, "village")
	var rice := sim.add_tile(20, 20, "rice_fields")
	sim.till(rice)
	_check(
		village != -1 and rice != -1 and village != rice
		and sim.get_plot_id_at(20, 20, "village") == village
		and sim.get_plot_id_at(20, 20, "rice_fields") == rice
		and sim.get_plot_id_at(20, 20) == -1
		and sim.get_plot_zone(rice) == "rice_fields"
		and not sim.get_plot(village).tilled,
		"the same cell in two zones is two different plots"
	)

func test_zone_plots_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.add_tile(2, 3, "rice_fields")
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)
	var plot_id := fresh_sim.get_plot_id_at(2, 3, "rice_fields")
	_check(plot_id != -1 and fresh_sim.get_plot_zone(plot_id) == "rice_fields", "a plot's zone survives a save/load")

func test_v5_save_migrates_plots_to_their_zone() -> void:
	# A v5 save: one grid, the rice fields at x >= 100 (their old grid_offset).
	var data := {"plots": {
		"0": {"x": 3, "y": 4, "tilled": true},
		"1": {"x": 104, "y": 6, "flooded": true},
	}, "next_plot_id": 2}
	var save_controller := SaveController.new()
	data = save_controller._migrate(data, 5)
	save_controller.free()
	var sim := _make_sim()
	sim.load_save_data(data)
	var village_plot := sim.get_plot_id_at(3, 4, "village")
	var rice_plot := sim.get_plot_id_at(4, 6, "rice_fields")
	_check(
		village_plot != -1 and sim.get_plot(village_plot).tilled
		and rice_plot != -1 and sim.get_plot(rice_plot).flooded
		and sim.get_plot_id_at(104, 6, "rice_fields") == -1,
		"migrating a v5 save puts each plot in its zone, the rice fields shifted back by their old offset"
	)

func test_harvest_reports_quantity_and_penalties() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.plant(0, "corn")
	var crop := sim.get_plot(0).crop
	crop.age = crop.growth_days
	crop.days_total = crop.growth_days
	crop.days_watered = 0 # never watered
	var reported: Array = []
	# Filled, not reassigned: a lambda can't reassign a local of its caller.
	sim.crop_harvested.connect(func(plot_id, crop_id, quantity, under_watered, off_season): reported.append_array([plot_id, crop_id, quantity, under_watered, off_season]))
	var before := sim.state.get_inventory_count("corn")
	sim.harvest(0)
	_check(
		reported.size() == 5 and reported[0] == 0 and reported[1] == "corn"
		and reported[2] == sim.state.get_inventory_count("corn") - before
		and reported[3] == true,
		"a harvest reports how much went into the bag, and that an under-watered crop was cut"
	)

func test_rain_waters_tilled_plots_only() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.set_weather(FarmState.Weather.RAIN)
	_check(sim.get_plot(0).watered and not sim.get_plot(1).watered and sim.is_raining(),
		"rain waters tilled plots, and leaves fallow ones dry")

func test_crops_grow_on_a_rainy_day_without_watering() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("corn_seed", 1)
	sim.set_weather(FarmState.Weather.RAIN) # woke up to rain...
	sim.plant(0, "corn") # ...and planted afterwards
	sim.advance_day()
	_check(sim.get_plot(0).crop.age == 1, "a crop planted on a rainy day grows without the watering can")

func test_weather_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.set_weather(FarmState.Weather.RAIN)
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)
	data.erase("weather")
	var old_save_sim := _make_sim()
	old_save_sim.load_save_data(data)
	_check(fresh_sim.is_raining() and not old_save_sim.is_raining(),
		"today's weather survives a save/load; a save from before it has a clear day")

func test_rain_is_much_more_likely_in_asara() -> void:
	seed(1234)
	var sim := _make_sim()
	sim.rain_chance = FarmSimulation.RAIN_CHANCE.duplicate()
	var rainy := {GameClock.Season.ASARA: 0, GameClock.Season.ASOTRY: 0}
	for season_start in [1, 31]: # first day of Asara, of Asotry
		for i in 2000:
			sim.state.clock.current_day = season_start
			if sim._roll_weather() == FarmState.Weather.RAIN:
				rainy[sim.state.clock.get_season()] += 1
	var asara: float = rainy[GameClock.Season.ASARA] / 2000.0
	var asotry: float = rainy[GameClock.Season.ASOTRY] / 2000.0
	_check(absf(asara - 0.45) < 0.04 and absf(asotry - 0.08) < 0.03,
		"it rains on ~45%% of Asara days and ~8%% of Asotry days (%.2f / %.2f)" % [asara, asotry])

func test_villager_routine_steps() -> void:
	var data := VillagerData.new()
	var routine: Array[VillagerStop] = []
	for entry in [[7, 0, "Marche"], [12, 30, "Banc"], [22, 0, "Maison"]]:
		var stop := VillagerStop.new()
		stop.hour = entry[0]
		stop.minute = entry[1]
		stop.spot = entry[2]
		routine.append(stop)
	data.routine = routine
	var at := func(minute: int) -> String:
		var stop := data.get_stop(minute)
		return stop.spot if stop != null else "home"
	_check(at.call(6 * 60 + 30) == "home" and at.call(7 * 60) == "Marche" and at.call(12 * 60 + 29) == "Marche"
			and at.call(15 * 60) == "Banc" and at.call(23 * 60) == "Maison" and at.call(60) == "Maison",
		"a villager's routine: home before the first step, each step until the next, the evening's last one past midnight")
