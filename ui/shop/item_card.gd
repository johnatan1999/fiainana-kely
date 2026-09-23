class_name ItemCard
extends PanelContainer

## One purchasable item tile in the shop grid. Self-contained: owns its own
## quantity stepper and fires add_requested when the player commits to a
## quantity - ShopUI/CartPanel never reach into its internals.

const HOVER_SCALE := Vector2(1.05, 1.05)
const HOVER_TIME := 0.12
const POP_SCALE := Vector2(0.9, 0.9)
const POP_TIME := 0.08
const MAX_QUANTITY := 99

const CATEGORY_PLACEHOLDER_COLORS := {
	ShopItemData.Category.SEEDS: Color(0.45, 0.65, 0.25),
	ShopItemData.Category.TOOLS: Color(0.55, 0.5, 0.45),
	ShopItemData.Category.FOOD: Color(0.75, 0.5, 0.2),
	ShopItemData.Category.ANIMALS: Color(0.6, 0.4, 0.25),
}

signal add_requested(item: ShopItemData, quantity: int)
signal sell_requested(item: ShopItemData, quantity: int)

@onready var icon_rect: TextureRect = %IconRect
@onready var icon_placeholder: ColorRect = %IconPlaceholder
@onready var name_label: Label = %NameLabel
@onready var malagasy_label: Label = %MalagasyLabel
@onready var description_label: Label = %DescriptionLabel
@onready var price_label: Label = %PriceLabel
@onready var minus_button: Button = %MinusButton
@onready var quantity_label: Label = %QuantityLabel
@onready var plus_button: Button = %PlusButton
@onready var add_button: Button = %AddButton
@onready var owned_label: Label = %OwnedLabel
@onready var sell_button: Button = %SellButton
@onready var qty_row: HBoxContainer = %QtyRow

var _item: ShopItemData
var _quantity: int = 1
var _hover_tween: Tween

func _ready() -> void:
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	minus_button.pressed.connect(_on_minus_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	add_button.pressed.connect(_on_add_pressed)
	sell_button.pressed.connect(_on_sell_pressed)

## locked = true when the item's unlock_day hasn't been reached yet: shown,
## greyed out, and non-interactive rather than hidden, so the player knows
## it exists and can plan for it. owned_count drives the "Tu as: N" label and
## whether the Sell button is enabled.
func setup(item: ShopItemData, locked: bool = false, owned_count: int = 0) -> void:
	_item = item
	_quantity = 1

	name_label.text = item.display_name
	malagasy_label.text = item.malagasy_name
	description_label.text = item.description
	owned_label.text = "Tu as: %d" % owned_count

	if item.icon:
		icon_rect.texture = item.icon
		icon_rect.visible = true
		icon_placeholder.visible = false
	else:
		icon_rect.visible = false
		icon_placeholder.visible = true
		icon_placeholder.color = CATEGORY_PLACEHOLDER_COLORS.get(item.category, Color.GRAY)

	# price <= 0 marks a sell-only entry (e.g. eggs): hide the buy controls
	# entirely instead of showing a misleading "Acheter" for 0 $.
	var buyable := item.price > 0
	price_label.visible = buyable
	price_label.text = Currency.format(item.price)
	qty_row.visible = buyable
	add_button.visible = buyable

	sell_button.visible = item.sell_price > 0
	sell_button.text = "Vendre 1 (%s)" % Currency.format(item.sell_price)
	sell_button.disabled = owned_count <= 0

	_refresh_quantity_label()
	_set_locked(locked)

func _set_locked(locked: bool) -> void:
	modulate = Color(1, 1, 1, 0.4) if locked else Color(1, 1, 1, 1)
	minus_button.disabled = locked
	plus_button.disabled = locked
	add_button.disabled = locked
	add_button.text = "Verrouillé" if locked else "Ajouter"

func _refresh_quantity_label() -> void:
	quantity_label.text = str(_quantity)

func _on_minus_pressed() -> void:
	if _quantity <= 1:
		return
	AudioManager.play_click_menu_sfx()
	_quantity -= 1
	_refresh_quantity_label()

func _on_plus_pressed() -> void:
	if _quantity >= MAX_QUANTITY:
		return
	AudioManager.play_click_menu_sfx()
	_quantity += 1
	_refresh_quantity_label()

func _on_add_pressed() -> void:
	AudioManager.play_click_menu_sfx()
	_play_pop()
	add_requested.emit(_item, _quantity)

func _on_sell_pressed() -> void:
	AudioManager.play_click_menu_sfx()
	_play_pop()
	sell_requested.emit(_item, 1)

func _on_mouse_entered() -> void:
	if add_button.disabled:
		return
	_animate_scale(HOVER_SCALE, HOVER_TIME)

func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE, HOVER_TIME)

func _play_pop() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", POP_SCALE, POP_TIME)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, POP_TIME)

func _animate_scale(target: Vector2, time: float) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, time).set_trans(Tween.TRANS_SINE)
