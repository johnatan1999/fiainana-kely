extends SceneTree

## Drives the real World.tscn through WorldManager into the Exterior zone
## (which now embeds the chicken pen directly - see WorldManager's
## get_node_or_null("Coop") check) and exercises the full
## build->buy->place->advance_day->egg chain. The unit tests cover
## FarmSimulation in isolation, this covers the wiring between
## WorldManager/AnimalManager/Coop/Chicken that only breaks at integration
## time.
##
## Deliberately untyped locals throughout (matching smoke_test_world.gd):
## typed locals referencing project classes force GDScript to eagerly
## resolve those classes at parse time, before --script mode has finished
## registering autoloads, which breaks any script that references them.

var _world
var _frame := 0

func _initialize() -> void:
	var packed = load("res://scenes/world/World.tscn")
	_world = packed.instantiate()
	root.add_child(_world)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run_flow()
		quit()
	return false

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		root.set_meta("failed", true)

## World.tscn auto-loads a real user://savegame.json if one exists on this
## machine (it does, from interactive playtesting) - so this can't assume a
## fresh game. Every check below is written as a delta or an explicit reset
## instead of an absolute value, so it passes regardless of what's already
## in that save.
func _run_flow() -> void:
	var world_manager = _world.get_node("Gameplay/WorldManager")
	var animal_manager = _world.get_node("Gameplay/AnimalManager")
	var simulation = _world.simulation

	world_manager.change_zone("exterior", "SpawnDefault")
	_check(animal_manager.farm_area != null, "entering the Exterior zone calls AnimalManager.set_farm_area() (Coop found)")

	var animal_container = animal_manager.farm_area.get_node("AnimalContainer")

	simulation.state.money = 1000
	simulation.state.has_coop = false
	simulation.state.coop_capacity = max(simulation.state.coop_capacity, simulation.get_all_animal_ids().size() + 1)
	var built = simulation.build_coop()
	_check(built, "build_coop() succeeds with enough money")

	var bought = simulation.buy_chicken(1)
	_check(bought, "buy_chicken() succeeds")

	var count_before_placing = animal_container.get_child_count()
	var animal_id = simulation.place_chicken()
	_check(animal_id != "", "place_chicken() succeeds once the coop exists")
	_check(
		animal_container.get_child_count() == count_before_placing + 1,
		"placing a chicken spawns exactly one new node under AnimalContainer"
	)

	var egg_count_before := _count_eggs(animal_container)
	var chicken_data = simulation.get_animal_data(0) # AnimalData.Species.CHICKEN
	for i in chicken_data.product_cycle_days:
		simulation.feed_animal(animal_id)
		simulation.water_animal(animal_id)
		simulation.advance_day()
	# ">=" not "==": any other pre-existing chicken from a loaded save could
	# also complete its own cycle during these same days.
	_check(
		_count_eggs(animal_container) >= egg_count_before + 1,
		"a full product cycle spawns at least one new Egg pickup in the world"
	)

	print("\n%s" % ("SOME CHECKS FAILED" if root.has_meta("failed") else "all integration checks passed"))

func _count_eggs(animal_container) -> int:
	var count := 0
	for child in animal_container.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("Egg.gd"):
			count += 1
	return count
