class_name PlayerController
extends CharacterBody2D

enum Tool { HOE, WATERING_CAN, SEEDS, HARVEST }

signal interact_requested(tool: Tool)
signal tool_changed(tool: Tool)

@export var walk_speed: float = 220.0
@export var run_speed: float = 400.0

var current_tool: Tool = Tool.HOE

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity = input_vector * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_requested.emit(current_tool)
	elif event.is_action_pressed("cycle_tool"):
		current_tool = ((current_tool + 1) % Tool.size()) as Tool
		tool_changed.emit(current_tool)
