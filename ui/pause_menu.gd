class_name PauseMenu
extends Control

## No "save" here: the game saves when the player goes to bed (see
## SaveController). Leaving during the day goes back to that morning - the
## menu asks for a second press to be sure.
signal title_requested
signal quit_requested

const LEAVE_WARNING := "Sans sauvegarder ? Confirmer"

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var title_button: Button = $Panel/VBoxContainer/TitleButton
@onready var language_button: Button = $Panel/VBoxContainer/LanguageButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var _shop_ui: ShopUI
var _inventory_ui: InventoryUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		_close()
	)

	title_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		if _confirm(title_button, "Menu principal"):
			_close()
			title_requested.emit()
	)

	# Cycles Français -> Malagasy -> English; saved right away by GameSettings.
	language_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		GameSettings.cycle_locale()
	)
	_refresh_language_button()

	quit_button.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		if _confirm(quit_button, "Quitter"):
			quit_requested.emit()
	)
	visible = false

## The language name itself is never translated (see GameSettings.LOCALE_NAMES),
## only the "Langue : %s" template around it.
func _refresh_language_button() -> void:
	language_button.text = tr("Langue : %s") % GameSettings.get_locale_name()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language_button()

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
	_reset_confirmations()

## Leaving loses the day: the first press asks (the button says so), the
## second does it. Returns whether it's confirmed.
func _confirm(button: Button, label: String) -> bool:
	if button.has_meta("armed"):
		_reset_confirmations()
		return true
	_reset_confirmations()
	button.set_meta("armed", label)
	button.text = tr(LEAVE_WARNING)
	return false

func _reset_confirmations() -> void:
	for button in [title_button, quit_button]:
		if button.has_meta("armed"):
			button.text = tr(button.get_meta("armed"))
			button.remove_meta("armed")
