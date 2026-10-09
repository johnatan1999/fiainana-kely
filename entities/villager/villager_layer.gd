@tool
class_name VillagerLayer
extends Resource

## One layer of a villager's look - a shirt, a lamba, hair, a hat... A sheet
## on the exact same grid as the base body (base_body.png: 6 columns x 4
## rows of 128 x 256), with only the garment drawn, transparent elsewhere.
## Drawn light (white / light grey), `color` tints it: one sheet, many colors.

@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
@export var color := Color.WHITE:
	set(value):
		color = value
		emit_changed()
