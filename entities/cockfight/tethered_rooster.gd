class_name TetheredRooster
extends Node2D

## The player's fighting rooster at the farm, tied by a cord to its stake
## (the way fighting cocks are kept): it struts and pecks around the stake,
## never further than the cord. A grain bubble over its head until it's fed
## today. Only shows the rooster and passes the player's interaction on -
## CockfightManager creates it at the zone's "RoosterStake" marker and
## decides what the interaction does. Built in code.

signal interacted

const FRAMES := preload("res://data/rooster.tres")
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
## How far the cord lets it go, and how it moves.
const TETHER := 34.0
const SPEED := 24.0
const PAUSE := Vector2(1.5, 4.5)
const SCALE := 0.55
## The cord is tied this high on the stake.
const STAKE_TOP := Vector2(0, -14)
const CORD_COLOR := Color(0.62, 0.52, 0.34)
const STAKE_COLOR := Color(0.42, 0.28, 0.16)

var _sprite: AnimatedSprite2D
var _bubble: NeedBubble
var _interactable: InteractableComponent
var _target := Vector2.ZERO
var _pause := 0.0

func _ready() -> void:
	y_sort_enabled = true
	var stake := _Stake.new()
	stake.name = "Stake"
	add_child(stake)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Rooster"
	_sprite.sprite_frames = FRAMES
	_sprite.scale = Vector2.ONE * SCALE
	# Feet on the node's position (the frames are centered 64 px cells).
	_sprite.offset = Vector2(0, -32)
	_sprite.position = Vector2(TETHER * 0.6, 6)
	_sprite.play("idle_down")
	add_child(_sprite)
	_bubble = NeedBubble.new()
	_bubble.position = Vector2(0, -60)
	_sprite.add_child(_bubble)
	_bubble.scale = Vector2.ONE / SCALE
	_interactable = INTERACTABLE.instantiate()
	_interactable.name = "InteractableComponent"
	add_child(_interactable)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var box := RectangleShape2D.new()
	box.size = Vector2(TETHER * 2.6, TETHER * 1.8)
	area.shape = box
	area.position = Vector2(0, -8)
	_interactable.interacted.connect(interacted.emit)
	_pause = randf_range(PAUSE.x, PAUSE.y)
	_target = _sprite.position

## What interacting does ("[E] <prompt>", already translated), and whether
## it still waits for its grain today.
func show_state(prompt: String, hungry: bool) -> void:
	_interactable.prompt_message = prompt
	_bubble.set_needs(hungry, false, false)

## Where the rooster itself is (global).
func get_rooster_position() -> Vector2:
	return _sprite.global_position

func _process(delta: float) -> void:
	queue_redraw() # the cord follows the rooster
	var to_target := _target - _sprite.position
	if to_target.length() > 1.0:
		_sprite.position += to_target.normalized() * minf(SPEED * delta, to_target.length())
		_play("walk", to_target)
		return
	_pause -= delta
	if _pause > 0.0:
		return
	_pause = randf_range(PAUSE.x, PAUSE.y)
	if randf() < 0.35:
		_play("idle", Vector2.DOWN)
		return
	var angle := randf() * TAU
	_target = Vector2(cos(angle), sin(angle) * 0.6) * randf_range(TETHER * 0.4, TETHER)
	_target.y = maxf(_target.y, 2.0) # in front of the stake, where it's seen

func _play(kind: String, direction: Vector2) -> void:
	var facing := "right" if direction.x > 0.0 else "left"
	if absf(direction.y) > absf(direction.x):
		facing = "down" if direction.y > 0.0 else "up"
	var animation := "%s_%s" % [kind, facing]
	if _sprite.animation != animation:
		_sprite.play(animation)

func _draw() -> void:
	# The cord, from the top of the stake to the rooster's leg, sagging.
	var end := _sprite.position + Vector2(0, -4)
	var middle := (STAKE_TOP + end) / 2.0 + Vector2(0, 6)
	draw_polyline(PackedVector2Array([STAKE_TOP, middle, end]), CORD_COLOR, 1.5, true)

## The stake, sorted on its own (the rooster passes in front or behind).
class _Stake extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-2.5, -18, 5, 18), TetheredRooster.STAKE_COLOR)
		draw_rect(Rect2(-3.5, -20, 7, 3), TetheredRooster.STAKE_COLOR.darkened(0.25))
