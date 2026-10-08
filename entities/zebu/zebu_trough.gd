class_name ZebuTrough
extends Prop

## The farm pen's trough and hay rack: filling it is the zebus' daily care
## (FarmSimulation.fill_zebu_trough) - ZebuManager decides, this only shows
## it, empty or full, and passes the player's interaction on. A Prop: its
## Sprite2D's region is switched between the sheet's two cells.

signal interacted

## Sheet cells (assets/sprites/props/zebu_market.png, tools/placeholder_art/
## gen_zebu_market.gd): empty, full.
const EMPTY_REGION := Rect2(0, 0, 192, 192)
const FULL_REGION := Rect2(192, 0, 192, 192)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	super()
	_interactable.interacted.connect(interacted.emit)
	if not Engine.is_editor_hint():
		var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
		var box := RectangleShape2D.new()
		box.size = Vector2(110, 70)
		area.shape = box
		area.position = Vector2(0, -20)

## `can_fill`: there are zebus to care for, and it isn't full yet.
func show_state(full: bool, can_fill: bool) -> void:
	_sprite.region_rect = FULL_REGION if full else EMPTY_REGION
	_interactable.prompt_message = "Remplir l'abreuvoir" if can_fill else ""
	_interactable.is_interactable = can_fill

func is_full() -> bool:
	return _sprite.region_rect == FULL_REGION
