class_name PloughTeam
extends Node2D

## The zebu team at the plough, for the length of a furrow - pure
## presentation, built in code: FarmingController walks it plot by plot
## (walk_to) and tills each plot as the share reaches it, then sends it off
## (leave). Its origin is the share, on the ground; the two zebus pull ahead
## of it, side by side.
##
## The zebu sheet only has a side view (facing right): ploughing up or down,
## the team is shown side-on, facing the way the player last faced
## sideways.

signal arrived

const ZEBU_SHEET := preload("res://assets/sprites/animals/zebu.png")
const PROPS_SHEET := preload("res://assets/sprites/props/zebu_market.png")
const PLOUGH_REGION := Rect2(576, 0, 192, 192)
## Px/s - a slow, heavy walk.
const SPEED := 70.0
## Walking frame per this many px walked.
const STRIDE := 9.0
const FRAMES_WALK := 4
## The two zebus, from the share, facing right: one a little behind the
## other, so both show.
const ZEBU_OFFSETS := [Vector2(78, -8), Vector2(92, 6)]
const FADE_TIME := 0.4

var _zebus: Array[Sprite2D] = []
var _plough: Sprite2D
var _target := Vector2.ZERO
var _moving := false
var _walked := 0.0

## `coats`: the two zebus' colors (GrazingZebu.COATS); `facing_left`: which
## way they pull.
func setup(coats: Array, facing_left: bool) -> void:
	y_sort_enabled = true
	_plough = Sprite2D.new()
	_plough.texture = PROPS_SHEET
	_plough.region_enabled = true
	_plough.region_rect = PLOUGH_REGION
	_plough.scale = Vector2.ONE * 0.5
	_plough.offset = Vector2(0, -PLOUGH_REGION.size.y / 2.0)
	_plough.flip_h = facing_left
	_plough.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_plough)
	for i in ZEBU_OFFSETS.size():
		var zebu := Sprite2D.new()
		zebu.texture = ZEBU_SHEET
		zebu.hframes = 4
		zebu.vframes = 2
		zebu.scale = Vector2.ONE * 0.8
		zebu.offset = Vector2(0, -48)
		zebu.flip_h = facing_left
		zebu.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		zebu.self_modulate = GrazingZebu.COATS[coats[i % coats.size()]]
		var offset: Vector2 = ZEBU_OFFSETS[i]
		zebu.position = Vector2(-offset.x if facing_left else offset.x, offset.y)
		add_child(zebu)
		_zebus.append(zebu)

## Walks the share to `point` (global); `arrived` when it's there.
func walk_to(point: Vector2) -> void:
	_target = point
	_moving = true

func _process(delta: float) -> void:
	if not _moving:
		return
	var to_target := _target - global_position
	var step := SPEED * delta
	if to_target.length() <= step:
		global_position = _target
		_moving = false
		for zebu in _zebus:
			zebu.frame = 0
		arrived.emit()
		return
	global_position += to_target.normalized() * step
	_walked += step
	for i in _zebus.size():
		# Out of step with each other, like a real pair.
		_zebus[i].frame = (int(_walked / STRIDE) + i * 2) % FRAMES_WALK

## Freed with its zone mid-furrow: whoever awaits `arrived` must not hang.
func _exit_tree() -> void:
	if _moving:
		_moving = false
		arrived.emit()

func is_walking() -> bool:
	return _moving

## Unhitched: fades out and is gone.
func leave() -> void:
	_moving = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
