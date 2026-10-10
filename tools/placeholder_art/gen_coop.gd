extends SceneTree
## The farm coop's placeholder art, once rebuilt, one per level (FamilyProject
## "coop"), in cells of 448 x 384 - twice the on-screen 224 x 192, the ruined
## coop's own footprint (assets/tileset/exterior.png): the building stands on
## y = 344 (the coop's origin), its door at x 192..252 like the ruin's.
##   0 level 1, rebuilt: red earth walls, thatched roof, a plank door
##   1 level 2, enlarged: the same, a lean-to wing on the right with nest
##     boxes full of straw
##   2 level 3, in bricks: brick walls, corrugated iron roof, a framed
##     window, a basket of eggs by the door
##   godot --headless --path . --script res://tools/placeholder_art/gen_coop.gd
const W := 448
const H := 384
const GROUND := 344
const DOOR := Rect2(192, 256, 60, 88)
const OUTLINE := Color(0.18, 0.1, 0.05)
const EARTH := Color(0.74, 0.37, 0.2)
const EARTH_DARK := Color(0.6, 0.28, 0.15)
const BRICK := Color(0.72, 0.33, 0.2)
const MORTAR := Color(0.85, 0.72, 0.58)
const THATCH := Color(0.55, 0.45, 0.32)
const THATCH_DARK := Color(0.42, 0.33, 0.22)
const TIN := Color(0.66, 0.68, 0.7)
const TIN_DARK := Color(0.5, 0.52, 0.55)
const WOOD := Color(0.5, 0.33, 0.18)
const WOOD_DARK := Color(0.34, 0.21, 0.11)
const STONE := Color(0.62, 0.55, 0.47)
const STRAW := Color(0.9, 0.78, 0.42)
const EGG := Color(0.97, 0.93, 0.85)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 11
	img = Image.create(W * 3, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _coop(1)
	_cell(1); _coop(2)
	_cell(2); _coop(3)
	img.save_png("res://assets/sprites/props/coop_levels.png")
	print("coop_levels.png written")
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

## A roof over x0..x1, from its ridge at `top` down to its eaves at
## `eaves`: a slope drawn row by row, thatch or corrugated iron.
func _roof(x0: float, x1: float, top: float, eaves: float, tin: bool) -> void:
	for y in range(int(top), int(eaves)):
		var t := float(y - top) / (eaves - top)
		var inset := (1.0 - t) * 26.0
		for x in range(int(x0 + inset), int(x1 - inset)):
			var c: Color
			if tin:
				c = TIN_DARK if int(x) % 14 < 3 else TIN
			else:
				c = THATCH_DARK if (int(x) * 7 + y * 3) % 11 < 3 else THATCH
			_px(x, y, c)
	_rect(x0 - 4, eaves - 6, x1 - x0 + 8, 8, TIN_DARK.darkened(0.2) if tin else THATCH_DARK)
	_rect(x0 + 22, top - 4, x1 - x0 - 44, 6, OUTLINE)

func _walls(x0: float, x1: float, top: float, brick: bool) -> void:
	_rect(x0, top, x1 - x0, GROUND - top, BRICK if brick else EARTH)
	if brick:
		for y in range(int(top) + 12, GROUND, 14):
			_rect(x0, y, x1 - x0, 2, MORTAR)
			var shift := 0 if (y / 14) % 2 == 0 else 14
			for x in range(int(x0) + shift, int(x1), 28):
				_rect(x, y - 12, 2, 12, MORTAR)
	else:
		for i in 40:
			_ellipse(rng.randf_range(x0 + 6, x1 - 6), rng.randf_range(top + 6, GROUND - 6), 6, 3, EARTH_DARK)
	# The stone base.
	for x in range(int(x0), int(x1), 22):
		_ellipse(x + 11, GROUND - 6, 12, 8, STONE)
	_frame(x0, top, x1 - x0, GROUND - top, OUTLINE, 3)

func _door(framed: bool) -> void:
	_rect(DOOR.position.x, DOOR.position.y, DOOR.size.x, DOOR.size.y, WOOD)
	for x in range(int(DOOR.position.x) + 12, int(DOOR.end.x), 12):
		_rect(x, DOOR.position.y, 2, DOOR.size.y, WOOD_DARK)
	_frame(DOOR.position.x, DOOR.position.y, DOOR.size.x, DOOR.size.y, WOOD_DARK if not framed else OUTLINE, 4)
	_ellipse(DOOR.end.x - 12, DOOR.position.y + 46, 3, 3, OUTLINE)

func _coop(level: int) -> void:
	_ellipse(W / 2.0, GROUND + 14, 214, 16, Color(0, 0, 0, 0.25))
	var brick := level >= 3
	var main_right := 330.0 if level == 2 else 430.0
	_walls(18, main_right, 170, brick)
	_roof(4, main_right + 14, 40, 176, brick)
	_door(brick)
	# Small air holes, or a framed window in bricks.
	if brick:
		_rect(64, 210, 64, 48, Color(0.15, 0.1, 0.08))
		_frame(60, 206, 72, 56, WOOD, 6)
		_rect(94, 206, 4, 56, WOOD)
		# The egg basket by the door.
		_ellipse(300, GROUND - 14, 30, 16, WOOD_DARK)
		_ellipse(300, GROUND - 20, 26, 10, WOOD)
		for i in 5:
			_ellipse(284 + i * 8, GROUND - 26 - (i % 2) * 4, 5, 7, EGG)
	else:
		for x in [70, 110, 290]:
			if x < main_right - 30:
				_rect(x, 214, 18, 12, OUTLINE)
	if level == 2:
		# The lean-to wing: nest boxes full of straw under a lower roof.
		_walls(330, 430, 220, false)
		_roof(320, 444, 170, 226, false)
		for i in 3:
			var x := 340 + i * 30
			_rect(x, 250, 26, 26, WOOD_DARK)
			_rect(x + 3, 256, 20, 17, STRAW)
			_frame(x, 250, 26, 26, OUTLINE, 2)
		_rect(336, 286, 88, 6, WOOD)
