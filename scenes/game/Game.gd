extends Node2D

const GRID_WIDTH := 3
const GRID_HEIGHT := 3
const TurnipData := preload("res://data/crops/turnip.tres")

@onready var farm_view: FarmView = $World/FarmView
@onready var player: PlayerController = $World/Player
@onready var farming_controller: FarmingController = $Gameplay/FarmingController
@onready var shop_controller: ShopController = $Gameplay/ShopController
@onready var save_controller: SaveController = $Gameplay/SaveController
@onready var hud: HUD = $UI/HUD
@onready var shop_ui: ShopUI = $UI/ShopUI

var simulation: FarmSimulation

func _ready() -> void:
	simulation = FarmSimulation.new(GRID_WIDTH, GRID_HEIGHT, {"turnip": TurnipData})
	simulation.state.add_inventory("turnip_seed", 3)

	farm_view.setup(simulation)
	farming_controller.setup(simulation, player, farm_view)
	shop_controller.setup(simulation)
	save_controller.setup(simulation)
	hud.setup(simulation, player)
	shop_ui.setup(shop_controller, simulation)

	hud.sleep_requested.connect(farming_controller.advance_day)
	hud.save_requested.connect(save_controller.save_game)
	hud.load_requested.connect(save_controller.load_game)

	if save_controller.has_save():
		save_controller.load_game()
