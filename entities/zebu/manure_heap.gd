class_name ManureHeap
extends Prop

## The manure heap by the farm pen (FarmSimulation.manure_pile): small or big
## by how much is waiting, gone when there's none; the player picks it all
## up. ZebuManager decides - this only shows it and passes the interaction
## on. No collision: the zebus walk past it to the gate.

signal interacted

## Sheet cells (assets/sprites/props/manure.png, tools/placeholder_art/
## gen_manure.gd): small heap, big heap.
const SMALL_REGION := Rect2(0, 0, 192, 192)
const BIG_REGION := Rect2(192, 0, 192, 192)
## From this much on, the big heap.
const BIG_FROM := 6

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interactable: InteractableComponent = $InteractableComponent

var _amount := 0

func _ready() -> void:
	super()
	_interactable.interacted.connect(interacted.emit)
	if not Engine.is_editor_hint():
		var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
		var box := RectangleShape2D.new()
		box.size = Vector2(100, 60)
		area.shape = box
		area.position = Vector2(0, -15)

func show_amount(amount: int) -> void:
	_amount = amount
	_sprite.visible = amount > 0
	_sprite.region_rect = BIG_REGION if amount >= BIG_FROM else SMALL_REGION
	_interactable.is_interactable = amount > 0
	_interactable.prompt_message = tr("Ramasser le fumier (%d)") % amount if amount > 0 else ""

func get_amount() -> int:
	return _amount
