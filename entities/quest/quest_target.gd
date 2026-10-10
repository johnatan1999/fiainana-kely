class_name QuestTarget
extends Node2D

## A spot of a side quest in a zone, its id `target_id` (QuestStep.target):
## Rakoto's zebu lost in the forest, hoof prints by the ford... Its children
## are what it looks like (a sprite, a drawing), shown only when `appears`
## says so (QuestManager: set_shown):
## - DURING_STEP: while a quest's current step is here - to walk to
##   (`reach_size` set: walking in does it) or to use (the interaction);
## - AFTER_DONE: once `quest_id` is finished (the zebu back home) - decor.
## Placed by tools/place_quest_targets.gd. Group "quest_targets".

signal triggered

enum Show { DURING_STEP, AFTER_DONE }

const GROUP := "quest_targets"
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")

## Its id in the quests' steps ("lost_zebu"). Unique in the game.
@export var target_id := ""
## AFTER_DONE: the quest whose end shows it.
@export var quest_id := ""
@export var appears := Show.DURING_STEP
## DURING_STEP, to walk into: the area (centered on the node). Zero: to
## use instead, within `interact_size` (above the node's origin).
@export var reach_size := Vector2.ZERO
@export var interact_size := Vector2(110, 90)

var _interactable: InteractableComponent
var _area: Area2D
var _shown := false

func _ready() -> void:
	add_to_group(GROUP)
	if appears == Show.DURING_STEP and reach_size != Vector2.ZERO:
		_area = Area2D.new()
		_area.monitorable = false
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = reach_size
		shape.shape = box
		_area.add_child(shape)
		add_child(_area)
		_area.body_entered.connect(func(body: Node2D):
			if _shown and body.is_in_group("player"):
				triggered.emit())
	elif appears == Show.DURING_STEP:
		_interactable = INTERACTABLE.instantiate()
		add_child(_interactable)
		var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
		var reach := RectangleShape2D.new()
		reach.size = interact_size
		area.shape = reach
		area.position = Vector2(0, -interact_size.y / 2.0 + 20)
		_interactable.interacted.connect(triggered.emit)
	visible = false
	_set_interactable(false)

## Shown or not, and what using it does ("[E] Approcher le zébu", already
## translated).
func set_shown(shown: bool, prompt := "") -> void:
	_shown = shown
	visible = shown
	_set_interactable(shown)
	if _interactable != null:
		_interactable.prompt_message = prompt

func is_shown() -> bool:
	return _shown

## Its area turned back on: a player already standing in it is walked in all
## the same (body_entered).
func _set_interactable(enabled: bool) -> void:
	if _interactable != null:
		_interactable.set_interactable(enabled)
	if _area != null:
		_area.set_deferred("monitoring", enabled)
