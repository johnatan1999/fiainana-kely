class_name InteractableComponent
extends Area2D

# Signal emitted when the player triggers this interaction
signal interacted

## What "interact" does here, shown as "[E] <prompt>" over the player's head
## while this is the interaction in reach (ActionPrompt) - a translation key.
## Empty: no prompt. Owners can change it live (e.g. the coop's "Settle a hen
## (2 waiting)").
@export var prompt_message: String = ""

# Whether the player can currently interact with this object
@export var is_interactable: bool = true
@export var interact_sfx: AudioStream

## The prompt as shown: translated, "" when there's nothing to say.
func get_prompt() -> String:
	return tr(prompt_message) if is_interactable and prompt_message != "" else ""

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
