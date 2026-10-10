class_name Chicken
extends CharacterBody2D

## Simple wander/eat/drink/sleep AI - no pathfinding, just move_toward within
## a radius of its spawn point, matching the project's existing movement
## style (PlayerController also has no navmesh). Reads AnimalState each tick
## to decide what to do; only ever writes back to it via AnimalManager calls
## (feed_animal/water_animal), never directly.
##
## Keeps the hours (DayNightController.CLOCK_GROUP): from ROOST_MINUTE a
## free-roaming chicken walks to its zone's coop door and goes in; from
## WAKE_MINUTE it comes back out and returns to its spot. Chickens kept in
## the coop (simulated ones) just sleep through the night. By the clock, not
## the light: retuning the sky colors never moves these hours.

enum State { IDLE, WALK, EAT, DRINK, SLEEP, ROOSTING }

const SPEED := 40.0
const WANDER_RADIUS := 60.0
const WILD_WANDER_RADIUS := 160.0
const EAT_DRINK_DURATION := 1.5
const ARRIVE_DISTANCE := 6.0
## Bowls are solid, so a chicken can never reach their center: it walks to a
## random spot around the bowl instead (so several can eat side by side) and
## counts as arrived once within BOWL_REACH of the bowl.
const BOWL_APPROACH_DISTANCE := 22.0
const BOWL_REACH := 30.0
## A walk that hasn't arrived after its expected travel time plus this much
## is abandoned (target behind a wall or another obstacle) - the chicken goes
## back to idle instead of pushing against it forever.
const WALK_TIMEOUT_MARGIN := 1.5
## Random delay before a freshly spawned chicken first moves, so a whole
## flock doesn't set off on the same frame.
const FIRST_MOVE_DELAY_MIN := 0.5
const FIRST_MOVE_DELAY_MAX := 3.0
## Chickens don't collide with each other (they're on the Animals physics
## layer, which they don't mask) - hard collisions made them shove and
## wedge into one another. Instead, any two closer than SEPARATION_RADIUS
## gently drift apart, so they never end up stacked on the same spot.
const SEPARATION_RADIUS := 12.0
const SEPARATION_SPEED := 25.0
## Needs are daily, matching FarmSimulation's care rules (eggs and breeding
## count consecutive days fed AND watered): a chicken wants to eat until it
## has eaten today (AnimalState.fed_today) and drink until it has drunk
## today, and the bubble shows exactly that. The hunger/thirst gauges only
## drop on days it went without - at or below this, the bubble turns red.
const CRITICAL_NEED_THRESHOLD := 20.0
## Pecking while eating/drinking (no dedicated art yet): the sprite squashes
## toward its feet and back, PECK_PERIOD seconds per peck.
const PECK_SQUASH := Vector2(1.06, 0.84)
const PECK_PERIOD := 0.3
## Going in at dusk, out in the morning (minute of the day). WAKE_MINUTE is
## a little after the 6:00 wake-up, so the player sees them come out.
const ROOST_MINUTE := 18 * 60 + 45
const WAKE_MINUTE := 6 * 60 + 15
## Hurrying home.
const HOME_SPEED := 55.0
## Walking home has no pathfinding: one stuck behind a fence or a house for
## this long slips away out of sight - it went round.
const HOME_STUCK_TIME := 1.2
## Coming out one by one, not as a block.
const WAKE_DELAY_MAX := 6.0
const FADE_TIME := 0.35

## Set start_wild = true on a Chicken instance placed directly in a zone
## scene (e.g. wandering free in the yard) instead of spawned by
## AnimalManager - it then never needs a FarmSimulation-backed AnimalState.
@export var start_wild: bool = false
@export var wild_wander_radius: float = WILD_WANDER_RADIUS
@export var sprite_frames: SpriteFrames
@export var tint_color: Color = Color.WHITE
@export var size_multiplier: float = 0.5


@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var collistion := $CollisionShape2D

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
## Where wander targets are picked (global coordinates) - the coop's
## ChickenArea for simulated chickens. Empty = wander around _home_position
## within _wander_radius (wild/decorative chickens).
var _wander_area := Rect2()
var _walk_time_left: float = 0.0
## FeedingBowl or WaterBowl (no shared base class - both expose get_center()).
var _target_bowl
var _need_bubble: NeedBubble
var _peck_tween: Tween
## Between ROOST_MINUTE and WAKE_MINUTE - see set_time_of_day().
var _roost_time := false
var _time_known := false
## Walking to the coop door for the night.
var _going_home := false
var _stuck_time := 0.0
var _wake_delay := 0.0
## Fading in or out through the coop door - killed when the other one starts,
## or a chicken coming out mid-fade would be hidden again by the old fade.
var _door_tween: Tween

func _ready() -> void:
	add_to_group(DayNightController.CLOCK_GROUP)
	anim.scale = Vector2(size_multiplier, size_multiplier)
	collistion.scale = Vector2(size_multiplier, size_multiplier)
	anim.modulate = tint_color
	if sprite_frames != null:
		anim.sprite_frames = sprite_frames
	if start_wild:
		setup_wild(wild_wander_radius)

func setup(animal_manager: AnimalManager, animal_id: String, wander_area := Rect2()) -> void:
	_animal_manager = animal_manager
	_animal_id = animal_id
	_home_position = global_position
	_target_position = global_position
	_wander_radius = WANDER_RADIUS
	_wander_area = wander_area
	_randomize_start()
	_create_need_bubble()

## Only simulated animals have needs - wild/decorative ones never get one.
## Tail tip sits just above the head: frames are 64px tall with the feet at
## the origin (see the AnimatedSprite2D offset), scaled by size_multiplier.
func _create_need_bubble() -> void:
	_need_bubble = NeedBubble.new()
	_need_bubble.position = Vector2(0, -64.0 * size_multiplier + 6.0)
	add_child(_need_bubble)

## Purely decorative: no FarmSimulation-backed AnimalState, so it never gets
## hungry/thirsty and never lays eggs - it just wanders and occasionally
## sleeps, forever.
func setup_wild(wander_radius: float = WILD_WANDER_RADIUS) -> void:
	_is_wild = true
	_home_position = global_position
	_target_position = global_position
	_wander_radius = wander_radius
	_randomize_start()

func _randomize_start() -> void:
	_wander_cooldown = randf_range(FIRST_MOVE_DELAY_MIN, FIRST_MOVE_DELAY_MAX)
	animator.face([Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN].pick_random())
	animator.play(Vector2.ZERO, "idle") # apply it now, not on the first physics tick

## DayNightController, on every new minute (and when the zone loads).
func set_time_of_day(minute_of_day: int) -> void:
	_roost_time = is_roost_time(minute_of_day)
	if not _time_known:
		_time_known = true
		# Zone entered at night: the chickens are in already.
		if _is_wild and _roost_time and _find_coop() != null:
			_go_in(true)

## Night hours for a chicken. The day starts at 6:00 (GameClock), so before
## WAKE_MINUTE is the very start of the morning.
static func is_roost_time(minute_of_day: int) -> bool:
	return minute_of_day >= ROOST_MINUTE or minute_of_day < WAKE_MINUTE

func _physics_process(delta: float) -> void:
	if _is_wild:
		if _state == State.ROOSTING:
			_process_roosting(delta)
			return
		if _roost_time and not _going_home:
			_head_home()
		match _state:
			State.WALK:
				_process_walk(delta)
			State.SLEEP:
				velocity = Vector2.ZERO
				_state_timer -= delta
				if _state_timer <= 0.0:
					_state = State.IDLE
			_:
				_process_wild_idle(delta)
		_move()
		return

	var animal: AnimalState = _animal_manager.simulation.animals.get_animal(_animal_id)
	if animal == null:
		queue_free() # sold/removed from the simulation
		return
	_need_bubble.set_needs(not animal.fed_today, not animal.watered_today,
		minf(animal.hunger, animal.thirst) <= CRITICAL_NEED_THRESHOLD)

	if _roost_time and _state in [State.IDLE, State.WALK]:
		# Shut in the coop already: just sleep through the night.
		_state = State.SLEEP
		_state_timer = 1.0
	match _state:
		State.EAT, State.DRINK, State.SLEEP:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.IDLE
				_stop_peck()
		State.WALK:
			_process_walk(delta)
		State.IDLE:
			_process_idle(delta, animal)

	_move()

## Facing comes from the walk velocity only - the separation drift is added
## after, so a nudge from a neighbor doesn't spin an idle chicken around.
func _move() -> void:
	var facing := velocity
	velocity += _separation_velocity()
	move_and_slide()
	_play_animation(facing)

func _separation_velocity() -> Vector2:
	var push := Vector2.ZERO
	for other in get_parent().get_children():
		# Roosting ones are inside the coop, not in the way at its door.
		if other == self or not other is Chicken or not other.visible:
			continue
		var away: Vector2 = global_position - other.global_position
		var dist := away.length()
		if dist >= SEPARATION_RADIUS:
			continue
		if dist < 0.01:
			away = Vector2.from_angle(randf() * TAU) # exactly stacked: pick any way out
			dist = 0.0
		push += away.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return push * SEPARATION_SPEED

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
		_walk_to(_pick_wander_target(), State.WALK)

func _process_idle(delta: float, animal: AnimalState) -> void:
	velocity = Vector2.ZERO
	_wander_cooldown -= delta

	if not animal.fed_today:
		var bowl := _animal_manager.get_feeding_bowl()
		if bowl != null and bowl.is_full():
			_walk_to_bowl(bowl, State.EAT)
			return
	if not animal.watered_today:
		var bowl := _animal_manager.get_water_bowl()
		if bowl != null and bowl.is_full():
			_walk_to_bowl(bowl, State.DRINK)
			return

	if _wander_cooldown > 0.0:
		return
	_wander_cooldown = randf_range(2.0, 5.0)
	if randf() < 0.2:
		_state = State.SLEEP
		_state_timer = randf_range(2.0, 4.0)
	else:
		_walk_to(_pick_wander_target(), State.WALK)

## A short stroll from where the chicken stands, kept inside _wander_area
## when it has one (so it never aims into a wall), else around its home.
func _pick_wander_target() -> Vector2:
	var offset := Vector2(randf_range(-_wander_radius, _wander_radius), randf_range(-_wander_radius, _wander_radius))
	if _wander_area.has_area():
		var target := global_position + offset
		return target.clamp(_wander_area.position, _wander_area.end)
	return _home_position + offset

# --- Night: going in, coming out --------------------------------------------

func _find_coop() -> Node2D:
	var closest: Node2D = null
	for coop in get_tree().get_nodes_in_group(Coop.GROUP):
		if closest == null or global_position.distance_to(coop.global_position) < global_position.distance_to(closest.global_position):
			closest = coop
	return closest

func _head_home() -> void:
	var coop := _find_coop()
	if coop == null:
		return # no coop in this zone: it just carries on
	_going_home = true
	_stuck_time = 0.0
	_walk_to(coop.get_door_position(), State.ROOSTING)
	_walk_time_left = INF # it keeps going until it's in (or stuck)

## Through the door, out of sight. `instantly`: no fade (zone just loaded).
func _go_in(instantly := false) -> void:
	_state = State.ROOSTING
	_going_home = false
	velocity = Vector2.ZERO
	collistion.set_deferred("disabled", true)
	_wake_delay = randf_range(0.0, WAKE_DELAY_MAX)
	if instantly:
		visible = false
		return
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_door_tween.tween_callback(hide)

func _process_roosting(delta: float) -> void:
	if _roost_time:
		return
	_wake_delay -= delta
	if _wake_delay > 0.0:
		return
	# Morning: out through the door, back to its spot.
	var coop := _find_coop()
	if coop:
		global_position = coop.get_door_position()
	if _door_tween:
		_door_tween.kill()
	visible = true
	modulate.a = 0.0
	_door_tween = create_tween()
	_door_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	collistion.set_deferred("disabled", false)
	_state = State.IDLE
	_walk_to(_home_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), State.IDLE)

func _process_walk(delta: float) -> void:
	_walk_time_left -= delta
	if _walk_time_left <= 0.0:
		_give_up_walk()
		return
	if _going_home:
		# No pathfinding: blocked for a while = it went round, out of sight.
		_stuck_time = _stuck_time + delta if get_real_velocity().length() < SPEED * 0.25 and velocity != Vector2.ZERO else 0.0
		if _stuck_time > HOME_STUCK_TIME:
			_go_in()
			return
	if _target_bowl != null and global_position.distance_to(_target_bowl.get_center()) <= BOWL_REACH:
		_on_arrived()
		return
	var to_target := _target_position - global_position
	if to_target.length() <= ARRIVE_DISTANCE:
		_on_arrived()
		return
	velocity = to_target.normalized() * (HOME_SPEED if _going_home else SPEED)

func _walk_to(target: Vector2, arrival_state: State) -> void:
	_target_position = target
	_arrival_state = arrival_state
	_target_bowl = null
	_walk_time_left = global_position.distance_to(target) / SPEED + WALK_TIMEOUT_MARGIN
	_state = State.WALK

func _walk_to_bowl(bowl, arrival_state: State) -> void:
	_walk_to(bowl.get_center() + Vector2.from_angle(randf() * TAU) * BOWL_APPROACH_DISTANCE, arrival_state)
	_target_bowl = bowl

## Blocked: back to idle without eating/drinking - a hungry chicken simply
## tries again (from a new random side of the bowl) on its next idle tick.
func _give_up_walk() -> void:
	velocity = Vector2.ZERO
	_target_bowl = null
	_state = State.IDLE

func _on_arrived() -> void:
	velocity = Vector2.ZERO
	_target_bowl = null
	if _arrival_state == State.EAT:
		var bowl := _animal_manager.get_feeding_bowl()
		if bowl != null:
			bowl.consume()
		_animal_manager.feed_animal(_animal_id)
		_state = State.EAT
		_start_peck()
		_state_timer = EAT_DRINK_DURATION
	elif _arrival_state == State.ROOSTING:
		_go_in()
	elif _arrival_state == State.DRINK:
		var bowl := _animal_manager.get_water_bowl()
		if bowl != null:
			bowl.consume()
		_animal_manager.water_animal(_animal_id)
		_state = State.DRINK
		_start_peck()
		_state_timer = EAT_DRINK_DURATION
	else:
		_state = State.IDLE

func _start_peck() -> void:
	_stop_peck()
	var base := Vector2(size_multiplier, size_multiplier)
	_peck_tween = create_tween().set_loops()
	_peck_tween.tween_property(anim, "scale", base * PECK_SQUASH, PECK_PERIOD * 0.4).set_trans(Tween.TRANS_SINE)
	_peck_tween.tween_property(anim, "scale", base, PECK_PERIOD * 0.6).set_trans(Tween.TRANS_SINE)

func _stop_peck() -> void:
	if _peck_tween != null:
		_peck_tween.kill()
		_peck_tween = null
	anim.scale = Vector2(size_multiplier, size_multiplier)

func _play_animation(facing: Vector2) -> void:
	if anim.sprite_frames == null:
		return
	var anim_name: String
	match _state:
		State.WALK: anim_name = "walk"
		State.EAT: anim_name = "eat"
		State.DRINK: anim_name = "drink"
		State.SLEEP: anim_name = "sleep"
		_: anim_name = "idle"
	animator.play(facing, anim_name)
	if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
		anim.animation = anim_name
		anim.play()
