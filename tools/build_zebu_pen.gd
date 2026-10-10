extends SceneTree

## Builds the zebu pen scenes, one per level of the farm pen (FamilyProject
## "zebu_pen" - every other pen is a level 1): a ZebuPen whose fence is
## painted with the fence terrain (fence_tileset.tres), an opening, and its
## Gate / Entrance / Spots markers. Rerun it after changing the table; tweak
## the markers in the editor afterwards if needed.
##   godot --headless --editor --path . --script res://tools/build_zebu_pen.gd
## Placing the pen in a zone: tools/place_zebu_herds.gd. The bigger levels
## replace the farm's pen in game (FamilyProjectManager.PEN_LEVELS: their
## scene and where their origin is, from the level 1's).

const TILE := 48
const SHELTER := "res://entities/props/thatched_hut.tscn"
## Per level: the scene, the size in fence cells (posts on (0, 0) ..
## SIZE - 1: the inside is SIZE - 2 cells), the opening (one fence cell left
## out) and which way the zebus come in through it ("west": from the left,
## "south": from below), the spots where they lie down (cells, fractions
## allowed), and a shelter inside (cell of its foot, or none).
const LEVELS := [
	{"out": "res://entities/zebu/zebu_pen.tscn", "size": Vector2i(6, 4), "opening": Vector2i(0, 2), "side": "west",
		"spots": [Vector2(1.9, 1.7), Vector2(4.0, 1.85), Vector2(2.3, 2.95), Vector2(4.2, 3.0)]},
	# West of the first one, the gate on the south side, facing the pasture.
	{"out": "res://entities/zebu/zebu_pen_2.tscn", "size": Vector2i(8, 4), "opening": Vector2i(6, 3), "side": "south",
		"spots": [Vector2(1.7, 1.7), Vector2(3.3, 1.8), Vector2(4.9, 1.7), Vector2(6.3, 1.8),
			Vector2(2.2, 2.9), Vector2(3.9, 3.0)]},
	# A row more to the north, and the thatched shelter in its north-west corner.
	{"out": "res://entities/zebu/zebu_pen_3.tscn", "size": Vector2i(8, 5), "opening": Vector2i(6, 4), "side": "south",
		"shelter": Vector2(2.3, 2.6),
		"spots": [Vector2(1.6, 3.2), Vector2(2.9, 3.4), Vector2(4.1, 1.7), Vector2(5.4, 1.8),
			Vector2(6.4, 1.7), Vector2(4.4, 2.9), Vector2(5.7, 3.0), Vector2(4.0, 3.9)]},
]

func _initialize() -> void:
	for level: Dictionary in LEVELS:
		_build(level)
	quit()

func _build(level: Dictionary) -> void:
	var size: Vector2i = level["size"]
	var opening: Vector2i = level["opening"]
	var pen := Node2D.new()
	pen.name = "ZebuPen"
	pen.y_sort_enabled = true
	pen.set_script(load("res://entities/zebu/zebu_pen.gd"))

	var fence := TileMapLayer.new()
	fence.name = "Fence"
	fence.y_sort_enabled = true
	fence.tile_set = load("res://assets/tileset/fence_tileset.tres")
	_add(pen, pen, fence)
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			if edge and cell != opening:
				cells.append(cell)
	fence.set_cells_terrain_connect(cells, 0, 0)

	if level["side"] == "west":
		_marker(pen, pen, "Gate", _center(opening) + Vector2(-TILE, 0))
		_marker(pen, pen, "Entrance", _center(opening) + Vector2(TILE * 1.1, 0))
	else:
		_marker(pen, pen, "Gate", _center(opening) + Vector2(0, TILE))
		_marker(pen, pen, "Entrance", _center(opening) + Vector2(0, -TILE * 1.1))
	var spots := Node2D.new()
	spots.name = "Spots"
	_add(pen, pen, spots)
	for i in level["spots"].size():
		_marker(pen, spots, "Spot%d" % (i + 1), level["spots"][i] * TILE)
	if level.has("shelter"):
		var shelter: Node2D = (load(SHELTER) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		shelter.name = "Shelter"
		shelter.position = level["shelter"] * TILE
		_add(pen, pen, shelter)

	var scene := PackedScene.new()
	scene.pack(pen)
	var error := ResourceSaver.save(scene, level["out"])
	print("%s written" % level["out"] if error == OK else "build_zebu_pen: save failed (%d)" % error)
	pen.free()

func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

func _marker(owner_node: Node, parent: Node, marker_name: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = at
	_add(owner_node, parent, marker)

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node
