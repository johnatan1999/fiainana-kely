class_name Shop extends StaticBody2D

@onready var interactable_component: InteractableComponent = $InteractableComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable_component.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	#AudioManager.play_interact_sfx()
	UIEvents.shop_requested.emit(null)
