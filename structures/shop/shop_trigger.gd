class_name ShopTrigger
extends Area2D

## Placed on the shop building. Player interacts with it (any tool) to open the shop.

var _player_inside := false
var _player: PlayerController
var _shop_ui: ShopUI

func setup(player: PlayerController, shop_ui: ShopUI) -> void:
	_player = player
	_shop_ui = shop_ui
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
		AudioManager.play_interact_sfx()
		_shop_ui.open()
