extends SceneTree

## Turns the coop's inside (chicken_coop_interior.tscn) into a room built
## from its level: takes out the old picture (Sprite2D, farm-interior01.png)
## and its hand-drawn walls (Walls), adds a CoopInterior - which draws the
## room, makes its walls and places the door, the spawn, the bowls, the hens'
## area and the camera limits from the coop's level. The zone's other nodes
## are kept. Safe to rerun. With --editor (see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/build_coop_interior.gd

const SCENE := "res://world/areas/interior/farm/chicken_coop_interior.tscn"
const INTERIOR := "res://structures/chicken_coop/coop_interior.gd"

func _initialize() -> void:
	var zone: Node = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for old in ["Sprite2D", "Walls", "CoopInterior"]:
		if zone.has_node(old):
			var node := zone.get_node(old)
			zone.remove_child(node)
			node.free()
	var interior := Node2D.new()
	interior.name = "CoopInterior"
	interior.set_script(load(INTERIOR))
	zone.add_child(interior)
	# First: its _ready places the others before the camera reads the limits.
	zone.move_child(interior, 0)
	interior.owner = zone
	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, SCENE)
	print("%s %s" % [SCENE, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	zone.free()
	quit()
