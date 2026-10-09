extends SceneTree
## The zebus' placeholder props, one per 192 x 192 cell (4 x 1), each
## standing on its cell's bottom edge, at twice the on-screen density.
##   0 the farm pen's trough, empty: a hollowed log and an empty hay rack
##   1 the same trough, full: water in the log, hay in the rack
##   2 the zebu dealer's post: a tethering post with a rope, a stick and a
##     hat hung on it
##   3 the zebu plough (angadin'omby), side view, pulled to the right: the
##     yoke at the beam's front (right) end, the share and handle at the back
##   godot --headless --path . --script res://tools/placeholder_art/gen_zebu_market.gd
const C := 192
const OUTLINE := Color(0.16, 0.1, 0.05)
const WOOD := Color(0.55, 0.37, 0.2)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
const WATER := Color(0.45, 0.62, 0.72)
const HAY := Color(0.88, 0.76, 0.4)
const HAY_DARK := Color(0.7, 0.58, 0.28)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 5
	img = Image.create(C * 4, C, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _trough(false)
	_cell(1); _trough(true)
	_cell(2); _post()
	_cell(3); _plough()
	_outline()
	img.save_png("res://assets/sprites/props/zebu_market.png")
	print("zebu_market.png written")
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

func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	for yy in range(int(y), int(y + h)):
		for xx in range(int(x), int(x + w)):
			_px(xx, yy, c)

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

func _trough(full: bool) -> void:
	_ellipse(96, C - 4, 88, 6, Color(0, 0, 0, 0.25))
	# The hay rack behind: two posts, slats.
	_rect(30, C - 120, 8, 100, WOOD_DARK)
	_rect(154, C - 120, 8, 100, WOOD_DARK)
	_rect(26, C - 124, 140, 8, WOOD)
	if full:
		for i in 40:
			var x := rng.randf_range(36, 156)
			_line(Vector2(x, C - 116), Vector2(x + rng.randf_range(-10, 10), C - 70), 3, HAY if i % 3 else HAY_DARK)
		_ellipse(96, C - 112, 64, 12, HAY)
	for x in range(40, 156, 14):
		_rect(x, C - 116, 4, 50, WOOD)
	# The hollowed log in front.
	_ellipse(96, C - 30, 84, 22, WOOD_DARK)
	_ellipse(96, C - 36, 80, 18, WOOD)
	_ellipse(96, C - 40, 70, 10, WATER if full else WOOD_DARK.darkened(0.2))
	if full:
		_ellipse(76, C - 42, 14, 3, WATER.lightened(0.3))
	_rect(14, C - 30, 10, 26, WOOD_DARK)
	_rect(168, C - 30, 10, 26, WOOD_DARK)

func _post() -> void:
	_ellipse(96, C - 4, 40, 6, Color(0, 0, 0, 0.25))
	_rect(88, C - 150, 16, 148, WOOD_DARK)
	_rect(90, C - 150, 6, 148, WOOD)
	_ellipse(96, C - 152, 10, 5, WOOD_LIGHT)
	# A coiled rope, a herding stick leaning on it, a straw hat on top.
	for i in 3:
		_ellipse(96, C - 96 + i * 7, 16, 5, HAY_DARK)
		_ellipse(96, C - 97 + i * 7, 12, 3, WOOD)
	_line(Vector2(130, C - 4), Vector2(104, C - 140), 4, WOOD_LIGHT)
	_ellipse(96, C - 158, 30, 7, HAY)
	_ellipse(96, C - 166, 16, 10, HAY)
	_rect(80, C - 162, 32, 3, Color(0.6, 0.2, 0.15))

func _plough() -> void:
	const METAL := Color(0.55, 0.56, 0.6)
	_ellipse(96, C - 4, 80, 5, Color(0, 0, 0, 0.25))
	# The beam, from the yoke (front, right) down to the share (back, left).
	_line(Vector2(176, C - 70), Vector2(52, C - 30), 7, WOOD_DARK)
	_line(Vector2(176, C - 72), Vector2(52, C - 32), 3, WOOD)
	# The yoke across the zebus' necks, seen end-on.
	_rect(166, C - 92, 14, 40, WOOD_DARK)
	_rect(168, C - 90, 10, 36, WOOD_LIGHT)
	# The share, biting into the ground, and the sole.
	_line(Vector2(56, C - 32), Vector2(70, C - 6), 9, METAL)
	_line(Vector2(30, C - 8), Vector2(76, C - 8), 5, WOOD_DARK)
	# The handle, rising back to where the ploughman holds it.
	_line(Vector2(48, C - 28), Vector2(14, C - 110), 6, WOOD_DARK)
	_line(Vector2(48, C - 30), Vector2(16, C - 108), 2, WOOD_LIGHT)
	_line(Vector2(8, C - 112), Vector2(24, C - 106), 5, WOOD_DARK)
	# Turned earth behind the share.
	for i in 6:
		_ellipse(20 + i * 7, C - 6 - (i % 2) * 3, 5, 3, Color(0.42, 0.25, 0.15))

## One-pixel outline around opaque pixels, within each cell.
func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / C == x / C and src.get_pixel(p.x, p.y).a > 0.7:
					img.set_pixel(x, y, OUTLINE)
					break
