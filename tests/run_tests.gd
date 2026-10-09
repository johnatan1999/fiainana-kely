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
const MANGO_TREE_ID := "village:TreeGroup/MangoTree"

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
	test_v6_save_moves_the_farm_out_of_the_village()
	test_v7_save_moves_ids_to_english()
	test_harvest_reports_quantity_and_penalties()
	test_rain_waters_tilled_plots_only()
	test_crops_grow_on_a_rainy_day_without_watering()
	test_weather_save_load_roundtrip()
	test_rain_is_much_more_likely_in_the_rainy_season()
	test_villager_routine_steps()
	test_villager_weekday_steps()
	test_weekday_calendar()
	test_zebus_bought_grow_and_sell()
	test_zebu_pen_capacity_and_money()
	test_zebus_save_load()
	test_ploughing_needs_a_strong_team()
	test_ploughing_tires_the_team()
	test_zebus_make_manure()
	test_manure_grows_a_bigger_harvest()
	test_neighbour_harvest_follows_the_calendar()
	test_helping_the_neighbours_harvest()
	test_neighbour_harvest_save_load_and_new_season()
	test_orders_only_what_the_player_can_get()
	test_order_accept_and_deliver()
	test_orders_run_out_without_penalty()
	test_orders_at_most_three_at_once()
	test_orders_save_load()
	test_friendship_talking_counts_once_a_day()
	test_friendship_hearts_and_gifts()
	test_friendship_better_order_price()
	test_friendship_save_load()
	test_school_fees_billed_a_week_before_the_season()
	test_school_fees_overdue_sends_fara_home()
	test_school_fees_paid_in_part()
	test_school_fees_paid_in_rice()
	test_school_debt_adds_up_and_keeps_its_due_day()
	test_school_fees_save_load()
	test_villager_steps_on_conditions()
	test_rooster_given_once()
	test_rooster_grows_with_care()
	test_cockfight_on_sunday_afternoon_only()
	test_cockfight_bouts_follow_the_powers()
	test_cockfight_villagers_fight_their_bouts()
	test_cockfight_season_champion()
	test_rooster_and_cockfight_save_load()
	test_save_slots_write_and_read()
	test_save_slots_keep_the_night_before()
	test_save_slots_delete()
	test_save_slots_migrate_the_old_save()
	test_day_log_counts_the_day()
	test_day_log_starts_afresh()
	test_tomorrow_plans()
	test_evening_plurals()

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
	_check(clock.get_season() == GameClock.Season.RAINY, "day 1 is Asara")
	clock.current_day = 30
	_check(clock.get_season() == GameClock.Season.RAINY, "day 30 is still Asara")
	clock.current_day = 31
	_check(clock.get_season() == GameClock.Season.DRY, "day 31 switches to Asotry")
	clock.current_day = 60
	_check(clock.get_season() == GameClock.Season.DRY, "day 60 is still Asotry")
	clock.current_day = 61
	_check(clock.get_season() == GameClock.Season.RAINY, "day 61 returns to Asara")

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
	farm_land_manager.register_field(FarmField.Kind.ZONE, cells, load("res://data/zones/upper_paddy.tres"), true)
	sim.state.money = 1000000
	farm_land_manager.buy_zone("upper_paddy")
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
	# v6 put it in the village, v7 moved the village's fields to the farm.
	var farm_plot := sim.get_plot_id_at(3, 4, "farm")
	var rice_plot := sim.get_plot_id_at(4, 6, "rice_fields")
	_check(
		farm_plot != -1 and sim.get_plot(farm_plot).tilled
		and rice_plot != -1 and sim.get_plot(rice_plot).flooded
		and sim.get_plot_id_at(104, 6, "rice_fields") == -1,
		"migrating a v5 save puts each plot in its zone, the rice fields shifted back by their old offset"
	)

func test_v6_save_moves_the_farm_out_of_the_village() -> void:
	var data := {
		"plots": {
			"0": {"x": 3, "y": 4, "zone": "village", "tilled": true},
			"1": {"x": 4, "y": 6, "zone": "rice_fields", "flooded": true},
		},
		"next_plot_id": 2,
		"trees": {
			"village:Trees/Verger_Manguier_02": {"type": "mango_tree", "fruit_ready": true, "days_growing": 0},
			"village:Trees/MangoTree": {"type": "mango_tree", "fruit_ready": false, "days_growing": 3},
		},
		"return_point": {"zone": "village", "spawn": "HouseGroup/House/ExitSpawn"},
		"zone_id": "village",
		"player_position": {"x": 900.0, "y": 600.0},
	}
	var save_controller := SaveController.new()
	data = save_controller._migrate(data, 6)
	save_controller.free()
	var trees: Dictionary = data["trees"]
	_check(data["plots"]["0"]["zone"] == "farm" and data["plots"]["1"]["zone"] == "rice_fields"
			and trees.has("farm:Trees/Orchard_MangoTree_02") and trees.has("village:Trees/MangoTree")
			and not trees.has("village:Trees/Verger_Manguier_02")
			and data["return_point"]["zone"] == "farm" and data["zone_id"] == "farm",
		"migrating a v6 save moves the farm's plots, orchard, house exit and the player in it to the farm zone")

func test_v7_save_moves_ids_to_english() -> void:
	var data := {
		"plots": {"0": {"x": 3, "y": 4, "zone": "bourg"}},
		"trees": {
			"village:Trees/Haie_Sud_1_01": {"type": "eucalyptus"},
			"bourg:Trees/Manga_Tsena_01": {"type": "mango_tree"},
		},
		"neighbour_harvest": {"rice_fields:Riziere1": {"season": 1, "cut": []}},
		"inventory": {"tool_angady": 1, "food_vary_sy_laoka": 2, "corn": 3},
		"hotbar": ["tool_hoe", "tool_angady", ""],
		"orders": {"neny_soa": {"item": "food_vary_amin_anana", "quantity": 1}},
		"unlocked_zone_ids": ["riziere_haute", "tany_lonaka_sud"],
		"return_point": {"zone": "village", "spawn": "HouseGroup/TranoKely01/ExitSpawn"},
		"zone_id": "bourg",
	}
	var save_controller := SaveController.new()
	data = save_controller._migrate(data, 7)
	save_controller.free()
	_check(data["zone_id"] == "market_town" and data["plots"]["0"]["zone"] == "market_town"
			and data["trees"].has("village:Trees/Hedge_South_1_01")
			and data["trees"].has("market_town:Trees/Mango_Market_01")
			and data["neighbour_harvest"].has("rice_fields:Paddy1")
			and data["inventory"] == {"tool_spade": 1, "food_rice_and_side_dish": 2, "corn": 3}
			and data["hotbar"] == ["tool_hoe", "tool_spade", ""]
			and data["orders"]["neny_soa"]["item"] == "food_rice_with_greens"
			and data["unlocked_zone_ids"] == ["upper_paddy", "fertile_land_south"]
			and data["return_point"]["spawn"] == "HouseGroup/HouseSmall01/ExitSpawn",
		"migrating a v7 save moves zone, tree, paddy, item and farm zone ids and node paths to English")

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

func test_rain_is_much_more_likely_in_the_rainy_season() -> void:
	seed(1234)
	var sim := _make_sim()
	sim.rain_chance = FarmSimulation.RAIN_CHANCE.duplicate()
	var rainy := {GameClock.Season.RAINY: 0, GameClock.Season.DRY: 0}
	for season_start in [1, 31]: # first day of Asara, of Asotry
		for i in 2000:
			sim.state.clock.current_day = season_start
			if sim._roll_weather() == FarmState.Weather.RAIN:
				rainy[sim.state.clock.get_season()] += 1
	var rainy_rate: float = rainy[GameClock.Season.RAINY] / 2000.0
	var dry_rate: float = rainy[GameClock.Season.DRY] / 2000.0
	_check(absf(rainy_rate - 0.45) < 0.04 and absf(dry_rate - 0.08) < 0.03,
		"it rains on ~45%% of Asara days and ~8%% of Asotry days (%.2f / %.2f)" % [rainy_rate, dry_rate])

func test_villager_routine_steps() -> void:
	var data := VillagerData.new()
	var routine: Array[VillagerStop] = []
	for entry in [[7, 0, "Market"], [12, 30, "Bench"], [22, 0, "House"]]:
		var stop := VillagerStop.new()
		stop.hour = entry[0]
		stop.minute = entry[1]
		stop.spot = entry[2]
		routine.append(stop)
	data.routine = routine
	var at := func(minute: int) -> String:
		var stop := data.get_stop(minute, GameClock.Weekday.TUESDAY)
		return stop.spot if stop != null else "home"
	_check(at.call(6 * 60 + 30) == "home" and at.call(7 * 60) == "Market" and at.call(12 * 60 + 29) == "Market"
			and at.call(15 * 60) == "Bench" and at.call(23 * 60) == "House" and at.call(60) == "House",
		"a villager's routine: home before the first step, each step until the next, the evening's last one past midnight")

func test_villager_weekday_steps() -> void:
	var data := VillagerData.new()
	var routine: Array[VillagerStop] = []
	for entry in [[7, 0, "Square", []], [8, 0, "School", [GameClock.Weekday.MONDAY, GameClock.Weekday.FRIDAY]]]:
		var stop := VillagerStop.new()
		stop.hour = entry[0]
		stop.spot = entry[2]
		stop.days = VillagerStop.days_mask(entry[3])
		routine.append(stop)
	data.routine = routine
	_check(data.get_stop(9 * 60, GameClock.Weekday.FRIDAY).spot == "School"
			and data.get_stop(9 * 60, GameClock.Weekday.SUNDAY).spot == "Square",
		"a step with weekdays only happens on them; on other days the previous step goes on")

func test_zebus_bought_grow_and_sell() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var zebu_id := sim.buy_zebu(0)
	_check(zebu_id != "" and sim.state.money == 100000 - FarmSimulation.ZEBU_PRICE
			and sim.get_zebu(zebu_id)["name"] == "Mena"
			and sim.get_zebu_value(zebu_id) == FarmSimulation.ZEBU_CALF_VALUE,
		"a young zebu costs ZEBU_PRICE, is named after its coat, and is worth less than its price at first")
	sim.advance_day() # trough empty: no growth
	_check(sim.get_zebu(zebu_id)["grown_days"] == 0, "a zebu doesn't grow on a day its trough stayed empty")
	_check(sim.fill_zebu_trough() and not sim.fill_zebu_trough(), "the trough is filled once a day")
	sim.advance_day()
	_check(sim.get_zebu(zebu_id)["grown_days"] == 1 and not sim.is_zebu_trough_full(),
		"a full trough: a day of growth, and it's empty again the next morning")
	sim.set_weather(FarmState.Weather.RAIN)
	_check(sim.is_zebu_trough_full(), "the rain fills the trough")
	for i in FarmSimulation.ZEBU_GROW_DAYS + 5:
		sim.fill_zebu_trough()
		sim.advance_day()
	_check(sim.is_zebu_grown(zebu_id) and sim.get_zebu_value(zebu_id) == FarmSimulation.ZEBU_ADULT_VALUE,
		"after ZEBU_GROW_DAYS days of care, a grown zebu is worth ZEBU_ADULT_VALUE")
	var money := sim.state.money
	_check(sim.sell_zebu(zebu_id) == FarmSimulation.ZEBU_ADULT_VALUE
			and sim.state.money == money + FarmSimulation.ZEBU_ADULT_VALUE and sim.get_zebu_ids().is_empty(),
		"selling a zebu pays its worth and takes it out of the herd")

func test_zebu_pen_capacity_and_money() -> void:
	var sim := _make_sim()
	sim.state.money = FarmSimulation.ZEBU_PRICE - 1
	_check(sim.buy_zebu() == "", "no zebu without the money")
	sim.state.money = 1000000
	for i in FarmSimulation.ZEBU_PEN_CAPACITY:
		sim.buy_zebu(0)
	var names := sim.get_zebu_ids().map(func(zebu_id: String) -> String: return sim.get_zebu(zebu_id)["name"])
	_check(sim.buy_zebu() == "" and sim.get_zebu_ids().size() == FarmSimulation.ZEBU_PEN_CAPACITY
			and names == ["Mena", "Mena 2", "Mena 3", "Mena 4"],
		"the pen holds ZEBU_PEN_CAPACITY zebus; same coats get numbered names")
	_check(not _make_sim().fill_zebu_trough(), "no trough to fill without zebus")

func test_zebus_save_load() -> void:
	var sim := _make_sim()
	sim.state.money = 100000
	var zebu_id := sim.buy_zebu(3)
	sim.fill_zebu_trough()
	sim.advance_day()
	sim.fill_zebu_trough()
	var data: Dictionary = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var other := _make_sim()
	other.load_save_data(data)
	_check(other.get_zebu(zebu_id) == {"name": "Mainty", "coat": 3, "grown_days": 1}
			and other.is_zebu_trough_full() and other.buy_zebu(3) == "zebu_1",
		"zebus, their growth and today's trough survive a save/load")

func test_ploughing_needs_a_strong_team() -> void:
	var sim := _make_sim()
	sim.state.money = 1000000
	var plot_id: int = sim.get_all_plot_ids()[0]
	sim.buy_zebu(0)
	_check(sim.check_plough() == FarmSimulation.PloughCheck.NO_TEAM and not sim.plough(plot_id),
		"no ploughing with a single zebu")
	sim.buy_zebu(1)
	_check(sim.check_plough() == FarmSimulation.PloughCheck.NO_TEAM,
		"no ploughing with two calves: they must be strong enough")
	for zebu_id: String in sim.get_zebu_ids():
		sim.state.zebus[zebu_id]["grown_days"] = FarmSimulation.ZEBU_WORK_MIN_DAYS
	_check(sim.check_plough() == FarmSimulation.PloughCheck.OK and sim.plough(plot_id)
			and sim.get_plot(plot_id).tilled and sim.state.plough_cells_today == 1,
		"two zebus of ZEBU_WORK_MIN_DAYS plough a plot")
	_check(not sim.plough(plot_id), "an already tilled plot isn't ploughed again")

func test_ploughing_tires_the_team() -> void:
	var sim := _make_sim()
	sim.state.money = 1000000
	for coat in 2:
		var zebu_id := sim.buy_zebu(coat)
		sim.state.zebus[zebu_id]["grown_days"] = FarmSimulation.ZEBU_GROW_DAYS
	sim.state.plough_cells_today = FarmSimulation.PLOUGH_CELLS_PER_DAY
	var plot_id: int = sim.get_all_plot_ids()[0]
	_check(sim.check_plough() == FarmSimulation.PloughCheck.TIRED and not sim.plough(plot_id)
			and sim.get_plough_cells_left() == 0,
		"after PLOUGH_CELLS_PER_DAY plots the team is tired")
	var data: Dictionary = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var other := _make_sim()
	other.load_save_data(data)
	_check(other.state.plough_cells_today == FarmSimulation.PLOUGH_CELLS_PER_DAY,
		"the team's tiredness survives a save/load")
	sim.advance_day()
	_check(sim.check_plough() == FarmSimulation.PloughCheck.OK and sim.plough(plot_id),
		"rested the next morning")

func test_zebus_make_manure() -> void:
	var sim := _make_sim()
	sim.state.money = 1000000
	sim.buy_zebu(0)
	sim.buy_zebu(1)
	sim.advance_day() # trough empty
	_check(sim.get_manure_pile() == 0, "no manure from zebus left without water and hay")
	sim.fill_zebu_trough()
	sim.advance_day()
	_check(sim.get_manure_pile() == 2 * FarmSimulation.MANURE_PER_ZEBU,
		"each zebu cared for leaves its manure on the heap")
	for i in 20:
		sim.fill_zebu_trough()
		sim.advance_day()
	_check(sim.get_manure_pile() == FarmSimulation.MANURE_PILE_MAX, "the heap stops growing at MANURE_PILE_MAX")
	var data: Dictionary = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var other := _make_sim()
	other.load_save_data(data)
	_check(other.get_manure_pile() == FarmSimulation.MANURE_PILE_MAX, "the heap survives a save/load")
	_check(sim.collect_manure() == FarmSimulation.MANURE_PILE_MAX and sim.get_manure_pile() == 0
			and sim.state.get_inventory_count(FarmSimulation.MANURE_ITEM) == FarmSimulation.MANURE_PILE_MAX,
		"picking up the heap puts it all in the inventory")

func test_manure_grows_a_bigger_harvest() -> void:
	var sim := _make_sim()
	var corn: CropData = sim.get_crop_data("corn")
	var plain: int = sim.get_all_plot_ids()[0]
	var manured: int = sim.get_all_plot_ids()[1]
	_check(not sim.can_fertilize(manured), "no fertilizing without manure")
	sim.state.add_inventory(FarmSimulation.MANURE_ITEM, 2)
	_check(not sim.fertilize(manured), "fallow ground isn't fertilized: till it first")
	sim.till(plain)
	sim.till(manured)
	_check(sim.fertilize(manured) and not sim.fertilize(manured)
			and sim.state.get_inventory_count(FarmSimulation.MANURE_ITEM) == 1,
		"a tilled plot takes manure once")
	for plot_id in [plain, manured]:
		sim.state.add_inventory("corn_seed", 1)
		sim.plant(plot_id, "corn")
	for i in corn.growth_days:
		sim.water(plain)
		sim.water(manured)
		sim.advance_day()
	seed(7)
	sim.harvest(plain)
	var plain_yield := sim.state.get_inventory_count("corn")
	seed(7)
	sim.harvest(manured)
	var manured_yield := sim.state.get_inventory_count("corn") - plain_yield
	var data: Dictionary = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	_check(manured_yield == ceili(plain_yield * FarmSimulation.MANURE_YIELD_MULTIPLIER)
			and not sim.get_plot(manured).fertilized,
		"a fertilized plot's harvest is MANURE_YIELD_MULTIPLIER bigger, and uses the manure up")
	sim.fertilize(plain)
	data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var other := _make_sim()
	other.load_save_data(data)
	_check(other.get_plot(plain).fertilized, "a plot's manure survives a save/load")

func test_weekday_calendar() -> void:
	var clock := GameClock.new()
	_check(clock.get_weekday() == GameClock.Weekday.MONDAY and clock.days_to_market() == 4,
		"day 1 is an Alatsinainy, four days before the zoma")
	for i in 4:
		clock.advance_day()
	_check(clock.is_market_day() and clock.days_to_market() == 0
			and GameClock.get_weekday_name(clock.get_weekday()) == "Zoma",
		"day 5 is the zoma, market day")
	for i in 3:
		clock.advance_day()
	_check(clock.get_weekday() == GameClock.Weekday.MONDAY and clock.days_to_market() == 4,
		"the week starts again on day 8")

func _make_sim_with_neighbour_paddy() -> FarmSimulation:
	var sim := _make_sim()
	sim.register_neighbour_paddy("rice_fields:Paddy1", Vector2i(5, 4))
	return sim

func test_neighbour_harvest_follows_the_calendar() -> void:
	var sim := _make_sim_with_neighbour_paddy()
	var clock := sim.state.clock
	clock.current_day = 5
	var young := sim.get_neighbour_rice_stage()
	clock.current_day = 24
	var ripe := sim.get_neighbour_rice_stage()
	var before := sim.get_neighbour_harvest_progress()
	clock.current_day = 27
	clock.minute_of_day = 6 * 60 + 30
	var mid := sim.get_neighbour_harvest_progress()
	clock.current_day = 29
	var done := sim.get_neighbour_harvest_progress()
	_check(young == 1 and ripe == 3 and before == 0.0 and absf(mid - 1.0 / 3.0) < 0.01 and done == 1.0
			and not sim.is_neighbour_harvest_on(),
		"the neighbours' rice: planted out, ripe late in the season, cut over the harvest days")

func test_helping_the_neighbours_harvest() -> void:
	var sim := _make_sim_with_neighbour_paddy()
	var paddy := "rice_fields:Paddy1"
	var clock := sim.state.clock
	clock.current_day = 20
	var too_early := sim.help_neighbour_harvest(paddy, Vector2i(4, 3))
	clock.current_day = 27
	clock.minute_of_day = 6 * 60 + 30 # the farmers have cut the first third
	var by_farmers := sim.help_neighbour_harvest(paddy, Vector2i(0, 0))
	var seeds := sim.state.get_inventory_count("rice_seed")
	var helped := sim.help_neighbour_harvest(paddy, Vector2i(4, 3))
	var twice := sim.help_neighbour_harvest(paddy, Vector2i(4, 3))
	var outside := sim.help_neighbour_harvest(paddy, Vector2i(9, 9))
	_check(too_early == 0 and by_farmers == 0 and helped == 1 and twice == 0 and outside == 0
			and sim.state.get_inventory_count("rice_seed") == seeds + 1
			and sim.is_neighbour_tuft_cut(paddy, Vector2i(4, 3)) and not sim.is_neighbour_tuft_cut(paddy, Vector2i(4, 2)),
		"helping the neighbours: a standing tuft cut at harvest time earns seed rice, once")

func test_neighbour_harvest_save_load_and_new_season() -> void:
	var sim := _make_sim_with_neighbour_paddy()
	var paddy := "rice_fields:Paddy1"
	sim.state.clock.current_day = 26
	sim.help_neighbour_harvest(paddy, Vector2i(4, 3))
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var loaded := _make_sim_with_neighbour_paddy()
	loaded.load_save_data(data)
	var kept := loaded.is_neighbour_tuft_cut(paddy, Vector2i(4, 3))
	loaded.state.clock.current_day = 31 # the next season: replanted
	_check(kept and not loaded.is_neighbour_tuft_cut(paddy, Vector2i(4, 3)) and loaded.get_neighbour_tufts_helped(paddy) == 0,
		"the tufts the player cut survive a save/load, and the next season starts afresh")

## A sim with corn (Asara), sweet potato (Asotry), cassava (all year) and
## rice (paddy), every order offered (chance 1).
func _make_sim_for_orders() -> FarmSimulation:
	var crops := {}
	for crop_id in ["corn", "sweet_potato", "cassava", "rice"]:
		crops[crop_id] = load("res://data/crops/%s.tres" % crop_id)
	var sim := FarmSimulation.new(4, 4, crops)
	sim.rain_chance = {}
	sim.order_offer_chance = 1.0
	return sim

func _order(item_id: String, quantity: int, unit_reward: int, days: int) -> OrderTemplate:
	var template := OrderTemplate.new()
	template.item_id = item_id
	template.quantity = Vector2i(quantity, quantity)
	template.unit_reward = unit_reward
	template.days = days
	return template

func test_orders_only_what_the_player_can_get() -> void:
	var sim := _make_sim_for_orders() # day 1: Asara, no paddy, no hens
	var dry_season_crop: Array[OrderTemplate] = [_order("sweet_potato", 3, 2000, 8)]
	var needs_paddy: Array[OrderTemplate] = [_order("rice", 5, 5500, 14)]
	var no_hens: Array[OrderTemplate] = [_order("egg", 2, 1000, 4)]
	var too_slow: Array[OrderTemplate] = [_order("cassava", 4, 1500, 5)] # grows in 8 days
	var fine: Array[OrderTemplate] = [_order("corn", 4, 1700, 7)]
	sim.register_order_giver("a", dry_season_crop)
	sim.register_order_giver("b", needs_paddy)
	sim.register_order_giver("c", no_hens)
	sim.register_order_giver("d", too_slow)
	sim.register_order_giver("e", fine)
	sim.refresh_order_offers()
	_check(sim.is_order_offered("e") and not sim.is_order_offered("a") and not sim.is_order_offered("b")
			and not sim.is_order_offered("c") and not sim.is_order_offered("d"),
		"orders: only offered when the player can get the items in time (in season, a paddy for rice, hens for eggs, time to grow)")

func test_order_accept_and_deliver() -> void:
	var sim := _make_sim_for_orders()
	var templates: Array[OrderTemplate] = [_order("corn", 4, 1700, 7)]
	sim.register_order_giver("ravao", templates)
	sim.refresh_order_offers()
	var money := sim.state.money
	var accepted := sim.accept_order("ravao")
	var deadline: int = sim.get_order("ravao")["deadline"]
	var early := sim.deliver_order("ravao") # nothing to give yet
	sim.state.add_inventory("corn", 5)
	var paid := sim.deliver_order("ravao")
	_check(accepted and deadline == 7 and early == 0 and paid == 4 * 1700 and sim.state.money == money + paid
			and sim.state.get_inventory_count("corn") == 1 and sim.get_order("ravao").is_empty()
			and sim.state.order_cooldowns["ravao"] == 1 + FarmSimulation.ORDER_COOLDOWN_DAYS,
		"orders: accepted with 7 days to deliver, paid 1700 Ar a corn once the 4 are brought, then a pause")

func test_orders_run_out_without_penalty() -> void:
	var sim := _make_sim_for_orders()
	var templates: Array[OrderTemplate] = [_order("corn", 4, 1700, 5)]
	sim.register_order_giver("koto", templates)
	sim.register_order_giver("mother", templates.duplicate())
	sim.refresh_order_offers()
	sim.accept_order("koto") # deadline: day 5
	var expired := []
	sim.order_expired.connect(func(id: String): expired.append(id))
	var money := sim.state.money
	sim.advance_day()
	sim.advance_day() # day 3
	var offer_gone := not sim.is_order_offered("mother") # offered day 1, not taken in 2 days
	sim.advance_day()
	sim.advance_day() # day 5: the last day
	var still_on := sim.is_order_active("koto")
	sim.advance_day() # day 6
	_check(still_on and offer_gone and not sim.is_order_active("koto") and expired == ["koto"] and sim.state.money == money,
		"orders: an offer not taken goes after 2 days; an accepted one runs out after its last day, with nothing lost")

func test_orders_at_most_three_at_once() -> void:
	var sim := _make_sim_for_orders()
	for id in ["a", "b", "c", "d"]:
		var templates: Array[OrderTemplate] = [_order("corn", 2, 1700, 7)]
		sim.register_order_giver(id, templates)
	var accepted := 0
	for day in 3:
		sim.refresh_order_offers()
		for id in ["a", "b", "c", "d"]:
			if sim.accept_order(id):
				accepted += 1
		sim.state.order_roll_day = 0 # offer again
	_check(accepted == FarmSimulation.ORDER_MAX_ACTIVE and sim.get_active_orders().size() == 3,
		"orders: at most 3 accepted at once")

func test_orders_save_load() -> void:
	var sim := _make_sim_for_orders()
	var templates: Array[OrderTemplate] = [_order("corn", 4, 1700, 7)]
	sim.register_order_giver("ravao", templates)
	sim.refresh_order_offers()
	sim.accept_order("ravao")
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var loaded := _make_sim_for_orders()
	loaded.register_order_giver("ravao", templates)
	loaded.load_save_data(data)
	var order := loaded.get_order("ravao")
	_check(loaded.is_order_active("ravao") and order["quantity"] == 4 and order["reward"] == 6800
			and loaded.get_order_template("ravao") == templates[0],
		"orders: an accepted order survives a save/load")

func _gift(hearts: int, item_id: String, quantity: int) -> FriendshipReward:
	var gift := FriendshipReward.new()
	gift.hearts = hearts
	gift.item_id = item_id
	gift.quantity = quantity
	return gift

func test_friendship_talking_counts_once_a_day() -> void:
	var sim := _make_sim_for_orders()
	var first := sim.talk_to("ravao")
	var again := sim.talk_to("ravao")
	var points_today := sim.get_friendship("ravao")
	sim.advance_day()
	var tomorrow := sim.talk_to("ravao")
	_check(first and not again and points_today == FarmSimulation.FRIENDSHIP_TALK and tomorrow
			and sim.get_friendship("ravao") == 2 * FarmSimulation.FRIENDSHIP_TALK,
		"friendship: talking to a villager counts once a day")

func test_friendship_hearts_and_gifts() -> void:
	var sim := _make_sim_for_orders()
	var gifts: Array[FriendshipReward] = [_gift(2, "tomato_seed", 5)]
	sim.register_friend("ravao", gifts)
	var levels := []
	sim.friendship_level_up.connect(func(_id: String, hearts: int, reward: FriendshipReward): levels.append([hearts, reward != null]))
	sim.add_friendship("ravao", 250) # 2 hearts at once
	var seeds := sim.state.get_inventory_count("tomato_seed")
	sim.add_friendship("ravao", 10000)
	_check(levels.slice(0, 2) == [[1, false], [2, true]] and seeds == 5 and sim.get_hearts("ravao") == 5
			and sim.get_friendship("ravao") == 500 and sim.get_heart_progress("ravao") == 1.0,
		"friendship: a heart every 100 points up to 5, each heart reached once, its gift handed over")

func test_friendship_better_order_price() -> void:
	var sim := _make_sim_for_orders()
	var templates: Array[OrderTemplate] = [_order("corn", 4, 1700, 7)]
	sim.register_order_giver("ravao", templates)
	sim.refresh_order_offers()
	sim.accept_order("ravao")
	sim.state.add_inventory("corn", 4)
	sim.add_friendship("ravao", 200) # 2 hearts: +10 %
	var payment := sim.get_order_payment("ravao")
	var before := sim.get_friendship("ravao")
	var paid := sim.deliver_order("ravao")
	_check(payment == 6800 + 700 and paid == payment
			and sim.get_friendship("ravao") == before + FarmSimulation.FRIENDSHIP_ORDER,
		"friendship: 5 % more on a friend's order per heart, and a delivered order brings you closer")

func test_friendship_save_load() -> void:
	var sim := _make_sim_for_orders()
	sim.add_friendship("koto", 130)
	sim.talk_to("neny_soa")
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var loaded := _make_sim_for_orders()
	loaded.load_save_data(data)
	_check(loaded.get_friendship("koto") == 130 and loaded.get_hearts("koto") == 1 and not loaded.talk_to("neny_soa"),
		"friendship: points and today's talk survive a save/load")

# --- Fara's school fees -------------------------------------------------------------

func _make_sim_for_school() -> FarmSimulation:
	var corn: CropData = load("res://data/crops/corn.tres")
	var rice: CropData = load("res://data/crops/rice.tres")
	var sim: FarmSimulation = FarmSimulation.new(4, 4, {"corn": corn, "rice": rice})
	sim.rain_chance = {}
	sim.order_offer_chance = 0.0
	return sim

func _advance_to_day(sim: FarmSimulation, day: int) -> void:
	while sim.state.day < day:
		sim.advance_day()

func test_school_fees_billed_a_week_before_the_season() -> void:
	var sim := _make_sim_for_school()
	var billed := [0]
	sim.school_fees_changed.connect(func(): billed[0] += 1)
	_advance_to_day(sim, 23)
	var before := sim.get_school_debt()
	_advance_to_day(sim, 24)
	_check(before == 0 and sim.get_school_debt() == FarmSimulation.SCHOOL_FEE and billed[0] == 1
			and sim.get_school_days_left() == 14 and not sim.is_school_fees_overdue(),
		"school: the first season is paid; the next one's fees come a week before it starts, due a week into it")

func test_school_fees_overdue_sends_fara_home() -> void:
	var sim := _make_sim_for_school()
	_advance_to_day(sim, 37)
	var last_day := sim.get_school_days_left() == 1 and sim.get_conditions().is_empty()
	_advance_to_day(sim, 38)
	var overdue := sim.is_school_fees_overdue() 		and sim.get_conditions().has(FarmSimulation.CONDITION_SCHOOL_FEES_OVERDUE)
	sim.state.money = FarmSimulation.SCHOOL_FEE
	sim.pay_school_fees(FarmSimulation.SCHOOL_FEE)
	_check(last_day and overdue and not sim.is_school_fees_overdue() and sim.get_conditions().is_empty(),
		"school: unpaid past the due day, Fara stays home - paying sends her back")

func test_school_fees_paid_in_part() -> void:
	var sim := _make_sim_for_school()
	_advance_to_day(sim, 24)
	sim.state.money = 3000
	var paid := sim.pay_school_fees(FarmSimulation.SCHOOL_FEE)
	var nothing_left := sim.pay_school_fees(FarmSimulation.SCHOOL_FEE)
	sim.state.money = 50000
	var rest := sim.pay_school_fees(50000)
	_check(paid == 3000 and nothing_left == 0 and rest == FarmSimulation.SCHOOL_FEE - 3000
			and sim.state.money == 50000 - rest and not sim.is_school_fee_due(),
		"school: fees can be paid in part, never more than owned or owed")

func test_school_fees_paid_in_rice() -> void:
	var sim := _make_sim_for_school()
	_advance_to_day(sim, 24)
	var price := sim.get_school_rice_price()
	sim.state.add_inventory("rice", 5)
	var given := sim.pay_school_fees_in_rice(10)
	var full := given == 2 and sim.state.get_inventory_count("rice") == 3 and not sim.is_school_fee_due()
	# Owing 7 000 Ar: two rice (10 000 Ar), 3 000 Ar back.
	var other := _make_sim_for_school()
	_advance_to_day(other, 24)
	other.state.money = 3000
	other.pay_school_fees(3000)
	other.state.add_inventory("rice", 2)
	var money_before := other.state.money
	var given_other := other.pay_school_fees_in_rice(2)
	_check(price == 5000 and full and given_other == 2 and not other.is_school_fee_due()
			and other.state.money == money_before + 2 * price - (FarmSimulation.SCHOOL_FEE - 3000),
		"school: rice is taken at the weekly market's price, only what's needed, the change given back")

func test_school_debt_adds_up_and_keeps_its_due_day() -> void:
	var sim := _make_sim_for_school()
	_advance_to_day(sim, 54)
	_check(sim.get_school_debt() == 2 * FarmSimulation.SCHOOL_FEE and sim.state.school_due_day == 37
			and sim.is_school_fees_overdue(),
		"school: an unpaid bill adds up with the next one, and keeps its due day")

func test_school_fees_save_load() -> void:
	var sim := _make_sim_for_school()
	_advance_to_day(sim, 24)
	sim.state.money = 4000
	sim.pay_school_fees(4000)
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var loaded := _make_sim_for_school()
	loaded.load_save_data(data)
	var same := loaded.get_school_debt() == FarmSimulation.SCHOOL_FEE - 4000 and loaded.state.school_due_day == 37 		and loaded.state.school_billed_season == 1
	# A save from before school fees, in the middle of the second season:
	# that season counts as paid, the next bill comes as usual.
	var old: Dictionary = data.duplicate(true)
	for key in ["school_debt", "school_due_day", "school_billed_season"]:
		old.erase(key)
	old["day"] = 45
	var from_old := _make_sim_for_school()
	from_old.load_save_data(old)
	from_old.advance_day()
	var quiet := not from_old.is_school_fee_due()
	_advance_to_day(from_old, 54)
	_check(same and quiet and from_old.get_school_debt() == FarmSimulation.SCHOOL_FEE and not from_old.is_school_fees_overdue(),
		"school: the fees survive a save/load; an older save starts with this season paid")

func test_villager_steps_on_conditions() -> void:
	var data := VillagerData.new()
	var routine: Array[VillagerStop] = []
	for entry in [["School", "", "late"], ["Mortar", "late", ""]]:
		var stop := VillagerStop.new()
		stop.hour = 7
		stop.spot = entry[0]
		stop.only_if = entry[1]
		stop.unless = entry[2]
		routine.append(stop)
	data.routine = routine
	_check(data.get_stop(9 * 60, GameClock.Weekday.MONDAY).spot == "School"
			and data.get_stop(9 * 60, GameClock.Weekday.MONDAY, {"late": true}).spot == "Mortar",
		"a step can need a story condition (only_if) or be cancelled by one (unless)")

# --- The fighting rooster and the Sunday tournament ------------------------------------

func _make_sim_for_cockfight() -> FarmSimulation:
	var sim := _make_sim_for_school()
	var roosters := FightingRoosterData.load_all()
	for rooster_id: String in roosters:
		sim.register_fighting_rooster(rooster_id, roosters[rooster_id])
	return sim

## Moves to the next Sunday (from a weekday), at `minute`.
func _to_sunday(sim: FarmSimulation, minute: int) -> void:
	while sim.state.clock.get_weekday() != GameClock.Weekday.SUNDAY:
		sim.advance_day()
	sim.state.clock.minute_of_day = minute

func test_rooster_given_once() -> void:
	var sim := _make_sim_for_cockfight()
	var first := sim.adopt_rooster()
	var second := sim.adopt_rooster("Autre")
	_check(first and not second and sim.get_rooster()["name"] == FarmSimulation.ROOSTER_NAME
			and sim.get_rooster_power() == 2 * FarmSimulation.ROOSTER_START_STAT,
		"rooster: Rakoto's gift, one rooster at a time")

func test_rooster_grows_with_care() -> void:
	var sim := _make_sim_for_cockfight()
	sim.adopt_rooster()
	sim.state.add_inventory("corn", 5)
	sim.state.add_inventory("tomato", 5)
	var refused := not sim.feed_rooster("tomato") and not sim.can_feed_rooster("rice")
	sim.feed_rooster("corn")
	sim.train_rooster()
	var once := not sim.feed_rooster("corn") and not sim.train_rooster()
	sim.advance_day() # fed and trained: force +2, endurance +2
	var day1 := [sim.get_rooster()["force"], sim.get_rooster()["endurance"]]
	sim.feed_rooster("corn")
	sim.advance_day() # fed only: endurance +1
	sim.train_rooster()
	sim.advance_day() # trained but hungry: nothing
	sim.advance_day() # forgotten: nothing lost
	sim.state.rooster["force"] = FarmSimulation.ROOSTER_MAX_STAT - 1
	sim.feed_rooster("corn")
	sim.train_rooster()
	sim.advance_day()
	_check(refused and once and day1 == [22, 22] and sim.get_rooster()["endurance"] == 25
			and sim.get_rooster()["force"] == FarmSimulation.ROOSTER_MAX_STAT
			and sim.state.get_inventory_count("corn") == 2,
		"rooster: a grain a day grows its endurance, training too its force - never lost, capped")

func test_cockfight_on_sunday_afternoon_only() -> void:
	var sim := _make_sim_for_cockfight()
	var no_rooster := sim.check_cockfight() == FarmSimulation.CockfightCheck.NO_ROOSTER
	sim.adopt_rooster()
	_to_sunday(sim, FarmSimulation.COCKFIGHT_HOURS.x - 1)
	var closed := sim.check_cockfight() == FarmSimulation.CockfightCheck.CLOSED
	sim.state.clock.minute_of_day = FarmSimulation.COCKFIGHT_HOURS.x
	var money := sim.state.money
	var bouts := sim.enter_cockfight()
	var powers := bouts.map(func(bout): return sim.get_cockfight_power(bout["opponent"]))
	var sorted_powers := powers.duplicate()
	sorted_powers.sort()
	var owners_closer := bouts.all(func(bout): return sim.get_friendship(
		sim.get_fighting_rooster(bout["opponent"]).owner_id) == FarmSimulation.FRIENDSHIP_COCKFIGHT)
	var wins := bouts.filter(func(bout): return bout["won"]).size()
	_check(no_rooster and closed and bouts.size() == FarmSimulation.COCKFIGHT_BOUTS and powers == sorted_powers
			and sim.state.money == money + FarmSimulation.COCKFIGHT_ENTRY_PRIZE and owners_closer
			and sim.get_cockfight_points("player") == wins * 3 + (3 - wins) * 1
			and sim.check_cockfight() == FarmSimulation.CockfightCheck.ALREADY_ENTERED,
		"cockfight: Sunday afternoons, once - 3 bouts weakest first, a prize, the owners closer, points")

func test_cockfight_bouts_follow_the_powers() -> void:
	var sim := _make_sim_for_cockfight()
	sim.adopt_rooster()
	seed(7)
	var strong_wins := 0
	var shapes_ok := true
	for i in 200:
		sim.state.rooster["force"] = 100
		sim.state.rooster["endurance"] = 100
		var bout := sim._bout("player", "kely")
		if bout["won"]:
			strong_wins += 1
		var hits: Array = bout["hits"]
		var winner_hits := hits.filter(func(hit): return hit == bout["won"]).size()
		shapes_ok = shapes_ok and hits.back() == bout["won"] and winner_hits == FarmSimulation.COCKFIGHT_HITS_TO_WIN \
			and hits.size() - winner_hits < FarmSimulation.COCKFIGHT_HITS_TO_WIN
	var even_wins := 0
	for i in 400:
		sim.state.rooster["force"] = 30
		sim.state.rooster["endurance"] = 15 # 45, Kely's power in week 1
		if sim._bout("player", "kely")["won"]:
			even_wins += 1
	_check(strong_wins >= 195 and even_wins > 160 and even_wins < 240 and shapes_ok,
		"cockfight: a much stronger rooster almost always wins, an even bout is a coin toss (%d/200, %d/400)" % [strong_wins, even_wins])

func test_cockfight_villagers_fight_their_bouts() -> void:
	var sim := _make_sim_for_cockfight()
	sim.adopt_rooster()
	_to_sunday(sim, FarmSimulation.COCKFIGHT_HOURS.x)
	sim.enter_cockfight()
	sim.advance_day()
	var roosters := FightingRoosterData.load_all().keys()
	var all_fought := roosters.all(func(id): return sim.get_cockfight_points(id) >= 3 and sim.get_cockfight_points(id) <= 9)
	var ranking := sim.get_cockfight_ranking()
	_check(all_fought and sim.state.cockfight_week_bouts.is_empty() and ranking.size() == roosters.size() + 1
			and ranking[0]["points"] >= ranking[-1]["points"],
		"cockfight: on Sunday, every villager's rooster fights 3 bouts too - the ranking follows the points")

func test_cockfight_season_champion() -> void:
	var sim := _make_sim_for_cockfight()
	sim.adopt_rooster()
	var champions := []
	sim.cockfight_season_ended.connect(func(id): champions.append(id))
	_advance_to_day(sim, 29)
	sim.state.cockfight_points["player"] = 100
	_advance_to_day(sim, 31)
	_check(champions == ["player"] and sim.get_cockfight_champion() == "player"
			and sim.state.cockfight_points.is_empty() and sim.get_friendship("rakoto") == FarmSimulation.FRIENDSHIP_CHAMPION,
		"cockfight: the season's top rooster is the village's best - its owner befriends the amateurs, points start again")

func test_rooster_and_cockfight_save_load() -> void:
	var sim := _make_sim_for_cockfight()
	sim.adopt_rooster()
	sim.state.add_inventory("corn", 1)
	sim.feed_rooster("corn")
	_to_sunday(sim, FarmSimulation.COCKFIGHT_HOURS.x)
	sim.enter_cockfight()
	sim.state.cockfight_champion = "mahery"
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	var loaded := _make_sim_for_cockfight()
	loaded.load_save_data(data)
	_check(loaded.get_rooster() == sim.get_rooster() and loaded.state.cockfight_points == sim.state.cockfight_points
			and loaded.state.cockfight_week_bouts == sim.state.cockfight_week_bouts
			and loaded.check_cockfight() == FarmSimulation.CockfightCheck.ALREADY_ENTERED
			and loaded.get_cockfight_champion() == "mahery",
		"rooster: the rooster, the points and today's entry survive a save/load")

# --- Save slots ---------------------------------------------------------------------------

const TEST_SAVES := "user://test_saves/"

## Points SaveSlots at an empty test folder (never the player's saves).
func _use_test_saves() -> void:
	SaveSlots.dir = TEST_SAVES
	_clear_test_saves()

func _clear_test_saves() -> void:
	if DirAccess.dir_exists_absolute(TEST_SAVES):
		for file in DirAccess.get_files_at(TEST_SAVES):
			DirAccess.remove_absolute(TEST_SAVES + file)

func _done_with_test_saves() -> void:
	_clear_test_saves()
	DirAccess.remove_absolute(TEST_SAVES)
	SaveSlots.dir = "user://saves/"
	SaveSlots.legacy_path = "user://savegame.json"

func test_save_slots_write_and_read() -> void:
	_use_test_saves()
	var empty := not SaveSlots.exists(1) and SaveSlots.read(1).is_empty() and SaveSlots.read_summary(1).is_empty()
	var written := SaveSlots.write(1, {"day": 12, "money": 500,
		"summary": {"day": 12, "money": 500, "play_seconds": 4000, "saved_at": 1700000000}})
	var summary := SaveSlots.read_summary(1)
	# A save from before summaries: what's in it.
	SaveSlots.write(2, {"day": 40, "money": 9000})
	var old := SaveSlots.read_summary(2)
	_check(empty and written and SaveSlots.exists(1) and not SaveSlots.exists(0) and SaveSlots.read(1)["day"] == 12
			and summary == {"day": 12, "money": 500, "play_seconds": 4000, "saved_at": 1700000000}
			and old["day"] == 40 and old["money"] == 9000 and old["saved_at"] == 0,
		"save slots: a save per slot, and its summary for the title screen")
	_done_with_test_saves()

func test_save_slots_keep_the_night_before() -> void:
	_use_test_saves()
	SaveSlots.write(0, {"day": 3})
	SaveSlots.write(0, {"day": 4})
	var backup = JSON.parse_string(FileAccess.get_file_as_string(SaveSlots.path(0) + SaveSlots.BACKUP))
	# The save gets corrupted (a crash while writing it...): the night before.
	var file := FileAccess.open(SaveSlots.path(0), FileAccess.WRITE)
	file.store_string("{\"day\": 5, broken")
	file.close()
	_check(backup["day"] == 3 and SaveSlots.read(0)["day"] == 3
			and not FileAccess.file_exists(SaveSlots.path(0) + SaveSlots.TEMP),
		"save slots: the previous save is kept, and read when the save is unreadable")
	_done_with_test_saves()

func test_save_slots_delete() -> void:
	_use_test_saves()
	SaveSlots.write(2, {"day": 3})
	SaveSlots.write(2, {"day": 4})
	SaveSlots.delete(2)
	_check(not SaveSlots.exists(2) and SaveSlots.read(2).is_empty(),
		"save slots: deleting a slot removes the save and the one before it")
	_done_with_test_saves()

func test_save_slots_migrate_the_old_save() -> void:
	_use_test_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVES)
	var legacy := TEST_SAVES + "savegame.json"
	var file := FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string(JSON.stringify({"day": 20, "money": 1234}))
	file.close()
	SaveSlots.legacy_path = legacy
	var migrated := SaveSlots.migrate_legacy()
	var again := SaveSlots.migrate_legacy()
	_check(migrated and not again and SaveSlots.read(0)["day"] == 20
			and not FileAccess.file_exists(legacy) and FileAccess.file_exists(legacy + ".migrated"),
		"save slots: the single save of earlier versions becomes the first slot, once")
	_done_with_test_saves()

# --- The day log and tomorrow (the evening meal) -------------------------------------------

func test_day_log_counts_the_day() -> void:
	var sim := _make_sim_for_school()
	sim.buy_seed("corn", 2) # -1 000 Ar
	var plot := sim.get_plot(0)
	plot.tilled = true
	plot.crop = CropState.new("corn", 4)
	plot.crop.age = 4
	sim.harvest(0)
	var harvested: int = sim.state.get_inventory_count("corn")
	sim.sell("corn", 1) # +1 200 Ar
	sim.collect_product("egg", 2)
	sim.add_friendship("ravao", 120)
	var log := sim.day_log
	_check(log.spent == 1000 and log.earned == 1200 and log.harvested == {"corn": harvested}
			and log.products == {"egg": 2} and log.new_hearts == {"ravao": 1} and log.friendship["ravao"] == 120
			and log.get_main_harvest() == "corn" and not log.is_quiet(),
		"day log: what came in and went out, harvested, picked up, the hearts won today")

func test_day_log_starts_afresh() -> void:
	var sim := _make_sim_for_school()
	sim.buy_seed("corn", 1)
	sim.advance_day()
	var morning := sim.day_log.is_quiet()
	sim.buy_seed("corn", 1)
	var data = JSON.parse_string(JSON.stringify(sim.to_save_data()))
	sim.load_save_data(data)
	var loaded := sim.day_log.is_quiet()
	sim.buy_seed("corn", 1)
	_check(morning and loaded and sim.day_log.spent == 500,
		"day log: empty each morning and after a load (the money as loaded isn't income)")

func test_tomorrow_plans() -> void:
	var sim := _make_sim_for_school()
	var ripe := sim.get_plot(0)
	ripe.tilled = true
	ripe.crop = CropState.new("corn", 4)
	ripe.crop.age = 3
	ripe.watered = true
	var dry := sim.get_plot(1)
	dry.tilled = true
	dry.crop = CropState.new("corn", 4)
	dry.crop.age = 3
	sim.state.orders["koto"] = {"item": "corn", "quantity": 2, "reward": 3000, "template": -1,
		"since": 1, "deadline": sim.state.day + 1}
	sim.state.orders["ravao"] = {"item": "corn", "quantity": 2, "reward": 3000, "template": -1,
		"since": 1, "deadline": sim.state.day + 5}
	_check(sim.get_ripening_tomorrow() == {"corn": 1} and sim.get_unwatered_plots() == 1
			and sim.get_orders_due_tomorrow() == ["koto"],
		"tomorrow: the crops ripe in the morning, the plots left dry, the orders due")

func test_evening_plurals() -> void:
	TranslationServer.set_locale("fr")
	_check(EveningManager.plural("haricot", 6) == "haricots" and EveningManager.plural("haricot", 1) == "haricot"
			and EveningManager.plural("maïs", 3) == "maïs" and EveningManager.plural("riz", 5) == "riz"
			and EveningManager.plural("patate douce", 2) == "patates douces"
			and EveningManager.plural("pomme de terre", 4) == "pommes de terre"
			and EveningManager.plural("graine de riz", 2) == "graines de riz",
		"evening meal: item names in the plural, the French way")
