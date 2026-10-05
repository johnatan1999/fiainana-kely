@tool
class_name TreeVisual
extends Node2D

## Look of one tree species, instanced by WorldTree from TreeData.visual_scene
## - the tree counterpart of CropVisual. Origin = the foot of the trunk (the
## tree's y-sort point): place everything relative to it in the editor, where
## the foot is marked.
##
## Children named Bare / Fruiting (any Node2D) are the states - WorldTree
## shows exactly one. A missing state falls back to the closest earlier one,
## so a decorative tree only needs Bare.
##
## Sprites need no offset, same convention as crops: each Sprite2D directly
## under a state is anchored by the bottom-center of its image (its region,
## on a sprite sheet) onto its own position. A one-piece tree sits at (0, 0);
## a tree split in parts puts its canopy sprite higher (its position is where
## the canopy's bottom edge goes).
##
## Optional nodes, by name:
## - Trunk (StaticBody2D, at the root): what blocks the player - the trunk
##   only, so they can walk behind the canopy.
## - FadeArea (Area2D, at the root): while the player's body is inside, the
##   foliage fades so they stay visible. Cover the area hidden by the canopy.
## - Canopy (any CanvasItem, anywhere): what fades. None = the whole tree fades.
##
## No art yet (no Sprite2D with a texture in the shown state): a placeholder
## tree is drawn instead, fruits included in Fruiting - so a species is
## playable, and placeable, before its sprites exist.

enum State { BARE, FRUITING }
## Indexed by State.
const STATE_NODE_NAMES := ["Bare", "Fruiting"]

## Alpha of the foliage while the player is under it.
const FADE_ALPHA := 0.45
const FADE_DURATION := 0.2

const PLACEHOLDER_TRUNK_SIZE := Vector2(14, 44)
const PLACEHOLDER_CANOPY_RADIUS := 42.0
const PLACEHOLDER_TRUNK_COLOR := Color(0.45, 0.3, 0.18)
## Fixed spots (fractions of the canopy radius) so the fruit never jumps around.
const PLACEHOLDER_FRUIT_SPOTS := [
	Vector2(-0.55, 0.1), Vector2(-0.2, 0.45), Vector2(0.15, -0.3),
	Vector2(0.5, 0.25), Vector2(0.3, 0.6), Vector2(-0.45, -0.35),
]
const EDITOR_GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.5)

## Placeholder colors only - ignored once the state has sprites, so species
## still look different from each other before their art exists.
@export var placeholder_canopy_color := Color(0.2, 0.5, 0.22):
	set(value):
		placeholder_canopy_color = value
		queue_redraw()
@export var placeholder_fruit_color := Color(0.98, 0.65, 0.12):
	set(value):
		placeholder_fruit_color = value
		queue_redraw()
## Placeholder height, as a multiple of the default one.
@export_range(0.5, 3.0, 0.05) var placeholder_scale := 1.0:
	set(value):
		placeholder_scale = value
		queue_redraw()
## The state previewed in the editor (WorldTree drives it in game).
@export var preview_state: State = State.FRUITING:
	set(value):
		preview_state = value
		if Engine.is_editor_hint() and is_node_ready():
			show_state(value)

var _state: State = State.BARE
var _fade_tween: Tween

func _ready() -> void:
	_anchor_sprites()
	show_state(preview_state if Engine.is_editor_hint() else _state)
	# In the editor, keep the anchoring live while regions are being picked.
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_anchor_sprites()
	queue_redraw() # a texture may just have been assigned: drop the placeholder

## Shows the node for `state`, hides the others.
func show_state(state: State) -> void:
	_state = state
	var shown := _find_state_node(state)
	for state_name in STATE_NODE_NAMES:
		var node := get_node_or_null(state_name) as CanvasItem
		if node:
			node.visible = node == shown
	queue_redraw()

func get_fade_area() -> Area2D:
	return get_node_or_null("FadeArea") as Area2D

## Fades the foliage (the Canopy nodes, or the whole tree) in or out.
func set_faded(faded: bool) -> void:
	var targets := find_children("Canopy", "CanvasItem", true, false)
	if targets.is_empty():
		targets = [self]
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel()
	for target in targets:
		_fade_tween.tween_property(target, "modulate:a", FADE_ALPHA if faded else 1.0, FADE_DURATION)

func _find_state_node(state: int) -> Node2D:
	for i in range(state, -1, -1):
		var node := get_node_or_null(STATE_NODE_NAMES[i]) as Node2D
		if node:
			return node
	return null

func _anchor_sprites() -> void:
	for state_name in STATE_NODE_NAMES:
		var state := get_node_or_null(state_name)
		if state == null:
			continue
		for child in state.get_children():
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

## Whether the shown state has real art (a Sprite2D with a texture).
func _has_art() -> bool:
	var shown := _find_state_node(_state)
	if shown == null:
		return false
	for sprite in shown.find_children("*", "Sprite2D", true, false):
		if sprite.texture != null:
			return true
	return false

func _draw() -> void:
	if not _has_art():
		_draw_placeholder(_state == State.FRUITING)
	if Engine.is_editor_hint():
		draw_line(Vector2(-4, 0), Vector2(4, 0), EDITOR_GUIDE_COLOR, 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), EDITOR_GUIDE_COLOR, 1.0)

func _draw_placeholder(with_fruit: bool) -> void:
	var r := PLACEHOLDER_CANOPY_RADIUS * placeholder_scale
	var trunk := PLACEHOLDER_TRUNK_SIZE * placeholder_scale
	var center := Vector2(0, -(trunk.y + r * 0.55))
	# Ground shadow, flattened.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, r * 0.8, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-trunk.x / 2.0, -trunk.y - r * 0.3, trunk.x, trunk.y + r * 0.3), PLACEHOLDER_TRUNK_COLOR)
	var shade := placeholder_canopy_color.darkened(0.25)
	draw_circle(center + Vector2(-r * 0.5, r * 0.2), r * 0.72, shade)
	draw_circle(center + Vector2(r * 0.5, r * 0.2), r * 0.72, shade)
	draw_circle(center, r * 0.85, placeholder_canopy_color)
	draw_circle(center + Vector2(-r * 0.25, -r * 0.3), r * 0.45, placeholder_canopy_color.lightened(0.15))
	if with_fruit:
		for spot in PLACEHOLDER_FRUIT_SPOTS:
			var p: Vector2 = center + spot * r
			draw_circle(p, 4.5, placeholder_fruit_color.darkened(0.3))
			draw_circle(p + Vector2(-0.8, -0.8), 3.5, placeholder_fruit_color)
