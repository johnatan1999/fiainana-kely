class_name AmbientBird
extends Node2D

## A small bird, drawn in code. Two lives:
## - on the ground (setup_ground): pecks, hops about, and flies off when the
##   player comes close - up and away, fading out - then lands again
##   somewhere else a little later (AmbientLife picks the spot);
## - in a flock (setup_flock): crosses the sky high above, its shadow sliding
##   over the ground, and frees itself once out of the area.
## Its origin is its shadow, on the ground: it y-sorts by where it stands,
## and flying is drawing the body `_height` px above it.

## Malagasy countryside birds. size: body scale; neck: egret's long neck.
const SPECIES := {
	"fody": {"body": Color(0.86, 0.16, 0.12), "wing": Color(0.45, 0.25, 0.15), "beak": Color(0.25, 0.2, 0.2), "size": 1.0, "neck": 0.0},
	"myna": {"body": Color(0.45, 0.3, 0.2), "wing": Color(0.2, 0.14, 0.1), "beak": Color(0.95, 0.8, 0.2), "size": 1.25, "neck": 0.0},
	"egret": {"body": Color(0.97, 0.97, 0.94), "wing": Color(0.85, 0.85, 0.82), "beak": Color(0.95, 0.75, 0.2), "size": 1.7, "neck": 5.0},
}
enum State { GROUND, FLEEING, AWAY, LANDING, FLOCK }

const FLEE_DISTANCE := 72.0
const FLEE_SPEED := 150.0
const FLOCK_SPEED := 110.0
const FLOCK_HEIGHT := 150.0
const RESPAWN_DELAY := Vector2(8.0, 20.0)

var _state := State.GROUND
var _species: Dictionary
var _life: AmbientLife
var _rng: RandomNumberGenerator
var _player: Node2D
var _height := 0.0
var _velocity := Vector2.ZERO
var _facing := 1.0
var _t := 0.0
var _timer := 0.0
var _peck := 0.0 # > 0 while the head is down
var _bounds: Rect2

func setup_ground(species: String, life: AmbientLife, rng: RandomNumberGenerator) -> void:
	_species = SPECIES.get(species, SPECIES["fody"])
	_life = life
	_rng = rng
	position = life.pick_landing_spot()
	_facing = 1.0 if rng.randf() < 0.5 else -1.0
	_timer = rng.randf_range(0.3, 2.0)
	_t = rng.randf() * 5.0

func setup_flock(species: String, start: Vector2, direction: Vector2, bounds: Rect2, rng: RandomNumberGenerator) -> void:
	_species = SPECIES.get(species, SPECIES["fody"])
	_rng = rng
	_state = State.FLOCK
	position = start
	_velocity = direction * FLOCK_SPEED
	_facing = signf(direction.x)
	_height = FLOCK_HEIGHT
	_bounds = bounds
	_t = rng.randf() * 5.0
	# High in the sky: over the trees too.
	z_index = 10

func _process(delta: float) -> void:
	_t += delta
	match _state:
		State.GROUND:
			_on_ground(delta)
		State.FLEEING:
			position += _velocity * delta
			_height = minf(_height + 90.0 * delta, 80.0)
			_timer -= delta
			modulate.a = clampf(_timer / 0.6, 0.0, 1.0)
			if _timer <= 0.0:
				_state = State.AWAY
				visible = false
				_timer = _rng.randf_range(RESPAWN_DELAY.x, RESPAWN_DELAY.y)
		State.AWAY:
			_timer -= delta
			if _timer <= 0.0:
				_start_landing()
		State.LANDING:
			_height = maxf(0.0, _height - 60.0 * delta)
			modulate.a = minf(1.0, modulate.a + delta * 2.0)
			if _height <= 0.0:
				_state = State.GROUND
				z_index = 0
				_timer = _rng.randf_range(0.5, 1.5)
		State.FLOCK:
			position += _velocity * delta
			if not _bounds.has_point(position):
				queue_free()
	queue_redraw()

func _on_ground(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		var to_bird := global_position - _player.global_position
		if to_bird.length() < FLEE_DISTANCE * _species["size"]:
			_take_off(to_bird.normalized())
			return
	_peck = maxf(0.0, _peck - delta)
	_timer -= delta
	if _height > 0.0: # mid-hop
		_height = maxf(0.0, _height - 40.0 * delta)
		position += _velocity * delta
	if _timer > 0.0:
		return
	_timer = _rng.randf_range(0.4, 1.8)
	if _rng.randf() < 0.55:
		_peck = 0.25
	else:
		# A hop (an egret takes a slow step instead).
		_facing = 1.0 if _rng.randf() < 0.5 else -1.0
		var step := 8.0 if _species["neck"] == 0.0 else 4.0
		_velocity = Vector2(_facing * step, _rng.randf_range(-3.0, 3.0)) / 0.2
		_height = 3.0 if _species["neck"] == 0.0 else 0.5

func _take_off(away: Vector2) -> void:
	_state = State.FLEEING
	if away == Vector2.ZERO:
		away = Vector2.UP
	_velocity = (away + Vector2(0, -0.3)).normalized() * FLEE_SPEED
	_facing = signf(_velocity.x) if _velocity.x != 0.0 else _facing
	_timer = 1.4
	# Airborne: over the props and trees around it.
	z_index = 4

func _start_landing() -> void:
	var player_pos := _player.global_position - _life.global_position if is_instance_valid(_player) else Vector2.INF
	position = _life.pick_landing_spot(player_pos, 220.0)
	_height = 60.0
	modulate.a = 0.0
	visible = true
	_state = State.LANDING

func _draw() -> void:
	var s: float = _species["size"]
	var flying := _state != State.GROUND or _height > 4.0
	# Shadow, on the ground - smaller and fainter the higher the bird.
	var shadow_scale := clampf(1.0 - _height / 260.0, 0.35, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 3.5 * s * shadow_scale, Color(0, 0, 0, 0.22 * shadow_scale))
	draw_set_transform(Vector2(0, -_height - 3.0 * s), 0.0, Vector2(_facing, 1.0))
	var body: Color = _species["body"]
	var wing: Color = _species["wing"]
	var neck: float = _species["neck"]
	if _state == State.FLOCK:
		# Far up: a dark silhouette.
		body = body.darkened(0.55)
		wing = wing.darkened(0.55)
	# Body and tail.
	draw_rect(Rect2(Vector2(-3, -2) * s, Vector2(6, 4) * s), body)
	draw_rect(Rect2(Vector2(-5, -2) * s, Vector2(2, 2) * s), wing)
	# Head (dipped while pecking), on a long neck for the egret.
	var head := Vector2(3, -3 - neck) * s
	if _peck > 0.0:
		head = Vector2(4, 1) * s
	if neck > 0.0:
		draw_line(Vector2(2, -1) * s, head, body, 1.5 * s)
	draw_rect(Rect2(head - Vector2(1, 1.5) * s, Vector2(2.5, 2.5) * s), body)
	draw_rect(Rect2(head + Vector2(1.5, -0.5) * s, Vector2(2 if neck == 0.0 else 3, 1) * s), _species["beak"])
	if flying:
		var flap := sin(_t * (18.0 if _state != State.FLOCK else 11.0))
		draw_line(Vector2(0, -1) * s, Vector2(-2, -1 - 5 * flap) * s, wing, 1.5 * s)
		draw_line(Vector2(1, -1) * s, Vector2(3, -1 - 5 * flap) * s, wing, 1.5 * s)
	else:
		draw_rect(Rect2(Vector2(-2, -1) * s, Vector2(4, 2) * s), wing)
		# Legs.
		draw_rect(Rect2(Vector2(-1, 2) * s, Vector2(0.6, 1 + neck * 0.4) * s), Color(0.3, 0.25, 0.2))
		draw_rect(Rect2(Vector2(1, 2) * s, Vector2(0.6, 1 + neck * 0.4) * s), Color(0.3, 0.25, 0.2))
