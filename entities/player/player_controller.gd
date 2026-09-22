class_name PlayerController
extends CharacterBody2D

enum Tool { HOE, WATERING_CAN, SEEDS, HARVEST }

signal interact_requested(tool: Tool)
signal tool_changed(tool: Tool)

@export var walk_speed: float = 220.0
@export var run_speed: float = 400.0

@onready var camera: Camera2D = $Camera2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_pivot: Node2D = $InteractionPivot
@onready var interaction_detector: Area2D = $InteractionPivot/InteractionDetector

var current_tool: Tool = Tool.HOE
var last_facing_direction: Vector2 = Vector2.RIGHT

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity = input_vector * speed
	move_and_slide()
	
	_update_animation(input_vector)
	_update_interaction_pivot(input_vector)

## Rotates the interaction pivot towards the last movement direction
func _update_interaction_pivot(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		last_facing_direction = dir
		interaction_pivot.rotation = dir.angle()
		
func _update_animation(dir: Vector2):
	if dir == Vector2.ZERO:
		_play_idle()
	else:
		_play_walk(dir)

func _play_idle():
	if anim.animation.begins_with("walk"):
		anim.animation = anim.animation.replace("walk", "idle")

func _play_walk(dir: Vector2):
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
