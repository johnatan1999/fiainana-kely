extends SceneTree
## The village centre's placeholder props, one per 192 x 192 cell (4 x 2),
## each standing on its cell's bottom edge, at twice the on-screen density.
##   0 water point (fantsakana): a concrete post, its tap, a basin, jerrycans
##   1 washing stones (lavoir) at a trickle of water, a basin, a lamba
##   2 grocery kiosk (épicerie): a wooden booth, tin roof, goods on the counter
##   3 eatery table (hotely): a long table, two benches, plates and cups
##   4 flagpole with the Malagasy flag (white, red, green)
##   5 wooden football goal
##   6 signboard (blank - the scenes write on it)
##   7 cooking hearth: three stones, a pot (vilany) on the fire
##   godot --headless --path . --script res://tools/placeholder_art/gen_village_center.gd
const C := 192
const OUTLINE := Color(0.16, 0.1, 0.05)
const WOOD := Color(0.55, 0.37, 0.2)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
const CONCRETE := Color(0.72, 0.7, 0.66)
const CONCRETE_DARK := Color(0.55, 0.53, 0.5)
const STONE := Color(0.6, 0.58, 0.55)
const STONE_DARK := Color(0.45, 0.43, 0.41)
const WATER := Color(0.45, 0.62, 0.72)
const TIN := Color(0.62, 0.64, 0.66)
const TIN_DARK := Color(0.45, 0.47, 0.5)
const JERRYCAN := Color(0.95, 0.78, 0.15)
var img: Image
var o := Vector2.ZERO

func _init():
	img = Image.create(C * 4, C * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cell(0); _water_point()
	_cell(1); _washing_stones()
	_cell(2); _kiosk()
	_cell(3); _eatery_table()
	_cell(4); _flagpole()
	_cell(5); _goal()
	_cell(6); _signboard()
	_cell(7); _hearth()
	_outline()
	img.save_png("res://assets/sprites/props/village_center.png")
	print("village_center.png written")
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

# --- props --------------------------------------------------------------------
func _jerrycan(x: float, y: float) -> void:
	_rect(x, y - 26, 20, 26, JERRYCAN)
	_rect(x, y - 26, 20, 4, JERRYCAN.darkened(0.15))
	_rect(x + 13, y - 32, 5, 6, Color(0.3, 0.3, 0.3)) # cap
	_rect(x + 3, y - 31, 8, 4, JERRYCAN.darkened(0.25)) # handle

func _water_point() -> void:
	_shadow(96, 70)
	# Puddle and the basin around the post.
	_ellipse(96, C - 10, 66, 10, WATER.darkened(0.1))
	_rect(46, C - 30, 100, 22, CONCRETE_DARK)
	_rect(50, C - 28, 92, 12, WATER)
	# The concrete post and its tap.
	_rect(84, C - 120, 26, 92, CONCRETE)
	_rect(84, C - 120, 26, 6, CONCRETE_DARK)
	_rect(104, C - 120, 6, 92, CONCRETE_DARK)
	_rect(70, C - 88, 18, 6, TIN_DARK) # spout
	_rect(70, C - 82, 5, 8, TIN_DARK)
	_line(Vector2(72, C - 74), Vector2(72, C - 34), 2, Color(0.6, 0.8, 0.95, 0.8)) # running water
	_rect(92, C - 108, 10, 4, Color(0.75, 0.2, 0.15)) # tap handle
	_jerrycan(20, C - 8)
	_jerrycan(148, C - 6)
	_jerrycan(60, C - 30)

func _washing_stones() -> void:
	_shadow(96, 80)
	# A trickle of water and the flat stones along it.
	_ellipse(96, C - 18, 86, 16, WATER)
	_ellipse(96, C - 18, 70, 8, WATER.lightened(0.15))
	for stone in [[44, C - 26, 24, 10], [96, C - 30, 26, 11], [148, C - 24, 22, 9], [70, C - 10, 20, 8], [128, C - 10, 22, 8]]:
		_ellipse(stone[0], stone[1], stone[2], stone[3], STONE)
		_ellipse(stone[0], stone[1] - 3, stone[2] - 4, stone[3] - 4, STONE.lightened(0.12))
	# A lamba laid out to dry on a stone, a basin of washing.
	_rect(80, C - 40, 34, 8, Color(0.85, 0.3, 0.25))
	_rect(80, C - 37, 34, 2, Color(0.95, 0.85, 0.3))
	_ellipse(150, C - 40, 20, 9, Color(0.3, 0.5, 0.75))
	_ellipse(150, C - 43, 16, 5, Color(0.95, 0.95, 0.9))

func _kiosk() -> void:
	_shadow(96, 84)
	# Posts and back wall of planks.
	_rect(22, C - 150, 148, 120, WOOD)
	for y in range(C - 150, C - 30, 12):
		_rect(22, y, 148, 2, WOOD_DARK)
	# Shelves with goods.
	for shelf_y in [C - 128, C - 102]:
		_rect(30, shelf_y, 132, 4, WOOD_DARK)
		for i in 11:
			var colors := [Color(0.85, 0.25, 0.2), Color(0.25, 0.55, 0.3), Color(0.95, 0.85, 0.3), Color(0.9, 0.9, 0.9), Color(0.3, 0.45, 0.8)]
			_rect(34 + i * 12, shelf_y - 12, 8, 12, colors[i % colors.size()])
	# Tin roof, sloping forward.
	for x in range(10, 182):
		var y: int = C - 160 + (2 if x % 12 < 6 else 0)
		_rect(x, y - 14, 1, 16, TIN if x % 12 < 6 else TIN_DARK)
	# Counter with bananas and soap.
	_rect(14, C - 58, 164, 30, WOOD_LIGHT)
	_rect(14, C - 58, 164, 5, WOOD_DARK)
	for i in 4:
		_ellipse(40 + i * 8, C - 64, 4, 7, Color(0.95, 0.85, 0.25))
	_rect(120, C - 66, 12, 8, Color(0.4, 0.7, 0.85))
	_rect(136, C - 66, 12, 8, Color(0.4, 0.7, 0.85))
	_rect(14, C - 28, 8, 24, WOOD_DARK)
	_rect(170, C - 28, 8, 24, WOOD_DARK)

func _eatery_table() -> void:
	_shadow(96, 84)
	# Back bench, table, front bench.
	_rect(26, C - 60, 140, 6, WOOD_DARK)
	_rect(32, C - 54, 6, 20, WOOD_DARK)
	_rect(154, C - 54, 6, 20, WOOD_DARK)
	_rect(14, C - 76, 164, 12, WOOD_LIGHT)
	_rect(14, C - 66, 164, 4, WOOD_DARK)
	_rect(22, C - 62, 8, 58, WOOD)
	_rect(162, C - 62, 8, 58, WOOD)
	# Plates of rice, cups.
	for x in [44, 96, 148]:
		_ellipse(x, C - 74, 14, 5, Color(0.95, 0.95, 0.92))
		_ellipse(x, C - 76, 9, 3, Color(1, 1, 0.97))
		_rect(x + 14, C - 84, 6, 9, Color(0.85, 0.85, 0.82))
	_rect(20, C - 28, 152, 6, WOOD_DARK)
	_rect(26, C - 22, 6, 18, WOOD_DARK)
	_rect(160, C - 22, 6, 18, WOOD_DARK)

func _flagpole() -> void:
	_shadow(96, 22)
	_rect(80, C - 14, 32, 12, CONCRETE_DARK) # base
	_rect(93, C - 186, 6, 174, Color(0.75, 0.75, 0.75))
	# Flag of Madagascar: white at the hoist, red over green.
	_rect(99, C - 182, 22, 54, Color(0.97, 0.97, 0.97))
	_rect(121, C - 182, 50, 27, Color(0.8, 0.15, 0.15))
	_rect(121, C - 155, 50, 27, Color(0.15, 0.55, 0.25))

func _goal() -> void:
	_shadow(96, 80)
	_rect(14, C - 110, 8, 108, Color(0.92, 0.9, 0.85))
	_rect(170, C - 110, 8, 108, Color(0.92, 0.9, 0.85))
	_rect(14, C - 110, 164, 8, Color(0.92, 0.9, 0.85))
	# The net behind, a light mesh.
	for x in range(26, 168, 10):
		_line(Vector2(x, C - 100), Vector2(x + 8, C - 12), 1, Color(0.95, 0.95, 0.95, 0.45))
	for y in range(C - 98, C - 10, 10):
		_line(Vector2(24, y), Vector2(168, y), 1, Color(0.95, 0.95, 0.95, 0.45))

func _signboard() -> void:
	_shadow(96, 60)
	_rect(40, C - 60, 8, 58, WOOD_DARK)
	_rect(144, C - 60, 8, 58, WOOD_DARK)
	_rect(24, C - 104, 144, 50, WOOD_LIGHT)
	_rect(24, C - 104, 144, 5, WOOD_DARK)
	_rect(24, C - 59, 144, 5, WOOD_DARK)

func _hearth() -> void:
	_shadow(96, 50)
	# Embers and flames between three stones, the pot on top.
	_ellipse(96, C - 14, 30, 8, Color(0.25, 0.2, 0.18))
	_ellipse(96, C - 18, 20, 8, Color(0.95, 0.45, 0.1))
	_ellipse(96, C - 22, 10, 10, Color(1.0, 0.8, 0.3))
	for x in [62, 96, 130]:
		_ellipse(x, C - 16, 14, 12, STONE_DARK)
		_ellipse(x, C - 20, 10, 7, STONE)
	_ellipse(96, C - 50, 34, 24, Color(0.2, 0.2, 0.22)) # the vilany
	_rect(62, C - 74, 68, 6, Color(0.28, 0.28, 0.3))
	_ellipse(96, C - 76, 30, 5, Color(0.95, 0.95, 0.9)) # rice steaming

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
