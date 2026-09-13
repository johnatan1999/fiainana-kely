class_name ShopUI
extends Control

const CROP_ID := "turnip"

@onready var seed_price_label: Label = $Panel/VBoxContainer/SeedPriceLabel
@onready var sell_price_label: Label = $Panel/VBoxContainer/SellPriceLabel
@onready var buy_button: Button = $Panel/VBoxContainer/BuyButton
@onready var sell_button: Button = $Panel/VBoxContainer/SellButton

var _shop_controller: ShopController

func setup(shop_controller: ShopController, simulation: FarmSimulation) -> void:
	_shop_controller = shop_controller
	var crop_data := simulation.get_crop_data(CROP_ID)
	seed_price_label.text = "Graine de navet: %d" % crop_data.seed_price
	sell_price_label.text = "Vente navet: %d" % crop_data.sell_price
	buy_button.pressed.connect(func(): _shop_controller.buy_seed(CROP_ID, 1))
	sell_button.pressed.connect(func(): _shop_controller.sell(CROP_ID, 1))
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_shop"):
		visible = not visible
