extends SceneTree
## Placeholder free-roaming zebu, side view facing right, twice the on-screen
## density. 512 x 192, cells of 128 x 96 (hframes 4, vframes 2):
##   0-3 walking (0 = standing)   4-5 grazing, head down, chewing
##   6 lying down (resting)       7 standing, head up (watching)
## The coat is light: GrazingZebu tints it, so one sheet gives a whole herd
## (brown, fawn, grey, near-black). Everything stands on the bottom edge.
##   godot --headless --path . --script res://tools/placeholder_art/gen_zebu.gd
const OUTLINE := Color(0.14, 0.09, 0.05)
const HIDE := Color(0.9, 0.86, 0.8)
const HIDE_DARK := Color(0.68, 0.63, 0.57)
const HIDE_LIGHT := Color(0.97, 0.95, 0.91)
const HORN := Color(0.98, 0.95, 0.86)
const HOOF := Color(0.25, 0.2, 0.17)
const GROUND := 94.0
var img: Image
var o := Vector2.ZERO

func _init():
	img = Image.create(512, 192, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for frame in 8:
		o = Vector2((frame % 4) * 128, (frame / 4) * 96)
		match frame:
			0, 1, 2, 3:
				_standing([0.0, 5.0, 0.0, -5.0][frame], "level")
			4:
				_standing(0.0, "grazing", 0.0)
			5:
				_standing(0.0, "grazing", 2.0)
			6:
				_lying()
			7:
				_standing(0.0, "watching")
	_outline()
	img.save_png("res://assets/sprites/animals/zebu.png")
	print("zebu.png written")
	quit()

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= 128 or y >= 96:
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

## Body, hump, dewlap, tail - shared by every standing pose.
func _body(body_y: float) -> void:
	_ellipse(30, body_y - 2, 6, 10, HIDE_DARK) # rump
	_ellipse(60, body_y, 38, 18, HIDE)
	_ellipse(60, body_y + 6, 34, 10, HIDE_LIGHT)
	_ellipse(84, body_y - 18, 13, 11, HIDE) # hump
	_line(Vector2(23, body_y - 8), Vector2(18, body_y + 20), 2, HIDE_DARK)
	_ellipse(18, body_y + 23, 3, 4, OUTLINE) # tail tuft

## Head, its muzzle and lyre horns, the head's center at `head`.
func _head(head: Vector2) -> void:
	_ellipse(head.x, head.y, 11, 9, HIDE)
	_ellipse(head.x + 9, head.y + 4, 5, 5, HIDE_DARK)
	_ellipse(head.x - 7, head.y - 6, 4, 3, HIDE_DARK)
	_line(head + Vector2(-4, -8), head + Vector2(-10, -22), 3, HORN)
	_line(head + Vector2(-10, -22), head + Vector2(-4, -30), 3, HORN)
	_line(head + Vector2(2, -8), head + Vector2(4, -22), 3, HORN)
	_line(head + Vector2(4, -22), head + Vector2(12, -28), 3, HORN)

## `head`: "level" (walking), "grazing" (down to the grass, `chew` moves the
## jaw), "watching" (raised).
func _standing(swing: float, head: String, chew := 0.0) -> void:
	for leg in [[34.0, -swing], [84.0, swing]]:
		_rect(leg[0] + leg[1] * 0.6, 62, 6, GROUND - 62, HIDE_DARK)
	_body(52)
	match head:
		"level":
			_ellipse(96, 62, 8, 10, HIDE_LIGHT) # dewlap
			_head(Vector2(110, 52))
		"grazing":
			_line(Vector2(96, 48), Vector2(110, 74), 10, HIDE) # neck down
			_head(Vector2(114, 80 + chew * 0.5))
		"watching":
			_ellipse(96, 58, 8, 10, HIDE_LIGHT)
			_head(Vector2(108, 42))
	for leg in [[42.0, swing], [92.0, -swing]]:
		var x: float = leg[0] + leg[1]
		_rect(x, 62, 7, GROUND - 62, HIDE)
		_rect(x, GROUND - 3, 7, 3, HOOF)

## Lying down, legs folded under, head up - chewing the cud.
func _lying() -> void:
	_rect(38, 84, 46, 8, HIDE_DARK) # folded legs
	_body(72)
	_ellipse(94, 76, 7, 8, HIDE_LIGHT)
	_head(Vector2(106, 66))

func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / 128 == x / 128 and p.y / 96 == y / 96 and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
