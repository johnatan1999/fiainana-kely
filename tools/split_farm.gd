extends SceneTree

## One-time split of the village (player_village.tscn) into two zones: the
## player's farm (a new zone, "farm", world/areas/exterior/player_farm.tscn)
## and the village. Both start from the same map; each keeps its own nodes:
## - the farm: the west part of the map (x < FARM_WIDTH cells) - the player's
##   house, the coop and its hens, the fields and their signs, the orchard;
##   the tiles further east erased, a hedge of eucalyptus along its new east
##   edge, and the way to the village there;
## - the village: everything else - villagers, market, zebu pen, cart, the
##   villagers' houses - the farm's nodes and fences removed (their ground
##   is left free for new buildings), and the way to the farm on its west
##   edge.
## Nothing moves: the farm keeps the village's coordinates, so its plots keep
## their cells (SaveController's v7 migration only renames their zone).
## Refuses to run again once the farm exists.
##   godot --headless --editor --path . --script res://tools/split_farm.gd

const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const FARM := "res://world/areas/exterior/player_farm.tscn"
const FARM_ZONE_DATA := "res://data/world_zones/farm.tres"
const WORLD_TREE := "res://entities/trees/world_tree.tscn"
const EUCALYPTUS := "res://data/trees/eucalyptus.tres"
const TRANSITION_SCRIPT := "res://components/zone_transition.gd"
const TILE := 48
const FARM_WIDTH := 30 # cells: 1440 px

## Nodes that go to the farm (removed from the village). A trailing * matches
## a name prefix.
const FARM_NODES := [
	"FarmView", "HouseGroup/House", "ChickenCoopBuilding", "AnimalContainer",
	"Hen", "NiggaHen", "Rooster",
	"ModularFarmZoneSign", "FarmZoneSign_zone_east", "FarmZoneSign_zone_south",
	"Props/GrandeMaison_*", "Props/Poulailler_*",
	"NightLights/Lanterne_GrandeMaison", "NightLights/Lanterne_Poulailler",
	"Trees/Verger_Manguier_*",
	"Spawns/SpawnFrom_CHICKEN_COOP",
]
## Nodes that stay in the village (removed from the farm) - besides anything
## east of the farm's edge.
const VILLAGE_NODES := [
	"HouseGroup/TranoKely01", "HouseGroup/TranoGasy01", "HouseGroup/TranoKely02",
	"Shop", "ToRiceFields", "HillWalls/East", "CartRoute_Est", "ZebuPen", "ZebuHerd",
	"VillagerRoads", "Villagers",
	"Props/Grenier", "Props/MaisonOuest_*", "Props/MaisonEst_*", "Props/MaisonSud_*", "Props/Marche_*",
	"NightLights/Lanterne_MaisonEst", "NightLights/Lanterne_MaisonOuest",
	"NightLights/Lanterne_MaisonSud", "NightLights/Lanterne_Marche",
	"Trees/Manguier_MaisonOuest",
	"Spawns/SpawnFrom_RICE_FIELDS",
]
## The farm's new east edge: a hedge, with a gap for the way to the village.
const HEDGE := [
	[Vector2(1398, 200), 1.0], [Vector2(1405, 330), 0.9],
	[Vector2(1400, 780), 1.05], [Vector2(1408, 920), 0.9], [Vector2(1396, 1070), 1.1],
	[Vector2(1404, 1220), 0.95], [Vector2(1398, 1370), 1.0], [Vector2(1406, 1510), 0.9],
]
## The way between them: the farm's east edge <-> the village's west edge.
const FARM_EXIT := Rect2(1416, 470, 24, 180)
const FARM_ARRIVAL := Vector2(1370, 560)
const VILLAGE_EXIT := Rect2(0, 440, 24, 130)
const VILLAGE_ARRIVAL := Vector2(70, 505)

func _initialize() -> void:
	if ResourceLoader.exists(FARM):
		push_error("split_farm: %s already exists - the split was done." % FARM)
		quit(1)
		return
	var source: PackedScene = load(VILLAGE)
	_make_farm(source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE))
	_make_village(source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE))
	var zone := ZoneData.new()
	zone.id = "farm"
	zone.display_name = "Ferme"
	zone.scene = load(FARM)
	print("%s %s" % [FARM_ZONE_DATA, "written" if ResourceSaver.save(zone, FARM_ZONE_DATA) == OK else "- SAVE FAILED"])
	quit()

func _make_farm(farm: Node) -> void:
	farm.name = "PlayerFarm"
	_remove(farm, VILLAGE_NODES)
	# Everything east of the new edge.
	for group in ["Trees", "Props", "NightLights"]:
		for node in farm.get_node(group).get_children():
			if (node as Node2D).global_position.x >= FARM_WIDTH * TILE:
				_free(node)
	for layer in farm.find_children("*", "TileMapLayer", false, false):
		for cell: Vector2i in (layer as TileMapLayer).get_used_cells():
			if layer.to_global(layer.map_to_local(cell)).x >= FARM_WIDTH * TILE:
				layer.erase_cell(cell)
	var trees: Node = farm.get_node("Trees")
	var tree_scene: PackedScene = load(WORLD_TREE)
	for i in HEDGE.size():
		var tree: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		tree.name = "Haie_Ferme_Est_%02d" % (i + 1)
		tree.position = HEDGE[i][0]
		tree.set("tree_data", load(EUCALYPTUS))
		tree.set("tree_id", "Trees/" + tree.name)
		tree.set("size_scale", HEDGE[i][1])
		_add(farm, trees, tree)
	_add_way(farm, "ToVillage", FARM_EXIT, "village", "SpawnFrom_FARM", "SpawnFrom_VILLAGE", FARM_ARRIVAL)
	_save(farm, FARM)

func _make_village(village: Node) -> void:
	_remove(village, FARM_NODES)
	(village.get_node("FenceLayer") as TileMapLayer).clear() # the fields' fences
	_add_way(village, "ToFarm", VILLAGE_EXIT, "farm", "SpawnFrom_VILLAGE", "SpawnFrom_FARM", VILLAGE_ARRIVAL)
	_save(village, VILLAGE)

## An exit (`exit_name`, to `target_zone` at `target_spawn`) and the spawn
## the other side's exit leads to here.
func _add_way(zone: Node, exit_name: String, rect: Rect2, target_zone: String, target_spawn: String,
		arrival_name: String, arrival: Vector2) -> void:
	var exit := Area2D.new()
	exit.name = exit_name
	exit.set_script(load(TRANSITION_SCRIPT))
	exit.set("target_zone", target_zone)
	exit.set("target_spawn", target_spawn)
	_add(zone, zone, exit)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	_add(zone, exit, shape)
	var spawn := Marker2D.new()
	spawn.name = arrival_name
	spawn.position = arrival
	_add(zone, zone.get_node("Spawns"), spawn)

func _remove(zone: Node, paths: Array) -> void:
	for path: String in paths:
		if path.ends_with("*"):
			var parent := zone.get_node(path.get_base_dir())
			for child in parent.get_children():
				if child.name.begins_with(path.get_file().trim_suffix("*")):
					_free(child)
		elif zone.has_node(path):
			_free(zone.get_node(path))
		else:
			push_warning("split_farm: no %s" % path)

func _free(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.free()

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	root.free()
