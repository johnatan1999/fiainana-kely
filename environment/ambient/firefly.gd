class_name Firefly
extends Node2D

## A firefly drifting slowly around its spot, its glow pulsing - only out
## at night (AmbientLife shows it). Unshaded, so it stays bright in the dark.

const COLOR := Color(0.85, 1.0, 0.45)
const WANDER_RADIUS := 60.0
const SPEED := 14.0

var _home: Vector2
var _target: Vector2
var _t := 0.0
var _pulse_speed := 2.0
var _rng: RandomNumberGenerator

func setup(home: Vector2, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_home = home
	position = home
	_target = home
	_t = rng.randf() * 10.0
	_pulse_speed = rng.randf_range(1.4, 2.6)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 3

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if position.distance_to(_target) < 4.0:
		_target = _home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * WANDER_RADIUS
	position = position.move_toward(_target, SPEED * delta)
	queue_redraw()

func _draw() -> void:
	var glow := pow(maxf(0.0, sin(_t * _pulse_speed)), 3.0)
	var lift := Vector2(0, -10 + sin(_t * 1.3) * 3.0)
	draw_circle(lift, 4.0, Color(COLOR, 0.18 * glow))
	draw_circle(lift, 1.5, Color(COLOR.lightened(0.3), 0.25 + 0.75 * glow))
