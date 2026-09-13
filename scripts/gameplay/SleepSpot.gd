class_name SleepSpot
extends Area2D

## Placed on the bed. Player interacts with it (any tool) to end the day.

signal sleep_requested

var _player_inside := false
var _player: PlayerController

func setup(player: PlayerController) -> void:
	_player = player
	_player.interact_requested.connect(_on_interact_requested)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body == _player:
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player_inside = false

func _on_interact_requested(_tool) -> void:
	if _player_inside:
		sleep_requested.emit()
