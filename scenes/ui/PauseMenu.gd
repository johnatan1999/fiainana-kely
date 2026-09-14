class_name PauseMenu
extends Control

signal save_requested
signal quit_requested

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var _shop_ui: ShopUI
var _inventory_ui: InventoryUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		_close()
	)

	save_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		save_requested.emit()
		_close()
	)

	quit_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		quit_requested.emit()
	)
	visible = false

func setup(shop_ui: ShopUI, inventory_ui: InventoryUI) -> void:
	_shop_ui = shop_ui
	_inventory_ui = inventory_ui

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not visible and _shop_ui != null and _shop_ui.visible:
		return # let the shop handle Escape first
	if not visible and _inventory_ui != null and _inventory_ui.visible:
		return # let the inventory handle Escape first
	if visible:
		_close()
	else:
		_open()
	get_viewport().set_input_as_handled()

func _open() -> void:
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	get_tree().paused = false
