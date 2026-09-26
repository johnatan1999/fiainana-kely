@tool
class_name CropVisual
extends Node2D

## In-field look of one crop, instanced by PlotView from CropData.visual_scene.
## Origin = the plot cell's bottom-center (the crop's "foot", also its y-sort
## point): place every stage relative to it in the editor, where the cell
## outline is drawn as a guide.
##
## Children named Seed / Sprout / Growing / Mature (any Node2D) are the
## stages - PlotView shows exactly one. A missing stage falls back to the
## closest earlier one. Collision shapes under a stage are only active while
## that stage is shown, so solidity is per stage: put a StaticBody2D under
## Growing and Mature to make the crop block from Growing on.

## Indexed by CropState.Stage.
const STAGE_NODE_NAMES := ["Seed", "Sprout", "Growing", "Mature"]
const EDITOR_GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.5)

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
