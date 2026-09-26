class_name InteractableComponent
extends Area2D

# Signal emitted when the player triggers this interaction
signal interacted

# Prompt displayed to the player (e.g. "Fill Bowl", "Open Chest", "Talk")
@export var prompt_message: String = "Interact"

# Whether the player can currently interact with this object
@export var is_interactable: bool = true
@export var interact_sfx: AudioStream


## Called by the player's interaction detector when the interact button is pressed
func interact() -> void:
	if not is_interactable:
		return
		
	if interact_sfx:
		AudioManager.play_sfx(interact_sfx)
	else:
		AudioManager.play_interact_sfx()
	# Notify listening parent entity that interaction happened
	interacted.emit()


## Enable or disable interaction programmatically
func set_interactable(enabled: bool) -> void:
	is_interactable = enabled
