class_name FarmZoneSign
extends Node2D

## Physical, self-contained purchase panel for one predefined (macro)
## farmable land zone. Player interacts (E) to open its own popup dialog -
## "Acheter" calls the exact same FarmLandManager.buy_zone() the old Shop
## integration used, so nothing about the underlying economy rules changes,
## only where the player triggers them from.

@export var zone_id: String = ""

@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var world_label: Label = $WorldLabel
@onready var dialog: CanvasLayer = $Dialog
@onready var name_label: Label = $Dialog/Panel/Margin/VBox/NameLabel
@onready var price_label: Label = $Dialog/Panel/Margin/VBox/PriceLabel
@onready var description_label: Label = $Dialog/Panel/Margin/VBox/DescriptionLabel
@onready var status_label: Label = $Dialog/Panel/Margin/VBox/StatusLabel
@onready var buy_button: Button = $Dialog/Panel/Margin/VBox/ButtonRow/BuyButton
@onready var cancel_button: Button = $Dialog/Panel/Margin/VBox/ButtonRow/CancelButton

var _farm_land_manager: FarmLandManager

func setup(zone_manager: FarmLandManager) -> void:
	_farm_land_manager = zone_manager

	interactable_component.interacted.connect(_on_interacted)
	buy_button.pressed.connect(_on_buy_pressed)
	cancel_button.pressed.connect(_close_dialog)
	_farm_land_manager.zone_unlocked.connect(_on_zone_unlocked)

	dialog.visible = false
	_refresh_world_label()

func _refresh_world_label() -> void:
	var zone_data := _farm_land_manager.get_zone_data(zone_id)
	if zone_data == null:
		world_label.text = "?"
		return
	world_label.text = ("%s (débloqué)" % zone_data.display_name) if _farm_land_manager.is_zone_unlocked(zone_id) else "%s (E)" % zone_data.display_name

func _on_zone_unlocked(unlocked_zone_id: String) -> void:
	if unlocked_zone_id == zone_id:
		_refresh_world_label()

func _on_interacted() -> void:
	if not dialog.visible:
		_open_dialog()

func _open_dialog() -> void:
	var zone_data := _farm_land_manager.get_zone_data(zone_id)
	if zone_data == null:
		return

	name_label.text = zone_data.display_name
	price_label.text = "%d $" % zone_data.price
	description_label.text = "%s (%d parcelles)" % [zone_data.description, zone_data.get_tile_count()]

	var already_unlocked := _farm_land_manager.is_zone_unlocked(zone_id)
	status_label.text = "Déjà débloqué." if already_unlocked else ""
	buy_button.disabled = already_unlocked
	buy_button.text = "Déjà acheté" if already_unlocked else "Acheter"

	dialog.visible = true
	AudioManager.play_click_menu_sfx()

func _close_dialog() -> void:
	dialog.visible = false

func _on_buy_pressed() -> void:
	var zone_data := _farm_land_manager.get_zone_data(zone_id)
	if zone_data == null:
		return

	if _farm_land_manager.buy_zone(zone_id):
		status_label.text = "%s débloqué !" % zone_data.display_name
		buy_button.disabled = true
		buy_button.text = "Déjà acheté"
		AudioManager.play_coop_build_sfx()
		_play_unlock_animation()
	else:
		status_label.text = "Fonds insuffisants !"
		AudioManager.play_click_menu_sfx()

func _play_unlock_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func _unhandled_input(event: InputEvent) -> void:
	if dialog.visible and event.is_action_pressed("ui_cancel"):
		_close_dialog()
		get_viewport().set_input_as_handled()
