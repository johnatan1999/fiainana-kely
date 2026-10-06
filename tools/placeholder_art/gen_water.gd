extends SceneTree
## Placeholder water tiles: two plain white 48 px tiles - water.gdshader
## paints the color itself, the texture only gives the shape. Tile (0, 0) is
## shallow paddy water (walkable), tile (1, 0) deep water (solid, see
## water_tileset.tres).
func _init():
	var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.save_png("res://assets/tileset/water_placeholder.png")
	print("water_placeholder.png written")
	quit()
