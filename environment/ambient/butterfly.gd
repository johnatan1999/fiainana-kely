class_name Butterfly
extends Node2D

## One butterfly fluttering around its home spot, a little shadow on the
## ground under it. It veers away when the player comes close. Drawn in code
## (wings flapping by squashing them) - see AmbientLife.

const PALETTES := [
	[Color(0.98, 0.6, 0.12), Color(0.35, 0.18, 0.05)], # orange
	[Color(0.98, 0.88, 0.3), Color(0.4, 0.32, 0.08)], # yellow
	[Color(0.96, 0.96, 0.92), Color(0.45, 0.45, 0.45)], # white
	[Color(0.35, 0.6, 0.95), Color(0.1, 0.15, 0.35)], # blue
]
const WANDER_RADIUS := 80.0
const SPEED := 32.0
const FLEE_SPEED := 95.0
const FLEE_DISTANCE := 56.0
## Flying height above its shadow, in px.
const HEIGHT := 18.0

var _home: Vector2
var _target: Vector2
var _velocity := Vector2.ZERO
var _t := 0.0
var _flap_speed := 16.0
var _colors: Array
var _rng: RandomNumberGenerator
var _player: Node2D

func setup(home: Vector2, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_home = home
	position = home
	_target = home
	_t = rng.randf() * 10.0
	_flap_speed = rng.randf_range(13.0, 19.0)
	_colors = PALETTES[rng.randi() % PALETTES.size()]
	# Flying: above the y-sorted ground (trees, props, the player).
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var speed := SPEED
	if _player and to_global(Vector2.ZERO).distance_to(_player.global_position) < FLEE_DISTANCE:
		var away := (to_global(Vector2.ZERO) - _player.global_position).normalized()
		_target = position + away * 70.0
		speed = FLEE_SPEED
	elif position.distance_to(_target) < 6.0 or _rng.randf() < delta * 0.4:
		_target = _home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * WANDER_RADIUS
	# Erratic flight: steer towards the target with a sideways wobble.
	var desired := (_target - position).normalized() * speed
	desired += desired.orthogonal() * sin(_t * 5.0) * 0.6
	_velocity = _velocity.lerp(desired, minf(1.0, delta * 3.0))
	position += _velocity * delta
	queue_redraw()

func _draw() -> void:
	var height := HEIGHT + sin(_t * 2.7) * 4.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	var body := Vector2(0, -height)
	var open := absf(sin(_t * _flap_speed)) # 0 = wings shut, 1 = spread
	var wing: Color = _colors[0]
	var edge: Color = _colors[1]
	for side in [-1.0, 1.0]:
		var w := 1.0 + 4.0 * open
		draw_rect(Rect2(body + Vector2(side * 0.5 - (w if side < 0 else 0.0), -4), Vector2(w, 4)), wing)
		draw_rect(Rect2(body + Vector2(side * 0.5 - (w * 0.7 if side < 0 else 0.0), 0), Vector2(w * 0.7, 3)), wing.darkened(0.15))
		draw_rect(Rect2(body + Vector2(side * (w + 0.5) - (1.0 if side < 0 else 0.0), -4), Vector2(1, 4)), edge)
	draw_rect(Rect2(body + Vector2(-0.5, -4), Vector2(1, 7)), edge)
