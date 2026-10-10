class_name ForageSpot
extends Node2D

## A wild plant to gather in the forest (its Discovery: a plant page of the
## notebook, with its item, season and regrowth): grown, it's there to pick
## ("Cueillir"); gathered, or out of season, only what's left of it shows.
## Its id in the save is its node name. ForestManager says how it is
## (show_state) and answers the interaction. Built in code; it looks like
## its Discovery's drawing (set_discovery). Its origin is its foot.
## Group "forage_spots".

signal gathered

const GROUP := "forage_spots"
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")

## Which plant (a Discovery id: "wild_greens", "honey"...).
@export var discovery_id := ""

var _sprite: Sprite2D
var _interactable: InteractableComponent
## Its drawing grown, then gathered.
var _looks: Array[Texture2D] = []
var _ready_to_pick := false

func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.offset = Vector2(0, -Discovery.SHEET_CELL / 2.0 + 8)
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

## What grows here: its drawing.
func set_discovery(discovery: Discovery) -> void:
	_looks = [discovery.get_drawing(0), discovery.get_drawing(1)]
	_sprite.texture = _looks[0 if _ready_to_pick else 1]

func get_spot_id() -> String:
	return name

## `ready`: grown, to pick (`prompt`: "[E] Cueillir...", already translated).
func show_state(ready: bool, prompt: String) -> void:
	_ready_to_pick = ready
	if not _looks.is_empty():
		_sprite.texture = _looks[0 if ready else 1]
	_interactable.set_interactable(ready)
	_interactable.prompt_message = prompt
