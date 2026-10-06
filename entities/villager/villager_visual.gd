@tool
class_name VillagerVisual
extends Node2D

## A villager's sprite, built from a VillagerLook: one Sprite2D for the body
## and one per layer, stacked, all showing the same frame - so clothes,
## hair... move with the body. The sheets share one grid (see
## gen_villager_base.gd):
##   columns: 0-1 idle, 2-5 walk     rows: down, left, right, up
## Origin = between the feet: put it at the villager's feet, under a
## y-sorted node. @tool: the look shows (and animates) in the editor too -
## set `facing` / `walking` in the inspector to check every direction.
##
## The villager's script drives it: `play(direction, moving)` each frame.

enum Facing { DOWN, LEFT, RIGHT, UP }

const CELL := Vector2i(128, 256)
const COLUMNS := 6
const ROWS := 4
const IDLE_FRAMES := [0, 1]
const WALK_FRAMES := [2, 3, 4, 5]
## Twice the on-screen density, like the rest of the art.
const ART_SCALE := 0.5
## Feet on y = 252 of the 256 px cell.
const FEET_Y := 252

@export var look: VillagerLook:
	set(value):
		if look != null and look.changed.is_connected(_rebuild):
			look.changed.disconnect(_rebuild)
		look = value
		if look != null:
			look.changed.connect(_rebuild)
		_rebuild()
@export var facing := Facing.DOWN
@export var walking := false
## Frames per second of each animation.
@export var idle_fps := 1.5
@export var walk_fps := 7.0

var _sprites: Array[Sprite2D] = []
var _time := 0.0

func _ready() -> void:
	_rebuild()

## `direction`: where the villager faces / walks (any length, zero keeps
## the current facing). Same rule as CharacterAnimator: the bigger axis wins.
func play(direction: Vector2, moving: bool) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
		else:
			facing = Facing.DOWN if direction.y > 0.0 else Facing.UP
	if moving != walking:
		walking = moving
		_time = 0.0

## The current cell (frame index on the sheets).
func get_frame() -> int:
	var frames: Array = WALK_FRAMES if walking else IDLE_FRAMES
	var fps := walk_fps if walking else idle_fps
	return int(facing) * COLUMNS + frames[int(_time * fps) % frames.size()]

func _process(delta: float) -> void:
	_time += delta
	var frame := get_frame()
	for sprite in _sprites:
		sprite.frame = frame

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	if look == null:
		return
	_add_layer(look.get_body(), look.skin_color)
	for layer in look.layers:
		if layer != null and layer.texture != null:
			_add_layer(layer.texture, layer.color)

## Created in code, never owned: nothing of it is saved in the scene.
func _add_layer(texture: Texture2D, color: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = COLUMNS
	sprite.vframes = ROWS
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	sprite.offset = Vector2(0, CELL.y / 2.0 - FEET_Y)
	sprite.self_modulate = color
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_sprites.append(sprite)
