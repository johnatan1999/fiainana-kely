extends SceneTree
## The market town's placeholder props, one per 192 x 192 cell (4 x 2), each
## standing on its cell's bottom edge. The bridge and the taxi-brousse are
## drawn at screen size (scale 1), the others at twice the density (0.5).
##   0 wooden bridge, seen from above: a plank deck between two rails
##   1 market stall: produce under a lamba awning (tomatoes, bananas, cassava)
##   2 market stall: lambas and baskets hanging from a frame
##   3 the collector's stall (weekly market shop): sacks of cloves, coffee,
##     vanilla bundles, a hanging scale
##   4 taxi-brousse: a minibus, side view, luggage tied on the roof
##   5 a pile of rice sacks (gony)
##   6 a tuft of reeds, for the river banks
##   7 hens in wicker cages (sobika), market day
##   godot --headless --path . --script res://tools/placeholder_art/gen_market_town.gd
const C := 192
const OUTLINE := Color(0.16, 0.1, 0.05)
const WOOD := Color(0.55, 0.37, 0.2)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
const STRAW := Color(0.85, 0.72, 0.42)
const STRAW_DARK := Color(0.66, 0.53, 0.28)
const SACK := Color(0.82, 0.76, 0.6)
const SACK_DARK := Color(0.64, 0.58, 0.44)
const CLOTH_RED := Color(0.8, 0.25, 0.2)
const CLOTH_YELLOW := Color(0.95, 0.8, 0.3)
const CLOTH_GREEN := Color(0.25, 0.55, 0.35)
const CLOTH_BLUE := Color(0.25, 0.4, 0.7)
var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 23
	img = Image.create(C * 4, C * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _bridge()
	_cell(1); _produce_stall()
	_cell(2); _lamba_stall()
	_cell(3); _collector_stall()
	_cell(4); _bush_taxi()
	_cell(5); _rice_sacks()
	_cell(6); _reeds()
	_cell(7); _hen_cages()
	_outline()
	img.save_png("res://assets/sprites/props/market_town.png")
	print("bourg.png written")
	quit()

func _cell(i: int) -> void:
	o = Vector2((i % 4) * C, (i / 4) * C)

# --- primitives, in cell coordinates (y = C - 1 is the ground) -------------------
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

func _shadow(cx: float, rx: float) -> void:
	_ellipse(cx, C - 4, rx, 5, Color(0, 0, 0, 0.25))

## A lamba awning on two poles: a sloping cloth with stripes.
func _awning(x: float, w: float, top: float, colors: Array) -> void:
	_rect(x + 4, top, 6, C - top - 2, WOOD_DARK)
	_rect(x + w - 10, top, 6, C - top - 2, WOOD_DARK)
	for yy in range(int(top - 26), int(top + 6)):
		var stripe: Color = colors[(yy / 6) % colors.size()]
		_rect(x - 4, yy, w + 8, 1, stripe)
	# Scalloped hem.
	for xx in range(int(x - 4), int(x + w + 4), 12):
		_ellipse(xx + 6, top + 6, 6, 4, colors[0])

# --- props --------------------------------------------------------------------
func _bridge() -> void:
	# Deck: planks across, from the north bank (top) to the south bank.
	for y in range(16, C - 8, 10):
		var shade := WOOD if (y / 10) % 2 == 0 else WOOD_LIGHT
		_rect(14, y, C - 28, 9, shade)
		_rect(14, y + 9, C - 28, 1, WOOD_DARK)
		_rect(20 + rng.randi_range(0, 120), y + 3, 3, 3, WOOD_DARK) # nail
	# Side beams and rails, with posts.
	for x in [6, C - 16]:
		_rect(x, 10, 10, C - 14, WOOD_DARK)
		_rect(x + 2, 10, 6, C - 14, WOOD)
		for y in range(12, C - 8, 44):
			_rect(x - 1, y, 12, 12, WOOD_DARK)
			_rect(x + 1, y + 2, 8, 6, WOOD_LIGHT)

func _stall_table(x: float, w: float) -> void:
	_rect(x, C - 62, w, 10, WOOD_LIGHT)
	_rect(x, C - 54, w, 4, WOOD_DARK)
	_rect(x + 6, C - 50, 6, 48, WOOD_DARK)
	_rect(x + w - 12, C - 50, 6, 48, WOOD_DARK)

func _produce_stall() -> void:
	_shadow(96, 84)
	_awning(20, 152, 52, [CLOTH_RED, CLOTH_YELLOW, CLOTH_GREEN])
	_stall_table(14, 164)
	# Little piles (tas) of tomatoes, bananas, cassava roots, beans.
	for i in 4:
		_ellipse(34 + i * 10, C - 68, 6, 6, Color(0.88, 0.2, 0.15))
	for i in 3:
		_ellipse(37 + i * 10, C - 76, 6, 6, Color(0.9, 0.24, 0.18))
	for i in 5:
		_ellipse(92 + i * 7, C - 70, 4, 9, Color(0.95, 0.82, 0.25))
	for i in 3:
		_line(Vector2(132 + i * 6, C - 64), Vector2(150 + i * 6, C - 78), 6, Color(0.55, 0.36, 0.22))
	# A basket at the foot of the table.
	_ellipse(160, C - 16, 18, 12, STRAW)
	_ellipse(160, C - 24, 16, 5, STRAW_DARK)

func _lamba_stall() -> void:
	_shadow(96, 84)
	# A frame of poles with a crossbar, lambas hanging from it.
	_rect(20, 30, 8, C - 32, WOOD_DARK)
	_rect(164, 30, 8, C - 32, WOOD_DARK)
	_rect(16, 30, 160, 8, WOOD)
	var colors := [CLOTH_RED, CLOTH_BLUE, CLOTH_YELLOW, CLOTH_GREEN, Color(0.6, 0.3, 0.6)]
	for i in 5:
		var x := 30 + i * 27
		var c: Color = colors[i]
		_rect(x, 38, 24, 90, c)
		_rect(x, 50 + (i % 2) * 20, 24, 6, c.lightened(0.35))
		_rect(x, 110, 24, 4, c.darkened(0.3))
		for fx in range(x, x + 24, 4): # fringe
			_rect(fx, 128, 2, 6, c)
	# Baskets (sobika) piled at the foot.
	for b in [[50, 18], [84, 14], [140, 20]]:
		_ellipse(b[0], C - 16, b[1], 12, STRAW)
		_ellipse(b[0], C - 24, b[1] - 3, 4, STRAW_DARK)

func _sack(cx: float, bottom: float, w: float, h: float, fill: Color) -> void:
	_rect(cx - w / 2, bottom - h, w, h, SACK)
	_rect(cx - w / 2, bottom - h, w, 3, SACK_DARK)
	_ellipse(cx, bottom - h + 2, w / 2 - 3, 5, fill)

func _collector_stall() -> void:
	_shadow(96, 86)
	_awning(14, 164, 46, [Color(0.95, 0.95, 0.9), CLOTH_BLUE])
	_stall_table(12, 168)
	# Cloves (dark), coffee (brown), green coffee, in open sacks on the table.
	_sack(42, C - 60, 34, 26, Color(0.3, 0.16, 0.1))
	_sack(82, C - 60, 34, 22, Color(0.45, 0.28, 0.15))
	# Vanilla bundles, tied.
	for i in 3:
		_rect(110 + i * 14, C - 84, 8, 24, Color(0.2, 0.12, 0.08))
		_rect(110 + i * 14, C - 74, 8, 3, STRAW)
	# A hanging scale (balance) from the awning.
	_line(Vector2(158, 56), Vector2(158, 92), 2, Color(0.3, 0.3, 0.3))
	_rect(144, 92, 28, 4, Color(0.55, 0.55, 0.58))
	_ellipse(158, 100, 14, 4, Color(0.65, 0.65, 0.68))
	# More sacks on the ground.
	_sack(36, C - 2, 40, 34, Color(0.3, 0.16, 0.1))
	_sack(160, C - 2, 36, 30, Color(0.95, 0.95, 0.9))

func _bush_taxi() -> void:
	_shadow(96, 92)
	var body := Color(0.92, 0.9, 0.82)
	var band := Color(0.2, 0.45, 0.7)
	# Body, roof rack and luggage.
	_rect(10, 70, 172, 92, body)
	_rect(10, 132, 172, 10, band)
	_rect(10, 70, 172, 6, body.darkened(0.15))
	_rect(14, 58, 160, 4, Color(0.3, 0.3, 0.3))
	for i in 5:
		_rect(18 + i * 4, 52, 2, 10, Color(0.3, 0.3, 0.3))
	var bags := [[22, 30, 22, CLOTH_RED], [54, 40, 18, SACK], [96, 26, 26, CLOTH_BLUE], [124, 36, 20, STRAW], [162, 10, 14, Color(0.3, 0.3, 0.3)]]
	for bag in bags:
		_rect(bag[0], 58 - bag[2], bag[1], bag[2], bag[3])
		_rect(bag[0], 58 - bag[2], bag[1], 3, (bag[3] as Color).darkened(0.25))
	# Windows, front windshield (right), door.
	for x in range(22, 140, 28):
		_rect(x, 82, 22, 30, Color(0.35, 0.45, 0.55))
		_rect(x + 2, 84, 8, 10, Color(0.6, 0.7, 0.8))
	_rect(150, 80, 28, 34, Color(0.35, 0.45, 0.55))
	_rect(118, 116, 2, 40, body.darkened(0.3))
	# Wheels.
	for x in [44, 150]:
		_ellipse(x, 164, 18, 18, Color(0.15, 0.15, 0.15))
		_ellipse(x, 164, 8, 8, Color(0.6, 0.6, 0.62))
	_rect(176, 142, 8, 8, Color(0.95, 0.85, 0.4)) # headlight

func _rice_sacks() -> void:
	_shadow(96, 70)
	for s in [[60, C - 2], [104, C - 2], [148, C - 2], [82, C - 36], [126, C - 36], [104, C - 70]]:
		_rect(s[0] - 24, s[1] - 34, 48, 34, SACK)
		_rect(s[0] - 24, s[1] - 34, 48, 4, SACK_DARK)
		_rect(s[0] - 10, s[1] - 22, 20, 8, Color(0.3, 0.45, 0.7)) # printed band
		_rect(s[0] - 24, s[1] - 2, 48, 2, SACK_DARK)

func _reeds() -> void:
	for i in 14:
		var x := 40.0 + i * 8.0 + rng.randf_range(-3, 3)
		var h := rng.randf_range(70, 130)
		var lean := rng.randf_range(-14, 14)
		_line(Vector2(x, C - 4), Vector2(x + lean, C - 4 - h), 3, Color(0.35, 0.55, 0.25).darkened(rng.randf_range(0, 0.25)))
		if i % 3 == 0:
			_ellipse(x + lean, C - 4 - h, 3, 9, Color(0.5, 0.35, 0.2)) # bulrush head

func _hen_cages() -> void:
	_shadow(96, 80)
	for cage in [[56, C - 4, 44], [136, C - 4, 40], [96, C - 52, 36]]:
		var cx: float = cage[0]
		var bottom: float = cage[1]
		var r: float = cage[2]
		# A hen inside...
		_ellipse(cx, bottom - r * 0.6, r * 0.5, r * 0.4, Color(0.6, 0.35, 0.2))
		_ellipse(cx + r * 0.35, bottom - r * 0.9, 7, 7, Color(0.6, 0.35, 0.2))
		_rect(cx + r * 0.35 - 2, bottom - r * 0.9 - 10, 5, 5, Color(0.85, 0.15, 0.1))
		# ...behind the wicker dome.
		for k in range(-4, 5):
			var x := cx + k * r / 4.5
			_line(Vector2(x, bottom), Vector2(cx + k * r / 9.0, bottom - r * 1.2), 2, STRAW_DARK)
		for yy in range(int(bottom - r * 1.1), int(bottom), 10):
			_rect(cx - r * 0.9, yy, r * 1.8, 2, STRAW)

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
						and p.x / C == x / C and p.y / C == y / C and src.get_pixel(p.x, p.y).a > 0.7:
					img.set_pixel(x, y, OUTLINE)
					break
