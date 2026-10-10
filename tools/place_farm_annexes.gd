extends SceneTree

## Places the farm house's annexes (HouseAnnex: the rice granary, the
## kitchen) in the farm scene, from the table below - where each will stand
## once built (FamilyProject "granary", "kitchen"). Rebuilds those nodes,
## leaving the rest of the scene alone. Run with --editor (see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_farm_annexes.gd

const ANNEX := "res://entities/farm/house_annex.gd"
const FARM := "res://world/areas/exterior/player_farm.tscn"
## Node name -> [building, where its foot stands]. In the yard, between the
## house and the field's fence, below the path the family walks (y = 560),
## either side of the rooster's stake (960, 650).
const ANNEXES := {
	"Granary": ["granary", Vector2(860, 684)],
	"Kitchen": ["kitchen", Vector2(1066, 684)],
}

func _initialize() -> void:
	var zone: Node = (load(FARM) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for node_name: String in ANNEXES:
		if zone.has_node(node_name):
			var old := zone.get_node(node_name)
			zone.remove_child(old)
			old.free()
		var annex := Node2D.new()
		annex.name = node_name
		annex.set_script(load(ANNEX))
		annex.set("building", ANNEXES[node_name][0])
		annex.position = ANNEXES[node_name][1]
		zone.add_child(annex)
		annex.owner = zone
	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, FARM)
	print("%s %s" % [FARM, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	zone.free()
	quit()
