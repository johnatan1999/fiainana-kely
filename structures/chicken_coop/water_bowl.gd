class_name WaterBowl
extends Area2D

## Player interacts (E) nearby to refill it for free. Chicken.gd's AI walks
## here when thirsty and self-serves - each visit consumes one serving.

signal refilled

const MAX_SERVINGS := 6

var servings: int = 0

var _player_inside := false
var _player: PlayerController

func setup(player: PlayerController) -> void:
	_player = player
	_player.interact_requested.connect(_on_interact_requested)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func is_full() -> bool:
	return servings > 0

## Called by a chicken once it actually reaches the bowl.
func consume() -> void:
	servings = max(0, servings - 1)

func _on_body_entered(body: Node) -> void:
	if body == _player:
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player_inside = false

func _on_interact_requested(_tool) -> void:
	if not _player_inside or servings >= MAX_SERVINGS:
		return
	servings = MAX_SERVINGS
	AudioManager.play_click_menu_sfx()
	refilled.emit()
