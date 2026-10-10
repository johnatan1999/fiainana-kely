extends SceneTree
## The forest's placeholder art (see docs/forest.md), in cells of 128 x 128 -
## twice the on-screen 64 x 64 - each standing on y = 120 (the ground),
## centered on x = 64.
## Row 0, the animals, two frames each (an idle animation): 0-1 sifaka
## (frame 1: arms up, sunbathing), 2-3 maki (frame 3: its tail swinging),
## 4-5 chameleon on a twig (frame 5: other colors), 6-7 tenrec (frame 7: its
## snout down, digging), 8-9 kingfisher on a stump (frame 9: head turned).
## Row 1, the wild plants, ready then gathered: 0-1 wild greens, 2-3 a
## hollow log with wild honey, 4-5 ravintsara shrub, 6-7 mushrooms in the
## leaf litter.
##   godot --headless --path . --script res://tools/placeholder_art/gen_forest.gd
const C := 128
const GROUND := 120
const OUTLINE := Color(0.15, 0.1, 0.06)
const SHADOW := Color(0, 0, 0, 0.22)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 41
	img = Image.create(C * 10, C * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for frame in 2:
		_cell(0 + frame, 0); _sifaka(frame)
		_cell(2 + frame, 0); _maki(frame)
		_cell(4 + frame, 0); _chameleon(frame)
		_cell(6 + frame, 0); _tenrec(frame)
		_cell(8 + frame, 0); _kingfisher(frame)
	for ready in [true, false]:
		var column := 0 if ready else 1
		_cell(0 + column, 1); _greens(ready)
		_cell(2 + column, 1); _honey(ready)
		_cell(4 + column, 1); _ravintsara(ready)
		_cell(6 + column, 1); _mushrooms(ready)
	img.save_png("res://assets/sprites/props/forest.png")
	print("forest.png written")
	quit()

func _cell(column: int, row: int) -> void:
	o = Vector2(column * C, row * C)

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

## An outlined blob: the outline first, a little bigger.
func _blob(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	_ellipse(cx, cy, rx + 2, ry + 2, OUTLINE)
	_ellipse(cx, cy, rx, ry, c)

func _shadow(rx := 26.0) -> void:
	_ellipse(64, GROUND, rx, 6, SHADOW)

# --- animals -------------------------------------------------------------------------------

func _sifaka(frame: int) -> void:
	var white := Color(0.95, 0.94, 0.9)
	var brown := Color(0.55, 0.36, 0.22)
	_shadow(20)
	# The long tail, down to the ground.
	_line(Vector2(70, 84), Vector2(84, 118), 7, OUTLINE)
	_line(Vector2(70, 84), Vector2(84, 118), 5, white)
	# Legs bent, body upright.
	_blob(58, 106, 9, 12, white)
	_blob(72, 106, 9, 12, white)
	_blob(64, 78, 15, 22, white)
	_ellipse(64, 70, 9, 8, brown)
	# Arms: hanging, or raised to the sun.
	for side in [-1, 1]:
		var shoulder := Vector2(64 + side * 12, 66)
		var hand := shoulder + (Vector2(side * 14, -24) if frame == 1 else Vector2(side * 6, 22))
		_line(shoulder, hand, 8, OUTLINE)
		_line(shoulder, hand, 6, white)
	# The face: dark, round eyes.
	_blob(64, 46, 11, 11, white)
	_ellipse(64, 49, 7, 7, Color(0.18, 0.13, 0.1))
	_ellipse(60, 46, 2.5, 2.5, Color(1, 0.75, 0.2))
	_ellipse(68, 46, 2.5, 2.5, Color(1, 0.75, 0.2))

func _maki(frame: int) -> void:
	var grey := Color(0.68, 0.66, 0.64)
	var dark := Color(0.2, 0.18, 0.18)
	_shadow(30)
	# The ringed tail, up like a flag (or swinging).
	var tip := Vector2(28 if frame == 0 else 18, 22 if frame == 0 else 34)
	var steps := 13
	for i in steps:
		var p := Vector2(44, 88).lerp(tip, float(i) / steps)
		_ellipse(p.x, p.y, 5, 5, dark if i % 2 == 0 else Color.WHITE)
	# Body on four legs.
	for x in [48, 58, 74, 84]:
		_line(Vector2(x, 96), Vector2(x, 118), 6, dark)
	_blob(66, 92, 24, 11, grey)
	# Head: white mask, black eye patches, black snout.
	_blob(92, 80, 11, 10, Color(0.95, 0.94, 0.92))
	_ellipse(96, 79, 3.5, 3.5, dark)
	_ellipse(100, 84, 4, 3, dark)
	_ellipse(86, 71, 4, 5, dark)

func _chameleon(frame: int) -> void:
	var body := Color(0.35, 0.65, 0.3) if frame == 0 else Color(0.85, 0.55, 0.25)
	var stripe := Color(0.65, 0.85, 0.4) if frame == 0 else Color(0.95, 0.8, 0.35)
	# The twig it walks on.
	_line(Vector2(10, 100), Vector2(118, 92), 6, Color(0.42, 0.28, 0.16))
	_line(Vector2(70, 96), Vector2(86, 120), 5, Color(0.42, 0.28, 0.16))
	# The curled tail.
	for i in 18:
		var angle := i * 0.42
		var r := 12.0 - i * 0.45
		_ellipse(36 + cos(angle) * r, 80 + sin(angle) * r, 3.5, 3.5, body)
	_blob(60, 80, 22, 12, body)
	_line(Vector2(44, 76), Vector2(76, 76), 3, stripe)
	# Feet gripping the twig.
	for x in [50, 70]:
		_line(Vector2(x, 88), Vector2(x - 2, 97), 4, body.darkened(0.2))
	# Head with its casque, and the big turret eye.
	_blob(86, 74, 11, 9, body)
	_ellipse(82, 64, 6, 6, body.darkened(0.15))
	_blob(88, 72, 5, 5, stripe)
	_ellipse(89, 72, 2, 2, OUTLINE)

func _tenrec(frame: int) -> void:
	var fur := Color(0.45, 0.33, 0.22)
	_shadow(26)
	# Spiky round body.
	_blob(60, 98, 24, 16, fur)
	for i in 22:
		var angle := PI + rng.randf() * PI
		var base := Vector2(60, 98) + Vector2(cos(angle) * 20, sin(angle) * 12)
		_line(base, base + Vector2(cos(angle) * 10, sin(angle) * 9), 2, Color(0.82, 0.76, 0.62))
	# Pointed snout, up sniffing or down digging.
	var nose := Vector2(98, 98 if frame == 0 else 110)
	_line(Vector2(80, 98), nose, 10, fur.lightened(0.15))
	_ellipse(nose.x, nose.y, 3, 3, OUTLINE)
	_ellipse(84, 92, 2, 2, OUTLINE)
	for x in [48, 70]:
		_line(Vector2(x, 110), Vector2(x, 118), 4, OUTLINE)

func _kingfisher(frame: int) -> void:
	var blue := Color(0.15, 0.45, 0.85)
	var rust := Color(0.85, 0.45, 0.2)
	# The stump it perches on.
	_shadow(20)
	_blob(64, 108, 14, 12, Color(0.45, 0.3, 0.17))
	_ellipse(64, 98, 12, 4, Color(0.62, 0.45, 0.28))
	# Body, wing and tail.
	_blob(64, 80, 12, 15, rust)
	_ellipse(60, 76, 9, 12, blue)
	_line(Vector2(56, 90), Vector2(50, 100), 5, blue)
	# Head and its long beak, turned or not.
	var face := -1 if frame == 1 else 1
	_blob(64 + face * 4, 60, 10, 9, blue)
	_ellipse(64 + face * 6, 62, 3, 2, Color.WHITE)
	_line(Vector2(64 + face * 12, 61), Vector2(64 + face * 28, 64), 4, Color(0.9, 0.35, 0.15))
	_ellipse(64 + face * 7, 58, 2, 2, OUTLINE)

# --- plants ---------------------------------------------------------------------------------

func _greens(ready: bool) -> void:
	_shadow(30)
	var leaf := Color(0.3, 0.6, 0.25)
	if ready:
		for i in 9:
			var x := 40 + i * 6 + rng.randf_range(-3, 3)
			_line(Vector2(x, 118), Vector2(x + rng.randf_range(-14, 14), 80 + rng.randf_range(-8, 8)), 3, leaf.darkened(0.2))
			_blob(x + rng.randf_range(-12, 12), 84 + rng.randf_range(-8, 10), 9, 6, leaf.lightened(rng.randf() * 0.2))
	else:
		for i in 7:
			var x := 42 + i * 7
			_line(Vector2(x, 118), Vector2(x, 110), 3, leaf.darkened(0.3))

func _honey(ready: bool) -> void:
	_shadow(40)
	var bark := Color(0.4, 0.28, 0.17)
	# A hollow log lying on the ground.
	_blob(64, 96, 46, 20, bark)
	_ellipse(104, 96, 12, 18, bark.lightened(0.15))
	_ellipse(104, 96, 7, 12, Color(0.12, 0.08, 0.05))
	if ready:
		# The comb in the hollow, a few bees.
		_ellipse(102, 96, 5, 9, Color(0.95, 0.72, 0.2))
		for i in 6:
			_ellipse(70 + rng.randf_range(-30, 50), 60 + rng.randf_range(-12, 12), 2.5, 2, Color(0.2, 0.15, 0.05))

func _ravintsara(ready: bool) -> void:
	_shadow(28)
	_line(Vector2(64, 120), Vector2(64, 80), 6, Color(0.4, 0.27, 0.15))
	var leaves := 26 if ready else 9
	for i in leaves:
		_blob(64 + rng.randf_range(-26, 26), 70 + rng.randf_range(-26, 20), 6, 4,
			Color(0.2, 0.45, 0.25).lightened(rng.randf() * 0.25))

func _mushrooms(ready: bool) -> void:
	# Dead leaves.
	for i in 14:
		_ellipse(64 + rng.randf_range(-36, 36), 112 + rng.randf_range(-6, 6), 7, 3,
			Color(0.6, 0.4, 0.2).darkened(rng.randf() * 0.3))
	if not ready:
		return
	for spot in [Vector2(48, 106), Vector2(70, 100), Vector2(84, 110)]:
		_line(spot, spot + Vector2(0, -14), 5, Color(0.92, 0.88, 0.78))
		_blob(spot.x, spot.y - 16, 11, 7, Color(0.62, 0.4, 0.22))
		_ellipse(spot.x - 3, spot.y - 18, 3, 2, Color(0.8, 0.6, 0.4))
