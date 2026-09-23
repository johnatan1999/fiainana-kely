class_name CartPanel
extends PanelContainer

## Holds the pending purchase list. Pure UI state - it never touches
## FarmSimulation itself; ShopUI listens to checkout_requested and performs
## the actual transactions, then calls clear() on success.

class CartEntry:
	var item: ShopItemData
	var quantity: int
	func _init(p_item: ShopItemData, p_quantity: int) -> void:
		item = p_item
		quantity = p_quantity

signal checkout_requested
signal cart_changed(total: int)

@onready var cart_list: VBoxContainer = %CartList
@onready var empty_label: Label = %EmptyLabel
@onready var total_label: Label = %TotalLabel
@onready var checkout_button: Button = %CheckoutButton

var _entries: Dictionary = {} # item_id: String -> CartEntry
var _rows: Dictionary = {} # item_id: String -> HBoxContainer (row)
var _row_labels: Dictionary = {} # item_id: String -> Label

func _ready() -> void:
	checkout_button.pressed.connect(_on_checkout_pressed)
	_refresh_totals()

func add_item(item: ShopItemData, quantity: int) -> void:
	if _entries.has(item.id):
		_entries[item.id].quantity += quantity
	else:
		_entries[item.id] = CartEntry.new(item, quantity)
		_create_row(item.id)
	_update_row_label(item.id)
	_refresh_totals()

func clear() -> void:
	for item_id in _rows.keys():
		_rows[item_id].queue_free()
	_rows.clear()
	_row_labels.clear()
	_entries.clear()
	_refresh_totals()

func get_entries() -> Array:
	return _entries.values()

func get_total() -> int:
	var total := 0
	for entry in _entries.values():
		total += entry.item.price * entry.quantity
	return total

func _create_row(item_id: String) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var remove_button := Button.new()
	remove_button.text = "x"
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.pressed.connect(_on_remove_pressed.bind(item_id))
	row.add_child(remove_button)

	cart_list.add_child(row)
	_rows[item_id] = row
	_row_labels[item_id] = label

func _update_row_label(item_id: String) -> void:
	var entry: CartEntry = _entries[item_id]
	var label: Label = _row_labels[item_id]
	label.text = "%s x%d — %s" % [entry.item.display_name, entry.quantity, Currency.format(entry.item.price * entry.quantity)]

func _on_remove_pressed(item_id: String) -> void:
	if not _entries.has(item_id):
		return
	AudioManager.play_click_menu_sfx()
	_entries.erase(item_id)
	_rows[item_id].queue_free()
	_rows.erase(item_id)
	_row_labels.erase(item_id)
	_refresh_totals()

func _refresh_totals() -> void:
	empty_label.visible = _entries.is_empty()
	checkout_button.disabled = _entries.is_empty()
	total_label.text = "Total: %s" % Currency.format(get_total())
	cart_changed.emit(get_total())

func _on_checkout_pressed() -> void:
	AudioManager.play_click_menu_sfx()
	checkout_requested.emit()

## Called by ShopUI when the player can't afford the whole cart.
func flash_insufficient_funds() -> void:
	var tween := create_tween()
	tween.tween_property(total_label, "modulate", Color(1.0, 0.35, 0.35), 0.1)
	tween.tween_property(total_label, "modulate", Color.WHITE, 0.3)
