class_name ShopUI
extends Control

## Village market: 4 categories (Seeds/Tools/Food/Animals), a scrollable grid
## of ItemCards, and a CartPanel. Seeds are synthesized from the real
## CropData registry (see ShopItemData.from_crop_data) so their price/growth
## numbers never drift from FarmSimulation; the other categories are
## hand-authored ShopItemData resources under data/shop_items/.

const TOOLS_FOOD_ANIMALS_RESOURCES: Array[ShopItemData] = [
	preload("res://data/shop_items/tool_angady.tres"),
	preload("res://data/shop_items/tool_watering_can_tin.tres"),
	preload("res://data/shop_items/food_vary_sy_laoka.tres"),
	preload("res://data/shop_items/food_vary_amin_anana.tres"),
	preload("res://data/shop_items/animal_chicken.tres"),
	preload("res://data/shop_items/animal_zebu.tres"),
]

const ItemCardScene := preload("res://scenes/ui/shop/ItemCard.tscn")

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.14
const CLOSED_SCALE := Vector2(0.9, 0.9)

@onready var money_label: Label = %MoneyLabel
@onready var close_button: Button = %CloseButton
@onready var category_row: HBoxContainer = %CategoryRow
@onready var item_grid: GridContainer = %ItemGrid
@onready var cart_panel: CartPanel = %CartPanel

var _shop_controller: ShopController
var _simulation: FarmSimulation
var _catalog: Dictionary = {} # ShopItemData.Category -> Array[ShopItemData]
var _selected_category: ShopItemData.Category = ShopItemData.Category.SEEDS
var _open_tween: Tween

func setup(shop_controller: ShopController, simulation: FarmSimulation) -> void:
	_shop_controller = shop_controller
	_simulation = simulation

	_build_catalog()
	_setup_category_buttons()

	close_button.pressed.connect(close)
	cart_panel.checkout_requested.connect(_on_checkout_requested)
	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(_on_day_changed)

	_on_money_changed(simulation.state.money)

	resized.connect(func(): pivot_offset = size / 2.0)
	visible = false
	modulate.a = 0.0
	scale = CLOSED_SCALE

func _build_catalog() -> void:
	_catalog = {
		ShopItemData.Category.SEEDS: [],
		ShopItemData.Category.TOOLS: [],
		ShopItemData.Category.FOOD: [],
		ShopItemData.Category.ANIMALS: [],
	}
	for crop_id in _simulation.get_all_crop_ids():
		var crop_data: CropData = _simulation.get_crop_data(crop_id)
		_catalog[ShopItemData.Category.SEEDS].append(ShopItemData.from_crop_data(crop_data))
	for shop_item in TOOLS_FOOD_ANIMALS_RESOURCES:
		_catalog[shop_item.category].append(shop_item)

## The 4 CategoryButton children are placed directly in ShopUI.tscn (fixed
## set of categories). This just wires them into one radio group and starts
## on Seeds.
func _setup_category_buttons() -> void:
	var group := ButtonGroup.new()
	for child in category_row.get_children():
		if child is CategoryButton:
			child.button_group = group
			child.category_chosen.connect(_on_category_chosen)
	var first_button := category_row.get_child(0)
	if first_button is CategoryButton:
		first_button.button_pressed = true # triggers _on_category_chosen -> first grid build

func _on_category_chosen(category: ShopItemData.Category) -> void:
	_selected_category = category
	_rebuild_item_grid()

func _rebuild_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	for item: ShopItemData in _catalog.get(_selected_category, []):
		var card: ItemCard = ItemCardScene.instantiate()
		item_grid.add_child(card)
		card.setup(item, _is_locked(item))
		card.add_requested.connect(_on_add_requested)

## Only SEEDS carry an unlock_day (via their backing CropData) - the other
## categories have no progression gate yet.
func _is_locked(item: ShopItemData) -> bool:
	if item.category != ShopItemData.Category.SEEDS:
		return false
	var crop_data := _simulation.get_crop_data(item.crop_id)
	return crop_data != null and _simulation.state.day < crop_data.unlock_day

func _on_add_requested(item: ShopItemData, quantity: int) -> void:
	cart_panel.add_item(item, quantity)

## All-or-nothing checkout: the whole cart must be affordable up front, so a
## purchase never runs out of money halfway through.
func _on_checkout_requested() -> void:
	var total := cart_panel.get_total()
	if _simulation.state.money < total:
		cart_panel.flash_insufficient_funds()
		return
	for entry in cart_panel.get_entries():
		_purchase(entry.item, entry.quantity)
	cart_panel.clear()

func _purchase(item: ShopItemData, quantity: int) -> void:
	if item.category == ShopItemData.Category.SEEDS:
		_shop_controller.buy_seed(item.crop_id, quantity)
	else:
		_shop_controller.buy_item(item.id, item.price, quantity)

func _on_money_changed(money: int) -> void:
	money_label.text = "Argent: %d $" % money

## Crop unlock_day gates can flip while the shop happens to be open; cheapest
## correct fix is to just re-lock/unlock the currently visible grid.
func _on_day_changed(_day: int) -> void:
	_rebuild_item_grid()

func open() -> void:
	visible = true
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
	_open_tween.chain().tween_callback(func(): visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
