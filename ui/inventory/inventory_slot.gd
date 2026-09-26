class_name InventorySlot
extends Control

## One cell of the inventory grid: the item's icon in a wooden frame, with
## its quantity in the corner. Purely presentational - InventoryUI resolves
## the item (InventoryCatalog.describe()) and decides which cell is
## selected; the cell only reports clicks and hovers.

signal clicked(item_id: String)
signal hover_changed(item_id: String, hovered: bool)

const HOVER_SCALE := Vector2(1.06, 1.06)
const SELECTED_FRAME_TINT := Color(1.35, 1.15, 0.7)
const ANIM_TIME := 0.1

@onready var glow: ColorRect = %Glow
@onready var frame: TextureRect = %Frame
@onready var icon_rect: TextureRect = %Icon
@onready var placeholder: ColorRect = %Placeholder
@onready var glyph: ToolGlyph = %Glyph
@onready var quantity_label: Label = %QuantityLabel

var item_id: String
var _selected := false
var _tween: Tween

func _ready() -> void:
	pivot_offset = size / 2.0
	mouse_entered.connect(func():
		_animate_scale(HOVER_SCALE)
		hover_changed.emit(item_id, true))
	mouse_exited.connect(func():
		_animate_scale(Vector2.ONE)
		hover_changed.emit(item_id, false))

func setup(info: Dictionary, quantity: int) -> void:
	item_id = info.id
	quantity_label.text = str(quantity)
	quantity_label.visible = quantity > 1
	var icon: Texture2D = info.icon
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	var glyph_id: String = info.get("glyph", "")
	glyph.visible = icon == null and glyph_id != ""
	if glyph.visible:
		glyph.tool_id = glyph_id
	placeholder.visible = icon == null and glyph_id == ""
	placeholder.color = info.color

func set_selected(selected: bool) -> void:
	_selected = selected
	glow.visible = selected
	frame.self_modulate = SELECTED_FRAME_TINT if selected else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(item_id)
		accept_event()

func _animate_scale(target: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, ANIM_TIME).set_trans(Tween.TRANS_SINE)
