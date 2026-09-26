extends Node2D

const GRID_WIDTH := 4
const GRID_HEIGHT := 4

const CROP_RESOURCES: Array[CropData] = [
	preload("res://data/crops/corn.tres"),
	preload("res://data/crops/cassava.tres"),
	preload("res://data/crops/sweet_potato.tres"),
	preload("res://data/crops/rice.tres"),
	preload("res://data/crops/bean.tres"),
	preload("res://data/crops/groundnut.tres"),
	preload("res://data/crops/tomato.tres"),
	preload("res://data/crops/potato.tres"),
	preload("res://data/crops/coffee.tres"),
	preload("res://data/crops/clove.tres"),
	preload("res://data/crops/vanilla.tres"),
	preload("res://data/crops/litchi.tres"),
]

const ANIMAL_RESOURCES: Array[AnimalData] = [
	preload("res://data/animals/chicken.tres"),
]

@onready var zone_container: Node2D = $ZoneContainer
@onready var player: PlayerController = $Player
@onready var farming_controller: FarmingController = $Gameplay/FarmingController
@onready var shop_controller: ShopController = $Gameplay/ShopController
@onready var save_controller: SaveController = $Gameplay/SaveController
@onready var world_manager: WorldManager = $Gameplay/WorldManager
@onready var animal_manager: AnimalManager = $Gameplay/AnimalManager
@onready var farm_land_manager: FarmLandManager = $Gameplay/FarmLandManager
@onready var hud: HUD = $UI/HUD
@onready var shop_ui: ShopUI = $UI/ShopUI
@onready var inventory_ui: InventoryUI = $UI/InventoryUI
@onready var pause_menu: PauseMenu = $UI/PauseMenu

var simulation: FarmSimulation
var item_db: ItemDatabase

func _ready() -> void:
	var crop_registry := {}
	for crop_data in CROP_RESOURCES:
		crop_registry[crop_data.id] = crop_data

	var animal_registry := {}
	for animal_data in ANIMAL_RESOURCES:
		animal_registry[animal_data.species] = animal_data

	simulation = FarmSimulation.new(GRID_WIDTH, GRID_HEIGHT, crop_registry, animal_registry)
	item_db = ItemDatabase.new(crop_registry, animal_registry)
	simulation.state.add_inventory("corn_seed", 3)

	world_manager.setup(simulation, player, zone_container)
	farm_land_manager.setup(simulation, world_manager)
	farming_controller.setup(simulation, player, world_manager)
	shop_controller.setup(simulation, farm_land_manager)
	hud.setup(simulation, player, farming_controller)
	shop_ui.setup(shop_controller, simulation, item_db)
	inventory_ui.setup(simulation, shop_ui, item_db)
	pause_menu.setup(shop_ui, inventory_ui)
	animal_manager.setup(simulation, world_manager)
	save_controller.setup(simulation, world_manager, player)

	pause_menu.save_requested.connect(save_controller.save_game)
	pause_menu.quit_requested.connect(get_tree().quit)

	if save_controller.has_save():
		save_controller.load_game()
	else:
		world_manager.change_zone("village", "SpawnDefault")
