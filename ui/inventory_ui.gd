class_name InventoryUI
extends Control

## Read-only view of everything in FarmState.inventory - seeds, harvested
## crops, eggs, unplaced chickens, purchased tools/food. Resolves each raw
## item_id to a display name/color/icon by reusing the same registries the
## Shop already built (CropData via FarmSimulation, and ShopUI's non-crop
## catalog + ItemCard's placeholder colors) so nothing drifts out of sync.

const SlotScene := preload("res://ui/inventory/inventory_slot.tscn")

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.14
const CLOSED_SCALE := Vector2(0.9, 0.9)

@onready var money_label: Label = %MoneyLabel
@onready var close_button: Button = %CloseButton
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel

var _simulation: FarmSimulation
var _shop_ui: ShopUI
var _open_tween: Tween

func setup(simulation: FarmSimulation, shop_ui: ShopUI) -> void:
	_simulation = simulation
	_shop_ui = shop_ui

	# Reste actif malgré get_tree().paused = true (voir open()/close()) - sinon
	# son propre bouton et son tween d'ouverture/fermeture se figeraient aussi.
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_button.pressed.connect(close)
	simulation.money_changed.connect(_on_money_changed)
	simulation.inventory_changed.connect(_on_inventory_changed)
	_on_money_changed(simulation.state.money)

	resized.connect(func(): pivot_offset = size / 2.0)
	visible = false
	modulate.a = 0.0
	scale = CLOSED_SCALE

func _on_money_changed(money: int) -> void:
	money_label.text = "Argent: %s" % Currency.format(money)

## Only rebuilds while actually visible - no point re-resolving every icon
## on every purchase/harvest while the player isn't even looking at it.
func _on_inventory_changed(_item_id: String, _amount: int) -> void:
	if visible:
		_rebuild()

func _rebuild() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	var item_ids := _simulation.state.inventory.keys()
	item_ids.sort()

	var shown := 0
	for item_id in item_ids:
		var quantity: int = _simulation.state.inventory[item_id]
		if quantity <= 0:
			continue
		var info := _describe_item(item_id)
		var slot: InventorySlot = SlotScene.instantiate()
		item_grid.add_child(slot)
		slot.setup(info.name, info.malagasy_name, quantity, info.color, info.icon)
		shown += 1

	empty_label.visible = shown == 0

func _describe_item(item_id: String) -> Dictionary:
	if item_id == "chicken_unplaced":
		return {
			"name": "Poule (à placer)",
			"malagasy_name": "Akoho",
			"color": ItemCard.CATEGORY_PLACEHOLDER_COLORS[ShopItemData.Category.ANIMALS],
			"icon": null,
		}

	if item_id.ends_with("_seed"):
		var crop_id := item_id.substr(0, item_id.length() - len("_seed"))
		var seed_crop_data := _simulation.get_crop_data(crop_id)
		if seed_crop_data != null:
			return {
				"name": "Graine de %s" % seed_crop_data.display_name,
				"malagasy_name": seed_crop_data.malagasy_name,
				"color": ItemCard.CATEGORY_PLACEHOLDER_COLORS[ShopItemData.Category.SEEDS],
				"icon": seed_crop_data.icon,
			}

	var crop_data := _simulation.get_crop_data(item_id)
	if crop_data != null:
		return {
			"name": crop_data.display_name,
			"malagasy_name": crop_data.malagasy_name,
			"color": ItemCard.CATEGORY_PLACEHOLDER_COLORS[ShopItemData.Category.SEEDS],
			"icon": crop_data.icon,
		}

	for shop_item: ShopItemData in ShopUI.TOOLS_FOOD_ANIMALS_RESOURCES:
		if shop_item.id == item_id:
			return {
				"name": shop_item.display_name,
				"malagasy_name": shop_item.malagasy_name,
				"color": ItemCard.CATEGORY_PLACEHOLDER_COLORS.get(shop_item.category, Color.GRAY),
				"icon": shop_item.icon,
			}

	return {"name": item_id, "malagasy_name": "", "color": Color.GRAY, "icon": null}

func open() -> void:
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
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
