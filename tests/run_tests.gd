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
	var sim := _make_sim()
	sim.state.add_inventory("corn", 1)
	var money_before := sim.state.money
	var ok := sim.sell("corn", 1)
	_check(ok and sim.state.money == money_before + 12, "sell() increases money by the sell price")

func test_buy_decreases_money() -> void:
	var sim := _make_sim()
	var money_before := sim.state.money
	var ok := sim.buy_seed("corn", 1)
	_check(ok and sim.state.money == money_before - 5, "buy_seed() decreases money by the seed price")

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
	sim.state.money = 1000
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
