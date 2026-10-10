extends SceneTree

## Places the side quests' QuestTargets in their zones, from the TARGETS
## table: under a "QuestTargets" node (y-sorted) in each zone's scene, a
## QuestTarget per row with its look as a child. A target already there by
## that name is replaced: add a row (or move one) and run it again. The
## rest of the scene is left alone. See docs/quests.md.
## Run with --editor (see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/place_quest_targets.gd

const QUEST_TARGET := "res://entities/quest/quest_target.gd"
const HOOF_PRINTS := "res://entities/quest/hoof_prints.gd"
const ZEBU_ART := "res://assets/sprites/animals/zebu.png"
const FOREST := "res://world/areas/exterior/forest.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"

## One per target:
## - "scene", "name" (the node), "target" (QuestStep.target);
## - "appears": QuestTarget.Show ("during": while a step is there, "after":
##   once "quest" is done);
## - "position", and "reach" (walk into this area) or "interact" (use it
##   within this size);
## - "look": "hoof_prints" (with "direction"), "zebu" (with "frame",
##   "flip") or "scene" (an instance of "path": a prop...).
const TARGETS := [
	# Rakoto's lost zebu (data/quests/rakoto_lost_zebu.tres).
	{"scene": FOREST, "name": "ZebuTracks", "target": "zebu_tracks", "appears": "during",
		"position": Vector2(1220, 718), "reach": Vector2(170, 110),
		"look": "hoof_prints", "direction": Vector2(1, 0.25)},
	{"scene": FOREST, "name": "LostZebu", "target": "lost_zebu", "appears": "during",
		"position": Vector2(1500, 860), "interact": Vector2(130, 100),
		"look": "zebu", "frame": 0, "flip": true},
	{"scene": VILLAGE, "name": "Volamena", "target": "volamena_home", "appears": "after",
		"quest": "rakoto_lost_zebu", "position": Vector2(330, 1270),
		"look": "zebu", "frame": 4, "flip": false},
	# Neny Soa's remedy (data/quests/neny_soa_remedy.tres): the jar she left
	# by the forest spring.
	{"scene": FOREST, "name": "NenySoaJar", "target": "spring_jar", "appears": "during",
		"position": Vector2(1135, 190), "interact": Vector2(130, 100),
		"look": "scene", "path": "res://entities/props/water_jar.tscn"},
]

func _initialize() -> void:
	var scenes := {}
	for row: Dictionary in TARGETS:
		if not scenes.has(row["scene"]):
			scenes[row["scene"]] = (load(row["scene"]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_place(scenes[row["scene"]], row)
	for path: String in scenes:
		var root: Node = scenes[path]
		var scene := PackedScene.new()
		scene.pack(root)
		var error := ResourceSaver.save(scene, path)
		print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
		root.free()
	quit()

func _place(zone: Node, row: Dictionary) -> void:
	var holder := zone.get_node_or_null("QuestTargets")
	if holder == null:
		holder = Node2D.new()
		holder.name = "QuestTargets"
		holder.y_sort_enabled = true
		_add(zone, zone, holder)
	var old := holder.get_node_or_null(NodePath(row["name"]))
	if old != null:
		holder.remove_child(old)
		old.free()
	var target := Node2D.new()
	target.name = row["name"]
	target.set_script(load(QUEST_TARGET))
	target.set("target_id", row["target"])
	target.position = row["position"]
	if row["appears"] == "after":
		target.set("appears", 1) # QuestTarget.Show.AFTER_DONE
		target.set("quest_id", row["quest"])
	if row.has("reach"):
		target.set("reach_size", row["reach"])
	if row.has("interact"):
		target.set("interact_size", row["interact"])
	_add(zone, holder, target)
	match row["look"]:
		"hoof_prints":
			var prints := Node2D.new()
			prints.name = "HoofPrints"
			prints.set_script(load(HOOF_PRINTS))
			prints.set("direction", row["direction"])
			prints.z_index = -1
			_add(zone, target, prints)
		"zebu":
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			sprite.texture = load(ZEBU_ART)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.hframes = 4
			sprite.vframes = 2
			sprite.frame = row["frame"]
			sprite.flip_h = row["flip"]
			sprite.scale = Vector2(0.8, 0.8)
			sprite.offset = Vector2(0, -48)
			_add(zone, target, sprite)
		"scene":
			var look: Node = (load(row["path"]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			_add(zone, target, look)
	print("%s: QuestTargets/%s" % [zone.name, row["name"]])

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node
