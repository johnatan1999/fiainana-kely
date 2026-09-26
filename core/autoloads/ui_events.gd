extends Node

signal shop_requested(shop: Shop)
## A short message for the player (Toast shows it at the top of the screen).
signal notification_requested(text: String)

## `text` already translated - messages often carry live values.
func notify(text: String) -> void:
	notification_requested.emit(text)
