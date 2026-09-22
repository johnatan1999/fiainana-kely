class_name Coop
extends Node2D

## Two-phase building: first interaction constructs it, every interaction
## after that places one purchased-but-unplaced chicken. All the actual
## rules live in AnimalManager/FarmSimulation - this just forwards "the
## player pressed interact here" and reflects the result visually.

@onready var label: Label = $Label
@onready var interactable_component: InteractableComponent = $InteractableComponent
var _animal_manager: AnimalManager

func setup(animal_manager: AnimalManager) -> void:
	_animal_manager = animal_manager
	interactable_component.interacted.connect(_on_interacted)
	refresh_visual()

func refresh_visual() -> void:
	var built: bool = _animal_manager.simulation.state.has_coop
	label.text = "Poulailler (E: placer une poule)" if built else "Construire le poulailler (E)"

func _on_interacted() -> void:
	_animal_manager.interact_with_coop(self)
