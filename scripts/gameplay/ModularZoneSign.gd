class_name ModularZoneSign
extends Area2D

## Physical, self-contained purchase panel for the modulable expansion zone
## (micro progression). Player interacts (E) to open a menu of fixed patch
## sizes - buying always calls the exact same
## ZoneManager.buy_progressive_patch() the old Shop integration used, which
## unlocks the next tiles in automatic order. The player never picks where.

const PATCH_OPTIONS := [
	{"label": "Acheter 1 parcelle", "size": 1, "price": 15},
	{"label": "Acheter patch 3x3 (9 parcelles)", "size": 9, "price": 110},
	{"label": "Acheter patch 5x5 (25 parcelles)", "size": 25, "price": 280},
]

@onready var world_label: Label = $WorldLabel
@onready var dialog: CanvasLayer = $Dialog
@onready var progress_label: Label = $Dialog/Panel/Margin/VBox/ProgressLabel
@onready var status_label: Label = $Dialog/Panel/Margin/VBox/StatusLabel
@onready var option_buttons_container: VBoxContainer = $Dialog/Panel/Margin/VBox/OptionButtons
@onready var cancel_button: Button = $Dialog/Panel/Margin/VBox/CancelButton

var _player: PlayerController
var _zone_manager: ZoneManager
var _player_inside := false
var _option_buttons: Array = []

func setup(player: PlayerController, zone_manager: ZoneManager) -> void:
	_player = player
	_zone_manager = zone_manager

	_player.interact_requested.connect(_on_interact_requested)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	cancel_button.pressed.connect(_close_dialog)
	_zone_manager.progressive_tiles_changed.connect(_on_progressive_tiles_changed)

	_build_option_buttons()
	dialog.visible = false
	_refresh_world_label()

func _build_option_buttons() -> void:
	for option in PATCH_OPTIONS:
		var button := Button.new()
		button.text = "%s — %d $" % [option["label"], option["price"]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_patch_pressed.bind(option))
		option_buttons_container.add_child(button)
		_option_buttons.append(button)

func _refresh_world_label() -> void:
	world_label.text = "Zone d'expansion : %d/%d (E)" % [
		_zone_manager.get_progressive_unlocked_count(), _zone_manager.get_progressive_capacity(),
	]

func _on_progressive_tiles_changed(_count: int) -> void:
	_refresh_world_label()

func _on_body_entered(body: Node) -> void:
	if body == _player:
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player_inside = false
		_close_dialog()

func _on_interact_requested(_tool) -> void:
	if _player_inside and not dialog.visible:
		_open_dialog()

func _open_dialog() -> void:
	status_label.text = ""
	_refresh_progress_label()
	_refresh_option_buttons()
	dialog.visible = true
	AudioManager.play_click_menu_sfx()

func _refresh_progress_label() -> void:
	progress_label.text = "Zone d'expansion : %d / %d parcelles" % [
		_zone_manager.get_progressive_unlocked_count(), _zone_manager.get_progressive_capacity(),
	]

## Greys out any patch bigger than what's actually left in the zone - the
## player can still see it exists, they just can't afford the tiles to fit it.
func _refresh_option_buttons() -> void:
	var remaining := _zone_manager.get_progressive_capacity() - _zone_manager.get_progressive_unlocked_count()
	for i in _option_buttons.size():
		var option: Dictionary = PATCH_OPTIONS[i]
		_option_buttons[i].disabled = option["size"] > remaining

func _close_dialog() -> void:
	dialog.visible = false

func _on_patch_pressed(option: Dictionary) -> void:
	if _zone_manager.buy_progressive_patch(option["size"], option["price"]):
		status_label.text = "%d parcelle(s) débloquée(s) !" % option["size"]
		AudioManager.play_coop_build_sfx()
		_play_unlock_animation()
		_refresh_progress_label()
		_refresh_option_buttons()
	else:
		status_label.text = "Fonds insuffisants ou capacité atteinte !"
		AudioManager.play_click_menu_sfx()

func _play_unlock_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func _unhandled_input(event: InputEvent) -> void:
	if dialog.visible and event.is_action_pressed("ui_cancel"):
		_close_dialog()
		get_viewport().set_input_as_handled()
