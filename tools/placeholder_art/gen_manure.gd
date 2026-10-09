extends SceneTree
## Zebu manure (zezik'omby), one per 192 x 192 cell (4 x 1), each standing
## on its cell's bottom edge, at twice the on-screen density:
##   0 a small manure heap by the pen
##   1 a big manure heap, with straw
##   2 a basket (sobika) of manure - the item's icon
##   3 manure spread on a plot, seen from above: dark clods over the whole
##     cell (drawn over the soil, at 1/4 scale it covers one 48 px plot)
##   godot --headless --path . --script res://tools/placeholder_art/gen_manure.gd
const C := 192
const OUTLINE := Color(0.16, 0.1, 0.05)
const DUNG := Color(0.33, 0.24, 0.14)
const DUNG_DARK := Color(0.22, 0.15, 0.09)
const DUNG_LIGHT := Color(0.45, 0.34, 0.2)
const STRAW := Color(0.85, 0.72, 0.42)
const STRAW_DARK := Color(0.66, 0.53, 0.28)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 9
	img = Image.create(C * 4, C, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _heap(70, 34, 6)
	_cell(1); _heap(90, 62, 14)
	_cell(2); _basket()
	_outline(3)
	_cell(3); _spread()
	img.save_png("res://assets/sprites/props/manure.png")
	print("manure.png written")
	quit()

func _cell(i: int) -> void:
	o = Vector2(i * C, 0)

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= C or y >= C:
		return
	var p := Vector2i(int(o.x + x), int(o.y + y))
	if c.a < 1.0:
		c = img.get_pixelv(p).blend(c)
	img.set_pixelv(p, c)

func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(cy - ry), int(cy + ry) + 1):
		for xx in range(int(cx - rx), int(cx + rx) + 1):
			if pow((xx - cx) / rx, 2) + pow((yy - cy) / ry, 2) <= 1.0:
				_px(xx, yy, c)

func _line(a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		_ellipse(p.x, p.y, width / 2.0, width / 2.0, c)

## A mound of dung, `rx` wide and `h` high, with bits of straw.
func _heap(rx: float, h: float, straws: int) -> void:
	_ellipse(96, C - 4, rx + 6, 6, Color(0, 0, 0, 0.25))
	_ellipse(96, C - 4 - h / 2.0, rx, h / 2.0 + 4, DUNG_DARK)
	_ellipse(96, C - 8 - h / 2.0, rx - 6, h / 2.0, DUNG)
	for i in 14:
		var x := 96 + rng.randf_range(-rx * 0.7, rx * 0.7)
		var y := C - 8 - rng.randf_range(0.2, 0.9) * h
		_ellipse(x, y, rng.randf_range(5, 10), rng.randf_range(3, 6), DUNG_LIGHT if i % 3 == 0 else DUNG_DARK)
	for i in straws:
		var x := 96 + rng.randf_range(-rx * 0.8, rx * 0.8)
		var y := C - 8 - rng.randf_range(0.1, 0.8) * h
		_line(Vector2(x, y), Vector2(x + rng.randf_range(-16, 16), y - rng.randf_range(2, 8)), 2, STRAW)

func _basket() -> void:
	_ellipse(96, C - 4, 66, 6, Color(0, 0, 0, 0.25))
	# The dung heaped above the rim, then the basket's woven body.
	_ellipse(96, C - 92, 56, 26, DUNG_DARK)
	_ellipse(96, C - 96, 50, 20, DUNG)
	for i in 8:
		_ellipse(96 + rng.randf_range(-40, 40), C - 96 - rng.randf_range(0, 14), 7, 4, DUNG_LIGHT)
	for y in range(C - 84, C - 6, 2):
		var t := float(y - (C - 84)) / 78.0
		var half := lerpf(62, 46, t)
		var c := STRAW if (y / 6) % 2 == 0 else STRAW_DARK
		_ellipse(96, y, half, 1, c)
	_ellipse(96, C - 84, 62, 7, STRAW_DARK)

## Clods scattered over the whole cell - no outline, it lies on the soil.
func _spread() -> void:
	for i in 70:
		var x := rng.randf_range(10, C - 10)
		var y := rng.randf_range(10, C - 10)
		var r := rng.randf_range(5, 12)
		_ellipse(x, y, r, r * 0.7, Color(DUNG_DARK, 0.85))
		_ellipse(x - 2, y - 2, r * 0.6, r * 0.4, Color(DUNG, 0.9))
	for i in 18:
		var x := rng.randf_range(10, C - 10)
		var y := rng.randf_range(10, C - 10)
		_line(Vector2(x, y), Vector2(x + rng.randf_range(-12, 12), y + rng.randf_range(-6, 6)), 2, Color(STRAW, 0.8))

## One-pixel outline around opaque pixels, in the first `cells` cells only.
func _outline(cells: int) -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in cells * C:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < cells * C and p.y < img.get_height() \
						and p.x / C == x / C and src.get_pixel(p.x, p.y).a > 0.7:
					img.set_pixel(x, y, OUTLINE)
					break
