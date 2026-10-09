extends SceneTree
## Villager sheets traced from the player's sprite (player2.png): the same
## painted silhouette and the same animations, made recolorable - a
## temporary base until the villagers get their own character art.
##
## Every pixel of the player's frames is sorted by its color: skin, T-shirt
## (white), shorts (green), hair (dark, on the head). Each sort becomes light
## grey keeping the painting's shading (its brightness relative to the
## sort's average), so a tint gives it any color:
## - base_body.png: the whole silhouette (VillagerLook.skin_color tints it);
## - example_shirt.png, example_shorts.png, example_hair.png: the player's
##   own T-shirt, shorts and hair;
## - example_trousers.png: the shorts carried down the legs to the ankles;
## - example_skirt.png: a long skirt from the waist to mid-calf, as wide as
##   the legs at each height;
## - example_hair_bun.png, example_hat.png: a bun / a straw hat set on the
##   head found in each frame;
## - villager_guide.png: the cell borders, the feet line and the body's
##   ghost, to draw new layers on.
##
## Same grid as VillagerVisual (cells of 128 x 256, feet on y = 252): the
## player's 1x frames are scaled 2x (nearest - at the game's 0.5 scale they
## show exactly as the player does).
##   rows:    0 down, 1 left, 2 right, 3 up
##   columns: 0-1 idle, 2-5 walk, 6-7 work (the player's crouching harvest)
##   godot --headless --path . --script res://tools/placeholder_art/gen_villager_from_player.gd
## Then open the editor once (or --editor --quit) to re-import the sheets.

const SRC := "res://assets/sprites/characters/player/player2.png"
const OUT_DIR := "res://assets/sprites/characters/villager/"
const SRC_CELL := Vector2i(64, 128)
const CELL := Vector2i(128, 256)
const COLUMNS := 8
const ROWS := 4
const FEET_Y := 252

## Villager row -> the player's frames (cell origins in player2.png), in the
## villager's column order: idle x2, walk x4, work x2. From the player's
## SpriteFrames (entities/player/player.tscn): idle_*, walk_*, and
## harvest_left/right for work (crouching, hands to the ground). There's no
## crouching from the front or the back: villagers work facing sideways.
const FRAMES := {
	0: [Vector2i(64, 384), Vector2i(64, 384), Vector2i(0, 384), Vector2i(64, 384), Vector2i(128, 384), Vector2i(64, 384), Vector2i(64, 384), Vector2i(64, 384)],
	1: [Vector2i(64, 256), Vector2i(64, 256), Vector2i(0, 256), Vector2i(64, 256), Vector2i(128, 256), Vector2i(64, 256), Vector2i(320, 128), Vector2i(384, 128)],
	2: [Vector2i(64, 128), Vector2i(64, 128), Vector2i(0, 128), Vector2i(64, 128), Vector2i(128, 128), Vector2i(64, 128), Vector2i(320, 0), Vector2i(384, 0)],
	3: [Vector2i(64, 0), Vector2i(64, 0), Vector2i(0, 0), Vector2i(128, 0), Vector2i(64, 0), Vector2i(128, 0), Vector2i(64, 0), Vector2i(64, 0)],
}
## Which way each row looks: the back of the head (for the bun) is opposite.
const FACING := {0: Vector2.DOWN, 1: Vector2.LEFT, 2: Vector2.RIGHT, 3: Vector2.UP}

enum Sort { SKIN, SHIRT, SHORTS, HAIR }
## The top of the figure this tall (share of its height) is the head; the
## hair is only in its upper part (below is the face's dark outline: chin,
## jaw).
const HEAD_SHARE := 0.24
const HAIR_SHARE := 0.15
## A sort's average brightness becomes this grey (highlights go above).
const GREY := 0.86
const OUTLINE := Color(0.16, 0.11, 0.08)
const LAYERS := ["base_body", "example_shirt", "example_shorts", "example_hair",
	"example_trousers", "example_skirt", "example_hair_bun", "example_hat"]

var _src: Image
var _mean := {} # Sort -> average luminance over every frame

func _init() -> void:
	_src = Image.load_from_file(SRC)
	_src.convert(Image.FORMAT_RGBA8)
	_measure()
	var sheets := {}
	for layer: String in LAYERS:
		sheets[layer] = Image.create(CELL.x * COLUMNS, CELL.y * ROWS, false, Image.FORMAT_RGBA8)
		sheets[layer].fill(Color(0, 0, 0, 0))
	for row: int in FRAMES:
		# One shift per row, from its idle frame: the feet on FEET_Y, and the
		# walk keeps its bob.
		var shift := FEET_Y - (_bottom(FRAMES[row][0]) * 2 + 1)
		for column in COLUMNS:
			var frame := _frame_layers(FRAMES[row][column], FACING[row])
			for layer: String in LAYERS:
				var cell: Image = frame[layer]
				cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
				sheets[layer].blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y + shift))
	for layer: String in LAYERS:
		sheets[layer].save_png(OUT_DIR + layer + ".png")
	_guide(sheets["base_body"]).save_png(OUT_DIR + "villager_guide.png")
	print("villager sheets traced from the player: %s + villager_guide" % ", ".join(LAYERS))
	quit()

# --- sorting the player's pixels ---------------------------------------------------

func _sort(c: Color, head: bool, hair_height := false) -> Sort:
	if hair_height and c.v < 0.22:
		return Sort.HAIR
	if c.h > 0.17 and c.h < 0.5 and c.s > 0.2 and c.v > 0.12:
		return Sort.SHORTS
	if not head and c.s < 0.22 and c.v > 0.5:
		return Sort.SHIRT
	return Sort.SKIN

## Average brightness of each sort, over every frame used.
func _measure() -> void:
	var total := {}
	var count := {}
	for sort in Sort.values():
		total[sort] = 0.0
		count[sort] = 0
	for row: int in FRAMES:
		for origin: Vector2i in FRAMES[row]:
			var box := _box(origin)
			for y in range(box.position.y, box.end.y):
				for x in range(box.position.x, box.end.x):
					var c := _src.get_pixel(origin.x + x, origin.y + y)
					if c.a < 0.5:
						continue
					var sort := _sort(c, _in_head(box, y), _in_hair(box, y))
					total[sort] += c.get_luminance()
					count[sort] += 1
	for sort in Sort.values():
		_mean[sort] = maxf(0.02, total[sort] / maxi(1, count[sort]))

## The light grey for a pixel of `sort`, keeping its shading: brightness
## relative to the sort's average - except the hair, nearly black, whose
## dark range is stretched over light greys (a ratio would keep it black).
func _grey(c: Color, sort: Sort) -> Color:
	var g := clampf(c.get_luminance() / _mean[sort] * GREY, 0.0, 1.0)
	if sort == Sort.HAIR:
		g = 0.55 + 0.45 * clampf(c.get_luminance() / 0.25, 0.0, 1.0)
	return Color(g, g, g, c.a)

## The figure's bounding box in a frame (cell coordinates): rows with a
## few solid pixels only - the sheet has stray specks around the figures,
## which would throw off where the head is.
func _box(origin: Vector2i) -> Rect2i:
	var top := -1
	var bottom := -1
	var left := SRC_CELL.x
	var right := -1
	for y in SRC_CELL.y:
		var solid := 0
		for x in SRC_CELL.x:
			if _src.get_pixel(origin.x + x, origin.y + y).a > 0.5:
				solid += 1
		if solid < 3:
			continue
		if top < 0:
			top = y
		bottom = y
		for x in SRC_CELL.x:
			if _src.get_pixel(origin.x + x, origin.y + y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	return Rect2i(left - 1, top, right - left + 3, bottom - top + 1)

func _bottom(origin: Vector2i) -> int:
	return _box(origin).end.y - 1

func _in_head(box: Rect2i, y: int) -> bool:
	return y < box.position.y + box.size.y * HEAD_SHARE

func _in_hair(box: Rect2i, y: int) -> bool:
	return y < box.position.y + box.size.y * HAIR_SHARE

# --- one frame, every layer ---------------------------------------------------------

func _frame_layers(origin: Vector2i, facing: Vector2) -> Dictionary:
	var layers := {}
	for layer: String in LAYERS:
		layers[layer] = Image.create(SRC_CELL.x, SRC_CELL.y, false, Image.FORMAT_RGBA8)
		layers[layer].fill(Color(0, 0, 0, 0))
	var box := _box(origin)
	var sorts := {} # Vector2i -> Sort
	var shorts_top := SRC_CELL.y
	var shorts_bottom := -1
	var head_left := SRC_CELL.x
	var head_right := -1
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := _src.get_pixel(origin.x + x, origin.y + y)
			if c.a < 0.1:
				continue
			var head := _in_head(box, y)
			var sort := _sort(c, head, _in_hair(box, y))
			sorts[Vector2i(x, y)] = sort
			layers["base_body"].set_pixel(x, y, _grey(c, sort))
			match sort:
				Sort.SHIRT:
					layers["example_shirt"].set_pixel(x, y, _grey(c, sort))
				Sort.SHORTS:
					layers["example_shorts"].set_pixel(x, y, _grey(c, sort))
					layers["example_trousers"].set_pixel(x, y, _grey(c, sort))
					shorts_top = mini(shorts_top, y)
					shorts_bottom = maxi(shorts_bottom, y)
				Sort.HAIR:
					layers["example_hair"].set_pixel(x, y, _grey(c, sort))
					layers["example_hair_bun"].set_pixel(x, y, _grey(c, sort))
			if head:
				head_left = mini(head_left, x)
				head_right = maxi(head_right, x)
	if shorts_bottom < 0: # no shorts found: guess the hips
		shorts_top = box.position.y + int(box.size.y * 0.52)
		shorts_bottom = box.position.y + int(box.size.y * 0.68)

	var feet_top := box.end.y - 5
	# Trousers: the legs below the shorts, down to the ankles.
	for y in range(shorts_bottom + 1, feet_top):
		for x in range(box.position.x, box.end.x):
			var c := _src.get_pixel(origin.x + x, origin.y + y)
			if c.a >= 0.1:
				layers["example_trousers"].set_pixel(x, y, _grey(c, Sort.SKIN))

	# Skirt: from the waist to mid-calf, straight-sided - from the hips'
	# width to the legs' spread at the hem, a little wider.
	var hem := shorts_top + int((box.end.y - shorts_top) * 0.74)
	var waist := _extent(sorts, shorts_top + 1, func(sort): return sort == Sort.SHORTS)
	var at_hem := _extent(sorts, hem, func(_sort): return true)
	if waist.y < 0:
		waist = at_hem
	if at_hem.y < 0:
		at_hem = waist
	if waist.y >= 0:
		for y in range(shorts_top, hem + 1):
			var t := float(y - shorts_top) / maxi(1, hem - shorts_top)
			var left := lerpf(waist.x - 1.0, minf(at_hem.x, waist.x) - 2.5, t)
			var right := lerpf(waist.y + 1.0, maxf(at_hem.y, waist.y) + 2.5, t)
			var grey := 0.95 if t < 0.85 else 0.8
			for x in range(roundi(left), roundi(right) + 1):
				_put(layers["example_skirt"], x, y, Color(grey, grey, grey))
	_outline(layers["example_skirt"])

	# On the head: a bun at the back, a straw hat on top.
	var head_center := (head_left + head_right + 1) / 2.0
	var head_width := float(head_right - head_left + 1)
	var top := float(box.position.y)
	var bun := Vector2(head_center, top + 1.0)
	if facing == Vector2.LEFT:
		bun = Vector2(head_center + head_width * 0.42, top + 4.0)
	elif facing == Vector2.RIGHT:
		bun = Vector2(head_center - head_width * 0.42, top + 4.0)
	elif facing == Vector2.UP:
		bun = Vector2(head_center, top + 3.0)
	_disc(layers["example_hair_bun"], bun, Vector2(4.0, 3.5), Color(0.8, 0.8, 0.8))
	_outline(layers["example_hair_bun"])
	_disc(layers["example_hat"], Vector2(head_center, top + 5.0), Vector2(head_width * 0.82, 2.6), Color(0.82, 0.82, 0.82))
	_disc(layers["example_hat"], Vector2(head_center, top + 2.0), Vector2(head_width * 0.5, 3.8), Color(0.97, 0.97, 0.97))
	for x in range(int(head_center - head_width * 0.5), int(head_center + head_width * 0.5) + 1):
		_put(layers["example_hat"], x, int(top + 4.0), Color(0.7, 0.7, 0.7)) # band
	_outline(layers["example_hat"])
	return layers

## The leftmost and rightmost x of the pixels of row `y` whose sort passes
## `keep` - (x, -1) when there's none.
func _extent(sorts: Dictionary, y: int, keep: Callable) -> Vector2:
	var left := SRC_CELL.x
	var right := -1
	for at: Vector2i in sorts:
		if at.y == y and keep.call(sorts[at]):
			left = mini(left, at.x)
			right = maxi(right, at.x)
	return Vector2(left, right)

func _disc(img: Image, center: Vector2, radius: Vector2, c: Color) -> void:
	for y in range(int(center.y - radius.y), int(center.y + radius.y) + 1):
		for x in range(int(center.x - radius.x), int(center.x + radius.x) + 1):
			if pow((x - center.x) / radius.x, 2) + pow((y - center.y) / radius.y, 2) <= 1.0:
				_put(img, x, y, c)

func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

## A 1 px outline around the drawn shapes, like the player's painting has.
func _outline(img: Image) -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break

## The cell borders, the feet line and the body's ghost.
func _guide(body: Image) -> Image:
	var guide := Image.create(body.get_width(), body.get_height(), false, Image.FORMAT_RGBA8)
	guide.fill(Color(0, 0, 0, 0))
	for y in body.get_height():
		for x in body.get_width():
			var c := body.get_pixel(x, y)
			if c.a > 0.1:
				guide.set_pixel(x, y, Color(0.6, 0.6, 0.6, 0.35))
	for row in ROWS:
		for column in COLUMNS:
			var origin := Vector2i(column * CELL.x, row * CELL.y)
			for x in CELL.x:
				guide.set_pixel(origin.x + x, origin.y, Color(0.5, 0.5, 0.5, 0.6))
				guide.set_pixel(origin.x + x, origin.y + FEET_Y, Color(1.0, 0.2, 0.2, 0.8))
			for y in CELL.y:
				guide.set_pixel(origin.x, origin.y + y, Color(0.5, 0.5, 0.5, 0.6))
				if y % 4 < 2:
					guide.set_pixel(origin.x + CELL.x / 2, origin.y + y, Color(1.0, 0.6, 0.1, 0.5))
	return guide
