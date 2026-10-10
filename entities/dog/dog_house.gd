@tool
class_name DogHouse
extends Prop

## The dog's doghouse at the farm, and its bowl: filling the bowl is the
## dog's daily care (DogRules.feed_dog) - DogManager decides, this only
## shows it (no dog yet: nothing at all; the bowl empty or full of rice) and
## passes the player's interaction on. The dog sleeps at `Bed`, in front of
## the door. Built by tools/build_dog.gd, placed by the same tool.

signal bowl_interacted

## Sheet cells (assets/sprites/props/dog_props.png, tools/placeholder_art/
## gen_dog.gd): the bowl empty, full.
const EMPTY_REGION := Rect2(192, 0, 192, 192)
const FULL_REGION := Rect2(384, 0, 192, 192)
## Where "fill the bowl" reaches, around InteractableComponent (on the bowl).
const BOWL_AREA := Vector2(64, 56)

@onready var _bowl: Sprite2D = $Bowl
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _bed: Marker2D = $Bed

func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		_interactable.interacted.connect(bowl_interacted.emit)
		var box := RectangleShape2D.new()
		box.size = BOWL_AREA
		(_interactable.get_node("InteractableCollision2D") as CollisionShape2D).shape = box

## Whether the family has a dog: without one, there's no doghouse.
func set_owned(owned: bool) -> void:
	visible = owned
	for shape in $Base.find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", not owned)
	if not owned:
		_interactable.set_interactable(false)

## `full`: filled today. Filling it is offered while it's empty.
func show_bowl(full: bool) -> void:
	_bowl.region_rect = FULL_REGION if full else EMPTY_REGION
	_interactable.prompt_message = "" if full else "Remplir la gamelle"
	_interactable.set_interactable(visible and not full)

func is_bowl_full() -> bool:
	return _bowl.region_rect == FULL_REGION

## Where the dog lies at night.
func get_bed_position() -> Vector2:
	return _bed.global_position
