extends SceneTree
## Rice, 4 growth stages side by side in 96 x 128 cells, standing on the
## bottom edge (CropVisual's anchoring convention). Drawn at twice the
## on-screen density, like voly.png - the scene scales it by 0.5.
const CW := 96
const CH := 128
const OUTLINE := Color(0.13, 0.2, 0.07)
var img: Image
var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 7
	img = Image.create(CW * 4, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Seed: three young transplanted seedlings.
	_mound(0, 14)
	_clump(0, 3, Vector2(14, 20), 4.0, Color(0.36, 0.6, 0.2), Color(0.62, 0.82, 0.38), 2.0)
	# Sprout: a young clump.
	_mound(1, 18)
	_clump(1, 7, Vector2(26, 42), 9.0, Color(0.3, 0.55, 0.18), Color(0.58, 0.8, 0.32), 2.5)
	# Growing: dense, deep green.
	_mound(2, 22)
	_clump(2, 15, Vector2(50, 82), 20.0, Color(0.2, 0.45, 0.14), Color(0.48, 0.72, 0.26), 3.0)
	# Mature: yellowing leaves under heavy golden panicles.
	_mound(3, 22)
	_clump(3, 13, Vector2(46, 72), 20.0, Color(0.42, 0.5, 0.16), Color(0.82, 0.78, 0.36), 3.0)
	for i in 6:
		_panicle(3, rng.randf_range(-14, 14), rng.randf_range(76, 96), -1.0 if i % 2 == 0 else 1.0)
	_outline()
	img.save_png("res://assets/sprites/crops/rice.png")
	print("rice.png written")
	quit()

func _put(p: Vector2, c: Color) -> void:
	var x := int(round(p.x))
	var y := int(round(p.y))
	if x >= 0 and y >= 0 and x < img.get_width() and y < CH:
		img.set_pixel(x, y, c)

## Small wet-mud mound at the foot.
func _mound(stage: int, half_width: float) -> void:
	var cx: float = stage * CW + CW / 2.0
	for x in range(-int(half_width), int(half_width) + 1):
		var h := int(5.0 * sqrt(maxf(0.0, 1.0 - pow(x / half_width, 2))))
		for y in h:
			_put(Vector2(cx + x, CH - 1 - y), Color(0.3, 0.2, 0.12).lerp(Color(0.42, 0.29, 0.17), float(y) / 5.0))

## `count` leaves from the foot, heights in [h.x, h.y], fanning out by `spread`.
func _clump(stage: int, count: int, h: Vector2, spread: float, base: Color, tip: Color, width: float) -> void:
	var cx: float = stage * CW + CW / 2.0
	for i in count:
		var k: float = (float(i) / maxf(1.0, count - 1)) * 2.0 - 1.0 # -1..1, left to right
		var height: float = rng.randf_range(h.x, h.y) * (1.0 - absf(k) * 0.25)
		var lean: float = k * spread + rng.randf_range(-3, 3)
		var foot := Vector2(cx + k * width * 2.0, CH - 4)
		var steps := int(height * 1.4)
		for s in steps:
			var t: float = float(s) / steps
			# Leaves arch outward and droop a little at the tip.
			var p: Vector2 = foot + Vector2(lean * t * t * 1.3, -height * t + maxf(0.0, t - 0.75) * absf(lean) * 0.6)
			var w: float = lerpf(width, 1.0, t)
			var c: Color = base.lerp(tip, t)
			for o in range(int(-w / 2.0), int(ceil(w / 2.0))):
				_put(p + Vector2(o, 0), c.darkened(0.12) if o < 0 else c)

## A grain head: a stem rising from the clump then bowing to `side`, grains along it.
func _panicle(stage: int, x_offset: float, height: float, side: float) -> void:
	var cx: float = stage * CW + CW / 2.0 + x_offset
	var top := Vector2(cx, CH - 4 - height)
	var stem_base := Vector2(cx, CH - 4 - height * 0.55)
	for s in 30:
		_put(stem_base.lerp(top, s / 30.0), Color(0.55, 0.55, 0.22))
	for s in 16:
		var t: float = s / 16.0
		var p: Vector2 = top + Vector2(side * 14.0 * t, 18.0 * t * t)
		_put(p, Color(0.6, 0.5, 0.2))
		if s % 2 == 0:
			for g: Vector2 in [Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_put(p + g + Vector2(side, 1.0), Color(0.93, 0.78, 0.32) if g != Vector2(0, 1) else Color(0.78, 0.6, 0.2))

## One-pixel dark outline around everything drawn, like the other crops.
func _outline() -> void:
	var src := img.duplicate()
	for y in CH:
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < CH and src.get_pixel(n.x, n.y).a > 0.5 and (n.x / CW) == (x / CW):
					img.set_pixel(x, y, OUTLINE)
					break
