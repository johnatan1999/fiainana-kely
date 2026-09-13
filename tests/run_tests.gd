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
	var turnip: CropData = load("res://data/crops/turnip.tres")
	return FarmSimulation.new(3, 3, {"turnip": turnip})

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
	test_harvest_increases_inventory()
	test_sell_increases_money()
	test_buy_decreases_money()
	test_cannot_plant_untilled_plot()
	test_cannot_harvest_immature_crop()
	test_cannot_buy_without_enough_money()
	test_save_load_roundtrip()

func test_till_plot() -> void:
	var sim := _make_sim()
	var ok := sim.till(0)
	_check(ok and sim.get_plot(0).tilled, "till() marks the plot as tilled")

func test_plant_on_tilled_plot() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	var ok := sim.plant(0, "turnip")
	_check(ok and sim.get_plot(0).crop != null, "plant() succeeds on a tilled plot")

func test_crop_progresses_on_day_advance() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	sim.plant(0, "turnip")
	sim.advance_day()
	_check(sim.get_plot(0).crop.age == 1, "advance_day() ages the planted crop")

func test_harvest_mature_crop() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	sim.plant(0, "turnip")
	for i in range(3):
		sim.advance_day()
	var ok := sim.harvest(0)
	_check(ok and sim.get_plot(0).crop == null, "harvest() succeeds once the crop is mature")

func test_harvest_increases_inventory() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	sim.plant(0, "turnip")
	for i in range(3):
		sim.advance_day()
	sim.harvest(0)
	_check(sim.state.get_inventory_count("turnip") == 1, "harvest() adds the crop to inventory")

func test_sell_increases_money() -> void:
	var sim := _make_sim()
	sim.state.add_inventory("turnip", 1)
	var money_before := sim.state.money
	var ok := sim.sell("turnip", 1)
	_check(ok and sim.state.money == money_before + 30, "sell() increases money by the sell price")

func test_buy_decreases_money() -> void:
	var sim := _make_sim()
	var money_before := sim.state.money
	var ok := sim.buy_seed("turnip", 1)
	_check(ok and sim.state.money == money_before - 10, "buy_seed() decreases money by the seed price")

func test_cannot_plant_untilled_plot() -> void:
	var sim := _make_sim()
	sim.state.add_inventory("turnip_seed", 1)
	var ok := sim.plant(0, "turnip")
	_check(not ok and sim.get_plot(0).crop == null, "plant() fails on a non-tilled plot")

func test_cannot_harvest_immature_crop() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	sim.plant(0, "turnip")
	var ok := sim.harvest(0)
	_check(not ok and sim.get_plot(0).crop != null, "harvest() fails on an immature crop")

func test_cannot_buy_without_enough_money() -> void:
	var sim := _make_sim()
	sim.state.money = 5
	var ok := sim.buy_seed("turnip", 1)
	_check(not ok and sim.state.money == 5, "buy_seed() fails when money is insufficient")

func test_save_load_roundtrip() -> void:
	var sim := _make_sim()
	sim.till(0)
	sim.state.add_inventory("turnip_seed", 1)
	sim.plant(0, "turnip")
	sim.water(0)
	sim.advance_day()
	sim.buy_seed("turnip", 1)

	var data := sim.to_save_data()
	# JSON round-trip, exactly like the real save file on disk.
	data = JSON.parse_string(JSON.stringify(data))

	var fresh_sim := _make_sim()
	fresh_sim.load_save_data(data)

	var plot := fresh_sim.get_plot(0)
	_check(
		fresh_sim.state.money == sim.state.money
		and fresh_sim.state.day == sim.state.day
		and fresh_sim.state.get_inventory_count("turnip_seed") == sim.state.get_inventory_count("turnip_seed")
		and plot.tilled
		and not plot.watered # advance_day() resets watered before the save happened
		and plot.crop != null
		and plot.crop.crop_id == "turnip"
		and plot.crop.age == 1,
		"load_save_data() restores money, day, inventory and plot/crop state"
	)
