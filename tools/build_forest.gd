extends SceneTree

## The forest (zone "forest", ala), east of the village - wild, not farmed:
## from the tables below:
## 1. its scene, world/areas/exterior/forest.tscn: ground, grass, tall grass,
##    a stream from its spring down to the south edge (a ford where the trail
##    crosses), trees (and the old sacred fig, amontana), the animals to
##    watch (WildAnimal), the wild plants to gather (ForageSpot), the places
##    to find (DiscoveryPlace), the way back west to the village - then its
##    ZoneData;
## 2. in the village, the way east to the forest (ToForest,
##    SpawnFrom_FOREST) and its signboard, if they aren't there yet.
## The scene is built once: afterwards it's edited in the editor, and this
## refuses to overwrite it - unless run with "-- --force" (which rebuilds it
## from the tables, losing editor changes). See docs/forest.md.
## Run with --editor (see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/build_forest.gd

const FOREST := "res://world/areas/exterior/forest.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const ZONE_DATA := "res://data/world_zones/forest.tres"
const ZONE_SCRIPT := "res://world/zone_root.gd"
const GROUND_SCRIPT := "res://environment/ground/ground_layer.gd"
const GROUND_TEXTURE := "res://assets/tileset/farm01_48.png"
const FARM_TILESET := "res://assets/tileset/farm_tileset.tres"
const WATER_TILESET := "res://assets/tileset/water_tileset.tres"
const STREAM_MATERIAL := "res://environment/water/stream_water_material.tres"
const TALL_GRASS_TILESET := "res://assets/tileset/tall_grass_tileset.tres"
const TALL_GRASS_MATERIAL := "res://environment/grass/tall_grass_material.tres"
const TALL_GRASS_SCRIPT := "res://environment/grass/tall_grass_layer.gd"
const TRANSITION_SCRIPT := "res://components/zone_transition.gd"
const AMBIENT_SCRIPT := "res://environment/ambient/ambient_life.gd"
const WORLD_TREE := "res://entities/trees/world_tree.tscn"
const EUCALYPTUS := "res://data/trees/eucalyptus.tres"
const MANGO := "res://data/trees/mango_tree.tres"
const SIGNBOARD := "res://entities/props/signboard.tscn"
const REEDS := "res://entities/props/reeds.tscn"
const WILD_ANIMAL := "res://entities/forest/wild_animal.gd"
const FORAGE_SPOT := "res://entities/forest/forage_spot.gd"
const DISCOVERY_PLACE := "res://entities/forest/discovery_place.gd"
const TILE := 48
const GRASS_TERRAIN := 1
const STREAM_TILE := Vector2i(1, 0)

## The map, in cells: 36 x 28 (1728 x 1344 px).
const SIZE := Vector2i(36, 28)
## The stream: its spring (a pool, north-east), then down to the south edge
## - and the ford where the trail crosses it.
const SPRING := Rect2i(25, 3, 5, 3)
const STREAM_COLUMNS := [27, 28]
const STREAM_FROM_ROW := 6
const FORD_ROWS := [14, 15]
## Bare ground: the trail from the village (west) to the clearing, on to the
## ford and the sacred fig - and the clearing itself.
const DIRT := [
	Rect2i(0, 13, 8, 3), Rect2i(6, 11, 3, 4), Rect2i(8, 10, 5, 3),
	Rect2i(13, 12, 9, 6), # the clearing
	Rect2i(21, 14, 12, 2), Rect2i(30, 16, 3, 6),
]
## Tall grass: round the clearing, and the wild corners.
const TALL_GRASS := [
	Rect2i(12, 9, 4, 3), Rect2i(20, 17, 4, 3), Rect2i(1, 22, 6, 4), Rect2i(31, 1, 4, 3),
]

## The way between them: the forest's west edge <-> the village's east edge.
const FOREST_EXIT := Rect2(0, 600, 24, 168)
const FOREST_ARRIVAL := Vector2(90, 684)
const VILLAGE_EXIT := Rect2(2328, 880, 25, 220)
const VILLAGE_ARRIVAL := Vector2(2268, 990)
const VILLAGE_SIGN := Vector2(2222, 900)

## Trees: [name, kind ("euca" / "mango"), position, scale]. The forest's
## border, groves, and the old sacred fig (a big mango tree for now).
const TREES := [
	["Edge_North_01", "euca", Vector2(80, 110), 1.0], ["Edge_North_02", "euca", Vector2(300, 70), 1.1],
	["Edge_North_03", "euca", Vector2(520, 130), 0.95], ["Edge_North_04", "euca", Vector2(760, 80), 1.05],
	["Edge_North_05", "euca", Vector2(980, 120), 1.0], ["Edge_North_06", "euca", Vector2(1650, 90), 1.0],
	["Edge_South_01", "euca", Vector2(120, 1320), 1.0], ["Edge_South_02", "euca", Vector2(420, 1300), 1.1],
	["Edge_South_03", "euca", Vector2(860, 1330), 1.0], ["Edge_South_04", "euca", Vector2(1120, 1290), 0.95],
	["Edge_South_05", "euca", Vector2(1600, 1320), 1.05],
	["Edge_East_01", "euca", Vector2(1690, 420), 1.0], ["Edge_East_02", "euca", Vector2(1700, 980), 1.0],
	["Grove_West_01", "euca", Vector2(250, 470), 1.1], ["Grove_West_02", "euca", Vector2(470, 410), 1.0],
	["Grove_West_03", "euca", Vector2(330, 1000), 1.0], ["Grove_West_04", "euca", Vector2(560, 1120), 1.05],
	["Grove_North_01", "euca", Vector2(1010, 420), 1.0], ["Grove_North_02", "mango", Vector2(1200, 470), 0.95],
	["Grove_South_01", "mango", Vector2(780, 1080), 1.0], ["Grove_South_02", "euca", Vector2(1040, 1120), 1.0],
	["Grove_East_01", "euca", Vector2(1560, 520), 1.0], ["Grove_East_02", "mango", Vector2(1640, 760), 0.9],
	["SacredFig", "mango", Vector2(1480, 1180), 1.7],
]
## The animals' spots: [name, Discovery id, position].
const ANIMALS := [
	["Sifaka", "sifaka", Vector2(470, 470)],
	["Maki", "maki", Vector2(800, 690)],
	["Chameleon", "chameleon", Vector2(640, 960)],
	["Tenrec", "tenrec", Vector2(1080, 470)],
	["Kingfisher", "kingfisher", Vector2(1250, 860)],
]
## The wild plants: [name (its id in the save), Discovery id, position].
const PLANTS := [
	["Greens_1", "wild_greens", Vector2(400, 560)],
	["Greens_2", "wild_greens", Vector2(700, 1060)],
	["Greens_3", "wild_greens", Vector2(1120, 1180)],
	["Hive", "honey", Vector2(1560, 640)],
	["Spring_Ravintsara", "ravintsara", Vector2(1180, 260)],
	["Mushrooms_1", "mushroom", Vector2(380, 1060)],
	["Mushrooms_2", "mushroom", Vector2(960, 470)],
]
## The places to find: [name, Discovery id, center, size].
const PLACES := [
	["Place_Spring", "forest_spring", Vector2(1320, 220), Vector2(300, 220)],
	["Place_SacredFig", "sacred_fig", Vector2(1480, 1150), Vector2(280, 200)],
	["Place_Clearing", "clearing", Vector2(840, 700), Vector2(380, 260)],
]
## Reeds along the stream.
const STREAM_REEDS := [Vector2(1250, 420), Vector2(1420, 560), Vector2(1250, 1000), Vector2(1430, 1240)]

func _initialize() -> void:
	if ResourceLoader.exists(FOREST) and not "--force" in OS.get_cmdline_user_args():
		print("%s exists - left alone (-- --force to rebuild it)" % FOREST)
	else:
		_build_forest()
	var zone := ZoneData.new()
	zone.id = "forest"
	zone.display_name = "Forêt"
	zone.scene = load(FOREST)
	print("%s %s" % [ZONE_DATA, "written" if ResourceSaver.save(zone, ZONE_DATA) == OK else "- SAVE FAILED"])
	_open_village()
	quit()

func _build_forest() -> void:
	var forest := Node2D.new()
	forest.name = "Forest"
	forest.set_script(load(ZONE_SCRIPT))
	forest.y_sort_enabled = true
	forest.set("bgm", ZoneRoot.BGM.EXTERIOR)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(forest, forest, spawns)
	for spawn_name in ["SpawnDefault", "SpawnFrom_VILLAGE"]:
		var spawn := Marker2D.new()
		spawn.name = spawn_name
		spawn.position = FOREST_ARRIVAL
		_add(forest, spawns, spawn)

	_paint_layers(forest)

	var trees := Node2D.new()
	trees.name = "Trees"
	trees.y_sort_enabled = true
	_add(forest, forest, trees)
	var tree_scene: PackedScene = load(WORLD_TREE)
	for entry: Array in TREES:
		var tree: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		tree.name = entry[0]
		tree.position = entry[2]
		tree.set("tree_data", load(EUCALYPTUS if entry[1] == "euca" else MANGO))
		tree.set("tree_id", "Trees/" + tree.name)
		tree.set("size_scale", entry[3])
		tree.set("flip", hash(tree.name) % 2 == 0)
		_add(forest, trees, tree)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	_add(forest, forest, props)
	for i in STREAM_REEDS.size():
		var reeds: Node2D = (load(REEDS) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		reeds.name = "Reeds_%02d" % (i + 1)
		reeds.position = STREAM_REEDS[i]
		_add(forest, props, reeds)

	var wildlife := Node2D.new()
	wildlife.name = "Wildlife"
	wildlife.y_sort_enabled = true
	_add(forest, forest, wildlife)
	for entry: Array in ANIMALS:
		var animal := Node2D.new()
		animal.name = entry[0]
		animal.set_script(load(WILD_ANIMAL))
		animal.set("discovery_id", entry[1])
		animal.position = entry[2]
		_add(forest, wildlife, animal)
	var plants := Node2D.new()
	plants.name = "WildPlants"
	plants.y_sort_enabled = true
	_add(forest, forest, plants)
	for entry: Array in PLANTS:
		var plant := Node2D.new()
		plant.name = entry[0]
		plant.set_script(load(FORAGE_SPOT))
		plant.set("discovery_id", entry[1])
		plant.position = entry[2]
		_add(forest, plants, plant)
	var places := Node2D.new()
	places.name = "Places"
	_add(forest, forest, places)
	for entry: Array in PLACES:
		var place := Area2D.new()
		place.name = entry[0]
		place.set_script(load(DISCOVERY_PLACE))
		place.set("discovery_id", entry[1])
		place.set("size", entry[3])
		place.position = entry[2]
		_add(forest, places, place)

	var ambient := Node2D.new()
	ambient.name = "AmbientLife"
	ambient.y_sort_enabled = true
	ambient.set_script(load(AMBIENT_SCRIPT))
	_add(forest, forest, ambient)

	_add_way(forest, "ToVillage", FOREST_EXIT, "village", "SpawnFrom_FOREST")
	_save(forest, FOREST)

func _paint_layers(forest: Node) -> void:
	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.z_index = -10
	ground.tile_set = _ground_tileset()
	ground.set_script(load(GROUND_SCRIPT))
	_add(forest, forest, ground)
	var grass := TileMapLayer.new()
	grass.name = "GrassLayer"
	grass.z_index = -9
	grass.tile_set = load(FARM_TILESET)
	_add(forest, forest, grass)
	var stream := TileMapLayer.new()
	stream.name = "StreamLayer"
	stream.z_index = -8
	stream.material = load(STREAM_MATERIAL)
	stream.tile_set = load(WATER_TILESET)
	_add(forest, forest, stream)
	var tall := TileMapLayer.new()
	tall.name = "TallGrassLayer"
	tall.y_sort_enabled = true
	tall.material = load(TALL_GRASS_MATERIAL)
	tall.tile_set = load(TALL_GRASS_TILESET)
	tall.set_script(load(TALL_GRASS_SCRIPT))
	_add(forest, forest, tall)

	var grass_cells: Array[Vector2i] = []
	var tall_cells: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 1, Vector2i(1, 3))
			var water := SPRING.has_point(cell) or (x in STREAM_COLUMNS and y >= STREAM_FROM_ROW and not y in FORD_ROWS)
			if water:
				stream.set_cell(cell, 0, STREAM_TILE)
				continue
			if _in_any(cell, DIRT) or (x in STREAM_COLUMNS and y in FORD_ROWS):
				continue
			grass_cells.append(cell)
			if _in_any(cell, TALL_GRASS):
				tall_cells.append(cell)
	grass.set_cells_terrain_connect(grass_cells, 0, GRASS_TERRAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for cell in tall_cells:
		for dy in 3:
			for dx in 3:
				if rng.randf() < 0.8:
					tall.set_cell(cell * 3 + Vector2i(dx, dy), 0, Vector2i(rng.randi_range(0, 5), 0))

func _in_any(cell: Vector2i, rects: Array) -> bool:
	for rect: Rect2i in rects:
		if rect.has_point(cell):
			return true
	return false

func _ground_tileset() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = load(GROUND_TEXTURE)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i(1, 3))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 1)
	return tileset

## The village's way east, its arrival spot and its signboard, once.
func _open_village() -> void:
	var village: Node = (load(VILLAGE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if village.has_node("ToForest"):
		print("%s already has ToForest" % VILLAGE)
		village.free()
		return
	_add_way(village, "ToForest", VILLAGE_EXIT, "forest", "SpawnFrom_VILLAGE")
	var spawn := Marker2D.new()
	spawn.name = "SpawnFrom_FOREST"
	spawn.position = VILLAGE_ARRIVAL
	_add(village, village.get_node("Spawns"), spawn)
	var sign_node: Node2D = (load(SIGNBOARD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	sign_node.name = "Sign_Forest"
	sign_node.position = VILLAGE_SIGN
	sign_node.set("text", "ALA")
	_add(village, village, sign_node)
	_save(village, VILLAGE)

func _add_way(zone: Node, exit_name: String, rect: Rect2, target_zone: String, target_spawn: String) -> void:
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

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	root.free()
