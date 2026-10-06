extends SceneTree

## Places the free-roaming zebu herds (and their pen, if any) in the zone
## scenes, from the table below: rebuilds each zone's ZebuHerd node (one
## GrazingZebu per home) and ZebuPen instance, leaving the rest of the scene
## alone. Rerun after editing the table - with --editor: outside the editor
## Godot doesn't know the scripts' default values and re-saving a scene
## would write every exported property into it:
##   godot --headless --editor --path . --script res://tools/place_zebu_herds.gd
## Fine-tuning by hand in the editor afterwards is fine too - but rerunning
## this resets the herds to the table.

const ZEBU := "res://entities/zebu/grazing_zebu.tscn"
const PEN := "res://entities/zebu/zebu_pen.tscn"
const TILE := 48

## zone scene -> herd: "homes" (where each zebu grazes around, in px) and
## "pen_cell" (the ground cell of the pen's top-left post; leave it out for
## a herd without a pen - it then sleeps in the field).
const ZONES := {
	"res://world/areas/exterior/player_village.tscn": {
		"homes": [Vector2(1880, 560), Vector2(1990, 625), Vector2(1960, 705), Vector2(1860, 745)],
		"pen_cell": Vector2i(43, 12),
	},
	"res://world/areas/exterior/rice_fields.tscn": {
		"homes": [Vector2(1600, 1160), Vector2(1720, 1090), Vector2(1650, 1240)],
	},
}

func _initialize() -> void:
	for path: String in ZONES:
		_place(path, ZONES[path])
	quit()

func _place(path: String, herd: Dictionary) -> void:
	var zone: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for old in ["ZebuPen", "ZebuHerd"]:
		if zone.has_node(old):
			var node := zone.get_node(old)
			zone.remove_child(node)
			node.free()

	if herd.has("pen_cell"):
		var pen: Node2D = (load(PEN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		pen.name = "ZebuPen"
		# On the ground grid, like everything else on the map.
		var ground: Node2D = zone.get_node("GroundLayer")
		pen.position = ground.position + Vector2(herd["pen_cell"] * TILE)
		zone.add_child(pen)
		pen.owner = zone

	var herd_node := Node2D.new()
	herd_node.name = "ZebuHerd"
	herd_node.y_sort_enabled = true
	zone.add_child(herd_node)
	herd_node.owner = zone
	var zebu_scene: PackedScene = load(ZEBU)
	var homes: Array = herd["homes"]
	for i in homes.size():
		var zebu: Node2D = zebu_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		zebu.name = "Zebu%d" % (i + 1)
		zebu.position = homes[i]
		herd_node.add_child(zebu)
		zebu.owner = zone

	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, path)
	print("%s: %d zebus%s%s" % [path, homes.size(), ", a pen" if herd.has("pen_cell") else "",
		"" if error == OK else " - SAVE FAILED (%d)" % error])
	zone.free()
