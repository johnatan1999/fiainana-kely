class_name HUD
extends Control

signal sleep_requested
signal save_requested
signal load_requested

const TOOL_NAMES := {
	PlayerController.Tool.HOE: "Houe",
	PlayerController.Tool.WATERING_CAN: "Arrosoir",
	PlayerController.Tool.SEEDS: "Graines",
	PlayerController.Tool.HARVEST: "Récolte",
}

@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var money_label: Label = $VBoxContainer/MoneyLabel
@onready var seeds_label: Label = $VBoxContainer/SeedsLabel
@onready var crops_label: Label = $VBoxContainer/CropsLabel
@onready var tool_label: Label = $VBoxContainer/ToolLabel
@onready var sleep_button: Button = $VBoxContainer/SleepButton
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/LoadButton

var _simulation: FarmSimulation
var _player: PlayerController

func setup(simulation: FarmSimulation, player: PlayerController) -> void:
	_simulation = simulation
	_player = player
	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(_on_day_changed)
	simulation.inventory_changed.connect(_on_inventory_changed)
	player.tool_changed.connect(_on_tool_changed)
	sleep_button.pressed.connect(func(): sleep_requested.emit())
	save_button.pressed.connect(func(): save_requested.emit())
	load_button.pressed.connect(func(): load_requested.emit())
	_refresh_all()

func _refresh_all() -> void:
	_on_day_changed(_simulation.state.day)
	_on_money_changed(_simulation.state.money)
	_on_inventory_changed("turnip_seed", _simulation.state.get_inventory_count("turnip_seed"))
	_on_inventory_changed("turnip", _simulation.state.get_inventory_count("turnip"))
	_on_tool_changed(_player.current_tool)

func _on_day_changed(day: int) -> void:
	day_label.text = "Jour %d" % day

func _on_money_changed(money: int) -> void:
	money_label.text = "Argent: %d" % money

func _on_inventory_changed(item_id: String, amount: int) -> void:
	if item_id == "turnip_seed":
		seeds_label.text = "Graines de navet: %d" % amount
	elif item_id == "turnip":
		crops_label.text = "Navets: %d" % amount

func _on_tool_changed(tool: PlayerController.Tool) -> void:
	tool_label.text = "Outil: %s" % TOOL_NAMES.get(tool, "?")
