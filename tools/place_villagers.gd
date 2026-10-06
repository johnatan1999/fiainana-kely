extends SceneTree

## Villagers, from the tables below:
## 1. builds entities/villager/villager.tscn (body, VillagerVisual, speech
##    bubble);
## 2. writes data/villagers/<id>.tres for each villager - only the missing
##    ones: once written, a villager is edited in the inspector (look,
##    routine, greetings) and this tool leaves it alone (delete the file to
##    have it rewritten from the table);
## 3. rebuilds, in each zone of ZONES, the VillagerRoads (roads + spots),
##    the neighbours' paddies (VillagePaddy) and the Villagers nodes - one
##    Villager per villager whose day passes through that zone - leaving the
##    rest of the scene alone.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_villagers.gd
## Fine-tuning roads and spots in the editor afterwards is fine - but
## rerunning this resets them to the tables.

const VILLAGER_SCENE := "res://entities/villager/villager.tscn"
const DATA_DIR := "res://data/villagers/"
const LAYERS := "res://assets/sprites/characters/villager/example_%s.png"
const TILE := 48

## World zone id -> its scene, the spots (Marker2Ds under
## VillagerRoads/Spots), the roads along its dirt paths (one Line2D each; a
## point shared by two roads, within VillagerRoads.MERGE_DISTANCE, joins
## them), its neighbours' paddies [ground cell of the top-left corner,
## size in cells] and the trees to take out to make room for them (by
## name, under Trees). "Vers_<zone>" spots are the ways to the other zones.
const ZONES := {
	"village": {
		"scene": "res://world/areas/exterior/player_village.tscn",
		"spots": {
			"Maison_Ouest": Vector2(274, 1108),
			"Maison_Est": Vector2(1986, 1025),
			"Maison_Sud": Vector2(1584, 1440),
			"Marche": Vector2(1290, 850),
			"Place": Vector2(950, 600),
			"Banc_Est": Vector2(1850, 1040),
			"Vers_rice_fields": Vector2(1505, 30),
		},
		"roads": {
			"Route_Ouest": [Vector2(274, 1108), Vector2(450, 1100), Vector2(480, 900), Vector2(480, 620), Vector2(560, 560)],
			"Route_Place": [Vector2(560, 560), Vector2(950, 575), Vector2(1150, 555), Vector2(1300, 575), Vector2(1460, 640), Vector2(1520, 720)],
			"Route_Nord": [Vector2(1520, 720), Vector2(1530, 450), Vector2(1510, 200), Vector2(1505, 30)],
			"Route_Marche": [Vector2(1460, 640), Vector2(1430, 780), Vector2(1290, 850)],
			"Route_Est": [Vector2(1520, 720), Vector2(1650, 880), Vector2(1760, 1030), Vector2(1850, 1030), Vector2(1986, 1025)],
			"Route_Sud": [Vector2(1430, 780), Vector2(1450, 960), Vector2(1370, 1150), Vector2(1370, 1440), Vector2(1584, 1440)],
		},
		"paddies": [],
		"remove_trees": [],
	},
	"rice_fields": {
		"scene": "res://world/areas/exterior/rice_fields.tscn",
		"spots": {
			"Vers_village": Vector2(960, 1320),
			"Cabane": Vector2(1135, 1125),
			"Riziere_Voisins_1": Vector2(1310, 1115),
			"Riziere_Voisins_2": Vector2(1420, 1205),
		},
		"roads": {
			"Route_Village": [Vector2(960, 1320), Vector2(960, 1180), Vector2(1135, 1150), Vector2(1235, 1150)],
		},
		# Right of the hut, seen from the road. The south hedge's west trees
		# would hide it under their foliage.
		"paddies": [[Vector2i(26, 22), Vector2i(5, 4)]],
		"remove_trees": ["Haie_Sud_3_01", "Haie_Sud_3_02", "Haie_Sud_3_03"],
	},
}

## id -> name, home (in the village), size, skin, layers [sheet, color],
## routine [hour, minute, zone ("" = home), spot, activity, rain_proof],
## greetings.
const VILLAGERS := {
	"rakoto": {
		"name": "Rakoto", "home": "Maison_Ouest", "size": 1.0, "skin": Color(0.45, 0.29, 0.19),
		"layers": [["trousers", Color(0.45, 0.35, 0.25)], ["shirt", Color(0.92, 0.9, 0.82)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.86, 0.74, 0.46)]],
		"routine": [
			[6, 30, "rice_fields", "Riziere_Voisins_1", "WORK", true],
			[12, 0, "rice_fields", "Cabane", "STAND", true],
			[13, 0, "rice_fields", "Riziere_Voisins_1", "WORK", true],
			[16, 0, "", "Place", "STAND", false],
			[18, 0, "", "Maison_Ouest", "INSIDE", true],
		],
		"greetings": ["Bonjour ! Le riz pousse bien cette année.", "Les rizières ont besoin de bras, tu sais."],
	},
	"ravao": {
		"name": "Ravao", "home": "Maison_Est", "size": 1.0, "skin": Color(0.55, 0.36, 0.24),
		"layers": [["skirt", Color(0.75, 0.3, 0.25)], ["shirt", Color(0.95, 0.85, 0.55)], ["hair_bun", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[7, 0, "", "Marche", "STAND", true],
			[12, 0, "", "Banc_Est", "STAND", false],
			[13, 30, "", "Marche", "STAND", true],
			[17, 30, "", "Maison_Est", "INSIDE", true],
		],
		"greetings": ["Des légumes frais au marché !", "Bonjour ! Tu passes au marché ?"],
	},
	"neny_soa": {
		"name": "Neny Soa", "home": "Maison_Sud", "size": 0.95, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["skirt", Color(0.3, 0.35, 0.55)], ["shirt", Color(0.85, 0.85, 0.85)], ["hair_bun", Color(0.75, 0.75, 0.75)]],
		"routine": [
			[8, 0, "", "Place", "WANDER", false],
			[11, 0, "", "Maison_Sud", "INSIDE", true],
			[15, 0, "", "Banc_Est", "STAND", false],
			[17, 30, "", "Maison_Sud", "INSIDE", true],
		],
		"greetings": ["Ah, mon enfant ! Tu travailles bien.", "Quand j'étais jeune, tout ce champ était à mon père."],
	},
	"koto": {
		"name": "Koto", "home": "Maison_Sud", "size": 0.8, "skin": Color(0.5, 0.33, 0.22),
		"layers": [["shorts", Color(0.25, 0.35, 0.6)], ["shirt", Color(0.85, 0.3, 0.25)], ["hair", Color(0.12, 0.09, 0.07)]],
		"routine": [
			[7, 30, "", "Place", "WANDER", false],
			[12, 0, "", "Maison_Sud", "INSIDE", true],
			[14, 0, "", "Marche", "WANDER", false],
			[17, 0, "", "Place", "WANDER", false],
			[18, 30, "", "Maison_Sud", "INSIDE", true],
		],
		"greetings": ["Salut ! On joue ?", "J'ai vu un caméléon près du manguier !"],
	},
	"naivo": {
		"name": "Naivo", "home": "Maison_Est", "size": 1.05, "skin": Color(0.62, 0.42, 0.28),
		"layers": [["shorts", Color(0.3, 0.4, 0.3)], ["shirt", Color(0.6, 0.45, 0.3)], ["hair", Color(0.1, 0.08, 0.06)], ["hat", Color(0.8, 0.68, 0.42)]],
		"routine": [
			[6, 15, "rice_fields", "Riziere_Voisins_2", "WORK", true],
			[11, 30, "rice_fields", "Cabane", "STAND", true],
			[12, 30, "rice_fields", "Riziere_Voisins_2", "WORK", true],
			[15, 30, "", "Marche", "STAND", false],
			[17, 0, "", "Place", "STAND", false],
			[18, 15, "", "Maison_Est", "INSIDE", true],
		],
		"greetings": ["Belle journée pour travailler la terre.", "Bonjour, voisin !", "Le repiquage, ça casse le dos !"],
	},
}

func _initialize() -> void:
	_build_villager_scene()
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	for id: String in VILLAGERS:
		if not ResourceLoader.exists(DATA_DIR + id + ".tres"):
			ResourceSaver.save(_make_data(VILLAGERS[id]), DATA_DIR + id + ".tres")
			print("%s%s.tres written" % [DATA_DIR, id])
	for zone_id: String in ZONES:
		_place_in_zone(zone_id)
	quit()

func _build_villager_scene() -> void:
	var villager := CharacterBody2D.new()
	villager.name = "Villager"
	villager.set_script(load("res://entities/villager/villager.gd"))
	villager.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Animals layer: the player (who masks it) bumps into them; they mask
	# nothing - they keep to the roads and wait for the player themselves.
	villager.collision_layer = 8
	villager.collision_mask = 0

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	_add(villager, villager, shape)

	var visual := Node2D.new()
	visual.name = "VillagerVisual"
	visual.set_script(load("res://entities/villager/villager_visual.gd"))
	_add(villager, villager, visual)

	var bubble := Label.new()
	bubble.name = "Bubble"
	bubble.visible = false
	bubble.position = Vector2(-90, -136)
	bubble.size = Vector2(180, 22)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.z_index = 40
	bubble.z_as_relative = false
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.outline_size = 5
	settings.outline_color = Color(0.1, 0.07, 0.05)
	bubble.label_settings = settings
	_add(villager, villager, bubble)

	_save(villager, VILLAGER_SCENE)
	villager.free()

func _make_data(spec: Dictionary) -> VillagerData:
	var look := VillagerLook.new()
	look.skin_color = spec["skin"]
	var layers: Array[VillagerLayer] = []
	for entry: Array in spec["layers"]:
		var layer := VillagerLayer.new()
		layer.texture = load(LAYERS % entry[0])
		layer.color = entry[1]
		layers.append(layer)
	look.layers = layers
	var data := VillagerData.new()
	data.display_name = spec["name"]
	data.home = spec["home"]
	data.size = spec["size"]
	data.look = look
	var routine: Array[VillagerStop] = []
	for entry: Array in spec["routine"]:
		var stop := VillagerStop.new()
		stop.hour = entry[0]
		stop.minute = entry[1]
		stop.zone = entry[2]
		stop.spot = entry[3]
		stop.activity = VillagerStop.Activity[entry[4]]
		stop.rain_proof = entry[5]
		routine.append(stop)
	data.routine = routine
	data.greetings = PackedStringArray(spec["greetings"])
	return data

func _place_in_zone(zone_id: String) -> void:
	var table: Dictionary = ZONES[zone_id]
	var path: String = table["scene"]
	var zone: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for old in ["VillagerRoads", "Villagers", "RizieresVoisins"]:
		if zone.has_node(old):
			var node := zone.get_node(old)
			zone.remove_child(node)
			node.free()

	var roads := Node2D.new()
	roads.name = "VillagerRoads"
	roads.set_script(load("res://entities/villager/villager_roads.gd"))
	roads.set("zone_id", zone_id)
	_add(zone, zone, roads)
	for road_name: String in table["roads"]:
		var line := Line2D.new()
		line.name = road_name
		line.points = PackedVector2Array(table["roads"][road_name])
		line.width = 6.0
		line.default_color = Color(1.0, 0.85, 0.3, 0.6)
		_add(zone, roads, line)
	var spots := Node2D.new()
	spots.name = "Spots"
	_add(zone, roads, spots)
	for spot_name: String in table["spots"]:
		var marker := Marker2D.new()
		marker.name = spot_name
		marker.position = table["spots"][spot_name]
		marker.gizmo_extents = 16.0
		_add(zone, spots, marker)

	for tree_name: String in table["remove_trees"]:
		var tree := zone.get_node_or_null("Trees/" + tree_name)
		if tree != null:
			tree.get_parent().remove_child(tree)
			tree.free()
			print("%s: tree %s removed" % [path, tree_name])

	if not table["paddies"].is_empty():
		var paddies := Node2D.new()
		paddies.name = "RizieresVoisins"
		paddies.y_sort_enabled = true
		_add(zone, zone, paddies)
		var ground: Node2D = zone.get_node("GroundLayer")
		for i in table["paddies"].size():
			var entry: Array = table["paddies"][i]
			var paddy := Node2D.new()
			paddy.name = "Riziere%d" % (i + 1)
			paddy.set_script(load("res://structures/farm/village_paddy/village_paddy.gd"))
			paddy.y_sort_enabled = true
			# On the ground grid, like everything else on the map.
			paddy.position = ground.position + Vector2(entry[0] * TILE)
			paddy.set("size", entry[1])
			_add(zone, paddies, paddy)
			# No tall grass growing in the water.
			var grass: TileMapLayer = zone.get_node_or_null("TallGrassLayer")
			if grass != null:
				for x in entry[1].x:
					for y in entry[1].y:
						var at: Vector2 = paddy.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
						grass.erase_cell(grass.local_to_map(grass.to_local(at)))

	var villagers := Node2D.new()
	villagers.name = "Villagers"
	villagers.y_sort_enabled = true
	_add(zone, zone, villagers)
	var scene: PackedScene = load(VILLAGER_SCENE)
	for id: String in VILLAGERS:
		var spec: Dictionary = VILLAGERS[id]
		if not _passes_through(spec, zone_id):
			continue
		var villager: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		villager.name = spec["name"].replace(" ", "")
		villager.set("data", load(DATA_DIR + id + ".tres"))
		# Placed by the clock in game; here, somewhere sensible to find it.
		villager.position = table["spots"].get(spec["home"], table["spots"].values()[0])
		_add(zone, villagers, villager)

	_save(zone, path)
	zone.free()

## Whether a villager's day passes through `zone_id` (home is the village).
func _passes_through(spec: Dictionary, zone_id: String) -> bool:
	if zone_id == "village":
		return true
	for entry: Array in spec["routine"]:
		if entry[2] == zone_id:
			return true
	return false

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
