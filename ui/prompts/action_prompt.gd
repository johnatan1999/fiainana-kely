class_name ActionPrompt
extends Control

## Contextual button prompts - listing only what the buttons would do right
## now. Button labels come from InputBindings: the keys actually bound, or
## the connected gamepad's buttons (Nintendo / PlayStation / Xbox symbols)
## once it's used. Two sources, one bubble:
## - an interactable in reach (coop, bowl...) with a prompt: "[E] <prompt>"
##   above the player's head - "interact" goes to it first (see
##   PlayerController._try_interact()), so it wins over the plot prompt;
## - otherwise the plot in front, e.g. "[Espace] Arroser   [E] Récolter",
##   above that plot, driven by FarmingController.target_actions_changed
##   (the same rules as the plot highlight, so the two always agree).

## "use_item" verb per FarmAction (translation keys).
const USE_VERBS := {
	FarmAction.Type.TILL: "Labourer",
	FarmAction.Type.PLOUGH: "Labourer (zébus)",
	FarmAction.Type.FERTILIZE: "Fumer",
	FarmAction.Type.WATER: "Arroser",
	FarmAction.Type.PLANT: "Planter",
}
const HARVEST_VERB := "Récolter"
## Gap between the bubble's bottom edge and the top of the plot, in pixels.
const LIFT := 6.0
## Interactable prompts sit this far above the player's feet (over the head).
const ABOVE_PLAYER := Vector2(0, -96)

@export var key_style: StyleBox

@onready var row: HBoxContainer = %Row

var _player: PlayerController
var _anchor := Vector2.ZERO
var _use_action := FarmAction.Type.NONE
var _can_harvest := false
## Prompt of the interactable in reach ("" = none), already translated.
var _interact_prompt := ""

func setup(farming_controller: FarmingController, player: PlayerController) -> void:
	_player = player
	farming_controller.target_actions_changed.connect(_on_target_actions_changed)
	InputBindings.device_changed.connect(func(_gamepad: bool): _rebuild())
	# Keeps running while paused only to hide itself under menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _on_target_actions_changed(anchor: Vector2, use_action: FarmAction.Type, can_harvest: bool) -> void:
	_anchor = anchor
	_use_action = use_action
	_can_harvest = can_harvest
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild()

func _has_actions() -> bool:
	return _interact_prompt != "" or _use_action != FarmAction.Type.NONE or _can_harvest

func _rebuild() -> void:
	# remove_child first: queue_free() alone keeps the old labels in the row
	# until the end of the frame, and the bubble would keep their width.
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if _interact_prompt != "":
		_add_action("interact", _interact_prompt)
	else:
		if _use_action != FarmAction.Type.NONE:
			_add_action("use_item", tr(USE_VERBS.get(_use_action, "")))
		if _can_harvest:
			_add_action("interact", tr(HARVEST_VERB))
	# Deferred: the new labels' minimum size is only known once laid out.
	reset_size.call_deferred()

## `text` is already translated (prompts can carry live counts).
func _add_action(action: StringName, text: String) -> void:
	var key_text := InputBindings.get_button_label(action)
	if key_text == "":
		return # nothing bound on this device - don't show a blank key
	var key := Label.new()
	key.text = key_text
	key.theme_type_variation = &"PromptKey"
	if key_style:
		key.add_theme_stylebox_override("normal", key_style)
	row.add_child(key)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"PromptVerb"
	row.add_child(label)

## Follows its anchor on screen (the camera moves) and hides under menus.
func _process(_delta: float) -> void:
	var focused := _player.get_focused_interactable() if _player else null
	var prompt := focused.get_prompt() if focused else ""
	if prompt != _interact_prompt:
		_interact_prompt = prompt
		_rebuild()
	visible = _has_actions() and not get_tree().paused and row.get_child_count() > 0
	if not visible:
		return
	var anchor := _player.global_position + ABOVE_PLAYER if _interact_prompt != "" else _anchor
	var screen_anchor := get_viewport().get_canvas_transform() * anchor
	position = (screen_anchor - Vector2(size.x / 2.0, size.y + LIFT)).round()
