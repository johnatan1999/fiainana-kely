extends SceneTree

## Validates every ZoneTransition (door) in every registered zone against
## WorldManager's data-driven zone registry: target_zone must be a real,
## registered zone id, and target_spawn must resolve to a real Marker2D in
## that target zone. Catches exactly the class of typo that would otherwise
## only surface when a player happens to walk through that one specific door
## - run this after adding or renaming any zone/spawn marker.
##
## Deliberately untyped locals throughout, and never a bare ClassName.CONST
## or ClassName.new() reference to a project class - matches run_tests.gd/
## smoke_test_world.gd's style, for the same reason documented in their
## headers (it avoids GDScript eagerly resolving a class whose script
## transitively touches AudioManager before --script mode has finished
## registering autoloads).

var _pass_count := 0
var _fail_count := 0
var _world
var _frame := 0

func _initialize() -> void:
	var packed = load("res://world/world.tscn")
	_world = packed.instantiate()
	root.add_child(_world)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run_checks()
		print("\n%d passed, %d failed" % [_pass_count, _fail_count])
		quit(1 if _fail_count > 0 else 0)
	return false

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1

func _run_checks() -> void:
	var world_manager = _world.get_node("Gameplay/WorldManager")
	var zone_ids: Array = world_manager._zones.keys()
	_check(zone_ids.size() > 0, "WorldManager's zone registry is not empty")
	for zone_id in zone_ids:
		_check_zone_doors(world_manager, zone_id)

func _check_zone_doors(world_manager, zone_id: String) -> void:
	var zone_data = world_manager._zones[zone_id]
	var zone = zone_data.scene.instantiate()

	for transition in _find_transitions(zone):
		var label := "zone '%s', door '%s'" % [zone_id, transition.name]
		var target_zone_id: String = transition.target_zone
		var target_spawn_name: String = transition.target_spawn

		_check(not target_zone_id.is_empty(), "%s: target_zone is set" % label)
		_check(not target_spawn_name.is_empty(), "%s: target_spawn is set" % label)
		if target_zone_id.is_empty():
			continue

		var target_data = world_manager._zones.get(target_zone_id)
		_check(target_data != null, "%s: target_zone '%s' exists in the registry" % [label, target_zone_id])
		if target_data == null or target_spawn_name.is_empty():
			continue

		var target_zone = target_data.scene.instantiate()
		var spawn = _find_spawn(target_zone, target_spawn_name)
		_check(spawn != null, "%s: target_spawn '%s' exists in zone '%s'" % [label, target_spawn_name, target_zone_id])
		target_zone.free()

	zone.free()

## Matches by script path, not `is ZoneTransition` - a direct class reference
## would force GDScript to eagerly resolve ZoneTransition at parse time,
## which transitively touches AudioManager (via PlayerController) and hits
## the same "Identifier not found: AudioManager" failure documented in this
## file's header and in integration_test_farm.gd's _count_eggs().
func _find_transitions(node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("zone_transition.gd"):
			result.append(child)
		result.append_array(_find_transitions(child))
	return result

func _find_spawn(zone, spawn_name: String):
	var spawns_container = zone.get_node_or_null("Spawns")
	if spawns_container:
		var marker = spawns_container.get_node_or_null(spawn_name)
		if marker:
			return marker
	return zone.get_node_or_null(spawn_name)
