class_name Coop
extends Node2D

## Two-phase building: first interaction constructs it, every interaction
## after that settles one of the hens bought and waiting. All the actual
## rules live in AnimalManager/FarmSimulation - this just forwards "the
## player pressed interact here" and keeps its prompt up to date
## ("[E] Settle a hen (2 waiting)", shown over the player by ActionPrompt).

@onready var label: Label = $Label
@onready var interactable_component: InteractableComponent = $InteractableComponent
var _animal_manager: AnimalManager

## Free-roaming chickens of the zone find the coop through this group to go
## in for the night - see Chicken.set_time_of_day().
const GROUP := "chicken_coops"

func _ready() -> void:
	add_to_group(GROUP)

## Just in front of the door: where chickens go in at dusk and come out at dawn.
func get_door_position() -> Vector2:
	var door := get_node_or_null("EntranceDoor") as Node2D
	return (door.global_position if door else global_position) + Vector2(0, 12)

func setup(animal_manager: AnimalManager) -> void:
	_animal_manager = animal_manager
	interactable_component.interacted.connect(_on_interacted)
	animal_manager.simulation.pending_animals_changed.connect(refresh_visual)
	animal_manager.simulation.animal_added.connect(func(_animal_id: String): refresh_visual())
	# The prompt says it all now - the old floating label would repeat it.
	label.visible = false
	refresh_visual()

func refresh_visual() -> void:
	var simulation := _animal_manager.simulation
	var prompt := ""
	if not simulation.state.has_coop:
		prompt = tr("Construire le poulailler (%s)") % Currency.format(FarmSimulation.COOP_COST)
	else:
		match simulation.check_place_animal(AnimalData.Species.CHICKEN):
			FarmSimulation.PlaceCheck.OK:
				prompt = tr("Installer une poule (%d en attente)") % simulation.get_pending_count(AnimalData.Species.CHICKEN)
			FarmSimulation.PlaceCheck.FULL:
				# Hens waiting but no room: say so rather than promise a no-op.
				prompt = tr("Poulailler plein (%s)") % _animal_manager.get_coop_occupancy()
	interactable_component.prompt_message = prompt

func _on_interacted() -> void:
	_animal_manager.interact_with_coop(self)
