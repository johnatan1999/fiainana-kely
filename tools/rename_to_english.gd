extends SceneTree

## One-time move of every id and node name to English (French and Malagasy
## stay in player-facing text only), with the tables of the save format's
## v8 migration (SaveController.v8_english_name, _V8_*), so old saves follow:
## 1. every scene: nodes renamed word by word (Haie_Sud_1_01 ->
##    Hedge_South_1_01), and the properties holding ids - a tree's tree_id,
##    an exit's or a door's zone and spawn, a road network's zone_id;
## 2. every data resource: item, zone and farm zone ids, and the villagers'
##    homes, routine spots and zones, gift and order items.
## Files were renamed beforehand (git mv, paths rewritten). Rerunning it
## changes nothing.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/rename_to_english.gd

const SKIP_DIRS := ["res://.godot", "res://.git", "res://addons"]
## Node properties holding a zone id, a node name, or a "Trees/<node>" path.
const ZONE_PROPERTIES := ["target_zone", "interior_zone", "zone_id", "home_zone", "zone"]
const NAME_PROPERTIES := ["target_spawn", "interior_spawn"]
const PATH_PROPERTIES := ["tree_id"]

var _constants: Dictionary

func _initialize() -> void:
	_constants = (load("res://systems/save/save_controller.gd") as GDScript).get_script_constant_map()
	var scenes: Array[String] = []
	var resources: Array[String] = []
	_collect("res://", scenes, resources)
	for path in scenes:
		_rename_scene(path)
	for path in resources:
		_rename_resource(path)
	quit()

func _collect(dir_path: String, scenes: Array[String], resources: Array[String]) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), scenes, resources)
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			scenes.append(dir_path.path_join(file))
		elif file.ends_with(".tres"):
			resources.append(dir_path.path_join(file))

func _zone(zone_id: String) -> String:
	return (_constants["_V8_ZONE_IDS"] as Dictionary).get(zone_id, zone_id)

func _item(item_id: String) -> String:
	return (_constants["_V8_ITEM_IDS"] as Dictionary).get(item_id, item_id)

func _rename_scene(path: String) -> void:
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var changes := 0
	for node in [root] + root.find_children("*", "", true, false):
		if node != root and node.owner != root:
			continue # inside an instanced scene: renamed in its own file
		changes += _rename_properties(node)
		var english := SaveController.v8_english_name(node.name)
		if english != str(node.name):
			node.name = english
			changes += 1
	if changes == 0:
		root.free()
		return
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s: %d renamed%s" % [path, changes, "" if error == OK else " - SAVE FAILED (%d)" % error])
	root.free()

func _rename_properties(node: Node) -> int:
	var changes := 0
	for property in ZONE_PROPERTIES + NAME_PROPERTIES + PATH_PROPERTIES:
		var value = node.get(property)
		if not value is String or (value as String).is_empty():
			continue
		var english: String = value
		if property in ZONE_PROPERTIES:
			english = _zone(value)
		elif property in NAME_PROPERTIES:
			english = SaveController.v8_english_name(value)
		else:
			english = SaveController.v8_english_path(value)
		if english != value:
			node.set(property, english)
			changes += 1
	return changes

func _rename_resource(path: String) -> void:
	var resource := load(path)
	var changes := 0
	if resource is ItemData:
		changes += _assign(resource, "id", _item(resource.id))
	elif resource is ZoneData:
		changes += _assign(resource, "id", _zone(resource.id))
	elif resource is FarmZoneData:
		changes += _assign(resource, "id", (_constants["_V8_FARM_ZONE_IDS"] as Dictionary).get(resource.id, resource.id))
	elif resource is VillagerData:
		changes += _assign(resource, "home", SaveController.v8_english_name(resource.home))
		changes += _assign(resource, "home_zone", _zone(resource.home_zone))
		for stop: VillagerStop in resource.routine:
			changes += _assign(stop, "zone", _zone(stop.zone))
			changes += _assign(stop, "spot", SaveController.v8_english_name(stop.spot))
		for gift: FriendshipReward in resource.friendship_rewards:
			changes += _assign(gift, "item_id", _item(gift.item_id))
		for order: OrderTemplate in resource.orders:
			changes += _assign(order, "item_id", _item(order.item_id))
	if changes > 0:
		var error := ResourceSaver.save(resource, path)
		print("%s: %d renamed%s" % [path, changes, "" if error == OK else " - SAVE FAILED (%d)" % error])

func _assign(object: Object, property: String, value: String) -> int:
	if object.get(property) == value:
		return 0
	object.set(property, value)
	return 1
