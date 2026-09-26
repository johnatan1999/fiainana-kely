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
	return FarmSimulation.new(4, 4, {"corn": corn})

## duplicate() so each test gets its own AnimalData instance - mutating
## breeding_chance for one test must never leak into another via the
## shared ResourceLoader cache.
func _make_sim_with_chicken(breeding_chance: float = 0.25) -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var chicken: AnimalData = load("res://data/animals/chicken.tres").duplicate()
	chicken.breeding_chance = breeding_chance
	return FarmSimulation.new(4, 4, {"corn": corn}, {AnimalData.Species.CHICKEN: chicken})

## FarmLandManager extends Node but is never added to the tree in these tests -
## fine, since buy_zone()/buy_progressive_patch() never touch tree-dependent
## APIs unless set_zone_markers() is called (it isn't here).
func _make_farm_land_manager(simulation: FarmSimulation) -> FarmLandManager:
	var farm_land_manager := FarmLandManager.new()
	farm_land_manager.setup(simulation)
	return farm_land_manager

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
	var zone_data := farm_land_manager.get_zone_data("zone_east")

	var ok := farm_land_manager.buy_zone("zone_east")

	var all_present := true
	for coordinates: Vector2i in zone_data.get_tile_coordinates():
		if sim.get_plot_id_at(coordinates.x, coordinates.y) == -1:
			all_present = false
			break
	_check(
		ok and all_present and farm_land_manager.is_zone_unlocked("zone_east"),
		"buy_zone() unlocks every tile in the zone's rectangle"
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

	# PROGRESSIVE_WIDTH is 8, so the 9th tile (index 8) wraps into row y=10.
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
