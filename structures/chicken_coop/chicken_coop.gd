class_name Coop
extends Node2D

## Two-phase building: first interaction constructs it, every interaction
## after that places one purchased-but-unplaced chicken. All the actual
## rules live in AnimalManager/FarmSimulation - this just forwards "the
## player pressed interact here" and reflects the result visually.

@onready var label: Label = $Label
@onready var interaction = $Area2D
var _player_inside := false
var _player: PlayerController
var _animal_manager: AnimalManager

func setup(player: PlayerController, animal_manager: AnimalManager) -> void:
	_player = player
	_animal_manager = animal_manager
	_player.interact_requested.connect(_on_interact_requested)
	interaction.body_entered.connect(_on_body_entered)
	interaction.body_exited.connect(_on_body_exited)
	refresh_visual()

func refresh_visual() -> void:
	var built: bool = _animal_manager.simulation.state.has_coop
	label.text = "Poulailler (E: placer une poule)" if built else "Construire le poulailler (E)"

func _on_body_entered(body: Node) -> void:
	if body == _player:
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player_inside = false

func _on_interact_requested(_tool) -> void:
	if _player_inside:
		_animal_manager.interact_with_coop(self)
