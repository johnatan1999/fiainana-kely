@tool
class_name WorldTree
extends Node2D

## A tree placed by hand in a zone scene. Its origin is the foot of the
## trunk, so in a y-sorted parent the player walks behind the canopy and in
## front of the trunk.
##
## What kind of tree it is lives in `tree_data`; how it looks (sprites,
## trunk collision, foliage fade area) lives in that species' TreeVisual
## scene (TreeData.visual_scene), instanced here as a child - see
## tree_visual.gd. A fruit tree is registered by TreeManager when its zone
## loads - its ripeness is FarmSimulation state, this node only shows it
## (show_state()) and reports presses (interacted). A tree whose data bears
## no fruit is pure decor.
##
## @tool so the editor previews the species. The visual is added without an
## owner, so it's never saved into the zone scene. And like FarmField, this
## never references gameplay scripts, so it never drags them (and their
## autoloads) into the editor.

signal interacted

## Where the player can press interact from: a box around the foot of the
## trunk, the same for every species.
const INTERACT_REACH := Vector2(78, 64)
const VISUAL_NODE_NAME := "Visual"

@export var tree_data: TreeData:
	set(value):
		if tree_data and tree_data.changed.is_connected(_rebuild_visual):
			tree_data.changed.disconnect(_rebuild_visual)
		tree_data = value
		if tree_data:
			tree_data.changed.connect(_rebuild_visual)
		if is_node_ready():
			_rebuild_visual()

## Per-tree variation, so a grove of one species doesn't look copy-pasted:
## mirror the art, and grow or shrink the whole tree (collision included).
@export var flip := false:
	set(value):
		flip = value
		_apply_variation()
@export_range(0.7, 1.4, 0.05) var size_scale := 1.0:
	set(value):
		size_scale = value
		_apply_variation()

# Untyped: InteractableComponent plays sounds through the AudioManager
# autoload - see the class doc.
@onready var _interactable = $InteractableComponent

var _visual: TreeVisual
var _ripe := false

func _ready() -> void:
	_rebuild_visual()
	if Engine.is_editor_hint():
		return
	var reach := RectangleShape2D.new()
	reach.size = INTERACT_REACH
	var reach_shape: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	reach_shape.shape = reach
	reach_shape.position = Vector2(0, -INTERACT_REACH.y / 4.0)
	_interactable.interacted.connect(interacted.emit)
	# Decor: nothing to do on a press - not even a sound.
	_interactable.set_interactable(tree_data != null and tree_data.bears_fruit())

## Called by TreeManager whenever the tree's state may have changed.
## `prompt`: what pressing interact here does ("[E] <prompt>").
func show_state(prompt: String, ripe: bool) -> void:
	_interactable.prompt_message = prompt
	_ripe = ripe
	if _visual:
		_visual.show_state(TreeVisual.State.FRUITING if ripe else TreeVisual.State.BARE)

## Swaps in the species' visual - or a bare TreeVisual (placeholder drawing,
## no collision) for a species with no visual_scene yet.
func _rebuild_visual() -> void:
	if _visual:
		remove_child(_visual)
		_visual.queue_free()
		_visual = null
	if tree_data == null:
		return
	if tree_data.visual_scene:
		_visual = tree_data.visual_scene.instantiate() as TreeVisual
		if _visual == null:
			push_warning("WorldTree %s: %s's visual_scene has no TreeVisual root." % [name, tree_data.id])
			return
	else:
		_visual = TreeVisual.new()
	_visual.name = VISUAL_NODE_NAME
	add_child(_visual)
	_apply_variation()
	if Engine.is_editor_hint():
		return
	_visual.show_state(TreeVisual.State.FRUITING if _ripe else TreeVisual.State.BARE)
	var fade_area := _visual.get_fade_area()
	if fade_area:
		fade_area.body_entered.connect(_on_fade_area_body_changed.bind(true))
		fade_area.body_exited.connect(_on_fade_area_body_changed.bind(false))

func _apply_variation() -> void:
	if _visual:
		_visual.scale = Vector2.ONE * size_scale
		_visual.flipped = flip

func _on_fade_area_body_changed(body: Node2D, entered: bool) -> void:
	if body.is_in_group("player"):
		_visual.set_faded(entered)
