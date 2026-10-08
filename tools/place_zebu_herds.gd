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
## Also, per zone (optional keys): the player's zebus' pasture marker and
## trough (ZebuManager spawns the herd there), the zebu dealer's stand and a
## herd only there on market day (MarketDayOnly), and trees to take out.
## Build the trough and stand scenes first: tools/build_zebu_market.gd.

const ZEBU := "res://entities/zebu/grazing_zebu.tscn"
const PEN := "res://entities/zebu/zebu_pen.tscn"
const TROUGH := "res://entities/zebu/zebu_trough.tscn"
const MANURE_HEAP := "res://entities/zebu/manure_heap.tscn"
const MARKET := "res://entities/zebu/zebu_market.tscn"
const MARKET_DAY_ONLY := "res://entities/zebu/market_day_only.gd"
const TILE := 48

## zone scene -> herd: "homes" (where each zebu grazes around, in px) and
## "pen_cell" (the ground cell of the pen's top-left post; leave it out for
## a herd without a pen - it then sleeps in the field). Optional:
## "wander_radius"; "market_only" (the herd is only there on market day -
## the zebus for sale); "market" (the dealer's stand, ZebuMarket);
## "pasture" and "trough" (the player's zebus graze around the ZebuPasture
## marker; their ZebuTrough and ManureHeap); "remove_trees" (names under
## Trees).
const ZONES := {
	"res://world/areas/exterior/player_village.tscn": {
		"homes": [Vector2(1880, 560), Vector2(1990, 625), Vector2(1960, 705), Vector2(1860, 745)],
		"pen_cell": Vector2i(43, 12),
	},
	"res://world/areas/exterior/rice_fields.tscn": {
		"homes": [Vector2(1600, 1160), Vector2(1720, 1090), Vector2(1650, 1240)],
	},
	# The player's zebus, west of the fields: their pen, pasture and trough.
	"res://world/areas/exterior/player_farm.tscn": {
		"homes": [],
		"pen_cell": Vector2i(3, 15),
		"pasture": Vector2(320, 1030),
		"trough": Vector2(290, 960),
		"manure": Vector2(185, 955),
	},
	# The zebu market, north of the river: zebus for sale in the corral on
	# the zoma, and the dealer's stand.
	"res://world/areas/exterior/bourg.tscn": {
		"homes": [Vector2(380, 150), Vector2(470, 130), Vector2(440, 190)],
		"pen_cell": Vector2i(6, 1),
		"wander_radius": 30.0,
		"market_only": true,
		"market": Vector2(200, 310),
		"remove_trees": ["Ala_Avaratra_02", "Ala_Avaratra_03"],
	},
}

func _initialize() -> void:
	for path: String in ZONES:
		_place(path, ZONES[path])
	quit()

func _place(path: String, herd: Dictionary) -> void:
	var zone: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for tree_name: String in herd.get("remove_trees", []):
		if zone.has_node("Trees/" + tree_name):
			var tree := zone.get_node("Trees/" + tree_name)
			tree.get_parent().remove_child(tree)
			tree.free()
	for old in ["ZebuPen", "ZebuHerd", "ZebuPasture", "ZebuTrough", "ManureHeap", "TsenaOmby"]:
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
	if herd.get("market_only", false):
		herd_node.set_script(load(MARKET_DAY_ONLY))
	zone.add_child(herd_node)
	herd_node.owner = zone
	var zebu_scene: PackedScene = load(ZEBU)
	var homes: Array = herd["homes"]
	for i in homes.size():
		var zebu: Node2D = zebu_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		zebu.name = "Zebu%d" % (i + 1)
		zebu.position = homes[i]
		if herd.has("wander_radius"):
			zebu.set("wander_radius", herd["wander_radius"])
		herd_node.add_child(zebu)
		zebu.owner = zone

	if herd.has("pasture"):
		var pasture := Marker2D.new()
		pasture.name = "ZebuPasture"
		pasture.position = herd["pasture"]
		zone.add_child(pasture)
		pasture.owner = zone
	for entry in [["trough", TROUGH, "ZebuTrough"], ["manure", MANURE_HEAP, "ManureHeap"],
			["market", MARKET, "TsenaOmby"]]:
		if herd.has(entry[0]):
			var node: Node2D = (load(entry[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			node.name = entry[2]
			node.position = herd[entry[0]]
			zone.add_child(node)
			node.owner = zone

	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, path)
	print("%s: %d zebus%s%s" % [path, homes.size(), ", a pen" if herd.has("pen_cell") else "",
		"" if error == OK else " - SAVE FAILED (%d)" % error])
	zone.free()
