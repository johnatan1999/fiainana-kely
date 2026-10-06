extends SceneTree
## Wooden fence, 16 tiles of 48 px in a 4x4 atlas: tile index = N*1 + E*2 +
## S*4 + W*8 (which sides connect). A post in the middle of the cell, two
## rails towards each connected side - along the cell's bottom half, so
## neighbouring tiles line up.
const C := 48
const WOOD := Color(0.56, 0.38, 0.21)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const OUTLINE := Color(0.2, 0.12, 0.06)
# Post: x 20..27, y 10..35 (its foot at y 35 = 11 px below the cell center).
const POST := Rect2i(20, 10, 8, 26)
var img: Image

func _init():
	img = Image.create(C * 4, C * 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for index in 16:
		var o := Vector2i((index % 4) * C, (index / 4) * C)
		var n := index & 1 != 0
		var e := index & 2 != 0
		var s := index & 4 != 0
		var w := index & 8 != 0
		_shadow(o)
		# Rails seen from the side (east/west) and from above (north/south).
		if w: _hrail(o, 0, 21)
		if e: _hrail(o, 27, C)
		if n: _vrail(o, 0, POST.position.y + 2)
		if s: _vrail(o, POST.end.y - 4, C)
		_post(o)
	_outline()
	img.save_png("res://assets/tileset/fence_wood.png")
	print("fence_wood.png written")
	quit()

func _rect(r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

func _shadow(o: Vector2i) -> void:
	for x in range(-9, 10):
		for y in range(-2, 3):
			if x * x / 81.0 + y * y / 4.0 <= 1.0:
				img.set_pixel(o.x + 24 + x, o.y + POST.end.y + y, Color(0, 0, 0, 0.22))

func _post(o: Vector2i) -> void:
	_rect(Rect2i(o + POST.position, POST.size), WOOD)
	_rect(Rect2i(o + POST.position, Vector2i(2, POST.size.y)), WOOD_LIGHT)
	_rect(Rect2i(o + POST.position + Vector2i(POST.size.x - 2, 0), Vector2i(2, POST.size.y)), WOOD_DARK)
	# Pointed top.
	_rect(Rect2i(o + POST.position + Vector2i(1, -2), Vector2i(POST.size.x - 2, 2)), WOOD)
	_rect(Rect2i(o + POST.position + Vector2i(3, -4), Vector2i(2, 2)), WOOD)

## Two horizontal planks between x0 and x1 (cell-relative).
func _hrail(o: Vector2i, x0: int, x1: int) -> void:
	for y in [15, 25]:
		_rect(Rect2i(o + Vector2i(x0, y), Vector2i(x1 - x0, 4)), WOOD)
		_rect(Rect2i(o + Vector2i(x0, y), Vector2i(x1 - x0, 1)), WOOD_LIGHT)
		_rect(Rect2i(o + Vector2i(x0, y + 3), Vector2i(x1 - x0, 1)), WOOD_DARK)

## A plank seen from above, running north-south between y0 and y1.
func _vrail(o: Vector2i, y0: int, y1: int) -> void:
	_rect(Rect2i(o + Vector2i(21, y0), Vector2i(6, y1 - y0)), WOOD)
	_rect(Rect2i(o + Vector2i(21, y0), Vector2i(1, y1 - y0)), WOOD_LIGHT)
	_rect(Rect2i(o + Vector2i(26, y0), Vector2i(1, y1 - y0)), WOOD_DARK)

## One-pixel outline around the wood (not the shadow), kept inside each tile.
func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / C == x / C and p.y / C == y / C and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
