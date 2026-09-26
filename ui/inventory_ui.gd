class_name InventoryUI
extends Control

## Read-only view of everything in FarmState.inventory, laid out on the
## inventory book (assets/sprites/inventory/inventory.png): category tabs on
## the left page, the items of the selected tab in the center frame, and a
## card describing the selected (or hovered) item on the right page.
## Item names/icons/details come from InventoryCatalog.

const SlotScene := preload("res://ui/inventory/inventory_slot.tscn")

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.14
const CLOSED_SCALE := Vector2(0.95, 0.95)

## The ScrollContainer's default grey scrollbar clashes with the parchment -
## these replace it (set in inventory_ui.tscn).
@export var scroll_track_style: StyleBox
@export var scroll_grabber_style: StyleBox

@onready var dim: ColorRect = %Dim
@onready var category_list: VBoxContainer = %CategoryList
@onready var item_scroll: ScrollContainer = %ItemScroll
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel
@onready var info_card: ItemInfoCard = %InfoCard
@onready var money_label: Label = %MoneyLabel

var _simulation: FarmSimulation
var _item_db: ItemDatabase
var _shop_ui: ShopUI
var _open_tween: Tween
var _tabs: Array[InventoryCategoryTab] = []

var _category := InventoryCatalog.Category.CROPS
var _selected_id := ""
var _hovered_id := ""
## item_id -> {info: Dictionary, quantity: int, slot: InventorySlot} for the
## items of the current tab, in grid order.
var _entries: Dictionary = {}
var _order: Array[String] = []

func setup(simulation: FarmSimulation, shop_ui: ShopUI, item_db: ItemDatabase) -> void:
	_simulation = simulation
	_shop_ui = shop_ui
	_item_db = item_db

	# Reste actif malgré get_tree().paused = true (voir open()/close()) - sinon
	# ses propres boutons et son tween d'ouverture/fermeture se figeraient aussi.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for child in category_list.get_children():
		if child is InventoryCategoryTab:
			_tabs.append(child)
			child.chosen.connect(_select_category)
	dim.gui_input.connect(_on_dim_input)
	_style_scrollbar()

	simulation.money_changed.connect(_on_money_changed)
	simulation.inventory_changed.connect(_on_inventory_changed)
	_on_money_changed(simulation.state.money)

	resized.connect(func(): pivot_offset = size / 2.0)
	visible = false
	modulate.a = 0.0
	scale = CLOSED_SCALE

func _style_scrollbar() -> void:
	var bar := item_scroll.get_v_scroll_bar()
	if scroll_track_style:
		bar.add_theme_stylebox_override("scroll", scroll_track_style)
	if scroll_grabber_style:
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(state, scroll_grabber_style)

func _on_money_changed(money: int) -> void:
	money_label.text = tr("Argent : %s") % Currency.format(money)

## Names/descriptions/counts are translated when built - redo them after a
## language switch (static texts in the scene re-translate on their own).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _simulation != null:
		_on_money_changed(_simulation.state.money)
		if visible:
			_rebuild()

## Only rebuilds while actually visible - no point re-resolving every item
## on every purchase/harvest while the player isn't even looking at it.
func _on_inventory_changed(_item_id: String, _amount: int) -> void:
	if visible:
		_rebuild()

## Owned items (quantity > 0) grouped by tab, each tab sorted by name.
func _collect_items() -> Dictionary:
	var by_category := {}
	for category in InventoryCatalog.Category.values():
		by_category[category] = []
	for item_id: String in _simulation.state.inventory:
		var quantity: int = _simulation.state.inventory[item_id]
		if quantity <= 0:
			continue
		var info := InventoryCatalog.describe(_item_db, item_id)
		by_category[info.category].append({"info": info, "quantity": quantity})
	for category in by_category:
		by_category[category].sort_custom(func(a, b): return a.info.name.naturalnocasecmp_to(b.info.name) < 0)
	return by_category

func _rebuild() -> void:
	var by_category := _collect_items()
	for tab in _tabs:
		tab.set_count(by_category[tab.category].size())
		tab.set_selected(tab.category == _category)

	for child in item_grid.get_children():
		child.queue_free()
	_entries.clear()
	_order.clear()
	_hovered_id = ""

	for entry in by_category[_category]:
		var slot: InventorySlot = SlotScene.instantiate()
		item_grid.add_child(slot)
		slot.setup(entry.info, entry.quantity)
		slot.clicked.connect(_select_item)
		slot.hover_changed.connect(_on_slot_hover_changed)
		var item_id: String = entry.info.id
		_entries[item_id] = {"info": entry.info, "quantity": entry.quantity, "slot": slot}
		_order.append(item_id)

	empty_label.visible = _order.is_empty()
	# Keep the selection across rebuilds (e.g. after selling one) when the
	# item is still there, else fall back to the first item of the tab.
	if not _entries.has(_selected_id):
		_selected_id = _order[0] if not _order.is_empty() else ""
	_refresh_selection()

func _select_category(category: InventoryCatalog.Category) -> void:
	if category == _category:
		return
	_category = category
	_selected_id = ""
	item_scroll.scroll_vertical = 0
	AudioManager.play_click_menu_sfx()
	_rebuild()

func _select_item(item_id: String) -> void:
	if item_id == _selected_id:
		return
	_selected_id = item_id
	AudioManager.play_click_menu_sfx()
	_refresh_selection()
	var slot: InventorySlot = _entries[item_id].slot
	item_scroll.ensure_control_visible(slot)

## Hovering previews an item on the card; leaving it goes back to the
## selected one.
func _on_slot_hover_changed(item_id: String, hovered: bool) -> void:
	if hovered:
		_hovered_id = item_id
	elif _hovered_id == item_id:
		_hovered_id = ""
	_refresh_card()

func _refresh_selection() -> void:
	for item_id in _entries:
		_entries[item_id].slot.set_selected(item_id == _selected_id)
	_refresh_card()

func _refresh_card() -> void:
	var shown_id := _hovered_id if _entries.has(_hovered_id) else _selected_id
	if _entries.has(shown_id):
		info_card.show_item(_entries[shown_id].info, _entries[shown_id].quantity)
	else:
		info_card.show_empty(tr("Aucun objet"))

## Opens on the last tab used, or the first non-empty one if that's empty.
func _pick_start_category() -> void:
	var by_category := _collect_items()
	if not by_category[_category].is_empty():
		return
	for category in InventoryCatalog.Category.values():
		if not by_category[category].is_empty():
			_category = category
			return

func _move_selection(dx: int, dy: int) -> void:
	if _order.is_empty():
		return
	var index := _order.find(_selected_id)
	if index == -1:
		_select_item(_order[0])
		return
	var target := index + dx + dy * item_grid.columns
	if target < 0 or target >= _order.size():
		return
	_select_item(_order[target])

func _cycle_category(step: int) -> void:
	var count := InventoryCatalog.Category.size()
	var next: int = ((_category + step) % count + count) % count
	_select_category(next as InventoryCatalog.Category)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func open() -> void:
	_pick_start_category()
	_rebuild()
	visible = true
	get_tree().paused = true
	AudioManager.play_click_menu_sfx()
	if _open_tween:
		_open_tween.kill()
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_TIME)
	_open_tween.tween_property(self, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	AudioManager.play_click_menu_sfx()
	if _open_tween:
		_open_tween.kill()
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(self, "modulate:a", 0.0, CLOSE_TIME)
	_open_tween.tween_property(self, "scale", CLOSED_SCALE, CLOSE_TIME)
	_open_tween.chain().tween_callback(func():
		visible = false
		get_tree().paused = false
	)

## "I" is a raw keycode, not a project InputMap action - kept out of it for
## the same reason PlayerController.NUMBER_KEY_TOOLS is (see its comment).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if not visible and _shop_ui != null and _shop_ui.visible:
			return # don't pop the inventory open on top of the shop
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_category(-1 if event.shift_pressed else 1)
	elif event.is_action_pressed("ui_left", true):
		_move_selection(-1, 0)
	elif event.is_action_pressed("ui_right", true):
		_move_selection(1, 0)
	elif event.is_action_pressed("ui_up", true):
		_move_selection(0, -1)
	elif event.is_action_pressed("ui_down", true):
		_move_selection(0, 1)
	else:
		return
	get_viewport().set_input_as_handled()
