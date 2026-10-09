extends SceneTree

## The village centre, on the ground the farm left free (tools/split_farm.gd):
## 1. builds the prop scenes of assets/sprites/props/village_center.png
##    (tools/placeholder_art/gen_village_center.gd) in entities/props/;
## 2. rebuilds the village's "VillageCenter" node from the table below - the
##    school (a house model, door shut, with its flag and its football
##    pitch), the water point and its washing stones, the eatery (hotely),
##    the grocery kiosk - leaving the rest of the scene alone.
## Run with --editor (re-saving a scene outside the editor writes every
## exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_village_center.gd
## The villagers' spots there (Sekoly, Fantsakana...) are in
## tools/place_villagers.gd.

const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const SHEET := "res://assets/sprites/props/village_center.png"
const PROPS_DIR := "res://entities/props/"
const PROP_SCRIPT := "res://entities/props/prop.gd"
const SIGN_SCRIPT := "res://entities/props/signboard.gd"
const CELL := 192

## Prop scene -> [sheet cell, scale, base collision size (art px, or
## Vector2.ZERO for none)].
const PROPS := {
	"water_point": [0, 0.8, Vector2(110, 22)],
	"washing_stones": [1, 0.85, Vector2.ZERO],
	"grocery_kiosk": [2, 0.8, Vector2(170, 20)],
	"eatery_table": [3, 0.75, Vector2(160, 16)],
	"flagpole": [4, 0.9, Vector2(30, 12)],
	"football_goal": [5, 0.65, Vector2.ZERO],
	"signboard": [6, 0.5, Vector2.ZERO],
	"hearth": [7, 0.55, Vector2(90, 20)],
}

## What goes where: [name, scene, position, extra properties].
const CENTRE := [
	# The school (sekoly) where the player's house stood, its flag and sign.
	["School", "res://structures/houses/models/house_small_02.tscn", Vector2(760, 470), {"locked": true}],
	["School_Flag", "flagpole", Vector2(1195, 470), {}],
	["School_Sign", "signboard", Vector2(700, 520), {"text": "SEKOLY"}],
	# The football pitch (kianja) in front of it.
	["Pitch_Goal_West", "football_goal", Vector2(640, 790), {}],
	["Pitch_Goal_East", "football_goal", Vector2(1110, 790), {}],
	# The water point (fantsakana) and the washing stones, by the west path.
	["WaterPoint", "water_point", Vector2(575, 870), {}],
	["WaterPoint_WashingStones", "washing_stones", Vector2(720, 875), {}],
	# The eatery (hotely): a house, its tables and its hearth.
	["Eatery", "res://structures/houses/models/house_small_01.tscn", Vector2(620, 1170), {"locked": true}],
	["Eatery_Sign", "signboard", Vector2(575, 1215), {"text": "HOTELY"}],
	["Eatery_Table_1", "eatery_table", Vector2(690, 1265), {}],
	["Eatery_Table_2", "eatery_table", Vector2(860, 1270), {}],
	["Eatery_Hearth", "hearth", Vector2(985, 1210), {}],
	# The grocery kiosk (épicerie), near the market.
	["Grocery", "grocery_kiosk", Vector2(1150, 985), {}],
	["Grocery_Sign", "signboard", Vector2(1040, 1010), {"text": "ÉPICERIE"}],
]

func _initialize() -> void:
	for prop_name: String in PROPS:
		_build_prop(prop_name, PROPS[prop_name])
	_place()
	quit()

func _build_prop(prop_name: String, spec: Array) -> void:
	var prop := Node2D.new()
	prop.name = prop_name.to_pascal_case()
	prop.set_script(load(SIGN_SCRIPT if prop_name == "signboard" else PROP_SCRIPT))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(SHEET)
	sprite.region_enabled = true
	var cell: int = spec[0]
	sprite.region_rect = Rect2((cell % 4) * CELL, (cell / 4) * CELL, CELL, CELL)
	sprite.scale = Vector2.ONE * spec[1]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add(prop, prop, sprite)
	var base_size: Vector2 = spec[2]
	if base_size != Vector2.ZERO:
		var base := StaticBody2D.new()
		base.name = "Base"
		_add(prop, prop, base)
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size = base_size * spec[1]
		shape.shape = box
		shape.position = Vector2(0, -box.size.y / 2.0)
		_add(prop, base, shape)
	_save(prop, PROPS_DIR + prop_name + ".tscn")

func _place() -> void:
	var village: Node = (load(VILLAGE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if village.has_node("VillageCenter"):
		var old := village.get_node("VillageCenter")
		village.remove_child(old)
		old.free()
	var centre := Node2D.new()
	centre.name = "VillageCenter"
	centre.y_sort_enabled = true
	_add(village, village, centre)
	for entry: Array in CENTRE:
		var path: String = entry[1]
		if not path.begins_with("res://"):
			path = PROPS_DIR + path + ".tscn"
		var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = entry[0]
		node.position = entry[2]
		var extra: Dictionary = entry[3]
		for property: String in extra:
			node.set(property, extra[property])
		_add(village, centre, node)
	_save(village, VILLAGE)

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	root.free()
