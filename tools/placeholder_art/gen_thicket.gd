extends SceneTree
## Placeholder forest thicket: clumps of dense foliage, seen from above at
## the game's 3/4 angle, one per wall cell of the forest (ThicketLayer, see
## tools/build_forest.gd). assets/tileset/thicket.png: 10 variants side by
## side, cells of 96 x 96 - twice a ground cell, so neighbouring clumps
## overlap and the wall reads as one mass of leaves. 0-5 big clumps (the
## walls' inside), 6-9 smaller, rounder ones (their edges and corners, so a
## wall's outline isn't square). The clump's foot (where it meets the
## ground, a dark shadow) is on y = 84; it's centered.
##   godot --headless --path . --script res://tools/placeholder_art/gen_thicket.gd
const CELL := 96
const VARIANTS := 10
## From this variant on, the clumps are smaller.
const SMALL_FROM := 6
const FOOT := 84.0
const OUTLINE := Color(0.06, 0.1, 0.07)
const SHADOW := Color(0.04, 0.08, 0.05, 0.55)
## Leaves, darkest to lightest: a blue-green like the eucalyptus, and a
## deeper green like the mango trees.
const PALETTES := [
	[Color(0.09, 0.2, 0.16), Color(0.13, 0.3, 0.24), Color(0.2, 0.42, 0.33), Color(0.33, 0.55, 0.42)],
	[Color(0.08, 0.2, 0.1), Color(0.13, 0.31, 0.15), Color(0.22, 0.44, 0.2), Color(0.38, 0.58, 0.3)],
]

var img: Image
var o := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _init():
	img = Image.create(CELL * VARIANTS, CELL, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in VARIANTS:
		o = Vector2(v * CELL, 0)
		rng.seed = 101 + v * 7
		_clump(PALETTES[v % 2], 0.72 if v >= SMALL_FROM else 1.0)
	_outline()
	img.save_png("res://assets/tileset/thicket.png")
	print("thicket.png written")
	quit()

func _px(x: float, y: float, c: Color) -> void:
	if x < 0 or y < 0 or x >= CELL or y >= CELL:
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

## A clump: its shadow on the ground, then leaf masses from the back
## (high, dark) to the front (low, light on top), then speckles of light.
## `size`: 1 for a big clump, less for a smaller one (around the same foot).
func _clump(palette: Array, size: float) -> void:
	_ellipse(48, FOOT, 44 * size, 10 * size, SHADOW)
	var blobs := []
	var top := FOOT - 62.0 * size
	for i in 9:
		var x := 48.0 + rng.randf_range(-32, 32) * size
		var y := rng.randf_range(top, FOOT - 18.0 * size)
		var r := rng.randf_range(15, 24) * size
		blobs.append([x, y, r])
	# Always a full base: the clump fills its cell and meets its neighbours.
	blobs.append([48.0 - 18.0 * size, FOOT - 22.0 * size, 22 * size])
	blobs.append([48.0 + 18.0 * size, FOOT - 22.0 * size, 22 * size])
	blobs.append([48, FOOT - 40.0 * size, 26 * size])
	blobs.sort_custom(func(a, b): return a[1] < b[1])
	for blob in blobs:
		var x: float = blob[0]
		var y: float = blob[1]
		var r: float = blob[2]
		_ellipse(x, y + 3, r, r * 0.85, palette[0])
		_ellipse(x, y, r * 0.95, r * 0.8, palette[1])
		_ellipse(x - r * 0.2, y - r * 0.25, r * 0.6, r * 0.45, palette[2])
		_ellipse(x - r * 0.3, y - r * 0.4, r * 0.25, r * 0.18, palette[3])
	# Leafy edges: small tufts where the clump meets the air.
	for i in 140:
		var x := rng.randf_range(12, 84)
		var y := rng.randf_range(6, 74)
		if not _near_edge(x, y):
			continue
		var r := rng.randf_range(3.5, 7.0)
		var shade: Color = palette[rng.randi_range(1, 2)]
		_ellipse(x, y, r, r * 0.8, shade)
		_ellipse(x - r * 0.3, y - r * 0.3, r * 0.4, r * 0.3, palette[3])
	for i in 26:
		var x := rng.randf_range(14, 82)
		var y := rng.randf_range(16, 70)
		if img.get_pixel(int(o.x + x), int(y)).a > 0.5:
			_px(x, y, palette[3] if rng.randf() < 0.6 else palette[0])

## Inside the leaves, but within a few pixels of their edge.
func _near_edge(x: float, y: float) -> bool:
	if img.get_pixel(int(o.x + x), int(y)).a < 0.9:
		return false
	for d: Vector2 in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, -6), Vector2(4, -4), Vector2(-4, -4)]:
		var p := Vector2(x, y) + d
		if p.x < 0 or p.y < 0 or p.x >= CELL or p.y >= CELL or img.get_pixel(int(o.x + p.x), int(p.y)).a < 0.9:
			return true
	return false

func _outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.6:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and p.x / CELL == x / CELL and src.get_pixel(p.x, p.y).a > 0.6:
					img.set_pixel(x, y, OUTLINE)
					break
