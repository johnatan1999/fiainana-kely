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

## Fired when the player switches between keyboard/mouse and a gamepad, so
## on-screen button prompts can swap their labels.
signal device_changed(using_gamepad: bool)

## Stick movement below this doesn't count as "using the gamepad" (drift).
const STICK_DEADZONE := 0.5

## Face-button labels per pad family, indexed by Godot's positional buttons.
const PAD_LABELS := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"},
	"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X"},
	"playstation": {JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△"},
}
const SHOULDER_LABELS := {
	"xbox": {JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB"},
	"nintendo": {JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R"},
	"playstation": {JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1"},
}
## Keyboard keys whose engine name isn't what the player reads on the key -
## translation keys (French source), see localization/translations.csv.
const KEY_NAMES := {
	KEY_SPACE: "Espace",
	KEY_TAB: "Tab",
	KEY_ESCAPE: "Échap",
}

var using_gamepad := false
var _gamepad_device := 0

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
	for i in FarmState.HOTBAR_SIZE:
		_ensure_action("hotbar_%d" % (i + 1), [_key(KEY_1 + i)])

## Tracks the last device the player touched. Never consumes the event.
func _input(event: InputEvent) -> void:
	var gamepad: bool
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < STICK_DEADZONE:
			return
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	else:
		return # mouse motion alone doesn't switch prompts back
	if gamepad:
		_gamepad_device = event.device
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		device_changed.emit(using_gamepad)

## Player-facing label of the button bound to `action` on the device in use
## - "E", "Espace", "A", "✕"... - read from the Input Map, so it follows any
## rebinding. Empty if nothing on that device is bound to it.
func get_button_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if using_gamepad and event is InputEventJoypadButton:
			var family := _pad_family()
			if PAD_LABELS[family].has(event.button_index):
				return PAD_LABELS[family][event.button_index]
			if SHOULDER_LABELS[family].has(event.button_index):
				return SHOULDER_LABELS[family][event.button_index]
			return str(event.button_index)
		if not using_gamepad and event is InputEventKey:
			var physical: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			if KEY_NAMES.has(physical):
				return tr(KEY_NAMES[physical])
			# What's printed on the player's own keyboard (AZERTY, QWERTY...).
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
	return ""

## Which label set matches the connected pad, from its reported name.
func _pad_family() -> String:
	var name := Input.get_joy_name(_gamepad_device).to_lower()
	if name.contains("nintendo") or name.contains("switch") or name.contains("joy-con") or name.contains("pro controller"):
		return "nintendo"
	if name.contains("playstation") or name.contains("dualsense") or name.contains("dualshock") or name.contains("ps4") or name.contains("ps5") or name.contains("sony"):
		return "playstation"
	return "xbox"

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
