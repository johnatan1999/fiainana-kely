class_name ShopUI
extends Control

const CROP_ID := "turnip"

@onready var seed_price_label: Label = $Panel/VBoxContainer/SeedPriceLabel
@onready var sell_price_label: Label = $Panel/VBoxContainer/SellPriceLabel
@onready var money_label: Label = $Panel/VBoxContainer/MoneyLabel
@onready var buy_button: Button = $Panel/VBoxContainer/BuyButton
@onready var sell_button: Button = $Panel/VBoxContainer/SellButton
@onready var sell_all_button: Button = $Panel/VBoxContainer/SellAllButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var _shop_controller: ShopController
var _simulation: FarmSimulation

func setup(shop_controller: ShopController, simulation: FarmSimulation) -> void:
	_shop_controller = shop_controller
	_simulation = simulation
	var crop_data := simulation.get_crop_data(CROP_ID)
	seed_price_label.text = "Graine de navet: %d $" % crop_data.seed_price
	sell_price_label.text = "Prix navet: %d $" % crop_data.sell_price
	buy_button.pressed.connect(func(): _shop_controller.buy_seed(CROP_ID, 1))
	sell_button.pressed.connect(func(): _shop_controller.sell(CROP_ID, 1))
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	close_button.pressed.connect(close)
	simulation.money_changed.connect(_on_money_changed)
	_on_money_changed(simulation.state.money)
	visible = false

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _on_sell_all_pressed() -> void:
	var quantity := _simulation.state.get_inventory_count(CROP_ID)
	if quantity > 0:
		_shop_controller.sell(CROP_ID, quantity)

func _on_money_changed(money: int) -> void:
	money_label.text = "Argent: %d $" % money

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
