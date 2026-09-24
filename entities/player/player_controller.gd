class_name PlayerController
extends CharacterBody2D

enum Tool {HOE, WATERING_CAN, SEEDS, HARVEST}

## Which tool-use animation (if any) a Tool plays. SEEDS has none yet - no
## sprite exists for planting, so it stays instant like before.
enum ActionAnim {NONE, SHOVEL, WATERING, HARVEST}

signal interact_requested(tool: Tool)
signal tool_changed(tool: Tool)
## Fires once the tool-use animation (if any) actually finishes - always
## exactly once per interact press, even for tools with no animation, so
## listeners can safely gate an effect on "the swing is done" without risking
## a permanent soft-lock if a sprite/animation goes missing later.
signal action_animation_finished(tool: Tool)
## Fires when an auto_walk_to() ends - arrived, timed out, or cancelled.
signal auto_walk_finished

@export var walk_speed: float = 220.0
@export var run_speed: float = 400.0
## How fast velocity ramps up to/down from the target speed - tuned so a tap
## still feels responsive but starting/stopping isn't an instant snap.
@export var acceleration: float = 1600.0
@export var friction: float = 2000.0

@onready var camera: Camera2D = $Camera2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_pivot: Node2D = $InteractionPivot
@onready var interaction_detector: Area2D = $InteractionPivot/InteractionDetector

var current_tool: Tool = Tool.HOE
var last_facing_direction: Vector2 = Vector2.RIGHT
## False during a zone transition (see WorldManager) or a tool-use animation -
## movement/tool input is ignored and the character smoothly decelerates to a
## stop via the same friction curve as releasing the movement keys, instead
## of snapping still.
var input_enabled := true
## True while a one-shot tool-use animation (shovel/watering/harvest) is
## playing - stops _physics_process()'s per-frame walk/idle logic from
## stomping over it every frame.
var _is_performing_action := false

## Scripted walk state (see auto_walk_to()) - overrides player input while
## active, so the character steps up to a plot or through a door on its own.
var _auto_walking := false
var _auto_walk_target := Vector2.ZERO
var _auto_walk_time_left := 0.0
## Close enough to the auto-walk target to call it arrived, in pixels.
const AUTO_WALK_ARRIVE_DISTANCE := 1.0

func _physics_process(delta: float) -> void:
	var input_vector: Vector2
	if _auto_walking:
		input_vector = _auto_walk_step(delta)
	else:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down") if input_enabled else Vector2.ZERO
		var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
		var target_velocity := input_vector * speed
		var accel := acceleration if input_vector != Vector2.ZERO else friction
		velocity = velocity.move_toward(target_velocity, accel * delta)
	move_and_slide()

	if not _is_performing_action:
		_update_animation(velocity)
	_update_interaction_pivot(input_vector)

## Walks the character to `target` at walk speed, ignoring player input
## until it arrives or `max_duration` runs out (the path may be blocked, e.g.
## by a solid crop - the walk then just gives up where it got stuck). Await
## it to know when it's over. A non-zero `face_dir` is applied on arrival, so
## an approach that isn't perfectly straight doesn't change what the player
## ends up facing. Starting a new walk cancels the current one.
func auto_walk_to(target: Vector2, max_duration: float, face_dir := Vector2.ZERO) -> void:
	cancel_auto_walk()
	_auto_walking = true
	_auto_walk_target = target
	_auto_walk_time_left = max_duration
	await auto_walk_finished
	if face_dir != Vector2.ZERO:
		_update_interaction_pivot(face_dir)
		if not _is_performing_action:
			_play_idle()

func cancel_auto_walk() -> void:
	if _auto_walking:
		_auto_walking = false
		velocity = Vector2.ZERO
		auto_walk_finished.emit()

func is_auto_walking() -> bool:
	return _auto_walking

## Sets velocity directly (no acceleration ramp) so the walk stops exactly on
## the target instead of sliding past it. Returns the movement direction,
## used like player input for facing.
func _auto_walk_step(delta: float) -> Vector2:
	var to_target := _auto_walk_target - global_position
	_auto_walk_time_left -= delta
	if to_target.length() <= AUTO_WALK_ARRIVE_DISTANCE or _auto_walk_time_left <= 0.0:
		cancel_auto_walk()
		return Vector2.ZERO
	var dir := to_target.normalized()
	velocity = dir * minf(walk_speed, to_target.length() / delta)
	return dir

## Rotates the interaction pivot towards the last movement direction
func _update_interaction_pivot(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		last_facing_direction = dir
		interaction_pivot.rotation = dir.angle()

## Driven by actual (smoothed) velocity rather than raw input, so the walk
## animation keeps playing while the character is still gliding to a stop
## instead of popping to idle the instant a key is released.
func _update_animation(vel: Vector2):
	if vel.length() < 5.0:
		_play_idle()
	else:
		_play_walk(vel)

## Always resolves the correct idle_* from last_facing_direction, rather than
## string-replacing the CURRENT animation name - that old approach only ever
## worked coming from a walk_* animation, so returning to idle after any tool
## animation (shovel_left, harvest_right...) silently failed and left the
## character stuck on its last action frame forever.
func _play_idle():
	anim.flip_h = false
	var idle_name := _idle_animation_for(last_facing_direction)
	if anim.animation != idle_name:
		anim.animation = idle_name
	anim.play()

func _idle_animation_for(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "idle_right" if dir.x > 0 else "idle_left"
	else:
		return "idle_down" if dir.y > 0 else "idle_up"

func _play_walk(dir: Vector2):
	anim.flip_h = false
	if abs(dir.x) > abs(dir.y):
		anim.animation = "walk_right" if dir.x > 0 else "walk_left"
	else:
		anim.animation = "walk_down" if dir.y > 0 else "walk_up"
	anim.play()


## 1=Houe 2=Graines 3=Arrosoir 4=Récolte - direct raw keycodes, kept out of the
## project's custom InputMap since it has repeatedly lost entries there.
const NUMBER_KEY_TOOLS := {
	KEY_1: Tool.HOE,
	KEY_2: Tool.SEEDS,
	KEY_3: Tool.WATERING_CAN,
	KEY_4: Tool.HARVEST,
}

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("interact"):
		var interacted := _try_interact()
		if not interacted:
			interact_requested.emit(current_tool)
		return

	if event.is_action_pressed("cycle_tool"):
		current_tool = ((current_tool + 1) % Tool.size()) as Tool
		tool_changed.emit(current_tool)
		return
	if event is InputEventKey and event.pressed and not event.echo and NUMBER_KEY_TOOLS.has(event.keycode):
		current_tool = NUMBER_KEY_TOOLS[event.keycode]
		tool_changed.emit(current_tool)

## Tries to interact with the closest component. Returns true if successful.
func _try_interact() -> bool:
	var overlapping_areas: Array[Area2D] = interaction_detector.get_overlapping_areas()
	if overlapping_areas.is_empty():
		return false

	var closest_interactable: InteractableComponent = null
	var min_distance: float = INF

	for area in overlapping_areas:
		if area is InteractableComponent and area.is_interactable:
			var distance := global_position.distance_squared_to(area.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_interactable = area

	if closest_interactable:
		closest_interactable.interact()
		return true # Une interaction a eu lieu !

	return false

func _tool_action_anim(tool: Tool) -> ActionAnim:
	match tool:
		Tool.HOE:
			return ActionAnim.SHOVEL
		Tool.WATERING_CAN:
			return ActionAnim.WATERING
		Tool.HARVEST:
			return ActionAnim.HARVEST
		_:
			return ActionAnim.NONE # SEEDS: no dedicated art yet, stays instant

## Only shovel/harvest_left/right/watering_left/right exist - shovel has a
## single animation for both sides (no up/down art either). The gaps are
## covered by mirroring the closest side via flip_h rather than waiting on
## more art: facing up/down reuses whichever side the player last faced
## horizontally, and a right-facing shovel swing is "shovel" flipped.
func _resolve_action_animation(action: ActionAnim) -> Dictionary:
	var facing_right := last_facing_direction.x >= 0.0
	match action:
		ActionAnim.SHOVEL:
			return {"name": "shovel", "flip_h": facing_right}
		ActionAnim.WATERING:
			return {"name": "watering_right" if facing_right else "watering_left", "flip_h": false}
		ActionAnim.HARVEST:
			return {"name": "harvest_right" if facing_right else "harvest_left", "flip_h": false}
		_:
			return {}

## Plays a one-shot tool-use animation and freezes input for its full
## duration (computed from the SpriteFrames resource itself, so retuning
## frame timings in the editor never drifts out of sync with code). Called
## externally by FarmingController - only once it has confirmed the action is
## actually possible (standing on a tillable/waterable plot, a mature crop to
## harvest...), so the character never swings a tool at nothing.
func play_tool_animation(tool: Tool) -> void:
	var action := _tool_action_anim(tool )
	if action == ActionAnim.NONE:
		action_animation_finished.emit(tool )
		return
	var resolved := _resolve_action_animation(action)
	if resolved.is_empty() or not anim.sprite_frames.has_animation(resolved["name"]):
		action_animation_finished.emit(tool )
		return

	_is_performing_action = true
	input_enabled = false
	anim.flip_h = resolved["flip_h"]
	anim.animation = resolved["name"]
	anim.play()

	var duration := _get_animation_duration(resolved["name"])
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout

	anim.flip_h = false
	_is_performing_action = false
	input_enabled = true
	action_animation_finished.emit(tool )

## SpriteFrames animations here loop, so animation_finished never fires for
## them - total playtime is computed directly from frame durations/speed
## instead of hardcoding it, so tweaking timings in the editor just works.
func _get_animation_duration(anim_name: String) -> float:
	var frames := anim.sprite_frames
	var speed := frames.get_animation_speed(anim_name)
	if speed <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / speed
