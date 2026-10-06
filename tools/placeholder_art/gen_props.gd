extends SceneTree
## Village life props, one per 160 x 112 cell (4 x 2), each standing on its
## cell's bottom edge. Drawn at twice the on-screen density like the crops -
## the prop scenes scale them by 0.5.
##   0 mortar & pestle (fanoto)   1 clay jars      2 woodpile      3 drying mat with rice
##   4 bench                      5 laundry line   6 zebu cart     7 big water jar (sinibe)
const CW := 160
const CH := 112
const OUTLINE := Color(0.16, 0.1, 0.05)
const WOOD := Color(0.55, 0.37, 0.2)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
const CLAY := Color(0.72, 0.38, 0.22)
const CLAY_DARK := Color(0.5, 0.25, 0.14)
const CLAY_LIGHT := Color(0.86, 0.55, 0.35)
var img: Image
var o := Vector2.ZERO # current cell origin
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 11
	img = Image.create(CW * 4, CH * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _mortar()
	_cell(1); _jars()
	_cell(2); _woodpile()
	_cell(3); _mat()
	_cell(4); _bench()
	_cell(5); _laundry()
	_cell(6); _cart()
	_cell(7); _sinibe()
	_outline()
	img.save_png("res://assets/sprites/props/village_props.png")
	print("village_props.png written")
	quit()

func _cell(i: int) -> void:
	o = Vector2((i % 4) * CW, (i / 4) * CH)

# --- primitives, in cell coordinates (y = CH - 1 is the ground) -------------
func _px(x: float, y: float, c: Color) -> void:
	var p := Vector2i(int(o.x + x), int(o.y + y))
	if x >= 0 and y >= 0 and x < CW and y < CH:
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

func _shadow(cx: float, rx: float) -> void:
	_ellipse(cx, CH - 3, rx, 4, Color(0, 0, 0, 0.25))

# --- props --------------------------------------------------------------------
func _mortar() -> void:
	_shadow(80, 26)
	# Pestle leaning out of the mortar.
	_line(Vector2(84, 62), Vector2(104, 4), 6, WOOD_LIGHT)
	_line(Vector2(86, 62), Vector2(106, 4), 2, WOOD_DARK)
	# Mortar: a carved trunk, narrower in the middle.
	for y in range(56, CH - 2):
		var t := float(y - 56) / (CH - 58)
		var half := 18.0 - 6.0 * sin(t * PI)
		_rect(80 - half, y, half * 2, 1, WOOD.lerp(WOOD_DARK, t * 0.5))
		_rect(80 - half, y, 3, 1, WOOD_LIGHT)
	_ellipse(80, 56, 18, 6, WOOD_LIGHT)
	_ellipse(80, 56, 13, 4, Color(0.25, 0.15, 0.08))
	_ellipse(80, 57, 9, 2, Color(0.95, 0.9, 0.75)) # rice inside

func _jar(cx: float, rx: float, h: float, body: Color, light: Color, dark: Color) -> void:
	var top := CH - 2 - h
	_ellipse(cx, CH - 2 - h * 0.45, rx, h * 0.45, body)
	_ellipse(cx + rx * 0.3, CH - 2 - h * 0.4, rx * 0.6, h * 0.35, dark)
	_ellipse(cx, CH - 2 - h * 0.45, rx * 0.8, h * 0.38, body)
	_ellipse(cx - rx * 0.4, CH - 2 - h * 0.55, rx * 0.25, h * 0.18, light)
	_rect(cx - rx * 0.45, top, rx * 0.9, h * 0.15, body)
	_ellipse(cx, top, rx * 0.55, 3, dark)

func _jars() -> void:
	_shadow(78, 40)
	_jar(64, 22, 58, CLAY, CLAY_LIGHT, CLAY_DARK)
	_jar(100, 15, 38, CLAY.darkened(0.08), CLAY_LIGHT, CLAY_DARK)

func _sinibe() -> void:
	_shadow(80, 34)
	_jar(80, 30, 72, Color(0.45, 0.3, 0.22), Color(0.6, 0.45, 0.35), Color(0.3, 0.18, 0.12))
	_ellipse(80, CH - 2 - 72, 15, 4, Color(0.25, 0.4, 0.45)) # water inside

func _woodpile() -> void:
	_shadow(80, 58)
	var rows := [[CH - 12, 6], [CH - 30, 5], [CH - 48, 3]]
	for r in rows:
		var y: float = r[0]
		var n: int = r[1]
		for i in n:
			var x := 80 - (n - 1) * 10.0 + i * 20.0 + rng.randf_range(-1, 1)
			_ellipse(x, y, 10, 9, WOOD_DARK)
			_ellipse(x, y, 8, 7, Color(0.78, 0.6, 0.38))
			_ellipse(x, y, 4, 3, Color(0.66, 0.48, 0.28))

func _mat() -> void:
	# A woven mat (tsihy) laid flat, rice spread out to dry.
	var x0 := 14.0
	var y0 := CH - 46.0
	for y in range(int(y0), CH - 4):
		for x in range(int(x0), CW - 14):
			var weave := (int(x / 4) + int(y / 4)) % 2 == 0
			_px(x, y, Color(0.83, 0.72, 0.48) if weave else Color(0.74, 0.62, 0.4))
	for i in 900:
		var x := rng.randf_range(x0 + 10, CW - 24)
		var y := rng.randf_range(y0 + 6, CH - 10)
		_px(x, y, Color(0.95, 0.82, 0.4) if i % 3 else Color(0.85, 0.68, 0.3))

func _bench() -> void:
	_shadow(80, 50)
	for x in [36, 118]:
		_rect(x, CH - 34, 6, 32, WOOD_DARK)
	_rect(28, CH - 40, 104, 8, WOOD)
	_rect(28, CH - 40, 104, 2, WOOD_LIGHT)
	_rect(28, CH - 33, 104, 1, WOOD_DARK)

func _laundry() -> void:
	for x in [8, 150]:
		_shadow(x + 2, 8)
		_rect(x, 10, 5, CH - 12, WOOD_DARK)
		_rect(x, 10, 1, CH - 12, WOOD_LIGHT)
	for x in range(12, 151):
		var sag := 7.0 * sin(PI * (x - 12) / 138.0)
		_px(x, 14 + sag, Color(0.85, 0.82, 0.7))
	# Lambas drying: striped, plain, patterned.
	var cloths := [[20, Color(0.8, 0.2, 0.18), Color(0.95, 0.93, 0.85)], [60, Color(0.95, 0.75, 0.2), Color(0.95, 0.75, 0.2)], [100, Color(0.22, 0.4, 0.7), Color(0.9, 0.9, 0.9)]]
	for cl in cloths:
		var cx: float = cl[0]
		for x in range(int(cx), int(cx) + 34):
			var top := 15 + 7.0 * sin(PI * (x - 12) / 138.0)
			var length := 46 + 3.0 * sin(x * 0.5)
			for y in range(int(top), int(top + length)):
				var stripe := int((y - top) / 6) % 2 == 0
				_px(x, y, cl[1] if stripe else cl[2])

func _cart() -> void:
	_shadow(78, 60)
	# Shafts reaching forward (to the zebu), resting on the ground.
	_line(Vector2(98, CH - 52), Vector2(154, CH - 6), 4, WOOD_DARK)
	_line(Vector2(92, CH - 54), Vector2(146, CH - 8), 4, WOOD)
	# Bed with plank sides.
	_rect(14, CH - 78, 96, 28, WOOD)
	for y in [CH - 78, CH - 66, CH - 54]:
		_rect(14, y, 96, 2, WOOD_LIGHT)
		_rect(14, y + 9, 96, 1, WOOD_DARK)
	_rect(14, CH - 78, 4, 28, WOOD_DARK)
	_rect(106, CH - 78, 4, 28, WOOD_DARK)
	# Big spoked wheel.
	var c := Vector2(58, CH - 32)
	_ellipse(c.x, c.y, 30, 30, WOOD_DARK)
	_ellipse(c.x, c.y, 26, 26, Color(0, 0, 0, 0))
	for yy in range(int(c.y - 26), int(c.y + 27)):
		for xx in range(int(c.x - 26), int(c.x + 27)):
			if pow(xx - c.x, 2) + pow(yy - c.y, 2) <= 26 * 26:
				img.set_pixelv(Vector2i(int(o.x + xx), int(o.y + yy)), Color(0, 0, 0, 0))
	for k in 8:
		var a := k * PI / 4.0
		_line(c, c + Vector2(cos(a), sin(a)) * 26, 3, WOOD)
	_ellipse(c.x, c.y, 6, 6, WOOD_DARK)

## One-pixel outline around opaque pixels (not shadows), within each cell.
func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / CW == x / CW and p.y / CH == y / CH and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
