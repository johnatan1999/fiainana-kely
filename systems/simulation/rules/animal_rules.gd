class_name AnimalRules
extends SimRules

## The coop and its hens: buying, settling, feeding, eggs, breeding - and
## rebuilding the ruined coop.
## A part of FarmSimulation (SimRules): simulation.animals.

const COOP_COST := 6000
## Why an animal can or can't be settled right now - the UI turns it into a
## message ("Coop full (6/6)"...).
enum PlaceCheck { OK, NO_BUILDING, FULL, NONE_WAITING }

var _animal_registry: Dictionary = {} # AnimalData.Species -> AnimalData
## Laid overnight in the brick coop, waiting for the new day to begin.
var _basket: Dictionary = {}

func get_animal_data(species: AnimalData.Species) -> AnimalData:
	return _animal_registry.get(species)

func get_animal(animal_id: String) -> AnimalState:
	return state.animals.get(animal_id)

func get_all_animal_ids() -> Array:
	return state.animals.keys()

## Ticks hunger/thirst decay, the product cycle, and breeding for every
## animal. Called once a night (FarmSimulation.advance_day) - fed_today/watered_today (set
## throughout the day by feed_animal()/water_animal()) are consumed here and
## reset for the next day, exactly like PlotState.watered.
func advance_animals() -> void:
	var qualifying_by_species: Dictionary = {} # AnimalData.Species -> count
	var basket: Dictionary = {} # product_id -> laid overnight, for the basket
	for animal_id in state.animals.keys():
		var animal: AnimalState = state.animals[animal_id]
		var animal_data := get_animal_data(animal.species)
		if animal_data == null:
			continue

		animal.age_days += 1
		if animal.is_well_cared_today():
			animal.days_well_cared += 1
			animal.days_since_product += 1
		else:
			animal.days_well_cared = 0

		if not animal.fed_today:
			animal.hunger = max(0.0, animal.hunger - animal_data.hunger_decay_per_day)
		if not animal.watered_today:
			animal.thirst = max(0.0, animal.thirst - animal_data.thirst_decay_per_day)

		animal.fed_today = false
		animal.watered_today = false

		if animal_data.product_id != "" and animal.days_since_product >= animal_data.product_cycle_days:
			animal.days_since_product = 0
			if sim.projects.get_building_level("coop") >= ProjectRules.COOP_BASKET_LEVEL:
				basket[animal_data.product_id] = int(basket.get(animal_data.product_id, 0)) + 1
			else:
				sim.product_ready.emit(animal_id, animal_data.product_id)

		if animal.days_well_cared >= animal_data.breeding_days_required:
			qualifying_by_species[animal.species] = qualifying_by_species.get(animal.species, 0) + 1

		sim.animal_changed.emit(animal_id)

	for species in qualifying_by_species:
		if qualifying_by_species[species] >= 2:
			_attempt_breeding(species)
	_basket = basket

## The new morning (its log begun): the brick coop's basket, laid overnight,
## into the bag.
func collect_basket() -> void:
	for product_id: String in _basket:
		collect_product(product_id, _basket[product_id])
		sim.basket_collected.emit(product_id, _basket[product_id])
	_basket = {}

## One roll per species per day (not per pair) once at least 2 adults qualify,
## so a full coop doesn't produce multiple babies from a single day's care.
func _attempt_breeding(species: AnimalData.Species) -> void:
	if state.animals.size() >= state.coop_capacity:
		return
	var animal_data := get_animal_data(species)
	if randf() > animal_data.breeding_chance:
		return
	var baby_id := state.generate_animal_id(species)
	state.animals[baby_id] = AnimalState.new(baby_id, species)
	for animal in state.animals.values():
		if animal.species == species and animal.days_well_cared >= animal_data.breeding_days_required:
			animal.days_well_cared = 0
	sim.animal_added.emit(baby_id)

func build_coop() -> bool:
	if state.has_coop or state.money < COOP_COST:
		return false
	sim.add_money(-COOP_COST)
	state.has_coop = true
	state.coop_capacity = ProjectRules.COOP_CAPACITY_BY_LEVEL[1]
	sim.coop_built.emit()
	return true

## Buying doesn't put the animal anywhere yet: it waits (the seller keeps it)
## until the player settles it in the pen of their choice - place_animal().
## Species with no AnimalData registered simply can't be bought yet - fails
## closed rather than crash.
func buy_animal(species: AnimalData.Species, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var animal_data := get_animal_data(species)
	if animal_data == null:
		return false
	var cost := animal_data.purchase_price * quantity
	if state.money < cost:
		return false
	sim.add_money(-cost)
	state.pending_animals[species] = get_pending_count(species) + quantity
	sim.pending_animals_changed.emit()
	return true

func get_pending_count(species: AnimalData.Species) -> int:
	return state.pending_animals.get(species, 0)

## Whether place_animal(species) would succeed, and if not, why.
func check_place_animal(species: AnimalData.Species) -> PlaceCheck:
	if not state.has_coop:
		return PlaceCheck.NO_BUILDING
	if get_pending_count(species) <= 0:
		return PlaceCheck.NONE_WAITING
	if state.animals.size() >= state.coop_capacity:
		return PlaceCheck.FULL
	return PlaceCheck.OK

## Settles one waiting animal of this species in the coop. Returns the new
## animal's id, or "" if it couldn't be settled (see check_place_animal()).
func place_animal(species: AnimalData.Species) -> String:
	if check_place_animal(species) != PlaceCheck.OK:
		return ""
	state.pending_animals[species] -= 1
	if state.pending_animals[species] <= 0:
		state.pending_animals.erase(species)
	sim.pending_animals_changed.emit()
	var animal_id := state.generate_animal_id(species)
	state.animals[animal_id] = AnimalState.new(animal_id, species)
	sim.animal_added.emit(animal_id)
	return animal_id

## Thin chicken-specific wrappers over buy_animal()/place_animal() - every
## current call site (Coop.gd, the shop) only ever deals in chickens, and
## these keep that call surface unchanged.
func buy_chicken(quantity: int = 1) -> bool:
	return buy_animal(AnimalData.Species.CHICKEN, quantity)

func place_chicken() -> String:
	return place_animal(AnimalData.Species.CHICKEN)

## Called by the world-layer Egg pickup once the player actually walks over
## it - product_ready only announces that an egg is ready to spawn, it never
## touches inventory itself (FarmSimulation never touches Node2D/pickups).
func collect_product(product_id: String, quantity: int = 1) -> void:
	day_log.add_product(product_id, quantity)
	sim.add_item(product_id, quantity)

func feed_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.fed_today:
		return false
	animal.hunger = 100.0
	animal.fed_today = true
	sim.animal_changed.emit(animal_id)
	return true

func water_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.watered_today:
		return false
	animal.thirst = 100.0
	animal.watered_today = true
	sim.animal_changed.emit(animal_id)
	return true
