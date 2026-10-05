class_name TallGrassLayer
extends TileMapLayer

## Tall grass, painted like any tile layer (16 px grid, y-sorted so the
## player walks behind/in front of tufts, no collision). Its ShaderMaterial
## (tall_grass.gdshader) does the movement; this script feeds it the
## player's position every frame, and when the player steps into a new grass
## cell, records a "rustle" there - the grass whips and settles around that
## spot - plus a puff of blades and an optional sound.
##
## The wind plays in the editor too (shader TIME); the player's effects only
## exist in game.

## Played when the player steps into grass. Empty = silent.
@export var rustle_sound: AudioStream
@export var rustle_volume_db := -10.0
## Blades thrown up when the player steps into grass.
@export var particle_color := Color(0.42, 0.6, 0.22)
## A player standing still in grass doesn't keep rustling it.
const MIN_RUSTLE_INTERVAL := 0.09
const MAX_RUSTLES := 8

var _player: Node2D
var _material: ShaderMaterial
var _time := 0.0
var _rustles: Array[Vector4] = []
var _next_rustle := 0
var _last_cell := Vector2i(1 << 30, 1 << 30)
var _last_rustle_time := -1.0
var _last_player_position := Vector2.ZERO

func _ready() -> void:
	_material = material as ShaderMaterial
	if _material == null:
		push_warning("TallGrassLayer %s: no ShaderMaterial - the grass won't move." % name)
		set_process(false)
		return
	_rustles.resize(MAX_RUSTLES)
	_rustles.fill(Vector4.ZERO)

func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("rustle_time", _time)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
		_last_player_position = _player.global_position
	var feet := _player.global_position
	_material.set_shader_parameter("player_position", feet)

	var moved := feet.distance_squared_to(_last_player_position) > 0.01
	_last_player_position = feet
	var cell := local_to_map(to_local(feet))
	if cell == _last_cell:
		return
	_last_cell = cell
	if moved and get_cell_source_id(cell) != -1 and _time - _last_rustle_time >= MIN_RUSTLE_INTERVAL:
		_rustle(feet)

func _rustle(at: Vector2) -> void:
	_last_rustle_time = _time
	_rustles[_next_rustle] = Vector4(at.x, at.y, _time, 1.0)
	_next_rustle = (_next_rustle + 1) % MAX_RUSTLES
	_material.set_shader_parameter("rustles", _rustles)
	_spawn_blades(at)
	if rustle_sound:
		AudioManager.play_sfx(rustle_sound, rustle_volume_db, randf_range(0.9, 1.15))

## A few blade bits thrown up from the player's feet, then freed.
func _spawn_blades(at: Vector2) -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 6
	puff.lifetime = 0.45
	puff.direction = Vector2.UP
	puff.spread = 70.0
	puff.gravity = Vector2(0, 260)
	puff.initial_velocity_min = 40.0
	puff.initial_velocity_max = 75.0
	puff.angular_velocity_min = -360.0
	puff.angular_velocity_max = 360.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color = particle_color
	# Drawn over the tufts right around the feet.
	puff.z_index = 1
	puff.finished.connect(puff.queue_free)
	add_child(puff)
	puff.global_position = at + Vector2(0, -4)
	puff.emitting = true
