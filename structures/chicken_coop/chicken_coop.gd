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

## Its look by level (FamilyProject "coop"): cells of LEVEL_CELL in
## LEVEL_SHEET (tools/placeholder_art/gen_coop.gd) - 0 the ruin, then
## rebuilt 1 to 3 - drawn at twice their size (shown at half: sharp), on the
## ruin's footprint - same walls, same door. The ruin's old art
## (WallSprite, RoofSprite: exterior.png) stays in the scene, hidden.
const LEVEL_SHEET := preload("res://assets/sprites/props/coop_levels.png")
const LEVEL_CELL := Vector2(448, 384)

var _level_sprite: Sprite2D

func _ready() -> void:
	add_to_group(GROUP)

## Shows the coop at `level` (FarmSimulation.get_building_level("coop")) -
## FamilyProjectManager sets it on the farm's coop.
func set_level(level: int) -> void:
	$WallSprite.visible = false
	$RoofSprite.visible = false
	if _level_sprite == null:
		_level_sprite = Sprite2D.new()
		_level_sprite.name = "LevelSprite"
		_level_sprite.texture = AtlasTexture.new()
		(_level_sprite.texture as AtlasTexture).atlas = LEVEL_SHEET
		_level_sprite.centered = false
		_level_sprite.scale = Vector2(0.5, 0.5)
		# Standing on the coop's origin, like the ruin (its walls at -172).
		_level_sprite.offset = Vector2(0, -344)
		add_child(_level_sprite)
	var index := clampi(level, 0, 3)
	(_level_sprite.texture as AtlasTexture).region = Rect2(Vector2(LEVEL_CELL.x * index, 0), LEVEL_CELL)
	_level_sprite.visible = true

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
