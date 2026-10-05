@tool
class_name Prop
extends Node2D

## A piece of village scenery (jar, woodpile, cart...). Origin = where it
## touches the ground - its y-sort point - like crops and trees.
##
## Same art convention as CropVisual: the object stands on its image's
## bottom edge, and every direct Sprite2D child is anchored by the
## bottom-center of its image (its region, on a sheet) onto its own position,
## so sprites need no offset. A StaticBody2D child, if any, is what blocks the
## player: keep it to the base, so the player can walk behind tall props.

func _ready() -> void:
	_anchor_sprites()
	# In the editor, keep the anchoring live while regions are being picked.
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_anchor_sprites()

func _anchor_sprites() -> void:
	for child in get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var height := sprite.region_rect.size.y if sprite.region_enabled else float(sprite.texture.get_height())
		var anchored := Vector2(0, -height / 2.0)
		# Only on change: in the editor, rewriting the same value every frame
		# would keep flagging the scene as modified.
		if not sprite.centered or sprite.offset != anchored:
			sprite.centered = true
			sprite.offset = anchored
