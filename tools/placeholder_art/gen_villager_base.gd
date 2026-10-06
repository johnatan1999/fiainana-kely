extends SceneTree
## Villager base body (a featureless mannequin) - the skeleton every outfit
## layer is drawn over - plus a few example layers. Twice the on-screen
## density, cells of 128 x 256:
##   columns: 0-1 idle (breathing), 2-5 walk (contact, passing, contact,
##            passing), 6-7 work (bent over, hands down to the ground and
##            back up - planting rice, weeding)
##   rows:    0 down (facing the camera), 1 left, 2 right, 3 up (back view)
## The right row is the left one mirrored. Feet on y = 252, centered on x = 64.
## Everything is drawn light: VillagerVisual tints the body with the skin
## color and each layer with its own color.
##
## Writes, in assets/sprites/characters/villager/:
## - base_body.png: the mannequin;
## - villager_guide.png: the same grid with the cell borders and the body's
##   reference lines (head top, eyes, chin, shoulders, hips, knees, ground) -
##   put it under a layer in the image editor to draw on it;
## - example_shirt.png, example_shorts.png, example_hair.png: layers drawn
##   from the same poses. A layer is the parts it covers, a little wider
##   than the body, with holes where the body passes in front of it (an
##   arm swinging in front of the shirt).
##   godot --headless --path . --script res://tools/placeholder_art/gen_villager_base.gd
const CELL := Vector2i(128, 256)
const COLUMNS := 8
const ROWS := 4
const OUT_DIR := "res://assets/sprites/characters/villager/"

const OUTLINE := Color(0.16, 0.11, 0.08)
const ERASE := Color(0, 0, 0, 0)
## Body shades (near, in shadow, far side) and the same for layers.
const SKIN := [Color(0.97, 0.94, 0.9), Color(0.86, 0.82, 0.78), Color(0.76, 0.72, 0.68)]
const CLOTH := [Color(0.98, 0.98, 0.98), Color(0.86, 0.86, 0.86), Color(0.74, 0.74, 0.74)]
const NEAR := 0
const SHADED := 1
const FAR := 2

## Reference lines (y, in cell pixels) - shared with the guide.
const GROUND := 252.0
const HIP := 168.0
const KNEE := 210.0
const SHOULDER := 106.0
const CHIN := 98.0
const EYES := 80.0
const HEAD_TOP := 62.0
const CX := 64.0

## Per walk frame: [lift of the left/near foot, lift of the right/far foot,
## stride (side view: near foot ahead < 0 < behind), arm swing, bob].
const WALK := [
	[0.0, 0.0, -1.0, 1.0, 0.0],
	[10.0, 0.0, 0.0, 0.0, -3.0],
	[0.0, 0.0, 1.0, -1.0, 0.0],
	[0.0, 10.0, 0.0, 0.0, -3.0],
]

## Sheet -> [body parts it covers, how much wider than the body (px)].
## Body parts: head, face (ears, eyes, nose, nape), neck, torso, pelvis
## (the bottom of the torso), arm_upper, arm_lower, hand, leg_upper,
## leg_lower, foot; and what's only drawn on a layer: hair, bun, skirt (long,
## to mid-calf, over both legs), hat (a straw satroka).
const SHEETS := {
	"base_body": [[], 0.0],
	"example_shorts": [["pelvis", "leg_upper"], 2.0],
	"example_shirt": [["torso", "pelvis", "arm_upper"], 2.5],
	"example_hair": [["hair"], 0.0],
	"example_trousers": [["pelvis", "leg_upper", "leg_lower"], 2.0],
	"example_skirt": [["skirt"], 0.0],
	"example_hair_bun": [["hair", "bun"], 0.0],
	"example_hat": [["hat"], 0.0],
}

enum View { FRONT, SIDE, BACK }

var img: Image
var o := Vector2.ZERO
## What's being drawn: [] = the body, else the parts of a layer.
var _parts: Array = []
var _grow := 0.0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for sheet: String in SHEETS:
		_parts = SHEETS[sheet][0]
		_grow = SHEETS[sheet][1]
		img = Image.create(CELL.x * COLUMNS, CELL.y * ROWS, false, Image.FORMAT_RGBA8)
		img.fill(ERASE)
		_draw_sheet()
		_outline()
		_mirror_row(1, 2)
		img.save_png(OUT_DIR + sheet + ".png")
	_guide().save_png(OUT_DIR + "villager_guide.png")
	print("villager sheets written: %s + villager_guide" % ", ".join(SHEETS.keys()))
	quit()

func _draw_sheet() -> void:
	for column in COLUMNS:
		var pose: Array
		if column < 2:
			pose = [0.0, 0.0, 0.0, 0.0, -2.0 * column] # breathing in
		elif column < 6:
			pose = WALK[column - 2]
		for row: int in [0, 1, 3]:
			o = Vector2(column * CELL.x, row * CELL.y)
			if column >= 6:
				var reach := 8.0 * (column - 6) # hands down to the ground
				match row:
					0: _work_front(reach, View.FRONT)
					1: _work_side(reach)
					3: _work_front(reach, View.BACK)
				continue
			match row:
				0: _front(pose, View.FRONT)
				1: _side(pose)
				3: _front(pose, View.BACK)

# --- parts --------------------------------------------------------------------

func _body() -> bool:
	return _parts.is_empty()

## The color to draw `part` with: its shade on the body, white-ish on a
## layer that covers it, and ERASE on a layer that doesn't - a part of the
## body drawn later is in front of the layer's garment and cuts it out.
func _col(part: String, shade: int) -> Color:
	if _body():
		return SKIN[shade]
	return CLOTH[shade] if part in _parts else ERASE

## Width of `part`: the body's, a little more for a garment covering it.
func _w(part: String, width: float) -> float:
	return width + _grow * 2.0 if not _body() and part in _parts else width

# --- drawing helpers ----------------------------------------------------------

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= CELL.x or y >= CELL.y:
		return
	img.set_pixelv(Vector2i(int(o.x + x), int(o.y + y)), c)

func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(cy - ry), int(cy + ry) + 1):
		for xx in range(int(cx - rx), int(cx + rx) + 1):
			if pow((xx - cx) / rx, 2) + pow((yy - cy) / ry, 2) <= 1.0:
				_px(xx, yy, c)

## A limb segment, `w0` wide at `a` tapering to `w1` at `b`.
func _limb(part: String, a: Vector2, b: Vector2, w0: float, w1: float, shade: int) -> void:
	var c := _col(part, shade)
	w0 = _w(part, w0)
	w1 = _w(part, w1)
	var steps := int(a.distance_to(b)) + 1
	for s in steps + 1:
		var t := float(s) / steps
		var p := a.lerp(b, t)
		var r := lerpf(w0, w1, t) / 2.0
		_ellipse(p.x, p.y, r, r, c)

## Torso between the shoulders and the hips: `half` gives the half-width
## at shoulders, waist and hips; `lean` shifts it sideways (side view). Its
## last PELVIS px are the "pelvis" part.
const PELVIS := 14.0
func _torso(top: float, bottom: float, half: Vector3, lean: float) -> void:
	for y in range(int(top), int(bottom) + 1):
		var part := "pelvis" if y > bottom - PELVIS else "torso"
		var t := (y - top) / (bottom - top)
		var w := lerpf(half.x, half.y, t / 0.65) if t < 0.65 else lerpf(half.y, half.z, (t - 0.65) / 0.35)
		if y - top < 6: # rounded shoulders
			w -= (6 - (y - top)) * 0.8
		w = _w(part, w * 2.0) / 2.0
		var c := _col(part, NEAR)
		for x in range(int(CX + lean - w), int(CX + lean + w) + 1):
			_px(x, y, c)
	if not _body() and ("torso" in _parts or "pelvis" in _parts):
		# A garment reaches a little lower than the body's hips.
		var last := "pelvis" if "pelvis" in _parts else "torso"
		for y in range(int(bottom) + 1, int(bottom + _grow * 2.0) + 1):
			var w := _w(last, half.z * 2.0) / 2.0
			for x in range(int(CX + lean - w), int(CX + lean + w) + 1):
				_px(x, y, _col(last, NEAR))

# --- views --------------------------------------------------------------------

## Facing the camera (FRONT) or seen from behind (BACK).
func _front(pose: Array, view: View) -> void:
	var bob: float = pose[4]
	var hip := HIP + bob
	# Legs: a lifted foot bends the knee up.
	for side in [-1.0, 1.0]:
		var lift: float = pose[0] if side < 0 else pose[1]
		var hip_point := Vector2(CX + side * 9, hip)
		var foot := Vector2(CX + side * 10, GROUND - 4 - lift)
		var knee := Vector2(CX + side * 10, KNEE - lift * 0.7 + bob * 0.5)
		_limb("leg_upper", hip_point, knee, 15, 12, SHADED)
		_limb("leg_lower", knee, foot, 12, 9, SHADED)
		_ellipse(foot.x + side * 1, foot.y + 1, 7, 4, _col("foot", SHADED))
	_torso(SHOULDER + bob - 4, hip + 4, Vector3(22, 16, 18), 0.0)
	_skirt(hip, 0.0, Vector2(20, 26), 0.0)
	# Arms at the sides, swinging a little.
	for side in [-1.0, 1.0]:
		var swing: float = pose[3] * side
		var shoulder := Vector2(CX + side * 21, SHOULDER + bob + 2)
		var elbow := Vector2(CX + side * 25, 140 + bob - swing * 2)
		var hand := Vector2(CX + side * (25 - swing * 2), 172 + bob - swing * 5)
		_limb("arm_upper", shoulder, elbow, 10, 9, SHADED)
		_limb("arm_lower", elbow, hand, 9, 8, SHADED)
		_ellipse(hand.x, hand.y + 2, 5, 6, _col("hand", SHADED))
	# Neck and head.
	_limb("neck", Vector2(CX, CHIN + bob - 4), Vector2(CX, SHOULDER + bob), 11, 12,
		SHADED if view == View.FRONT else NEAR)
	var head := Vector2(CX, (HEAD_TOP + CHIN) / 2.0 + bob)
	_ellipse(head.x - 15, head.y + 2, 3, 5, _col("face", SHADED)) # ears
	_ellipse(head.x + 15, head.y + 2, 3, 5, _col("face", SHADED))
	_ellipse(head.x, head.y, 15, 18, _col("head", NEAR))
	if view == View.FRONT:
		for side in [-1.0, 1.0]:
			_ellipse(CX + side * 6, EYES + bob, 1.6, 2.4, OUTLINE if _body() else ERASE)
		_ellipse(CX, EYES + bob + 8, 2, 2, _col("face", SHADED)) # nose
		_hair(head, func(x: float, y: float) -> bool:
			# A cap down to the brow, and down the sides to the ears.
			return y < EYES + bob - 6 or (absf(x - head.x) > 11 and y < EYES + bob + 4))
		_headwear(head, Vector2(0, -19), 26.0)
	else:
		_hair(head, func(_x: float, y: float) -> bool: return y < CHIN + bob - 7)
		_headwear(head, Vector2(0, -4), 26.0)

## Seen from the side, facing left (the right row is this one mirrored).
func _side(pose: Array) -> void:
	var bob: float = pose[4]
	var hip := HIP + bob
	var stride: float = pose[2]
	var swing: float = pose[3]
	# Far arm and far leg first, darker.
	_side_arm(-swing, bob, FAR)
	_side_leg(-stride, pose[1], hip, FAR)
	_torso(SHOULDER + bob - 4, hip + 4, Vector3(12, 11, 13), -1.0)
	_side_leg(stride, pose[0], hip, SHADED)
	_skirt(hip, -1.0, Vector2(13, 20), stride)
	# Neck and head, the face to the left.
	_limb("neck", Vector2(CX - 1, CHIN + bob - 4), Vector2(CX, SHOULDER + bob), 11, 12, SHADED)
	var head := Vector2(CX - 2, (HEAD_TOP + CHIN) / 2.0 + bob)
	_ellipse(head.x, head.y, 14, 18, _col("head", NEAR))
	_ellipse(head.x - 12, head.y + 7, 5, 4, _col("face", NEAR)) # nose and chin
	_ellipse(head.x + 3, head.y + 2, 3, 5, _col("face", SHADED)) # ear
	_ellipse(head.x - 8, EYES + bob, 1.6, 2.4, OUTLINE if _body() else ERASE)
	_hair(head, func(x: float, y: float) -> bool:
		# The top down to the brow, the back of the head down to the nape.
		return y < EYES + bob - 6 or (x > head.x - 1 and y < CHIN + bob - 7))
	_headwear(head, Vector2(15, -10), 24.0)
	_side_arm(swing, bob, SHADED)

## Bent over, facing the camera (FRONT: the head low in front of the
## shoulders, the arms hanging down in front of the legs) or seen from
## behind (BACK: the back and the hips, the head hidden below them).
func _work_front(reach: float, view: View) -> void:
	var hip := HIP
	var shoulder_y := 136.0
	var head := Vector2(CX, 120.0 + reach * 0.4)
	if view == View.BACK:
		# Arms and head first: the back hides them.
		_work_front_arms(reach, shoulder_y)
		_ellipse(head.x, head.y + 14, 15, 18, _col("head", NEAR))
	for side in [-1.0, 1.0]:
		var hip_point := Vector2(CX + side * 9, hip)
		var foot := Vector2(CX + side * 13, GROUND - 4)
		var knee := Vector2(CX + side * 12, KNEE)
		_limb("leg_upper", hip_point, knee, 15, 12, SHADED)
		_limb("leg_lower", knee, foot, 12, 9, SHADED)
		_ellipse(foot.x + side * 1, foot.y + 1, 7, 4, _col("foot", SHADED))
	_torso(shoulder_y - 4, hip + 4, Vector3(23, 20, 19), 0.0)
	_skirt(hip, 0.0, Vector2(20, 26), 0.0)
	if view == View.FRONT:
		# Looking down: more of the top of the head, the eyes lower.
		_ellipse(head.x - 15, head.y + 4, 3, 5, _col("face", SHADED))
		_ellipse(head.x + 15, head.y + 4, 3, 5, _col("face", SHADED))
		_ellipse(head.x, head.y, 15, 18, _col("head", NEAR))
		for side in [-1.0, 1.0]:
			_ellipse(CX + side * 6, head.y + 6, 1.6, 2.0, OUTLINE if _body() else ERASE)
		_hair(head, func(x: float, y: float) -> bool:
			return y < head.y + 1 or (absf(x - head.x) > 11 and y < head.y + 8))
		_headwear(head, Vector2(0, -19), 26.0)
		_work_front_arms(reach, shoulder_y)

func _work_front_arms(reach: float, shoulder_y: float) -> void:
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(CX + side * 20, shoulder_y + 4)
		var elbow := Vector2(CX + side * 21, 184 + reach * 0.5)
		var hand := Vector2(CX + side * 18, 220 + reach)
		# Lighter than the legs behind them, to read in front of them.
		_limb("arm_upper", shoulder, elbow, 10, 9, NEAR)
		_limb("arm_lower", elbow, hand, 9, 8, NEAR)
		_ellipse(hand.x, hand.y + 2, 5, 6, _col("hand", NEAR))

## Bent over, seen from the side (facing left): the back slanting down to
## the shoulders, the head low and forward, the arms hanging to the ground.
func _work_side(reach: float) -> void:
	var hip := Vector2(CX + 10, HIP - 2)
	var shoulder := Vector2(CX - 26, 132)
	var head := Vector2(CX - 40, 128 + reach * 0.4)
	_work_side_arm(shoulder + Vector2(4, 0), Vector2(CX - 28, 180 + reach * 0.5), Vector2(CX - 22, 226 + reach), FAR)
	_limb("leg_upper", hip, Vector2(CX + 14, KNEE), 15, 12, FAR)
	_limb("leg_lower", Vector2(CX + 14, KNEE), Vector2(CX + 16, GROUND - 4), 12, 9, FAR)
	_ellipse(CX + 12, GROUND - 3, 9, 4, _col("foot", FAR))
	_limb("pelvis", hip, hip.lerp(shoulder, 0.3), 30, 28, NEAR)
	_limb("torso", hip.lerp(shoulder, 0.25), shoulder, 28, 24, NEAR)
	_limb("leg_upper", hip, Vector2(CX + 6, KNEE), 15, 12, SHADED)
	_limb("leg_lower", Vector2(CX + 6, KNEE), Vector2(CX + 4, GROUND - 4), 12, 9, SHADED)
	_ellipse(CX, GROUND - 3, 9, 4, _col("foot", SHADED))
	_skirt(HIP, 10.0, Vector2(14, 20), 0.0)
	_limb("neck", shoulder, head + Vector2(10, 2), 12, 11, SHADED)
	_ellipse(head.x, head.y, 14, 17, _col("head", NEAR))
	_ellipse(head.x - 10, head.y + 9, 5, 4, _col("face", NEAR)) # nose and chin
	_ellipse(head.x + 4, head.y, 3, 5, _col("face", SHADED)) # ear
	_ellipse(head.x - 7, head.y + 3, 1.6, 2.0, OUTLINE if _body() else ERASE)
	_hair(head, func(x: float, y: float) -> bool: return y < head.y - 4 or x > head.x)
	_headwear(head, Vector2(13, -8), 24.0)
	_work_side_arm(shoulder, Vector2(CX - 34, 178 + reach * 0.5), Vector2(CX - 30, 226 + reach), SHADED)

func _work_side_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, shade: int) -> void:
	_limb("arm_upper", shoulder, elbow, 11, 9, shade)
	_limb("arm_lower", elbow, hand, 9, 8, shade)
	_ellipse(hand.x, hand.y + 2, 5, 6, _col("hand", shade))

## stride < 0: this foot ahead (to the left); `lift` raises it, knee forward.
func _side_leg(stride: float, lift: float, hip: float, shade: int) -> void:
	var foot := Vector2(CX + stride * 16 - lift * 0.4, GROUND - 4 - lift)
	var knee := Vector2(CX + stride * 8 - lift * 0.9, KNEE - lift * 0.5 + (hip - HIP) * 0.5)
	_limb("leg_upper", Vector2(CX, hip), knee, 15, 12, shade)
	_limb("leg_lower", knee, foot, 12, 9, shade)
	_ellipse(foot.x - 4, foot.y + 1, 9, 4, _col("foot", shade))

## swing < 0: the hand forward (to the left).
func _side_arm(swing: float, bob: float, shade: int) -> void:
	var shoulder := Vector2(CX, SHOULDER + bob + 3)
	var elbow := Vector2(CX + swing * 7, 140 + bob)
	var hand := Vector2(CX + swing * 16, 170 + bob - absf(swing) * 3)
	_limb("arm_upper", shoulder, elbow, 11, 9, shade)
	_limb("arm_lower", elbow, hand, 9, 8, shade)
	_ellipse(hand.x, hand.y + 2, 5, 6, _col("hand", shade))

## Short hair: the head, a little bigger, where `covers(x, y)` says.
func _hair(head: Vector2, covers: Callable) -> void:
	if not "hair" in _parts:
		return
	var rx := 17.0
	var ry := 20.0
	for yy in range(int(head.y - ry), int(head.y + ry) + 1):
		for xx in range(int(head.x - rx), int(head.x + rx) + 1):
			if pow((xx - head.x) / rx, 2) + pow((yy - head.y) / ry, 2) <= 1.0 and covers.call(xx, yy):
				_px(xx, yy, CLOTH[NEAR])

## A long skirt, from the hips to mid-calf: `half` = half-width at the top
## and at the hem, swaying with the stride (side view).
func _skirt(hip: float, lean: float, half: Vector2, stride: float) -> void:
	if not "skirt" in _parts:
		return
	var top := hip - 6.0
	var hem := GROUND - 34.0
	for y in range(int(top), int(hem) + 1):
		var t := (y - top) / (hem - top)
		var w := lerpf(half.x, half.y, t)
		var x0 := CX + lean - w + stride * 4.0 * t
		var x1 := CX + lean + w - stride * 4.0 * t
		for x in range(int(minf(x0, x1)), int(maxf(x0, x1)) + 1):
			_px(x, y, CLOTH[NEAR] if t < 0.85 else CLOTH[SHADED])

## A bun (`bun_offset` from the head's center) and a straw hat with a brim
## `brim` px wide (half), each when the layer has it.
func _headwear(head: Vector2, bun_offset: Vector2, brim: float) -> void:
	if "bun" in _parts:
		_ellipse(head.x + bun_offset.x, head.y + bun_offset.y, 9, 8, CLOTH[SHADED])
	if "hat" in _parts:
		var top := HEAD_TOP + (head.y - (HEAD_TOP + CHIN) / 2.0)
		_ellipse(head.x, top + 12, brim, 7, CLOTH[SHADED]) # brim
		_ellipse(head.x, top + 4, 15, 11, CLOTH[NEAR]) # crown
		for x in range(int(head.x - 15), int(head.x + 16)):
			_px(x, top + 9, CLOTH[FAR]) # band

# --- post-processing ----------------------------------------------------------

func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / CELL.x == x / CELL.x and p.y / CELL.y == y / CELL.y \
						and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break

## Copies row `from` into row `to`, each cell flipped horizontally.
func _mirror_row(from: int, to: int) -> void:
	for column in COLUMNS:
		var cell := img.get_region(Rect2i(column * CELL.x, from * CELL.y, CELL.x, CELL.y))
		cell.flip_x()
		img.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, to * CELL.y))

func _guide() -> Image:
	var guide := Image.create(CELL.x * COLUMNS, CELL.y * ROWS, false, Image.FORMAT_RGBA8)
	guide.fill(ERASE)
	var lines := {
		HEAD_TOP: Color(0.2, 0.5, 1.0, 0.6), EYES: Color(0.2, 0.5, 1.0, 0.35),
		CHIN: Color(0.2, 0.5, 1.0, 0.6), SHOULDER: Color(0.1, 0.7, 0.3, 0.6),
		HIP: Color(0.1, 0.7, 0.3, 0.6), KNEE: Color(0.1, 0.7, 0.3, 0.35),
		GROUND: Color(1.0, 0.2, 0.2, 0.8),
	}
	for row in ROWS:
		for column in COLUMNS:
			var origin := Vector2i(column * CELL.x, row * CELL.y)
			for x in CELL.x:
				guide.set_pixel(origin.x + x, origin.y, Color(0.5, 0.5, 0.5, 0.6))
				for y: float in lines:
					guide.set_pixel(origin.x + x, origin.y + int(y), lines[y])
			for y in CELL.y:
				guide.set_pixel(origin.x, origin.y + y, Color(0.5, 0.5, 0.5, 0.6))
				if y % 4 < 2:
					guide.set_pixel(origin.x + int(CX), origin.y + y, Color(1.0, 0.6, 0.1, 0.5))
	return guide
