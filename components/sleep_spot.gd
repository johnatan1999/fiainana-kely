class_name SleepSpot
extends Node2D

## Placed on the bed. Player interacts with it (any tool) to end the day.

signal sleep_requested

@onready var interactable_component: InteractableComponent = $InteractableComponent

func _ready() -> void:
	interactable_component.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	sleep_requested.emit()
