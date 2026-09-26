class_name HotbarSlot
extends Control

## One cell of the hotbar: the item's icon (or a placeholder), its stack count,
## and its key number. Purely visual - HotbarUI fills it and reports clicks.

signal clicked(index: int)

const SELECTED_FRAME_TINT := Color(1.4, 1.15, 0.6)
const SELECTED_SCALE := Vector2(1.12, 1.12)
const ANIM_TIME := 0.08

@onready var glow: ColorRect = %Glow
@onready var frame: TextureRect = %Frame
@onready var icon_rect: TextureRect = %Icon
@onready var glyph: ToolGlyph = %Glyph
@onready var placeholder: ColorRect = %Placeholder
@onready var count_label: Label = %CountLabel
@onready var key_label: Label = %KeyLabel

var index := 0
var _tween: Tween

func _ready() -> void:
	pivot_offset = size / 2.0
	key_label.text = str(index + 1)

## `icon` null + `tool_id` set -> drawn pictogram; both empty -> placeholder
## square of `color` (or nothing at all for an empty slot).
func show_item(icon: Texture2D, tool_id: String, color: Color, count: int, empty: bool) -> void:
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	glyph.visible = icon == null and tool_id != ""
	if glyph.visible:
		glyph.tool_id = tool_id
	placeholder.visible = not empty and icon == null and tool_id == ""
	placeholder.color = color
	count_label.text = str(count)
	count_label.visible = count > 0

func set_selected(selected: bool) -> void:
	glow.visible = selected
	frame.self_modulate = SELECTED_FRAME_TINT if selected else Color.WHITE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", SELECTED_SCALE if selected else Vector2.ONE, ANIM_TIME).set_trans(Tween.TRANS_SINE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()
