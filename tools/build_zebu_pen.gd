extends SceneTree

## Builds entities/zebu/zebu_pen.tscn: a ZebuPen whose fence is painted with
## the fence terrain (fence_tileset.tres), an opening on the west side, and
## its Gate / Entrance / Spots markers. Rerun it after changing the size or
## the opening below; tweak the markers in the editor afterwards if needed.
##   godot --headless --editor --path . --script res://tools/build_zebu_pen.gd
## Placing the pen in a zone: tools/place_zebu_herds.gd.

const TILE := 48
const OUT := "res://entities/zebu/zebu_pen.tscn"
## Fence posts on cells (0, 0) .. (SIZE - 1): the inside is SIZE - 2 cells.
const SIZE := Vector2i(6, 4)
## The opening: one fence cell left out, in the west side.
const OPENING := Vector2i(0, 2)
## Where the zebus lie down, in cells (fractions allowed) - two rows of two.
const SPOTS := [Vector2(1.9, 1.7), Vector2(4.0, 1.85), Vector2(2.3, 2.95), Vector2(4.2, 3.0)]

func _initialize() -> void:
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
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1
			if edge and cell != OPENING:
				cells.append(cell)
	fence.set_cells_terrain_connect(cells, 0, 0)

	_marker(pen, pen, "Gate", _center(OPENING) + Vector2(-TILE, 0))
	_marker(pen, pen, "Entrance", _center(OPENING) + Vector2(TILE * 1.1, 0))
	var spots := Node2D.new()
	spots.name = "Spots"
	_add(pen, pen, spots)
	for i in SPOTS.size():
		_marker(pen, spots, "Spot%d" % (i + 1), SPOTS[i] * TILE)

	var scene := PackedScene.new()
	scene.pack(pen)
	var error := ResourceSaver.save(scene, OUT)
	print("%s written" % OUT if error == OK else "build_zebu_pen: save failed (%d)" % error)
	pen.free()
	quit()

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
