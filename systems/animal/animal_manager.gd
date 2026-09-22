class_name AnimalManager
extends Node

## Bridges FarmSimulation's animal state to the Chicken/Egg nodes actually
## visible in whichever zone currently has a Coop (the Exterior yard) -
## mirrors FarmingController's relationship to FarmView. Never enforces
## rules itself, only spawns/despawns nodes to match what FarmSimulation
## already decided.

const ChickenScene := preload("res://entities/animals/chicken/chicken.tscn")
const EggScene := preload("res://entities/animals/chicken/egg.tscn")

var simulation: FarmSimulation
var player: PlayerController
var farm_area: Node # the zone currently containing a Coop, or null

var _coop: Coop
var _feeding_bowl: FeedingBowl
var _water_bowl: WaterBowl
var _animal_container: Node2D

var _chicken_nodes: Dictionary = {} # animal_id: String -> Chicken
## product_ids whose product_ready fired while no Coop-bearing zone was
## loaded to spawn them into - flushed the next time set_farm_area()
## activates one. Note: this queue is intentionally not persisted across a
## save/quit, so an egg that became ready right before quitting without ever
## revisiting the yard can be lost - accepted as a minor edge case.
var _pending_products: Array = []

func setup(p_simulation: FarmSimulation, p_player: PlayerController) -> void:
	simulation = p_simulation
	player = p_player
	simulation.animal_added.connect(_on_animal_added)
	simulation.product_ready.connect(_on_product_ready)

## Called by WorldManager whenever a zone with a Coop child is loaded/unloaded.
func set_farm_area(p_zone: Node) -> void:
	farm_area = p_zone
	_chicken_nodes.clear() # the previous zone's nodes were freed with it
	if farm_area == null:
		_coop = null
		_feeding_bowl = null
		_water_bowl = null
		_animal_container = null
		return

	_coop = farm_area.get_node("ChickenCoop")
	_feeding_bowl = farm_area.get_node("FeedingBowl")
	_water_bowl = farm_area.get_node("WaterBowl")
	_animal_container = farm_area.get_node("AnimalContainer")
	_coop.setup(player, self)
	#_feeding_bowl.setup(player)
	#_water_bowl.setup(player)

	for animal_id in simulation.get_all_animal_ids():
		_spawn_chicken(animal_id)
	_flush_pending_products()

func interact_with_coop(coop: Coop) -> void:
	if not simulation.state.has_coop:
		if simulation.build_coop():
			AudioManager.play_coop_build_sfx()
			coop.refresh_visual()
		return
	if simulation.place_chicken() != "":
		AudioManager.play_click_menu_sfx()
	# place_chicken() already fired animal_added -> _spawn_chicken(); nothing
	# else to do here even on success.

func feed_animal(animal_id: String) -> void:
	if simulation.feed_animal(animal_id):
		AudioManager.play_chicken_sfx()

func water_animal(animal_id: String) -> void:
	simulation.water_animal(animal_id)

func get_feeding_bowl() -> FeedingBowl:
	return _feeding_bowl

func get_water_bowl() -> WaterBowl:
	return _water_bowl

func _on_animal_added(animal_id: String) -> void:
	if farm_area == null:
		return # spawned instead when the zone is next loaded
	_spawn_chicken(animal_id)

func _spawn_chicken(animal_id: String) -> void:
	if _chicken_nodes.has(animal_id) or simulation.get_animal(animal_id) == null:
		return
	var chicken: Chicken = ChickenScene.instantiate()
	_animal_container.add_child(chicken)
	chicken.global_position = _coop.global_position
	chicken.setup(self, animal_id)
	_chicken_nodes[animal_id] = chicken

func _on_product_ready(_animal_id: String, product_id: String) -> void:
	if farm_area == null:
		_pending_products.append(product_id)
		return
	_spawn_egg(product_id)

func _flush_pending_products() -> void:
	for product_id in _pending_products:
		_spawn_egg(product_id)
	_pending_products.clear()

func _spawn_egg(product_id: String) -> void:
	var egg: Egg = EggScene.instantiate()
	_animal_container.add_child(egg)
	var scatter := Vector2(randf_range(-20.0, 20.0), randf_range(20.0, 40.0))
	egg.global_position = _coop.global_position + scatter
	egg.setup(simulation, product_id)
