extends SceneTree
## Placeholder dogs (alika): the family's dog, side view facing right, twice
## the on-screen density. assets/sprites/animals/dog.png, 448 x 288, cells of
## 112 x 96 (hframes 4, vframes 3), standing on y = 92:
##   0-3 trotting (0 = standing)   4-5 sitting, tail down / wagging
##   6 lying down, head up          7 asleep, curled up
##   8 barking (sitting, head up)   9 sniffing the ground
##   10 happy (tail high, tongue)   11 petted (sitting, eyes shut)
## The coat is light: Dog tints it (a tan village dog, black, brown...).
## And assets/sprites/props/dog_props.png, cells of 192 x 192 (4 x 1), on the
## bottom edge: the doghouse, the bowl empty, the bowl full (rice), Rakoto's
## basket of puppies (sobika).
##   godot --headless --path . --script res://tools/placeholder_art/gen_dog.gd
const OUTLINE := Color(0.14, 0.09, 0.05)
const COAT := Color(0.95, 0.92, 0.86)
const COAT_DARK := Color(0.76, 0.72, 0.66)
const COAT_LIGHT := Color(1.0, 0.99, 0.96)
const NOSE := Color(0.12, 0.09, 0.08)
const TONGUE := Color(0.93, 0.5, 0.55)
const GROUND := 92.0
const CELL := Vector2(112, 96)

const WOOD := Color(0.55, 0.36, 0.2)
const WOOD_DARK := Color(0.4, 0.25, 0.13)
const THATCH := Color(0.78, 0.64, 0.36)
const THATCH_DARK := Color(0.6, 0.47, 0.24)
const INSIDE := Color(0.13, 0.08, 0.05)
const TIN := Color(0.62, 0.62, 0.6)
const TIN_DARK := Color(0.42, 0.42, 0.41)
const RICE := Color(0.98, 0.97, 0.92)
const RICE_SHADE := Color(0.86, 0.84, 0.78)
const BASKET := Color(0.8, 0.66, 0.4)
const BASKET_DARK := Color(0.62, 0.48, 0.26)
const PUPPY_COATS := [Color(0.86, 0.62, 0.36), Color(0.36, 0.3, 0.27), Color(0.97, 0.93, 0.85)]

var img: Image
var o := Vector2.ZERO
var cell := CELL

func _init():
	_dogs()
	_props()
	quit()

# --- the dog -----------------------------------------------------------------------------

func _dogs() -> void:
	img = Image.create(448, 288, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	cell = CELL
	for frame in 12:
		o = Vector2((frame % 4) * CELL.x, (frame / 4) * CELL.y)
		match frame:
			0, 1, 2, 3:
				_standing([0.0, 6.0, 0.0, -6.0][frame], [0.0, -1.0, 0.0, -1.0][frame], "level", "curled")
			4:
				_sitting("down", "open")
			5:
				_sitting("up", "open")
			6:
				_lying(false)
			7:
				_lying(true)
			8:
				_sitting("up", "bark")
			9:
				_standing(2.0, 0.0, "sniff", "curled")
			10:
				_standing(0.0, -2.0, "happy", "high")
			11:
				_sitting("up", "shut")
	_outline()
	img.save_png("res://assets/sprites/animals/dog.png")
	print("dog.png written")

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

func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var lo := Vector2(min(a.x, b.x, c.x), min(a.y, b.y, c.y))
	var hi := Vector2(max(a.x, b.x, c.x), max(a.y, b.y, c.y))
	for yy in range(int(lo.y), int(hi.y) + 1):
		for xx in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(xx, yy)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
				_px(xx, yy, color)

## The head, its center at `at`: pointed upright ears, the muzzle to the
## right. `mouth`: "closed", "open" (panting), "bark", "shut" (eyes shut,
## content).
func _head(at: Vector2, mouth := "closed") -> void:
	_tri(at + Vector2(-8, -4), at + Vector2(-1, -5), at + Vector2(-7, -19), COAT_DARK) # far ear
	_ellipse(at.x, at.y, 11, 9, COAT)
	_tri(at + Vector2(-4, -5), at + Vector2(4, -6), at + Vector2(-1, -21), COAT) # near ear
	_tri(at + Vector2(-2, -7), at + Vector2(2, -7), at + Vector2(-1, -16), COAT_DARK)
	if mouth == "bark":
		_ellipse(at.x + 11, at.y - 1, 8, 4, COAT)
		_tri(at + Vector2(6, 3), at + Vector2(18, 1), at + Vector2(16, 9), INSIDE)
		_ellipse(at.x + 11, at.y + 7, 6, 2.5, COAT_LIGHT)
		_ellipse(at.x + 18, at.y - 3, 2.5, 2, NOSE)
	else:
		_ellipse(at.x + 11, at.y + 2, 8, 5, COAT_LIGHT) # muzzle
		_ellipse(at.x + 18, at.y, 2.5, 2, NOSE)
		_line(at + Vector2(9, 5), at + Vector2(15, 5), 1, NOSE)
		if mouth == "open":
			_ellipse(at.x + 12, at.y + 7, 2.5, 3, TONGUE)
	if mouth == "shut":
		_line(at + Vector2(1, -2), at + Vector2(4, -3), 1, NOSE)
		_line(at + Vector2(4, -3), at + Vector2(7, -2), 1, NOSE)
	else:
		_ellipse(at.x + 4, at.y - 2, 1.6, 1.8, NOSE)

## The village dog's curly tail, from `root`: "curled" over the back,
## "high" (wagging, happy), "down", "up" (sitting, wagging on the ground).
func _tail(root: Vector2, shape: String) -> void:
	match shape:
		"curled":
			_line(root, root + Vector2(-6, -12), 4, COAT)
			_line(root + Vector2(-6, -12), root + Vector2(2, -17), 4, COAT)
			_line(root + Vector2(2, -17), root + Vector2(5, -11), 3, COAT_LIGHT)
		"high":
			_line(root, root + Vector2(-4, -16), 4, COAT)
			_line(root + Vector2(-4, -16), root + Vector2(2, -24), 4, COAT)
			_line(root + Vector2(2, -24), root + Vector2(6, -20), 3, COAT_LIGHT)
		"down":
			_line(root, root + Vector2(-12, 6), 4, COAT)
			_line(root + Vector2(-12, 6), root + Vector2(-20, 4), 4, COAT_LIGHT)
		"up":
			_line(root, root + Vector2(-12, -2), 4, COAT)
			_line(root + Vector2(-12, -2), root + Vector2(-18, -10), 4, COAT_LIGHT)

## Trotting / standing. `swing`: the legs' stride, `bob`: the body's.
## `head`: "level", "sniff" (nose to the ground), "happy" (raised, panting).
func _standing(swing: float, bob: float, head: String, tail: String) -> void:
	var y := 58.0 + bob
	for leg in [[36.0, -swing], [70.0, swing]]: # far legs
		_line(Vector2(leg[0], y + 6), Vector2(leg[0] + leg[1], GROUND - 2), 5, COAT_DARK)
	_tail(Vector2(30, y - 4), tail)
	_ellipse(52, y, 25, 11, COAT)
	_ellipse(54, y + 5, 20, 5, COAT_LIGHT) # belly
	_ellipse(48, y - 7, 16, 4, COAT_DARK) # saddle
	_ellipse(72, y - 1, 10, 12, COAT) # chest
	match head:
		"level":
			_line(Vector2(74, y - 6), Vector2(82, y - 18), 11, COAT)
			_head(Vector2(86, y - 22))
		"happy":
			_line(Vector2(74, y - 6), Vector2(82, y - 20), 11, COAT)
			_head(Vector2(86, y - 26), "open")
		"sniff":
			_line(Vector2(74, y - 4), Vector2(84, y + 14), 11, COAT)
			_head(Vector2(88, y + 22))
	for leg in [[42.0, swing], [76.0, -swing]]: # near legs
		var foot := Vector2(leg[0] + leg[1], GROUND - 2)
		_line(Vector2(leg[0], y + 6), foot, 6, COAT)
		_ellipse(foot.x + 1.5, GROUND - 2, 4, 2, COAT_LIGHT)

## Sitting on its haunches, front legs straight. `tail`: "down" / "up",
## `mouth`: what _head draws (head raised to bark).
func _sitting(tail: String, mouth: String) -> void:
	_tail(Vector2(40, 86), tail)
	_ellipse(48, 76, 15, 14, COAT) # haunch
	_ellipse(45, 74, 9, 8, COAT_DARK)
	_ellipse(62, 62, 11, 19, COAT) # chest, upright
	_ellipse(65, 66, 6, 12, COAT_LIGHT)
	for x in [60.0, 68.0]:
		_line(Vector2(x, 66), Vector2(x + 1, GROUND - 2), 6, COAT)
		_ellipse(x + 2.5, GROUND - 2, 4, 2, COAT_LIGHT)
	_ellipse(46, GROUND - 2, 7, 2.5, COAT_LIGHT) # hind paw
	var head := Vector2(70, 34) if mouth != "bark" else Vector2(70, 30)
	_head(head, mouth)

## Lying down, front paws ahead: head up, or `asleep` (curled, head down on
## the paws, eyes shut).
func _lying(asleep: bool) -> void:
	if asleep:
		_ellipse(52, 80, 27, 11, COAT)
		_ellipse(48, 75, 18, 5, COAT_DARK)
		_line(Vector2(28, 84), Vector2(56, 90), 5, COAT_LIGHT) # tail around
		_ellipse(78, 86, 12, 5, COAT_LIGHT) # paws
		_ellipse(76, 80, 11, 8, COAT) # head, down
		_ellipse(86, 83, 7, 4, COAT_LIGHT)
		_ellipse(92, 82, 2, 1.6, NOSE)
		_tri(Vector2(68, 76), Vector2(74, 74), Vector2(66, 66), COAT_DARK)
		_line(Vector2(76, 79), Vector2(81, 79), 1, NOSE)
		return
	_tail(Vector2(28, 84), "down")
	_ellipse(52, 80, 28, 10, COAT)
	_ellipse(50, 74, 18, 4, COAT_DARK)
	_ellipse(54, 85, 20, 4, COAT_LIGHT)
	_rect(70, 86, 26, 5, COAT_LIGHT) # front paws ahead
	_line(Vector2(72, 76), Vector2(80, 66), 11, COAT)
	_head(Vector2(84, 60))

func _outline() -> void:
	var src := img.duplicate()
	var cell_size := Vector2i(cell)
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / cell_size.x == x / cell_size.x and p.y / cell_size.y == y / cell_size.y \
						and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break

# --- the doghouse, the bowl, the puppies -------------------------------------------------

func _props() -> void:
	img = Image.create(768, 192, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	cell = Vector2(192, 192)
	o = Vector2(0, 0)
	_doghouse()
	o = Vector2(192, 0)
	_bowl(false)
	o = Vector2(384, 0)
	_bowl(true)
	o = Vector2(576, 0)
	_puppies()
	_outline()
	img.save_png("res://assets/sprites/props/dog_props.png")
	print("dog_props.png written")

## A little plank house, a thatched roof, an arched doorway: front view.
func _doghouse() -> void:
	_rect(42, 104, 108, 84, WOOD)
	for x in range(42, 150, 18): # planks
		_rect(x, 104, 2, 84, WOOD_DARK)
	_rect(42, 182, 108, 6, WOOD_DARK)
	# the doorway, an arch
	_rect(74, 136, 44, 52, INSIDE)
	_ellipse(96, 136, 22, 20, INSIDE)
	_rect(72, 186, 48, 2, WOOD_DARK)
	# the roof: thatch, two slopes
	_tri(Vector2(26, 112), Vector2(166, 112), Vector2(96, 44), THATCH)
	for i in 9:
		var x := 34.0 + i * 16.0
		_line(Vector2(96, 50), Vector2(x, 110), 2, THATCH_DARK)
	_rect(24, 108, 144, 8, THATCH_DARK)
	_line(Vector2(96, 44), Vector2(96, 40), 4, WOOD_DARK)

## A tin bowl (a cut-down jar lid), empty or heaped with rice.
func _bowl(full: bool) -> void:
	_ellipse(96, 176, 34, 12, TIN_DARK)
	_rect(62, 164, 69, 12, TIN)
	_ellipse(96, 164, 34, 9, TIN_DARK if not full else TIN)
	if full:
		_ellipse(96, 160, 28, 10, RICE_SHADE)
		_ellipse(94, 157, 24, 9, RICE)
		for p: Vector2 in [Vector2(84, 154), Vector2(100, 152), Vector2(108, 158)]:
			_ellipse(p.x, p.y, 2, 1.5, RICE_SHADE)
	else:
		_ellipse(96, 165, 29, 6, Color(0.3, 0.3, 0.3))

## A round woven basket (sobika), three puppies peeping out.
func _puppies() -> void:
	for i in 3:
		var at := Vector2(66 + i * 30, 128 - (6 if i == 1 else 0))
		var coat: Color = PUPPY_COATS[i]
		_ellipse(at.x, at.y + 10, 15, 12, coat.darkened(0.15))
		_ellipse(at.x, at.y, 13, 11, coat)
		_ellipse(at.x - 12, at.y + 1, 4, 7, coat.darkened(0.25)) # floppy ears
		_ellipse(at.x + 12, at.y + 1, 4, 7, coat.darkened(0.25))
		_ellipse(at.x, at.y + 5, 6, 4, coat.lightened(0.35))
		_ellipse(at.x, at.y + 3, 2.2, 1.8, NOSE)
		_ellipse(at.x - 5, at.y - 2, 1.6, 1.8, NOSE)
		_ellipse(at.x + 5, at.y - 2, 1.6, 1.8, NOSE)
	_ellipse(96, 172, 60, 16, BASKET_DARK)
	_rect(36, 140, 121, 32, BASKET)
	_ellipse(96, 140, 60, 10, BASKET_DARK)
	_ellipse(96, 141, 56, 7, BASKET)
	for y in range(146, 172, 6): # the weave
		for x in range(40, 152, 10):
			_rect(x + (5 if (y / 6) % 2 == 0 else 0), y, 5, 2, BASKET_DARK)
