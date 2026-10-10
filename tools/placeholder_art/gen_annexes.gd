extends SceneTree
## The farm house's annexes (FamilyProject "granary", "kitchen"), placeholder
## art in cells of 256 x 320 - twice the on-screen 128 x 160 - each standing
## on its cell's bottom edge, centered (HouseAnnex: feet at the node).
##   0 the rice granary (fitoeram-bary): a thatched wooden loft on four
##     stilts, each with a flat stone disc against the rats, a notched-log
##     ladder
##   1 the kitchen (lakozia): a small earth hut, thatched, smoke curling
##     from the roof, the hearth glowing through the open door, firewood
##   godot --headless --path . --script res://tools/placeholder_art/gen_annexes.gd
const W := 256
const H := 320
const GROUND := 312
const OUTLINE := Color(0.18, 0.1, 0.05)
const WOOD := Color(0.52, 0.34, 0.18)
const WOOD_DARK := Color(0.34, 0.21, 0.11)
const WOOD_LIGHT := Color(0.66, 0.47, 0.28)
const STONE := Color(0.6, 0.57, 0.52)
const STONE_DARK := Color(0.44, 0.41, 0.38)
const THATCH := Color(0.62, 0.5, 0.32)
const THATCH_DARK := Color(0.46, 0.36, 0.22)
const EARTH := Color(0.74, 0.37, 0.2)
const EARTH_DARK := Color(0.6, 0.28, 0.15)
const FIRE := Color(1.0, 0.62, 0.2)
const FIRE_CORE := Color(1.0, 0.88, 0.45)
const SMOKE := Color(0.8, 0.78, 0.76, 0.55)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 23
	img = Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _granary()
	_cell(1); _kitchen()
	img.save_png("res://assets/sprites/props/house_annexes.png")
	print("house_annexes.png written")
	quit()

func _cell(i: int) -> void:
	o = Vector2(i * W, 0)

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	var p := Vector2i(int(o.x + x), int(o.y + y))
	if c.a < 1.0:
		c = img.get_pixelv(p).blend(c)
	img.set_pixelv(p, c)

func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	for yy in range(int(y), int(y + h)):
		for xx in range(int(x), int(x + w)):
			_px(xx, yy, c)

func _frame(x: float, y: float, w: float, h: float, c: Color, t := 3.0) -> void:
	_rect(x, y, w, t, c)
	_rect(x, y + h - t, w, t, c)
	_rect(x, y, t, h, c)
	_rect(x + w - t, y, t, h, c)

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

## A thatched roof over x0..x1, ridge at `top`, eaves at `eaves`.
func _thatch(x0: float, x1: float, top: float, eaves: float) -> void:
	for y in range(int(top), int(eaves)):
		var t := float(y - top) / (eaves - top)
		var inset := (1.0 - t) * (x1 - x0) * 0.32
		for x in range(int(x0 + inset), int(x1 - inset)):
			_px(x, y, THATCH_DARK if (int(x) * 5 + y * 3) % 13 < 4 else THATCH)
	_rect(x0 - 2, eaves - 5, x1 - x0 + 4, 7, THATCH_DARK)
	_rect(x0 + (x1 - x0) * 0.32, top - 4, (x1 - x0) * 0.36, 6, OUTLINE)

func _granary() -> void:
	_ellipse(128, GROUND - 2, 92, 10, Color(0, 0, 0, 0.25))
	# Four stilts, each with its stone disc against the rats.
	for x in [56, 96, 160, 200]:
		_rect(x - 5, 196, 10, GROUND - 196, WOOD_DARK)
		_rect(x - 3, 196, 4, GROUND - 196, WOOD)
		_ellipse(x, 214, 18, 6, STONE_DARK)
		_ellipse(x, 212, 16, 5, STONE)
	# The loft: planks.
	_rect(40, 120, 176, 80, WOOD)
	for y in range(126, 196, 12):
		_rect(40, y, 176, 2, WOOD_DARK)
	_frame(40, 120, 176, 80, OUTLINE, 3)
	# Its little door, shut.
	_rect(112, 136, 34, 50, WOOD_LIGHT)
	_frame(112, 136, 34, 50, WOOD_DARK, 3)
	_rect(127, 152, 4, 14, OUTLINE)
	# The roof.
	_thatch(22, 234, 40, 128)
	# A notched log for a ladder, leaning on the loft.
	_line(Vector2(186, GROUND - 4), Vector2(150, 196), 9, WOOD_DARK)
	for i in 5:
		var p := Vector2(186, GROUND - 4).lerp(Vector2(150, 196), (i + 0.5) / 5.0)
		_rect(p.x - 6, p.y - 1, 12, 3, WOOD_LIGHT)

func _kitchen() -> void:
	_ellipse(128, GROUND - 2, 100, 10, Color(0, 0, 0, 0.25))
	# Earth walls.
	_rect(40, 170, 176, GROUND - 170, EARTH)
	for i in 30:
		_ellipse(rng.randf_range(46, 210), rng.randf_range(176, GROUND - 6), 5, 3, EARTH_DARK)
	_frame(40, 170, 176, GROUND - 170, OUTLINE, 3)
	# The open door, the hearth glowing inside.
	_rect(92, 214, 48, GROUND - 214, Color(0.12, 0.07, 0.04))
	_ellipse(116, GROUND - 14, 16, 8, FIRE)
	_ellipse(116, GROUND - 16, 8, 5, FIRE_CORE)
	_frame(92, 214, 48, GROUND - 214, WOOD_DARK, 4)
	# The roof, and smoke curling from its top.
	_thatch(22, 234, 74, 176)
	for i in 6:
		_ellipse(128 + sin(i * 1.3) * 10 + i * 3, 64 - i * 11, 9 + i * 2, 7 + i, SMOKE)
	# Firewood stacked by the wall.
	for row in 3:
		for col in 3 - row:
			var x := 168 + col * 14 + row * 7
			var y := GROUND - 10 - row * 12
			_ellipse(x, y, 7, 6, WOOD_DARK)
			_ellipse(x, y, 4, 3, WOOD_LIGHT)
