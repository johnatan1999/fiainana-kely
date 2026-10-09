class_name FiresidePlayer
extends Node2D

## The player character crouched by the campfire of the home screen,
## warming up: breathing slowly, now and then shifting a little (two poses
## of the player's sheet). Its origin is where the feet are. Decor only.

const SHEET := preload("res://assets/sprites/characters/player/player2.png")
## Crouched poses of player2.png (64 x 128 cells), turned towards the fire
## on the right.
const POSES := [Rect2(320, 0, 64, 128), Rect2(384, 0, 64, 128)]
const SHIFT_EVERY := Vector2(2.5, 5.0)
const BREATH_PERIOD := 3.2

var _sprite: Sprite2D
var _shift_in := 0.0
var _t := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.region_rect = POSES[0]
	# The feet sit near the bottom of the cell.
	_sprite.offset = Vector2(0, -60)
	add_child(_sprite)
	_shift_in = randf_range(SHIFT_EVERY.x, SHIFT_EVERY.y)

func _process(delta: float) -> void:
	_t += delta
	# Breathing: the body rises a hair, from the feet.
	_sprite.scale = Vector2(1.0, 1.0 + 0.012 * sin(_t * TAU / BREATH_PERIOD))
	_shift_in -= delta
	if _shift_in <= 0.0:
		_shift_in = randf_range(SHIFT_EVERY.x, SHIFT_EVERY.y)
		_sprite.region_rect = POSES[1] if _sprite.region_rect == POSES[0] else POSES[0]
