class_name ForageSpot
extends Node2D

## A wild plant to gather in the forest (its Discovery: a plant page of the
## notebook, with its item, season and regrowth): grown, it's there to pick
## ("Cueillir"); gathered, or out of season, only what's left of it shows.
## Its id in the save is its node name. ForestManager says how it is
## (show_state) and answers the interaction. Built in code from SHEET (row
## 1, tools/placeholder_art/gen_forest.gd); its origin is its foot.
## Group "forage_spots".

signal gathered

const GROUP := "forage_spots"
const SHEET := preload("res://assets/sprites/props/forest.png")
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
const CELL := 128
## Row 1 of SHEET: each plant ready (this column), then gathered (the next).
const CELLS := {"wild_greens": 0, "honey": 2, "ravintsara": 4, "mushroom": 6}

## Which plant (a Discovery id: "wild_greens", "honey"...).
@export var discovery_id := ""

var _sprite: Sprite2D
var _interactable: InteractableComponent

func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = AtlasTexture.new()
	(_sprite.texture as AtlasTexture).atlas = SHEET
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.offset = Vector2(0, -CELL / 2.0 + 8)
	add_child(_sprite)
	_interactable = INTERACTABLE.instantiate()
	add_child(_interactable)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var reach := RectangleShape2D.new()
	reach.size = Vector2(80, 60)
	area.shape = reach
	area.position = Vector2(0, -16)
	_interactable.interacted.connect(gathered.emit)
	show_state(false, "")

func get_spot_id() -> String:
	return name

## `ready`: grown, to pick (`prompt`: "[E] Cueillir...", already translated).
func show_state(ready: bool, prompt: String) -> void:
	var column: int = CELLS.get(discovery_id, 0) + (0 if ready else 1)
	(_sprite.texture as AtlasTexture).region = Rect2(column * CELL, CELL, CELL, CELL)
	_interactable.set_interactable(ready)
	_interactable.prompt_message = prompt
