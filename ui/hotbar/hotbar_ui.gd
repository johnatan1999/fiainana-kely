class_name HotbarUI
extends Control

## Draws the Hotbar at the bottom of the screen: one HotbarSlot per slot, the
## selected one highlighted, and the name of the held item shown for a moment
## whenever the selection changes. All state lives in Hotbar; this only
## listens and redraws (and turns slot clicks into Hotbar.select()).

const SlotScene := preload("res://ui/hotbar/hotbar_slot.tscn")

const NAME_SHOW_TIME := 1.2
const NAME_FADE_TIME := 0.4

@onready var slot_row: HBoxContainer = %SlotRow
@onready var name_label: Label = %NameLabel

var _hotbar: Hotbar
var _item_db: ItemDatabase
var _slots: Array[HotbarSlot] = []
var _name_tween: Tween

func setup(hotbar: Hotbar, item_db: ItemDatabase) -> void:
	_hotbar = hotbar
	_item_db = item_db
	for i in FarmState.HOTBAR_SIZE:
		var slot: HotbarSlot = SlotScene.instantiate()
		slot.index = i
		slot_row.add_child(slot)
		slot.clicked.connect(_hotbar.select)
		_slots.append(slot)
	hotbar.slots_changed.connect(_refresh_slots)
	hotbar.selection_changed.connect(_on_selection_changed)
	hotbar.simulation.inventory_changed.connect(func(_item_id: String, _count: int): _refresh_slots())
	name_label.modulate.a = 0.0
	_refresh_slots()
	for slot in _slots:
		slot.set_selected(slot.index == _hotbar.selected_index)

func _refresh_slots() -> void:
	for slot in _slots:
		var item_id := _hotbar.get_item(slot.index)
		var item := _item_db.get_item(item_id) if item_id != "" else null
		if item == null:
			slot.show_item(null, "", Color.TRANSPARENT, 0, true)
			continue
		var glyph: String = ToolGlyph.glyph_for(item.tool_action) if item.icon == null else ""
		var color: Color = ItemData.CATEGORY_COLORS.get(item.category, Color.GRAY)
		# Seed stacks always show their count; a single tool doesn't need "1".
		var count := _hotbar.get_count(slot.index)
		var shown_count := count if _item_db.is_seed(item_id) or count > 1 else 0
		slot.show_item(item.icon, glyph, color, shown_count, false)

func _on_selection_changed(index: int) -> void:
	for slot in _slots:
		slot.set_selected(slot.index == index)
	_show_name(_item_name(_hotbar.get_item(index)))

func _item_name(item_id: String) -> String:
	if item_id == "":
		return ""
	var item := _item_db.get_item(item_id)
	return item.get_display_name() if item else item_id

## Pops the held item's name above the bar, then fades it out.
func _show_name(text: String) -> void:
	if _name_tween:
		_name_tween.kill()
	name_label.text = text
	if text == "":
		name_label.modulate.a = 0.0
		return
	name_label.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(NAME_SHOW_TIME)
	_name_tween.tween_property(name_label, "modulate:a", 0.0, NAME_FADE_TIME)
