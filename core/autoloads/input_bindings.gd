extends Node

## Autoload singleton (registered in project.godot [autoload]).
## Default bindings for the actions added by code rather than in the editor's
## Input Map - that list has lost entries before when project.godot was
## rewritten, so these are (re)declared here at startup. An action already
## defined in the Input Map is left untouched: the editor, or a future
## remapping screen, always wins over these defaults.
##
## Every gameplay input goes through an action (never a raw keycode) so it
## works the same on keyboard, mouse and gamepad. Gamepad buttons use Godot's
## positional layout (Xbox names): A = bottom face button, X = left face
## button, LEFT/RIGHT_SHOULDER = L/R on a Nintendo Switch pad.

const HOTBAR_SIZE := 8

func _ready() -> void:
	# Two-button farming, like Stardew: "use_item" acts with what the player
	# holds (till, water, plant), "interact" is the bare-hands action (harvest,
	# signs, bowls...). Never ambiguous, whatever is selected in the Hotbar.
	_ensure_action("use_item", [
		_key(KEY_SPACE),
		_mouse(MOUSE_BUTTON_LEFT),
		_joy(JOY_BUTTON_X),
	])
	# "interact" (E) is declared in the editor's Input Map - add its gamepad
	# button on top, without touching the keyboard binding there.
	_ensure_event("interact", _joy(JOY_BUTTON_A))
	_ensure_action("hotbar_next", [
		_key(KEY_TAB),
		_mouse(MOUSE_BUTTON_WHEEL_DOWN),
		_joy(JOY_BUTTON_RIGHT_SHOULDER),
	])
	_ensure_action("hotbar_prev", [
		_key(KEY_TAB, true),
		_mouse(MOUSE_BUTTON_WHEEL_UP),
		_joy(JOY_BUTTON_LEFT_SHOULDER),
	])
	# Physical keys, so the number row works on AZERTY too (no Shift needed).
	for i in HOTBAR_SIZE:
		_ensure_action("hotbar_%d" % (i + 1), [_key(KEY_1 + i)])

func _ensure_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event in events:
		InputMap.action_add_event(action, event)

## Adds `event` to an existing action unless an equivalent one is bound.
func _ensure_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _key(keycode: Key, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.shift_pressed = shift
	return event

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
