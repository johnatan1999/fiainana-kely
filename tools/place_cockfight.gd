extends SceneTree

## Places the cockfight pieces in the zone scenes, from the table below:
## - "stake": a Marker2D "RoosterStake" - CockfightManager ties the player's
##   rooster there (TetheredRooster) once they have one;
## - "ring": the tournament ring, a CockfightRing node "CockfightRing".
## Rebuilds those nodes, leaving the rest of the scene alone. Rerun after
## editing the table - with --editor (outside the editor, re-saving a scene
## writes every exported default into it - see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_cockfight.gd
## The villagers who watch the tournament stand at the ring's spots
## (Cockfight_*, tools/place_villagers.gd) - move them with the ring.

const RING := "res://entities/cockfight/cockfight_ring.gd"

const ZONES := {
	# In the yard, south of the house, clear of the paths.
	"res://world/areas/exterior/player_farm.tscn": {"stake": Vector2(960, 650)},
	# On the grass north-east of the market square, by the bridge.
	"res://world/areas/exterior/market_town.tscn": {"ring": Vector2(1380, 500)},
}

func _initialize() -> void:
	for path: String in ZONES:
		_place(path, ZONES[path])
	quit()

func _place(path: String, table: Dictionary) -> void:
	var zone: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for old in ["RoosterStake", "CockfightRing"]:
		if zone.has_node(old):
			var node := zone.get_node(old)
			zone.remove_child(node)
			node.free()
	if table.has("stake"):
		var stake := Marker2D.new()
		stake.name = "RoosterStake"
		stake.position = table["stake"]
		stake.gizmo_extents = 16.0
		zone.add_child(stake)
		stake.owner = zone
	if table.has("ring"):
		var ring := Node2D.new()
		ring.name = "CockfightRing"
		ring.set_script(load(RING))
		ring.position = table["ring"]
		zone.add_child(ring)
		ring.owner = zone
	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	zone.free()
