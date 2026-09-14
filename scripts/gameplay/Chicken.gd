class_name Chicken
extends CharacterBody2D

## Simple wander/eat/drink/sleep AI - no pathfinding, just move_toward within
## a radius of its spawn point, matching the project's existing movement
## style (PlayerController also has no navmesh). Reads AnimalState each tick
## to decide what to do; only ever writes back to it via AnimalManager calls
## (feed_animal/water_animal), never directly.

enum State { IDLE, WALK, EAT, DRINK, SLEEP }

const SPEED := 40.0
const WANDER_RADIUS := 60.0
const WILD_WANDER_RADIUS := 160.0
const EAT_DRINK_DURATION := 1.5
const HUNGRY_THRESHOLD := 50.0
const THIRSTY_THRESHOLD := 50.0
const ARRIVE_DISTANCE := 6.0

## Set start_wild = true on a Chicken instance placed directly in a zone
## scene (e.g. wandering free in the yard) instead of spawned by
## AnimalManager - it then never needs a FarmSimulation-backed AnimalState.
@export var start_wild: bool = false
@export var wild_wander_radius: float = WILD_WANDER_RADIUS

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var placeholder: ColorRect = $Placeholder

var _animal_manager: AnimalManager
var _animal_id: String
var _is_wild: bool = false
var _home_position: Vector2
var _target_position: Vector2
var _wander_radius: float = WANDER_RADIUS
var _state: State = State.IDLE
var _arrival_state: State = State.IDLE
var _state_timer: float = 0.0
var _wander_cooldown: float = 0.0

func _ready() -> void:
	if start_wild:
		setup_wild(wild_wander_radius)

func setup(animal_manager: AnimalManager, animal_id: String) -> void:
	_animal_manager = animal_manager
	_animal_id = animal_id
	_home_position = global_position
	_target_position = global_position
	_wander_radius = WANDER_RADIUS
	# Only needed until a real chicken SpriteFrames resource exists.
	placeholder.visible = anim.sprite_frames == null

## Purely decorative: no FarmSimulation-backed AnimalState, so it never gets
## hungry/thirsty and never lays eggs - it just wanders and occasionally
## sleeps, forever.
func setup_wild(wander_radius: float = WILD_WANDER_RADIUS) -> void:
	_is_wild = true
	_home_position = global_position
	_target_position = global_position
	_wander_radius = wander_radius
	placeholder.visible = anim.sprite_frames == null

func _physics_process(delta: float) -> void:
	if _is_wild:
		match _state:
			State.WALK:
				_process_walk()
			State.SLEEP:
				velocity = Vector2.ZERO
				_state_timer -= delta
				if _state_timer <= 0.0:
					_state = State.IDLE
			_:
				_process_wild_idle(delta)
		move_and_slide()
		_play_animation()
		return

	var animal: AnimalState = _animal_manager.simulation.get_animal(_animal_id)
	if animal == null:
		queue_free() # sold/removed from the simulation
		return

	match _state:
		State.EAT, State.DRINK, State.SLEEP:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.IDLE
		State.WALK:
			_process_walk()
		State.IDLE:
			_process_idle(delta, animal)

	move_and_slide()
	_play_animation()

func _process_wild_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	_wander_cooldown -= delta
	if _wander_cooldown > 0.0:
		return
	_wander_cooldown = randf_range(2.0, 5.0)
	if randf() < 0.2:
		_state = State.SLEEP
		_state_timer = randf_range(2.0, 4.0)
	else:
		var offset := Vector2(randf_range(-_wander_radius, _wander_radius), randf_range(-_wander_radius, _wander_radius))
		_walk_to(_home_position + offset, State.WALK)

func _process_idle(delta: float, animal: AnimalState) -> void:
	velocity = Vector2.ZERO
	_wander_cooldown -= delta

	if animal.hunger <= HUNGRY_THRESHOLD:
		var bowl := _animal_manager.get_feeding_bowl()
		if bowl != null and bowl.is_full():
			_walk_to(bowl.global_position, State.EAT)
			return
	if animal.thirst <= THIRSTY_THRESHOLD:
		var bowl := _animal_manager.get_water_bowl()
		if bowl != null and bowl.is_full():
			_walk_to(bowl.global_position, State.DRINK)
			return

	if _wander_cooldown > 0.0:
		return
	_wander_cooldown = randf_range(2.0, 5.0)
	if randf() < 0.2:
		_state = State.SLEEP
		_state_timer = randf_range(2.0, 4.0)
	else:
		var offset := Vector2(randf_range(-_wander_radius, _wander_radius), randf_range(-_wander_radius, _wander_radius))
		_walk_to(_home_position + offset, State.WALK)

func _process_walk() -> void:
	var to_target := _target_position - global_position
	if to_target.length() <= ARRIVE_DISTANCE:
		_on_arrived()
		return
	velocity = to_target.normalized() * SPEED

func _walk_to(target: Vector2, arrival_state: State) -> void:
	_target_position = target
	_arrival_state = arrival_state
	_state = State.WALK

func _on_arrived() -> void:
	velocity = Vector2.ZERO
	if _arrival_state == State.EAT:
		var bowl := _animal_manager.get_feeding_bowl()
		if bowl != null:
			bowl.consume()
		_animal_manager.feed_animal(_animal_id)
		_state = State.EAT
		_state_timer = EAT_DRINK_DURATION
	elif _arrival_state == State.DRINK:
		var bowl := _animal_manager.get_water_bowl()
		if bowl != null:
			bowl.consume()
		_animal_manager.water_animal(_animal_id)
		_state = State.DRINK
		_state_timer = EAT_DRINK_DURATION
	else:
		_state = State.IDLE

func _play_animation() -> void:
	if anim.sprite_frames == null:
		return
	var anim_name: String
	match _state:
		State.WALK: anim_name = "walk"
		State.EAT: anim_name = "eat"
		State.DRINK: anim_name = "drink"
		State.SLEEP: anim_name = "sleep"
		_: anim_name = "idle"
	if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
		anim.animation = anim_name
		anim.play()
