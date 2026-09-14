class_name HUD
extends Control

const TOOL_NAMES := {
	PlayerController.Tool.HOE: "Houe",
	PlayerController.Tool.WATERING_CAN: "Arrosoir",
	PlayerController.Tool.SEEDS: "Graines",
	PlayerController.Tool.HARVEST: "Récolte",
}

const SEASON_NAMES := {
	GameClock.Season.ASARA: "Asara",
	GameClock.Season.ASOTRY: "Asotry",
}

@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var season_label: Label = $VBoxContainer/SeasonLabel
@onready var money_label: Label = $VBoxContainer/MoneyLabel
@onready var seeds_label: Label = $VBoxContainer/SeedsLabel
@onready var crops_label: Label = $VBoxContainer/CropsLabel
@onready var tool_label: Label = $VBoxContainer/ToolLabel

var _simulation: FarmSimulation
var _player: PlayerController
var _farming_controller: FarmingController
var _selected_crop_id: String

func setup(simulation: FarmSimulation, player: PlayerController, farming_controller: FarmingController) -> void:
	_simulation = simulation
	_player = player
	_farming_controller = farming_controller
	_selected_crop_id = farming_controller.selected_crop_id

	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(_on_day_changed)
	simulation.inventory_changed.connect(_on_inventory_changed)
	player.tool_changed.connect(_on_tool_changed)
	farming_controller.crop_selected.connect(_on_crop_selected)

	_refresh_all()

func _refresh_all() -> void:
	_on_day_changed(_simulation.state.day)
	_on_money_changed(_simulation.state.money)
	_refresh_crop_labels()
	_on_tool_changed(_player.current_tool)

func _on_day_changed(day: int) -> void:
	day_label.text = "Jour %d" % day
	season_label.text = "Saison: %s" % SEASON_NAMES.get(_simulation.state.clock.get_season(), "?")

func _on_money_changed(money: int) -> void:
	money_label.text = "Argent: %d $" % money

func _on_inventory_changed(item_id: String, _amount: int) -> void:
	if item_id == _selected_crop_id or item_id == _selected_crop_id + "_seed":
		_refresh_crop_labels()

func _on_crop_selected(crop_id: String) -> void:
	_selected_crop_id = crop_id
	_refresh_crop_labels()

func _refresh_crop_labels() -> void:
	var crop_data := _simulation.get_crop_data(_selected_crop_id)
	var display_name := crop_data.display_name if crop_data else _selected_crop_id
	var seed_count := _simulation.state.get_inventory_count(_selected_crop_id + "_seed")
	var crop_count := _simulation.state.get_inventory_count(_selected_crop_id)
	seeds_label.text = "Graines (%s): %d" % [display_name, seed_count]
	crops_label.text = "Récolte (%s): %d" % [display_name, crop_count]

func _on_tool_changed(tool: PlayerController.Tool) -> void:
	tool_label.text = "Outil: %s" % TOOL_NAMES.get(tool, "?")
