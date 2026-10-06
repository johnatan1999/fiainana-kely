extends SceneTree
## Placeholder zebu cart (sarety), side view facing right, at twice the
## on-screen density (the scene scales it by 0.5). One sheet, 512 x 192:
##   row 0: zebu walking, 4 frames of 128 x 96 (frame 0 is also standing)
##   row 1: cart body 160 x 96 | wheel 80 x 80 | driver 64 x 96
## Everything stands on the bottom edge of its cell (the wheel is centered).
##   godot --headless --path . --script res://tools/placeholder_art/gen_zebu_cart.gd
const OUTLINE := Color(0.14, 0.09, 0.05)
const HIDE := Color(0.62, 0.45, 0.32)
const HIDE_DARK := Color(0.45, 0.31, 0.21)
const HIDE_LIGHT := Color(0.78, 0.63, 0.48)
const HORN := Color(0.93, 0.88, 0.74)
const WOOD := Color(0.56, 0.38, 0.21)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const WOOD_LIGHT := Color(0.7, 0.5, 0.3)
var img: Image
var o := Vector2.ZERO
var cell := Vector2(128, 96)

func _init():
	img = Image.create(512, 192, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for frame in 4:
		o = Vector2(frame * 128, 0)
		cell = Vector2(128, 96)
		_zebu(frame)
	o = Vector2(0, 96)
	cell = Vector2(160, 96)
	_cart_body()
	o = Vector2(160, 96)
	cell = Vector2(80, 80)
	_wheel()
	o = Vector2(256, 96)
	cell = Vector2(64, 96)
	_driver()
	_outline()
	img.save_png("res://assets/sprites/animals/zebu_cart.png")
	print("zebu_cart.png written")
	quit()

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= cell.x or y >= cell.y:
		return
	img.set_pixelv(Vector2i(int(o.x + x), int(o.y + y)), c)

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

## A Malagasy zebu: hump over the shoulders, dewlap, lyre horns. Legs swing
## in diagonal pairs over the 4 frames.
func _zebu(frame: int) -> void:
	var swing: float = [0.0, 5.0, 0.0, -5.0][frame]
	var ground := 94.0
	# Far legs first (darker), then the body, then the near legs.
	for leg in [[34.0, -swing], [84.0, swing]]:
		_rect(leg[0] + leg[1] * 0.6, 62, 6, ground - 62, HIDE_DARK)
	_ellipse(30, 50, 6, 10, HIDE_DARK) # rump
	_ellipse(60, 52, 38, 18, HIDE) # body
	_ellipse(60, 58, 34, 10, HIDE_LIGHT) # lighter belly
	_ellipse(84, 34, 13, 11, HIDE) # hump
	_ellipse(96, 62, 8, 10, HIDE_LIGHT) # dewlap
	# Head, low and forward, with a darker muzzle.
	_ellipse(110, 52, 11, 9, HIDE)
	_ellipse(119, 56, 5, 5, HIDE_DARK)
	_ellipse(103, 46, 4, 3, HIDE_DARK) # ear
	# Lyre horns.
	_line(Vector2(106, 44), Vector2(100, 30), 3, HORN)
	_line(Vector2(100, 30), Vector2(106, 22), 3, HORN)
	_line(Vector2(112, 44), Vector2(114, 30), 3, HORN)
	_line(Vector2(114, 30), Vector2(122, 24), 3, HORN)
	# Tail with its tuft.
	_line(Vector2(23, 44), Vector2(18, 72), 2, HIDE_DARK)
	_ellipse(18, 75, 3, 4, OUTLINE)
	# Near legs, with hooves.
	for leg in [[42.0, swing], [92.0, -swing]]:
		var x: float = leg[0] + leg[1]
		_rect(x, 62, 7, ground - 62, HIDE)
		_rect(x, ground - 3, 7, 3, OUTLINE)

## The cart's box and its shaft (the zebus are separate sprites).
func _cart_body() -> void:
	_rect(8, 34, 128, 34, WOOD)
	for y in [34, 45, 56]:
		_rect(8, y, 128, 2, WOOD_LIGHT)
		_rect(8, y + 9, 128, 1, WOOD_DARK)
	_rect(8, 34, 4, 34, WOOD_DARK)
	_rect(132, 34, 4, 34, WOOD_DARK)
	# Shaft towards the yoke.
	_rect(132, 58, 28, 5, WOOD_DARK)
	# Legs of the box resting on the axle.
	_rect(60, 68, 8, 26, WOOD_DARK)

## A big spoked wheel - rotated in game.
func _wheel() -> void:
	var c := Vector2(40, 40)
	_ellipse(c.x, c.y, 38, 38, WOOD_DARK)
	_ellipse(c.x, c.y, 33, 33, Color(0, 0, 0, 0))
	for yy in range(int(c.y - 33), int(c.y + 34)):
		for xx in range(int(c.x - 33), int(c.x + 34)):
			if pow(xx - c.x, 2) + pow(yy - c.y, 2) <= 33 * 33:
				img.set_pixelv(Vector2i(int(o.x + xx), int(o.y + yy)), Color(0, 0, 0, 0))
	for k in 8:
		var a := k * PI / 4.0
		_line(c, c + Vector2(cos(a), sin(a)) * 34, 4, WOOD)
	_ellipse(c.x, c.y, 8, 8, WOOD_DARK)

## The driver sitting on the cart, straw hat and lamba.
func _driver() -> void:
	_rect(18, 60, 26, 30, Color(0.92, 0.9, 0.82)) # lamba over the body
	_rect(18, 82, 30, 10, Color(0.4, 0.3, 0.22)) # legs, sitting
	_ellipse(31, 50, 9, 10, Color(0.42, 0.27, 0.18)) # head
	_ellipse(31, 40, 18, 4, Color(0.85, 0.74, 0.45)) # satroka brim
	_ellipse(31, 36, 9, 6, Color(0.85, 0.74, 0.45)) # crown
	_line(Vector2(44, 66), Vector2(60, 60), 3, Color(0.42, 0.27, 0.18)) # arm holding the goad
	_line(Vector2(56, 64), Vector2(63, 20), 2, WOOD_DARK) # goad

func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and _same_cell(p, Vector2i(x, y)) and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break

## Outlines never cross from one sprite into its neighbour.
func _same_cell(a: Vector2i, b: Vector2i) -> bool:
	if a.y < 96 and b.y < 96:
		return a.x / 128 == b.x / 128
	if a.y >= 96 and b.y >= 96:
		var ka := 0 if a.x < 160 else (1 if a.x < 256 else 2)
		var kb := 0 if b.x < 160 else (1 if b.x < 256 else 2)
		return ka == kb
	return false
