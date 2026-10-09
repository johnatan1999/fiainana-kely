extends SceneTree

## The market town (zone "market_town"), south of the village - the market
## town of the commune, from the tables below:
## 1. the shop profiles (data/shops/): the village grocery, the weekly market;
## 2. the market town's prop scenes, from assets/sprites/props/market_town.png
##    (tools/placeholder_art/gen_market_town.gd), in entities/props/, and the
##    weekly market's shop (structures/shop/market_stall_shop.tscn);
## 3. the market town's scene, world/areas/exterior/market_town.tscn: ground,
##    grass, the river and its bridge, the washing stones, the market square
##    and its stalls, houses (doors shut), the bush taxi stop, trees, and the
##    way north to the village - then its ZoneData;
## 4. in the village, the way south to the market town (ToMarketTown,
##    SpawnFrom_MARKET_TOWN), if it isn't there yet.
## The scene is built once: afterwards it's edited in the editor, and this
## refuses to overwrite it - unless run with "-- --force" (which rebuilds it
## from the tables, losing editor changes). The rest is rewritten each run.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/build_market_town.gd
## Its villagers, roads and spots are in tools/place_villagers.gd.

const MARKET_TOWN := "res://world/areas/exterior/market_town.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const ZONE_DATA := "res://data/world_zones/market_town.tres"
const SHOPS_DIR := "res://data/shops/"
const SHEET := "res://assets/sprites/props/market_town.png"
const PROPS_DIR := "res://entities/props/"
const PROP_SCRIPT := "res://entities/props/prop.gd"
const SHOP_SCRIPT := "res://structures/shop/shop.gd"
const MARKET_SHOP := "res://structures/shop/market_stall_shop.tscn"
const INTERACTABLE := "res://components/interaction/interactable_component.tscn"
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
const NIGHT_LIGHT_SCRIPT := "res://environment/lighting/night_light.gd"
const WORLD_TREE := "res://entities/trees/world_tree.tscn"
const EUCALYPTUS := "res://data/trees/eucalyptus.tres"
const MANGO := "res://data/trees/mango_tree.tres"
const HOUSES := "res://structures/houses/models/%s.tscn"
const CELL := 192
const TILE := 48

## Grass terrain (farm_tileset terrain set 0) and the stream tile.
const GRASS_TERRAIN := 1
const STREAM_TILE := Vector2i(1, 0)

## Shop profiles: file -> properties.
const SHOPS := {
	"village_shop": {
		"title": "Marché du village",
		"seeds": ShopProfile.SeedRange.LOCAL,
	},
	"weekly_market": {
		"title": "Tsena du zoma",
		"seeds": ShopProfile.SeedRange.ALL,
		"sells_tools": false,
		"sells_animals": false,
		"sell_multiplier": 1.25,
		"open_days": 1 << GameClock.Weekday.FRIDAY,
		"opens_at": 6 * 60,
		"closes_at": 17 * 60,
		"closed_message": "Le tsena n'ouvre que le zoma, de 6:00 à 17:00.",
	},
}

## Prop scene -> [sheet cell, scale, base collision size (art px, or
## Vector2.ZERO for none), z_index].
const PROPS := {
	"bridge": [0, 1.0, Vector2.ZERO, -7],
	"market_stall_produce": [1, 1.0, Vector2(170, 16), 0],
	"market_stall_cloth": [2, 1.0, Vector2(160, 16), 0],
	"bush_taxi": [4, 1.0, Vector2(176, 24), 0],
	"rice_sacks": [5, 0.6, Vector2(150, 20), 0],
	"reeds": [6, 0.5, Vector2.ZERO, 0],
	"hen_cages": [7, 0.55, Vector2(150, 18), 0],
}

## The map, in cells: 44 x 34 (2112 x 1632 px).
const SIZE := Vector2i(44, 34)
## The river, flowing west to east, and the bridge's columns.
const RIVER_ROWS := [7, 8]
const BRIDGE_COLUMNS := [20, 21, 22, 23]
## Bare ground (no grass): the road north to south, the market square, the
## path to the washing stones.
const DIRT := [
	Rect2i(20, 0, 4, 7),
	Rect2i(20, 9, 4, 4),
	Rect2i(10, 12, 24, 13),
	Rect2i(11, 9, 9, 2),
	Rect2i(20, 25, 4, 9),
	Rect2i(24, 28, 6, 4), # the taxi-brousse stop
]
## Tall grass along the banks and in the corners.
const TALL_GRASS := [
	Rect2i(2, 9, 6, 2), Rect2i(30, 9, 10, 2), Rect2i(1, 27, 6, 5), Rect2i(37, 26, 6, 6),
]

## Everything else: [name, scene (a prop of PROPS, or res://), position,
## extra properties].
const PLACES := [
	# The bridge over the river, and the washing stones downstream.
	["Bridge", "bridge", Vector2(1056, 464), {}],
	["WashingStones", "res://entities/props/washing_stones.tscn", Vector2(700, 470), {}],
	["WashingStones_Laundry", "res://entities/props/laundry_line.tscn", Vector2(560, 520), {}],
	["Reeds_01", "reeds", Vector2(150, 340), {}],
	["Reeds_02", "reeds", Vector2(420, 336), {}],
	["Reeds_03", "reeds", Vector2(1380, 338), {}],
	["Reeds_04", "reeds", Vector2(1800, 336), {}],
	["Reeds_05", "reeds", Vector2(260, 470), {}],
	["Reeds_06", "reeds", Vector2(1640, 474), {}],
	["Reeds_07", "reeds", Vector2(1960, 470), {}],
	# The market square: the stalls either side of the road.
	["Market_Sign", "res://entities/props/signboard.tscn", Vector2(900, 620), {"text": "TSENA"}],
	["Market_Collector", "res://structures/shop/market_stall_shop.tscn", Vector2(1290, 800), {}],
	["Market_Vegetables_1", "market_stall_produce", Vector2(620, 800), {}],
	["Market_Cloth_1", "market_stall_cloth", Vector2(830, 800), {}],
	["Market_Cloth_2", "market_stall_cloth", Vector2(620, 1070), {}],
	["Market_Vegetables_2", "market_stall_produce", Vector2(830, 1070), {}],
	["Market_Vegetables_3", "market_stall_produce", Vector2(1500, 800), {}],
	["Market_Vegetables_4", "market_stall_produce", Vector2(1290, 1070), {}],
	["Market_RiceSacks", "rice_sacks", Vector2(1500, 1060), {}],
	["Market_Hens", "hen_cages", Vector2(560, 1180), {}],
	["Market_Basket", "res://entities/props/basket.tscn", Vector2(910, 930), {}],
	["Market_Jars", "res://entities/props/clay_jars.tscn", Vector2(1210, 930), {}],
	# Houses round the square, doors shut.
	["House_West_1", "trano_lava_01", Vector2(40, 860), {"locked": true}],
	["House_West_2", "trano_gasy_01", Vector2(60, 1330), {"locked": true}],
	["House_East_1", "trano_kely_01", Vector2(1720, 860), {"locked": true}],
	["House_East_2", "trano_kely_02", Vector2(1700, 1330), {"locked": true}],
	# The taxi-brousse stop, on the road south.
	["BushTaxi", "bush_taxi", Vector2(1290, 1460), {}],
	["BushTaxi_Sign", "res://entities/props/signboard.tscn", Vector2(1210, 1530), {"text": "TAXI"}],
	["BushTaxi_RiceSacks", "rice_sacks", Vector2(1440, 1500), {}],
]
## Trees: [name, kind ("euca" / "mango"), position, scale].
const TREES := [
	["Forest_North_01", "euca", Vector2(120, 170), 1.0], ["Forest_North_02", "euca", Vector2(330, 120), 0.9],
	["Forest_North_03", "euca", Vector2(560, 200), 1.1], ["Forest_North_04", "euca", Vector2(800, 130), 0.95],
	["Forest_North_05", "euca", Vector2(1330, 150), 1.0], ["Forest_North_06", "euca", Vector2(1560, 210), 0.9],
	["Forest_North_07", "euca", Vector2(1790, 120), 1.05], ["Forest_North_08", "euca", Vector2(2010, 190), 0.95],
	["Hedge_West_01", "euca", Vector2(40, 620), 0.9], ["Hedge_West_02", "euca", Vector2(30, 1580), 1.0],
	["Hedge_East_01", "euca", Vector2(2080, 620), 0.95], ["Hedge_East_02", "euca", Vector2(2070, 1590), 1.0],
	["Hedge_South_01", "euca", Vector2(500, 1600), 1.0], ["Hedge_South_02", "euca", Vector2(760, 1570), 0.9],
	["Hedge_South_03", "euca", Vector2(1700, 1600), 0.95],
	["Mango_Market_01", "mango", Vector2(520, 1230), 1.0], ["Mango_Market_02", "mango", Vector2(1620, 1230), 0.95],
	["Mango_River", "mango", Vector2(1800, 560), 0.9],
]
## Lanterns at night: name -> position.
const LIGHTS := {
	"Lantern_Collector": Vector2(1290, 720),
	"Lantern_Market": Vector2(725, 990),
	"Lantern_BushTaxi": Vector2(1210, 1450),
}

## The way between them: the market town's north edge <-> the village's south
## edge (its road reaches the edge at cells 31-34).
const MARKET_TOWN_EXIT := Rect2(960, 0, 192, 24)
const MARKET_TOWN_ARRIVAL := Vector2(1056, 80)
const VILLAGE_EXIT := Rect2(1489, 1608, 192, 24)
const VILLAGE_ARRIVAL := Vector2(1585, 1560)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOPS_DIR)
	for shop_name: String in SHOPS:
		_write_shop(shop_name, SHOPS[shop_name])
	for prop_name: String in PROPS:
		_build_prop(prop_name, PROPS[prop_name])
	_build_market_shop()
	if ResourceLoader.exists(MARKET_TOWN) and not "--force" in OS.get_cmdline_user_args():
		print("%s exists - left alone (-- --force to rebuild it)" % MARKET_TOWN)
	else:
		_build_market_town()
	var zone := ZoneData.new()
	zone.id = "market_town"
	zone.display_name = "Bourg"
	zone.scene = load(MARKET_TOWN)
	print("%s %s" % [ZONE_DATA, "written" if ResourceSaver.save(zone, ZONE_DATA) == OK else "- SAVE FAILED"])
	_open_village()
	quit()

func _write_shop(shop_name: String, properties: Dictionary) -> void:
	var path := SHOPS_DIR + shop_name + ".tres"
	var profile: ShopProfile = load(path) if ResourceLoader.exists(path) else ShopProfile.new()
	for property: String in properties:
		profile.set(property, properties[property])
	print("%s %s" % [path, "written" if ResourceSaver.save(profile, path) == OK else "- SAVE FAILED"])

func _sheet_sprite(cell: int, scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(SHEET)
	sprite.region_enabled = true
	sprite.region_rect = Rect2((cell % 4) * CELL, (cell / 4) * CELL, CELL, CELL)
	sprite.scale = Vector2.ONE * scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

func _base() -> StaticBody2D:
	var base := StaticBody2D.new()
	base.name = "Base"
	return base

func _add_base(root: Node, parent: Node, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector2(0, -size.y / 2.0)
	_add(root, parent, shape)

func _build_prop(prop_name: String, spec: Array) -> void:
	var prop := Node2D.new()
	prop.name = prop_name.to_pascal_case()
	prop.set_script(load(PROP_SCRIPT))
	prop.z_index = spec[3]
	_add(prop, prop, _sheet_sprite(spec[0], spec[1]))
	var base_size: Vector2 = spec[2]
	if base_size != Vector2.ZERO:
		var base := _base()
		_add(prop, prop, base)
		_add_base(prop, base, base_size * spec[1])
	_save(prop, PROPS_DIR + prop_name + ".tscn")

## The collector's stall: a Shop (weekly market profile) drawn as a stall.
func _build_market_shop() -> void:
	var shop := StaticBody2D.new()
	shop.name = "MarketStallShop"
	shop.set_script(load(SHOP_SCRIPT))
	shop.set("profile", load(SHOPS_DIR + "weekly_market.tres"))
	shop.set("reach", Vector2(150, 90))
	var scale := 1.0
	var sprite := _sheet_sprite(3, scale)
	sprite.position = Vector2(0, -CELL * scale / 2.0)
	_add(shop, shop, sprite)
	_add_base(shop, shop, Vector2(170, 16) * scale)
	var interactable: Node = (load(INTERACTABLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	interactable.name = "InteractableComponent"
	_add(shop, shop, interactable)
	_save(shop, MARKET_SHOP)

func _build_market_town() -> void:
	var town := Node2D.new()
	town.name = "MarketTown"
	town.set_script(load(ZONE_SCRIPT))
	town.y_sort_enabled = true
	town.set("bgm", ZoneRoot.BGM.EXTERIOR)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(town, town, spawns)
	for spawn_name in ["SpawnDefault", "SpawnFrom_VILLAGE"]:
		var spawn := Marker2D.new()
		spawn.name = spawn_name
		spawn.position = MARKET_TOWN_ARRIVAL
		_add(town, spawns, spawn)

	_paint_layers(town)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	_add(town, town, props)
	for entry: Array in PLACES:
		var path: String = entry[1]
		if not path.begins_with("res://"):
			path = (PROPS_DIR + path + ".tscn") if PROPS.has(path) else HOUSES % path
		var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = entry[0]
		node.position = entry[2]
		var extra: Dictionary = entry[3]
		for property: String in extra:
			node.set(property, extra[property])
		_add(town, props, node)

	var trees := Node2D.new()
	trees.name = "Trees"
	trees.y_sort_enabled = true
	_add(town, town, trees)
	var tree_scene: PackedScene = load(WORLD_TREE)
	for entry: Array in TREES:
		var tree: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		tree.name = entry[0]
		tree.position = entry[2]
		tree.set("tree_data", load(EUCALYPTUS if entry[1] == "euca" else MANGO))
		tree.set("tree_id", "Trees/" + tree.name)
		tree.set("size_scale", entry[3])
		tree.set("flip", hash(tree.name) % 2 == 0)
		_add(town, trees, tree)

	var ambient := Node2D.new()
	ambient.name = "AmbientLife"
	ambient.y_sort_enabled = true
	ambient.set_script(load(AMBIENT_SCRIPT))
	_add(town, town, ambient)

	var lights := Node2D.new()
	lights.name = "NightLights"
	lights.z_index = 1
	_add(town, town, lights)
	for light_name: String in LIGHTS:
		var light := Node2D.new()
		light.name = light_name
		light.position = LIGHTS[light_name]
		light.set_script(load(NIGHT_LIGHT_SCRIPT))
		_add(town, lights, light)

	_add_way(town, "ToVillage", MARKET_TOWN_EXIT, "village", "SpawnFrom_MARKET_TOWN")
	_save(town, MARKET_TOWN)

func _paint_layers(town: Node) -> void:
	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.z_index = -10
	ground.tile_set = _ground_tileset()
	ground.set_script(load(GROUND_SCRIPT))
	_add(town, town, ground)
	var grass := TileMapLayer.new()
	grass.name = "GrassLayer"
	grass.z_index = -9
	grass.tile_set = load(FARM_TILESET)
	_add(town, town, grass)
	var stream := TileMapLayer.new()
	stream.name = "StreamLayer"
	stream.z_index = -8
	stream.material = load(STREAM_MATERIAL)
	stream.tile_set = load(WATER_TILESET)
	_add(town, town, stream)
	var tall := TileMapLayer.new()
	tall.name = "TallGrassLayer"
	tall.y_sort_enabled = true
	tall.material = load(TALL_GRASS_MATERIAL)
	tall.tile_set = load(TALL_GRASS_TILESET)
	tall.set_script(load(TALL_GRASS_SCRIPT))
	_add(town, town, tall)

	var grass_cells: Array[Vector2i] = []
	var tall_cells: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 1, Vector2i(1, 3))
			if y in RIVER_ROWS:
				if not x in BRIDGE_COLUMNS:
					stream.set_cell(cell, 0, STREAM_TILE)
				continue
			if _in_any(cell, DIRT):
				continue
			grass_cells.append(cell)
			if _in_any(cell, TALL_GRASS):
				tall_cells.append(cell)
	grass.set_cells_terrain_connect(grass_cells, 0, GRASS_TERRAIN)
	# Tall grass is on a 16 px grid (3 x 3 tufts per cell), 6 tuft variants,
	# a few left out so the patches look grown, not tiled.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
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

## The village's ground: the farm tileset's plain dirt tile.
func _ground_tileset() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = load(GROUND_TEXTURE)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i(1, 3))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 1)
	return tileset

## The village's way south, once.
func _open_village() -> void:
	var village: Node = (load(VILLAGE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if village.has_node("ToMarketTown"):
		print("%s already has ToMarketTown" % VILLAGE)
		village.free()
		return
	_add_way(village, "ToMarketTown", VILLAGE_EXIT, "market_town", "SpawnFrom_VILLAGE")
	var spawn := Marker2D.new()
	spawn.name = "SpawnFrom_MARKET_TOWN"
	spawn.position = VILLAGE_ARRIVAL
	_add(village, village.get_node("Spawns"), spawn)
	_save(village, VILLAGE)

## An exit (`exit_name`, to `target_zone` at `target_spawn`).
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
