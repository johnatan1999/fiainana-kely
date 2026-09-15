extends SceneTree

## Drives the real World.tscn through WorldManager into the Exterior zone
## (which now embeds the chicken pen directly - see WorldManager's
## get_node_or_null("Coop") check) and exercises the full
## build->buy->place->advance_day->egg chain. The unit tests cover
## FarmSimulation in isolation, this covers the wiring between
## WorldManager/AnimalManager/Coop/Chicken that only breaks at integration
## time.
##
## Deliberately untyped locals throughout, and NEVER a bare ClassName.CONST
## or ClassName.new() reference to a project class (matching
## smoke_test_world.gd's style) - either one forces GDScript to eagerly
## resolve that class at parse time, before --script mode has finished
## registering autoloads. Any project class whose script transitively calls
## AudioManager.* then fails with "Identifier not found: AudioManager".
## Always go through an existing instance instead (e.g. `sign.SOME_CONST`,
## not `SignClassName.SOME_CONST`).

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

	_run_zone_manager_checks()

	print("\n%s" % ("SOME CHECKS FAILED" if root.has_meta("failed") else "all integration checks passed"))

## Verifies ZoneManager actually found the ZoneMarker_*/ProgressiveZoneMarker
## nodes authored in Exterior.tscn - a typo'd node name would pass every
## unit test (which never touches real scene nodes) but silently show no
## feedback in game, so it needs its own dedicated check here.
func _run_zone_manager_checks() -> void:
	var shop_controller = _world.get_node("Gameplay/ShopController")
	var zone_manager = _world.get_node("Gameplay/ZoneManager")
	var simulation = _world.simulation

	_check(
		zone_manager._predefined_markers.size() == 2,
		"Exterior.tscn's two ZoneMarker_* nodes are both found by ZoneManager.set_zone_markers()"
	)
	_check(
		zone_manager._progressive_marker_label != null,
		"Exterior.tscn's ProgressiveZoneMarker is found by ZoneManager.set_zone_markers()"
	)

	simulation.state.money = 10000
	simulation.state.unlocked_zone_ids.erase("zone_east")
	var ok = shop_controller.buy_zone("zone_east")
	var marker: Dictionary = zone_manager._predefined_markers.get("zone_east", {})
	_check(
		ok and not marker.is_empty() and marker["label"].text.contains("débloqué"),
		"buying a zone through ShopController updates its world marker label"
	)

	var progressive_before = zone_manager.get_progressive_unlocked_count()
	shop_controller.buy_progressive_patch(1, 15)
	_check(
		zone_manager.get_progressive_unlocked_count() == progressive_before + 1
		and zone_manager._progressive_marker_label.text.contains(str(progressive_before + 1)),
		"buying a progressive patch through ShopController updates the expansion zone's marker label"
	)

	_run_zone_sign_checks(zone_manager, simulation)

## The Shop no longer sells land - ZoneSign/ModularZoneSign in Exterior.tscn
## are now the only purchase path. This drives them exactly like a real
## interaction would (mark the player "inside", fire interact, click the
## dialog's button) to prove the panels are wired end-to-end, not just that
## ZoneManager's own logic works in isolation.
func _run_zone_sign_checks(zone_manager, simulation) -> void:
	var zone = _world.get_node("ZoneContainer").get_child(0)
	var modular_sign = zone.get_node_or_null("ModularZoneSign")
	var zone_sign_south = zone.get_node_or_null("ZoneSign_zone_south")

	_check(
		modular_sign != null and zone_sign_south != null,
		"ZoneSign_zone_south and ModularZoneSign both exist in the loaded Exterior scene"
	)
	if modular_sign == null or zone_sign_south == null:
		return

	modular_sign._player_inside = true
	modular_sign._on_interact_requested(null)
	_check(modular_sign.dialog.visible, "interacting with ModularZoneSign opens its own dialog")

	var progressive_before = zone_manager.get_progressive_unlocked_count()
	modular_sign._on_patch_pressed(modular_sign.PATCH_OPTIONS[0]) # "Acheter 1 parcelle" - via the instance, not the bare class name (see file header)
	_check(
		zone_manager.get_progressive_unlocked_count() == progressive_before + 1,
		"clicking a patch option on ModularZoneSign's dialog buys it via ZoneManager"
	)

	simulation.state.money = 10000
	zone_sign_south._player_inside = true
	zone_sign_south._on_interact_requested(null)
	_check(zone_sign_south.dialog.visible, "interacting with ZoneSign opens its own dialog")

	var zone_south_unlocked_before = zone_manager.is_zone_unlocked("zone_south")
	zone_sign_south._on_buy_pressed()
	_check(
		not zone_south_unlocked_before and zone_manager.is_zone_unlocked("zone_south"),
		"clicking Acheter on ZoneSign's dialog buys the zone via ZoneManager"
	)

func _count_eggs(animal_container) -> int:
	var count := 0
	for child in animal_container.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("Egg.gd"):
			count += 1
	return count
