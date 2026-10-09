extends Node2D

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

const HOME_SCREEN := "res://ui/home/home_screen.tscn"

## What a brand-new game starts with (a loaded save replaces it entirely).
const STARTER_INVENTORY := {
	"tool_hoe": 1,
	"tool_watering_can": 1,
	"corn_seed": 3,
}

const ANIMAL_RESOURCES: Array[AnimalData] = [
	preload("res://data/animals/chicken.tres"),
]

## Every tree species a WorldTree may point at - fruit trees not listed here
## are shown but never bear fruit (TreeManager warns).
const TREE_RESOURCES: Array[TreeData] = [
	preload("res://data/trees/mango_tree.tres"),
]

@onready var zone_container: Node2D = $ZoneContainer
@onready var player: PlayerController = $Player
@onready var farming_controller: FarmingController = $Gameplay/FarmingController
@onready var shop_controller: ShopController = $Gameplay/ShopController
@onready var save_controller: SaveController = $Gameplay/SaveController
@onready var world_manager: WorldManager = $Gameplay/WorldManager
@onready var animal_manager: AnimalManager = $Gameplay/AnimalManager
@onready var farm_land_manager: FarmLandManager = $Gameplay/FarmLandManager
@onready var tree_manager: TreeManager = $Gameplay/TreeManager
@onready var neighbour_paddies: NeighbourPaddyManager = $Gameplay/NeighbourPaddyManager
@onready var order_manager: OrderManager = $Gameplay/OrderManager
@onready var friendship_manager: FriendshipManager = $Gameplay/FriendshipManager
@onready var day_night: DayNightController = $Gameplay/DayNightController
@onready var weather: WeatherController = $Gameplay/WeatherController
@onready var hotbar: Hotbar = $Gameplay/Hotbar
@onready var hud: HUD = $UI/HUD
@onready var hotbar_ui: HotbarUI = $UI/HotbarUI
@onready var action_prompt: ActionPrompt = $UI/ActionPrompt
@onready var shop_ui: ShopUI = $UI/ShopUI
@onready var inventory_ui: InventoryUI = $UI/InventoryUI
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var orders_tracker: OrdersTracker = $UI/OrdersTracker
@onready var order_panel: OrderPanel = $UI/OrderPanel
@onready var zebu_manager: ZebuManager = $Gameplay/ZebuManager
@onready var zebu_market_panel: ZebuMarketPanel = $UI/ZebuMarketPanel
@onready var school_manager: SchoolManager = $Gameplay/SchoolManager
@onready var school_panel: SchoolPanel = $UI/SchoolPanel
@onready var cockfight_manager: CockfightManager = $Gameplay/CockfightManager
@onready var rooster_panel: RoosterPanel = $UI/RoosterPanel
@onready var cockfight_panel: CockfightPanel = $UI/CockfightPanel

var simulation: FarmSimulation
var item_db: ItemDatabase

func _ready() -> void:
	var crop_registry := {}
	for crop_data in CROP_RESOURCES:
		crop_registry[crop_data.id] = crop_data

	var animal_registry := {}
	for animal_data in ANIMAL_RESOURCES:
		animal_registry[animal_data.species] = animal_data

	var tree_registry := {}
	for tree_data in TREE_RESOURCES:
		tree_registry[tree_data.id] = tree_data

	# No plots yet: the land is painted in the zone scenes as FarmFields
	# (starter field included), registered by FarmLandManager as they load.
	simulation = FarmSimulation.new(0, 0, crop_registry, animal_registry, tree_registry)
	item_db = ItemDatabase.new(crop_registry, animal_registry)
	for item_id in STARTER_INVENTORY:
		simulation.state.add_inventory(item_id, STARTER_INVENTORY[item_id])

	world_manager.setup(simulation, player, zone_container)
	farm_land_manager.setup(simulation, world_manager)
	hotbar.setup(simulation, item_db)
	farming_controller.setup(simulation, player, world_manager, hotbar)
	shop_controller.setup(simulation, farm_land_manager)
	hud.setup(simulation)
	hotbar_ui.setup(hotbar, item_db)
	action_prompt.setup(farming_controller, player)
	shop_ui.setup(shop_controller, simulation, item_db)
	inventory_ui.setup(simulation, shop_ui, item_db, hotbar)
	pause_menu.setup(shop_ui, inventory_ui)
	animal_manager.setup(simulation, world_manager)
	tree_manager.setup(simulation, item_db, world_manager)
	neighbour_paddies.setup(simulation, item_db, world_manager, player)
	friendship_manager.setup(simulation, item_db, world_manager)
	order_manager.setup(simulation, item_db, world_manager, player, order_panel, orders_tracker)
	zebu_manager.setup(simulation, world_manager, zebu_market_panel)
	# After OrderManager: the head teacher greets (OrderManager), then the panel opens.
	school_manager.setup(simulation, item_db, world_manager, school_panel, orders_tracker)
	# After OrderManager too: Rakoto greets, then hands over his rooster.
	cockfight_manager.setup(simulation, item_db, world_manager, rooster_panel, cockfight_panel)
	day_night.setup(simulation, world_manager)
	weather.setup(simulation, world_manager, day_night, player)
	# The slot picked on the home screen (SaveSlots.current); none when the
	# world runs on its own (tests, F6 in the editor): a new game, never saved.
	save_controller.setup(simulation, world_manager, player, SaveSlots.current)

	save_controller.night_saved.connect(func(saved: bool):
		if saved:
			UIEvents.notify(tr("Bonne nuit ! La partie est sauvegardée."))
		elif save_controller.slot >= 0:
			UIEvents.notify(tr("La sauvegarde a échoué : la partie n'a pas pu être enregistrée.")))
	pause_menu.title_requested.connect(func(): get_tree().change_scene_to_file(HOME_SCREEN))
	pause_menu.quit_requested.connect(get_tree().quit)

	if save_controller.has_save():
		save_controller.load_game()
	else:
		world_manager.change_zone("farm", "SpawnDefault")
		# A new game: its slot shows on the home screen from now on.
		save_controller.save_game()
