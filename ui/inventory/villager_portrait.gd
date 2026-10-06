class_name VillagerPortrait
extends RefCounted

## A villager's portrait for the UI (the inventory's Villageois tab): head
## and shoulders, facing the camera, composed from their VillagerLook - the
## body tinted with the skin color, each layer with its own - exactly as
## VillagerVisual draws them in the world. Made once per look, then cached.

## The sheet cell used: row 0 (facing down), column 0 (standing).
const CELL := Rect2i(0, 0, 128, 256)
## The square kept around the head (px of the sheet).
const SIZE := 96
## Space kept above the top of the head.
const HEADROOM := 6

static var _cache: Dictionary = {} # VillagerLook -> ImageTexture

static func make(look: VillagerLook) -> Texture2D:
	if look == null:
		return null
	if _cache.has(look):
		return _cache[look]
	var portrait := Image.create(CELL.size.x, CELL.size.y, false, Image.FORMAT_RGBA8)
	portrait.fill(Color(0, 0, 0, 0))
	_add_layer(portrait, look.get_body(), look.skin_color)
	for layer in look.layers:
		if layer != null and layer.texture != null:
			_add_layer(portrait, layer.texture, layer.color)
	var used := portrait.get_used_rect()
	var top := maxi(0, used.position.y - HEADROOM)
	var left := clampi(used.get_center().x - SIZE / 2, 0, CELL.size.x - SIZE)
	var texture := ImageTexture.create_from_image(portrait.get_region(Rect2i(left, top, SIZE, SIZE)))
	_cache[look] = texture
	return texture

## Blends `texture`'s cell, multiplied by `tint`, over `into`.
static func _add_layer(into: Image, texture: Texture2D, tint: Color) -> void:
	var sheet := texture.get_image()
	if sheet == null:
		return
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var cell := sheet.get_region(CELL)
	for y in cell.get_height():
		for x in cell.get_width():
			var c := cell.get_pixel(x, y)
			if c.a > 0.0:
				cell.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a))
	into.blend_rect(cell, Rect2i(Vector2i.ZERO, CELL.size), Vector2i.ZERO)
