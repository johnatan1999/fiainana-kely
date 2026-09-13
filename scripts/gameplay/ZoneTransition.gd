class_name ZoneTransition
extends Area2D

## Placed at doors/exits. Walking into it asks WorldManager to switch zones.

signal triggered(target_zone: String, target_spawn: String)

@export var target_zone: String
@export var target_spawn: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		triggered.emit(target_zone, target_spawn)
