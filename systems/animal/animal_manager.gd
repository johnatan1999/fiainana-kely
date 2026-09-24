class_name AnimalManager
extends Node

## Bridges FarmSimulation's animal state to the Chicken/Egg nodes actually
## visible in whichever zone currently has a Coop (the Exterior yard) -
## mirrors FarmingController's relationship to FarmView. Never enforces
## rules itself, only spawns/despawns nodes to match what FarmSimulation
## already decided.

const EggScene := preload("res://entities/animals/chicken/egg.tscn")

## Spawn placement inside the zone's ChickenArea: at least this far from
## every other animal and from the bowls (their origin), so nobody starts
## stacked or wedged against a bowl. Falls back to the least-crowded
## candidate if the area is too full to honor it.
const SPAWN_MIN_SPACING := 20.0
const SPAWN_BOWL_CLEARANCE := 30.0
const SPAWN_CANDIDATES := 30
## Used only if a coop zone has no ChickenArea node.
const FALLBACK_AREA_HALF_SIZE := Vector2(60, 40)

## Species -> the scene AnimalManager instantiates for it. Chicken is the only
## one with real art/AI today; buy_animal()/place_animal() in FarmSimulation
## already work for any species, so supporting a new one here later is just
## adding its scene to this table, not rewriting the spawn logic below.
const SPECIES_SCENES := {
	AnimalData.Species.CHICKEN: preload("res://entities/animals/chicken/chicken.tscn"),
}

var simulation: FarmSimulation
var farm_area: Node # the zone currently containing a Coop, or null

var _coop: Coop
var _feeding_bowl: FeedingBowl
var _water_bowl: WaterBowl
var _animal_container: Node2D
## Global rect animals spawn and wander in - the zone's ChickenArea
## ReferenceRect (drawn and resizable in the editor, invisible in game).
var _animal_area: Rect2

var _animal_nodes: Dictionary = {} # animal_id: String -> Node2D
## product_ids whose product_ready fired while no Coop-bearing zone was
## loaded to spawn them into - flushed the next time set_farm_area()
## activates one. Note: this queue is intentionally not persisted across a
## save/quit, so an egg that became ready right before quitting without ever
## revisiting the yard can be lost - accepted as a minor edge case.
var _pending_products: Array = []

func setup(p_simulation: FarmSimulation, p_world_manager: WorldManager) -> void:
	simulation = p_simulation
	simulation.animal_added.connect(_on_animal_added)
	simulation.product_ready.connect(_on_product_ready)
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(_on_zone_unloading)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	if zone.get_node_or_null("ChickenCoop"):
		set_farm_area(zone)

func _on_zone_unloading(_zone: ZoneRoot) -> void:
	set_farm_area(null)

func set_farm_area(p_zone: Node) -> void:
	farm_area = p_zone
	_animal_nodes.clear() # the previous zone's nodes were freed with it
	if farm_area == null:
		_coop = null
		_feeding_bowl = null
		_water_bowl = null
		_animal_container = null
		_animal_area = Rect2()
		return

	_coop = farm_area.get_node("ChickenCoop")
	_feeding_bowl = farm_area.get_node("FeedingBowl")
	_water_bowl = farm_area.get_node("WaterBowl")
	_animal_container = farm_area.get_node("AnimalContainer")
	_animal_area = _find_animal_area(farm_area)
	_coop.setup(self)

	for animal_id in simulation.get_all_animal_ids():
		_spawn_animal(animal_id)
	_flush_pending_products()

func interact_with_coop(coop: Coop) -> void:
	if not simulation.state.has_coop:
		if simulation.build_coop():
			AudioManager.play_coop_build_sfx()
			coop.refresh_visual()
		return
	if simulation.place_chicken() != "":
		AudioManager.play_click_menu_sfx()
	# place_chicken() already fired animal_added -> _spawn_animal(); nothing
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
	_spawn_animal(animal_id)

func _spawn_animal(animal_id: String) -> void:
	if _animal_nodes.has(animal_id):
		return
	var animal := simulation.get_animal(animal_id)
	if animal == null:
		return
	var scene: PackedScene = SPECIES_SCENES.get(animal.species)
	if scene == null:
		push_warning("AnimalManager: no scene registered for species %d (animal %s) - nothing spawned." % [animal.species, animal_id])
		return
	var node: Node2D = scene.instantiate()
	_animal_container.add_child(node)
	node.global_position = _pick_spawn_position()
	node.setup(self, animal_id, _animal_area)
	_animal_nodes[animal_id] = node

func _find_animal_area(zone: Node) -> Rect2:
	var area := zone.get_node_or_null("ChickenArea") as Control
	if area != null:
		return area.get_global_rect()
	push_warning("AnimalManager: no ChickenArea in zone %s - animals spawn around the coop instead." % zone.name)
	return Rect2(_coop.global_position - FALLBACK_AREA_HALF_SIZE, FALLBACK_AREA_HALF_SIZE * 2.0)

## Random point in _animal_area, re-rolled up to SPAWN_CANDIDATES times until
## it's clear of the other animals and the bowls - a new layout every time
## the zone is entered.
func _pick_spawn_position() -> Vector2:
	var avoid: Array[Vector2] = []
	for node in _animal_nodes.values():
		if is_instance_valid(node):
			avoid.append(node.global_position)
	var bowls: Array[Vector2] = []
	for bowl in [_feeding_bowl, _water_bowl]:
		if bowl != null:
			bowls.append(bowl.get_center())

	var best := _animal_area.get_center()
	var best_score := -INF
	for i in SPAWN_CANDIDATES:
		var candidate := _animal_area.position + Vector2(randf(), randf()) * _animal_area.size
		# Score = how much room the candidate has, relative to each minimum.
		var score := INF
		for p in avoid:
			score = minf(score, candidate.distance_to(p) / SPAWN_MIN_SPACING)
		for p in bowls:
			score = minf(score, candidate.distance_to(p) / SPAWN_BOWL_CLEARANCE)
		if score >= 1.0:
			return candidate
		if score > best_score:
			best_score = score
			best = candidate
	return best

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
