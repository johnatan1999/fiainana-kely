extends SceneTree
## Placeholder tall grass: one row of 6 tufts, 16 x 32 each, standing on the
## bottom edge (TallGrassLayer's convention: a single row, so the shader
## reads a vertex's height from UV.y). 4 green, 2 dry, three heights.
func _init():
	var w := 16
	var h := 32
	var img := Image.create(w * 6, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bases := [Color(0.23, 0.42, 0.14), Color(0.28, 0.46, 0.16), Color(0.36, 0.48, 0.18)]
	for t in 6:
		var blades := rng.randi_range(7, 11)
		var tall: float = 0.55 + 0.45 * (float(t % 3) / 2.0)
		var dry := t >= 4
		for b in blades:
			var x0: float = t * w + rng.randf_range(2.5, 13.5)
			var height: float = rng.randf_range(0.55, 1.0) * (h - 2) * tall
			var lean: float = rng.randf_range(-4.0, 4.0)
			var base: Color = bases[rng.randi() % bases.size()]
			if dry:
				base = Color(0.55, 0.5, 0.25).lerp(base, 0.25)
			var tip: Color = base.lightened(0.45)
			for s in int(height):
				var k: float = float(s) / maxf(1.0, height)
				var x: float = x0 + lean * k * k
				var y: int = h - 1 - s
				var c: Color = base.lerp(tip, k)
				var px: int = int(round(x))
				if px >= t * w and px < (t + 1) * w and y >= 0:
					img.set_pixel(px, y, c)
					if k < 0.35 and px + 1 < (t + 1) * w:
						img.set_pixel(px + 1, y, c.darkened(0.15))
	img.save_png("res://assets/tileset/tall_grass_placeholder.png")
	print("tall_grass_placeholder.png written")
	quit()
