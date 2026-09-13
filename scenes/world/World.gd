extends Node2D

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const TurnipData := preload("res://data/crops/turnip.tres")

@onready var zone_container: Node2D = $ZoneContainer
@onready var player: PlayerController = $Player
@onready var farming_controller: FarmingController = $Gameplay/FarmingController
@onready var shop_controller: ShopController = $Gameplay/ShopController
@onready var save_controller: SaveController = $Gameplay/SaveController
@onready var world_manager: WorldManager = $Gameplay/WorldManager
@onready var hud: HUD = $UI/HUD
@onready var shop_ui: ShopUI = $UI/ShopUI
@onready var pause_menu: PauseMenu = $UI/PauseMenu

var simulation: FarmSimulation

func _ready() -> void:
	simulation = FarmSimulation.new(GRID_WIDTH, GRID_HEIGHT, {"turnip": TurnipData})
	simulation.state.add_inventory("turnip_seed", 3)

	farming_controller.setup(simulation, player)
	shop_controller.setup(simulation)
	save_controller.setup(simulation)
	hud.setup(simulation, player)
	shop_ui.setup(shop_controller, simulation)
	pause_menu.setup(shop_ui)
	world_manager.setup(simulation, player, farming_controller, shop_ui, zone_container)

	pause_menu.save_requested.connect(save_controller.save_game)
	pause_menu.quit_requested.connect(get_tree().quit)

	if save_controller.has_save():
		save_controller.load_game()

	world_manager.change_zone("house", "SpawnDefault")
