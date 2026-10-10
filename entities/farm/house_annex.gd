class_name HouseAnnex
extends Node2D

## One of the farm house's annexes (FamilyProject "granary", "kitchen"):
## nothing there until it's built, then its building, solid at its foot,
## something to interact with. Only shows it and passes the interaction on -
## FamilyProjectManager sets its level, KitchenManager answers the kitchen.
## Built in code from SHEET (tools/placeholder_art/gen_annexes.gd); its
## origin is the middle of its foot. Group "house_annexes".

signal interacted

const GROUP := "house_annexes"
const SHEET := preload("res://assets/sprites/props/house_annexes.png")
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
## Cells of SHEET, at twice the on-screen size.
const CELL := Vector2(256, 320)
const CELLS := {"granary": 0, "kitchen": 1}
## Its footprint on screen, from its origin.
const AREA := Rect2(-64, -160, 128, 160)

## Which annex: "granary" or "kitchen" (ProjectRules.BUILDINGS).
@export var building := ""

var _sprite: Sprite2D
var _base: StaticBody2D
var _interactable: InteractableComponent
var _level := -1

func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = AtlasTexture.new()
	(_sprite.texture as AtlasTexture).atlas = SHEET
	(_sprite.texture as AtlasTexture).region = Rect2(Vector2(CELL.x * CELLS.get(building, 0), 0), CELL)
	_sprite.centered = false
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.offset = Vector2(-CELL.x / 2.0, -CELL.y)
	add_child(_sprite)
	_base = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(100, 14)
	shape.shape = box
	shape.position = Vector2(0, -7)
	_base.add_child(shape)
	add_child(_base)
	_interactable = INTERACTABLE.instantiate()
	add_child(_interactable)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var reach := RectangleShape2D.new()
	reach.size = Vector2(130, 90)
	area.shape = reach
	area.position = Vector2(0, -30)
	_interactable.interacted.connect(interacted.emit)
	set_level(0)

## 0: not built - nothing there. 1: built.
func set_level(level: int) -> void:
	_level = level
	var built := level >= 1
	_sprite.visible = built
	_base.process_mode = Node.PROCESS_MODE_INHERIT if built else Node.PROCESS_MODE_DISABLED
	_base.get_child(0).set_deferred("disabled", not built)
	_interactable.set_interactable(built)

func is_built() -> bool:
	return _level >= 1

## What interacting does ("[E] <prompt>", already translated).
func set_prompt(prompt: String) -> void:
	_interactable.prompt_message = prompt
