class_name ShopUI
extends Control

## Village market: 4 categories (Seeds/Tools/Food/Animals), a scrollable grid
## of ItemCards, and a CartPanel. What's on sale comes from ItemDatabase
## (seeds synthesized from the real CropData registry, the rest hand-authored
## ItemData resources) - see ItemDatabase.ITEM_PATHS for the catalog.

const ItemCardScene := preload("res://ui/shop/item_card.tscn")

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.14
const CLOSED_SCALE := Vector2(0.9, 0.9)

@onready var money_label: Label = %MoneyLabel
@onready var close_button: BaseButton = %CloseButton
@onready var category_row: HBoxContainer = %CategoryRow
@onready var item_grid: GridContainer = %ItemGrid
@onready var cart_panel: CartPanel = %CartPanel

var _shop_controller: ShopController
var _simulation: FarmSimulation
var _item_db: ItemDatabase
var _catalog: Dictionary = {} # ItemData.Category -> Array[ItemData]
var _selected_category: ItemData.Category = ItemData.Category.SEEDS
var _open_tween: Tween

func _ready() -> void:
	# Écoute du signal global émis par le Shop / ShopBuilding
	UIEvents.shop_requested.connect(_on_shop_requested)

	# Reste actif malgré get_tree().paused = true (voir open()/close()) - sinon
	# ses propres boutons et son tween d'ouverture/fermeture se figeraient aussi.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configuration visuelle initiale (masqué par défaut)
	resized.connect(func(): pivot_offset = size / 2.0)
	visible = false
	modulate.a = 0.0
	scale = CLOSED_SCALE


func _on_shop_requested(_shop_data = null) -> void:
	open()
	
func setup(shop_controller: ShopController, simulation: FarmSimulation, item_db: ItemDatabase) -> void:
	_shop_controller = shop_controller
	_simulation = simulation
	_item_db = item_db

	_build_catalog()
	_setup_category_buttons()

	close_button.pressed.connect(close)
	cart_panel.checkout_requested.connect(_on_checkout_requested)
	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(_on_day_changed)
	simulation.inventory_changed.connect(_on_inventory_changed)

	_on_money_changed(simulation.state.money)

	resized.connect(func(): pivot_offset = size / 2.0)
	visible = false
	modulate.a = 0.0
	scale = CLOSED_SCALE

func _build_catalog() -> void:
	_catalog = _item_db.get_shop_catalog()

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
		# set_pressed_no_signal: the initial category is a silent default, not
		# a real click - button_pressed = true would fire toggled() and play
		# the click SFX/pop animation at game launch, before the shop ever opens.
		first_button.set_pressed_no_signal(true)
	_rebuild_item_grid() # _selected_category already defaults to SEEDS

func _on_category_chosen(category: ItemData.Category) -> void:
	_selected_category = category
	_rebuild_item_grid()

func _rebuild_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	for item: ItemData in _catalog.get(_selected_category, []):
		var card: ItemCard = ItemCardScene.instantiate()
		item_grid.add_child(card)
		var owned_id := item.crop_id if item.category == ItemData.Category.SEEDS else item.id
		card.setup(item, _is_locked(item), _simulation.state.get_inventory_count(owned_id))
		card.add_requested.connect(_on_add_requested)
		card.sell_requested.connect(_on_sell_requested)

## Only SEEDS carry an unlock_day (via their backing CropData) - the other
## categories have no progression gate.
func _is_locked(item: ItemData) -> bool:
	if item.category != ItemData.Category.SEEDS:
		return false
	var crop_data := _simulation.get_crop_data(item.crop_id)
	return crop_data != null and _simulation.state.day < crop_data.unlock_day

func _on_add_requested(item: ItemData, quantity: int) -> void:
	cart_panel.add_item(item, quantity)

## Selling is instant (no cart step) - symmetric to the old per-crop "Vendre"
## button, just generalized to any category via FarmSimulation.sell_item().
func _on_sell_requested(item: ItemData, quantity: int) -> void:
	if item.category == ItemData.Category.SEEDS:
		_shop_controller.sell(item.crop_id, quantity)
	else:
		_shop_controller.sell_item(item.id, item.sell_price, quantity)

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

func _purchase(item: ItemData, quantity: int) -> void:
	if item.category == ItemData.Category.SEEDS:
		_shop_controller.buy_seed(item.crop_id, quantity)
	elif item.category == ItemData.Category.ANIMALS and item.animal_species == AnimalData.Species.CHICKEN:
		_shop_controller.buy_chicken(quantity)
	else:
		_shop_controller.buy_item(item.id, item.price, quantity)

func _on_money_changed(money: int) -> void:
	money_label.text = tr("Argent : %s") % Currency.format(money)

## Cards and the money line are built from translated texts - rebuild them
## after a language switch (static scene texts re-translate on their own).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _simulation != null:
		_on_money_changed(_simulation.state.money)
		_rebuild_item_grid()

## Crop unlock_day gates can flip while the shop happens to be open; cheapest
## correct fix is to just re-lock/unlock the currently visible grid.
func _on_day_changed(_day: int) -> void:
	_rebuild_item_grid()

## Keeps "Tu as : N" and the Sell button's enabled state live while the shop
## is open (e.g. selling one egg should immediately grey out Sell at 0 left).
func _on_inventory_changed(_item_id: String, _amount: int) -> void:
	_rebuild_item_grid()

func open() -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
