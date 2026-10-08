extends SceneTree

## The bourg (zone "bourg"), south of the village - the market town of the
## commune, from the tables below:
## 1. the shop profiles (data/shops/): the village grocery, the zoma market;
## 2. the bourg's prop scenes, from assets/sprites/props/bourg.png
##    (tools/placeholder_art/gen_bourg.gd), in entities/props/, and the zoma
##    market's shop (structures/shop/market_stall_shop.tscn);
## 3. the bourg's scene, world/areas/exterior/bourg.tscn: ground, grass, the
##    river and its bridge, the washing stones, the market square and its
##    stalls, houses (doors shut), the taxi-brousse stop, trees, and the way
##    north to the village - then its ZoneData;
## 4. in the village, the way south to the bourg (ToBourg, SpawnFrom_BOURG),
##    if it isn't there yet.
## The scene is built once: afterwards it's edited in the editor, and this
## refuses to overwrite it - unless run with "-- --force" (which rebuilds it
## from the tables, losing editor changes). The rest is rewritten each run.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/build_bourg.gd
## Its villagers, roads and spots are in tools/place_villagers.gd.

const BOURG := "res://world/areas/exterior/bourg.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const ZONE_DATA := "res://data/world_zones/bourg.tres"
const SHOPS_DIR := "res://data/shops/"
const SHEET := "res://assets/sprites/props/bourg.png"
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
	"zoma_market": {
		"title": "Tsena du zoma",
		"seeds": ShopProfile.SeedRange.ALL,
		"sells_tools": false,
		"sells_animals": false,
		"sell_multiplier": 1.25,
		"open_days": 1 << GameClock.Weekday.ZOMA,
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
	"market_stall_lamba": [2, 1.0, Vector2(160, 16), 0],
	"taxi_brousse": [4, 1.0, Vector2(176, 24), 0],
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
	["Pont", "bridge", Vector2(1056, 464), {}],
	["Lavoir", "res://entities/props/washing_stones.tscn", Vector2(700, 470), {}],
	["Lavoir_Linge", "res://entities/props/laundry_line.tscn", Vector2(560, 520), {}],
	["Roseaux_01", "reeds", Vector2(150, 340), {}],
	["Roseaux_02", "reeds", Vector2(420, 336), {}],
	["Roseaux_03", "reeds", Vector2(1380, 338), {}],
	["Roseaux_04", "reeds", Vector2(1800, 336), {}],
	["Roseaux_05", "reeds", Vector2(260, 470), {}],
	["Roseaux_06", "reeds", Vector2(1640, 474), {}],
	["Roseaux_07", "reeds", Vector2(1960, 470), {}],
	# The market square (tsena): the stalls either side of the road.
	["Tsena_Panneau", "res://entities/props/signboard.tscn", Vector2(900, 620), {"text": "TSENA"}],
	["Tsena_Mpanangona", "res://structures/shop/market_stall_shop.tscn", Vector2(1290, 800), {}],
	["Tsena_Legioma_1", "market_stall_produce", Vector2(620, 800), {}],
	["Tsena_Lamba_1", "market_stall_lamba", Vector2(830, 800), {}],
	["Tsena_Lamba_2", "market_stall_lamba", Vector2(620, 1070), {}],
	["Tsena_Legioma_2", "market_stall_produce", Vector2(830, 1070), {}],
	["Tsena_Legioma_3", "market_stall_produce", Vector2(1500, 800), {}],
	["Tsena_Legioma_4", "market_stall_produce", Vector2(1290, 1070), {}],
	["Tsena_Gony", "rice_sacks", Vector2(1500, 1060), {}],
	["Tsena_Akoho", "hen_cages", Vector2(560, 1180), {}],
	["Tsena_Sobika", "res://entities/props/basket.tscn", Vector2(910, 930), {}],
	["Tsena_Siny", "res://entities/props/clay_jars.tscn", Vector2(1210, 930), {}],
	# Houses round the square, doors shut.
	["Trano_Andrefana_1", "trano_lava_01", Vector2(40, 860), {"locked": true}],
	["Trano_Andrefana_2", "trano_gasy_01", Vector2(60, 1330), {"locked": true}],
	["Trano_Atsinanana_1", "trano_kely_01", Vector2(1720, 860), {"locked": true}],
	["Trano_Atsinanana_2", "trano_kely_02", Vector2(1700, 1330), {"locked": true}],
	# The taxi-brousse stop, on the road south.
	["TaxiBrousse", "taxi_brousse", Vector2(1290, 1460), {}],
	["TaxiBrousse_Panneau", "res://entities/props/signboard.tscn", Vector2(1210, 1530), {"text": "TAXI"}],
	["TaxiBrousse_Gony", "rice_sacks", Vector2(1440, 1500), {}],
]
## Trees: [name, kind ("euca" / "mango"), position, scale].
const TREES := [
	["Ala_Avaratra_01", "euca", Vector2(120, 170), 1.0], ["Ala_Avaratra_02", "euca", Vector2(330, 120), 0.9],
	["Ala_Avaratra_03", "euca", Vector2(560, 200), 1.1], ["Ala_Avaratra_04", "euca", Vector2(800, 130), 0.95],
	["Ala_Avaratra_05", "euca", Vector2(1330, 150), 1.0], ["Ala_Avaratra_06", "euca", Vector2(1560, 210), 0.9],
	["Ala_Avaratra_07", "euca", Vector2(1790, 120), 1.05], ["Ala_Avaratra_08", "euca", Vector2(2010, 190), 0.95],
	["Haie_Andrefana_01", "euca", Vector2(40, 620), 0.9], ["Haie_Andrefana_02", "euca", Vector2(30, 1580), 1.0],
	["Haie_Atsinanana_01", "euca", Vector2(2080, 620), 0.95], ["Haie_Atsinanana_02", "euca", Vector2(2070, 1590), 1.0],
	["Haie_Atsimo_01", "euca", Vector2(500, 1600), 1.0], ["Haie_Atsimo_02", "euca", Vector2(760, 1570), 0.9],
	["Haie_Atsimo_03", "euca", Vector2(1700, 1600), 0.95],
	["Manga_Tsena_01", "mango", Vector2(520, 1230), 1.0], ["Manga_Tsena_02", "mango", Vector2(1620, 1230), 0.95],
	["Manga_Renirano", "mango", Vector2(1800, 560), 0.9],
]
## Lanterns at night: name -> position.
const LIGHTS := {
	"Lanterne_Mpanangona": Vector2(1290, 720),
	"Lanterne_Tsena": Vector2(725, 990),
	"Lanterne_TaxiBrousse": Vector2(1210, 1450),
}

## The way between them: the bourg's north edge <-> the village's south
## edge (its road reaches the edge at cells 31-34).
const BOURG_EXIT := Rect2(960, 0, 192, 24)
const BOURG_ARRIVAL := Vector2(1056, 80)
const VILLAGE_EXIT := Rect2(1489, 1608, 192, 24)
const VILLAGE_ARRIVAL := Vector2(1585, 1560)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOPS_DIR)
	for shop_name: String in SHOPS:
		_write_shop(shop_name, SHOPS[shop_name])
	for prop_name: String in PROPS:
		_build_prop(prop_name, PROPS[prop_name])
	_build_market_shop()
	if ResourceLoader.exists(BOURG) and not "--force" in OS.get_cmdline_user_args():
		print("%s exists - left alone (-- --force to rebuild it)" % BOURG)
	else:
		_build_bourg()
	var zone := ZoneData.new()
	zone.id = "bourg"
	zone.display_name = "Bourg"
	zone.scene = load(BOURG)
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

## The collector's stall: a Shop (zoma market profile) drawn as a stall.
func _build_market_shop() -> void:
	var shop := StaticBody2D.new()
	shop.name = "MarketStallShop"
	shop.set_script(load(SHOP_SCRIPT))
	shop.set("profile", load(SHOPS_DIR + "zoma_market.tres"))
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

func _build_bourg() -> void:
	var bourg := Node2D.new()
	bourg.name = "Bourg"
	bourg.set_script(load(ZONE_SCRIPT))
	bourg.y_sort_enabled = true
	bourg.set("bgm", ZoneRoot.BGM.EXTERIOR)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(bourg, bourg, spawns)
	for spawn_name in ["SpawnDefault", "SpawnFrom_VILLAGE"]:
		var spawn := Marker2D.new()
		spawn.name = spawn_name
		spawn.position = BOURG_ARRIVAL
		_add(bourg, spawns, spawn)

	_paint_layers(bourg)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	_add(bourg, bourg, props)
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
		_add(bourg, props, node)

	var trees := Node2D.new()
	trees.name = "Trees"
	trees.y_sort_enabled = true
	_add(bourg, bourg, trees)
	var tree_scene: PackedScene = load(WORLD_TREE)
	for entry: Array in TREES:
		var tree: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		tree.name = entry[0]
		tree.position = entry[2]
		tree.set("tree_data", load(EUCALYPTUS if entry[1] == "euca" else MANGO))
		tree.set("tree_id", "Trees/" + tree.name)
		tree.set("size_scale", entry[3])
		tree.set("flip", hash(tree.name) % 2 == 0)
		_add(bourg, trees, tree)

	var ambient := Node2D.new()
	ambient.name = "AmbientLife"
	ambient.y_sort_enabled = true
	ambient.set_script(load(AMBIENT_SCRIPT))
	_add(bourg, bourg, ambient)

	var lights := Node2D.new()
	lights.name = "NightLights"
	lights.z_index = 1
	_add(bourg, bourg, lights)
	for light_name: String in LIGHTS:
		var light := Node2D.new()
		light.name = light_name
		light.position = LIGHTS[light_name]
		light.set_script(load(NIGHT_LIGHT_SCRIPT))
		_add(bourg, lights, light)

	_add_way(bourg, "ToVillage", BOURG_EXIT, "village", "SpawnFrom_BOURG")
	_save(bourg, BOURG)

func _paint_layers(bourg: Node) -> void:
	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.z_index = -10
	ground.tile_set = _ground_tileset()
	ground.set_script(load(GROUND_SCRIPT))
	_add(bourg, bourg, ground)
	var grass := TileMapLayer.new()
	grass.name = "GrassLayer"
	grass.z_index = -9
	grass.tile_set = load(FARM_TILESET)
	_add(bourg, bourg, grass)
	var stream := TileMapLayer.new()
	stream.name = "StreamLayer"
	stream.z_index = -8
	stream.material = load(STREAM_MATERIAL)
	stream.tile_set = load(WATER_TILESET)
	_add(bourg, bourg, stream)
	var tall := TileMapLayer.new()
	tall.name = "TallGrassLayer"
	tall.y_sort_enabled = true
	tall.material = load(TALL_GRASS_MATERIAL)
	tall.tile_set = load(TALL_GRASS_TILESET)
	tall.set_script(load(TALL_GRASS_SCRIPT))
	_add(bourg, bourg, tall)

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
	if village.has_node("ToBourg"):
		print("%s already has ToBourg" % VILLAGE)
		village.free()
		return
	_add_way(village, "ToBourg", VILLAGE_EXIT, "bourg", "SpawnFrom_VILLAGE")
	var spawn := Marker2D.new()
	spawn.name = "SpawnFrom_BOURG"
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
