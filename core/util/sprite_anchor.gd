@tool
class_name SpriteAnchor
extends RefCounted

## The art convention shared by crops, trees and props: an object stands on
## its image's bottom edge, centered - so its Sprite2D is anchored by the
## bottom-center of its image (its region, on a sprite sheet) onto its own
## position, and needs no offset by hand. The node's origin is then where
## the object touches the ground - its y-sort point.
##
## @tool: CropVisual, TreeVisual and Prop also anchor live in the editor.

## Anchors every Sprite2D directly under `parent`.
static func anchor_children(parent: Node) -> void:
	for child in parent.get_children():
		if child is Sprite2D:
			anchor(child)

static func anchor(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var height := sprite.region_rect.size.y if sprite.region_enabled else float(sprite.texture.get_height())
	var anchored := Vector2(0, -height / 2.0)
	# Only on change: in the editor, rewriting the same value every frame
	# would keep flagging the scene as modified.
	if not sprite.centered or sprite.offset != anchored:
		sprite.centered = true
		sprite.offset = anchored
