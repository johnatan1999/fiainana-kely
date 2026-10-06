@tool
class_name Prop
extends Node2D

## A piece of village scenery (jar, woodpile, cart...). Origin = where it
## touches the ground - its y-sort point - like crops and trees.
##
## Every direct Sprite2D child is anchored bottom-center on its own position
## (SpriteAnchor - the art convention shared with crops and trees), so
## sprites need no offset. A StaticBody2D child, if any, is what blocks the
## player: keep it to the base, so the player can walk behind tall props.

func _ready() -> void:
	_anchor_sprites()
	# In the editor, keep the anchoring live while regions are being picked.
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_anchor_sprites()

func _anchor_sprites() -> void:
	SpriteAnchor.anchor_children(self)
