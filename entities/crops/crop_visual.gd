@tool
class_name CropVisual
extends Node2D

## In-field look of one crop, instanced by PlotView from CropData.visual_scene.
## Origin = the plot cell's bottom-center (the crop's "foot", also its y-sort
## point): place every stage relative to it in the editor, where the cell
## outline is drawn as a guide.
##
## Children named Seed / Sprout / Growing / Mature (any Node2D) are the
## stages - PlotView shows exactly one.
##
## Sprites need no offset: each stage's Sprite2D is anchored automatically by
## the bottom-center of its image (its region, on a sprite sheet) onto the
## foot. The art convention that makes it work, for every crop: in the
## sheet, the plant stands on the bottom edge of its cell, centered
## horizontally. Scale sets its size; `position` can still nudge one sprite
## if its art breaks the convention. A missing stage falls back to the
## closest earlier one. Collision shapes under a stage are only active while
## that stage is shown, so solidity is per stage: put a StaticBody2D under
## Growing and Mature to make the crop block from Growing on.

## Wind sway + leaning away from the player (crop_sway.gdshader), shared by
## every crop. Its offsets assume the bottom-center anchoring below.
const SWAY_MATERIAL := preload("res://entities/crops/crop_sway_material.tres")

## Indexed by CropState.Stage.
const STAGE_NODE_NAMES := ["Seed", "Sprout", "Growing", "Mature"]
const EDITOR_GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.5)

func _ready() -> void:
	_anchor_sprites()
	# In game only: set in the editor, it would be saved into the crop scenes.
	if not Engine.is_editor_hint():
		_apply_sway()
	# In the editor, keep the anchoring live while regions are being picked.
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_anchor_sprites()

func _anchor_sprites() -> void:
	for stage_name in STAGE_NODE_NAMES:
		var stage := get_node_or_null(stage_name)
		if stage == null:
			continue
		for child in stage.get_children():
			var sprite := child as Sprite2D
			if sprite == null or sprite.texture == null:
				continue
			var height := sprite.region_rect.size.y if sprite.region_enabled else float(sprite.texture.get_height())
			var anchored := Vector2(0, -height / 2.0)
			# Only on change: in the editor, rewriting the same value every
			# frame would keep flagging the scene as modified.
			if not sprite.centered or sprite.offset != anchored:
				sprite.centered = true
				sprite.offset = anchored

func _apply_sway() -> void:
	for stage_name in STAGE_NODE_NAMES:
		var stage := get_node_or_null(stage_name)
		if stage == null:
			continue
		for child in stage.get_children():
			if child is Sprite2D and child.material == null:
				child.material = SWAY_MATERIAL

## Shows the node for `stage` (a CropState.Stage value), hides the others and
## returns it - or null if the scene has no stage node at or below `stage`.
func show_stage(stage: int) -> Node2D:
	var shown := _find_stage_node(stage)
	for stage_name in STAGE_NODE_NAMES:
		var node := get_node_or_null(stage_name) as Node2D
		if node:
			node.visible = node == shown
			_set_collisions_enabled(node, node == shown)
	return shown

func _find_stage_node(stage: int) -> Node2D:
	for i in range(stage, -1, -1):
		var node := get_node_or_null(STAGE_NODE_NAMES[i]) as Node2D
		if node:
			return node
	return null

## Hiding a node doesn't stop its physics bodies, so shapes are toggled
## explicitly. Deferred because plot_changed can fire mid physics step (e.g.
## during a save load), where toggling a shape directly isn't allowed.
func _set_collisions_enabled(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", not enabled)
		_set_collisions_enabled(child, enabled)

## Editor-only guide: the plot cell and the foot point, so stages can be
## placed by eye instead of by typing offsets.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(PlotView.CELL_TOP_LEFT, Vector2.ONE * PlotView.CELL_SIZE), EDITOR_GUIDE_COLOR, false, 1.0)
	draw_line(Vector2(-3, 0), Vector2(3, 0), EDITOR_GUIDE_COLOR, 1.0)
	draw_line(Vector2(0, -3), Vector2(0, 3), EDITOR_GUIDE_COLOR, 1.0)
