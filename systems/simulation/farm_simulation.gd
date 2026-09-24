class_name FarmSimulation
extends RefCounted

## Owns FarmState and enforces every rule of the farm loop.
## Never touches Node2D/Sprite2D/UI - presentation only listens to the signals below.

signal money_changed(money: int)
signal day_changed(day: int)
signal plot_changed(plot_id: int)
## A new plot came into existence (grid expansion, or a loaded save) - the
## presentation layer should create a PlotView for it. Distinct from
## plot_changed, which only updates a PlotView that already exists.
signal plot_added(plot_id: int)
## A plot was permanently removed - the presentation layer should free its
## PlotView.
signal plot_removed(plot_id: int)
signal inventory_changed(item_id: String, amount: int)

signal animal_added(animal_id: String)
signal animal_changed(animal_id: String)
## Fired once an animal's product is ready - the presentation layer spawns
## the actual pickup (e.g. Egg.tscn) in response; FarmSimulation never touches
## Node2D itself, so it doesn't put the product directly into inventory here.
signal product_ready(animal_id: String, product_id: String)

const COOP_COST := 6000

var state: FarmState
var grid_width: int
var grid_height: int

var _crop_registry: Dictionary = {} # crop_id: String -> CropData
var _animal_registry: Dictionary = {} # AnimalData.Species -> AnimalData

func _init(p_grid_width: int, p_grid_height: int, crop_registry: Dictionary, animal_registry: Dictionary = {}) -> void:
	grid_width = p_grid_width
	grid_height = p_grid_height
	_crop_registry = crop_registry
	_animal_registry = animal_registry
	state = FarmState.new(p_grid_width, p_grid_height)

func get_plot(plot_id: int) -> PlotState:
	return state.plots.get(plot_id)

func get_plot_id_at(x: int, y: int) -> int:
	return state.get_plot_id_at(x, y)

func get_plot_position(plot_id: int) -> Vector2i:
	return state.plot_positions.get(plot_id, Vector2i(-1, -1))

func get_all_plot_ids() -> Array:
	return state.plots.keys()

## Grows the farm to at least new_width x new_height, filling in any missing
## plot inside that rectangle with a fresh empty one. Never shrinks or
## removes anything - use remove_tile()/clear_tile() for that.
func expand_grid(new_width: int, new_height: int) -> void:
	var target_width: int = max(new_width, grid_width)
	var target_height: int = max(new_height, grid_height)
	for y in range(target_height):
		for x in range(target_width):
			add_tile(x, y) # no-op if a plot is already there
	grid_width = target_width
	grid_height = target_height

## Adds a single empty, untilled plot at (x, y). Returns the new plot_id, or
## -1 if a plot already exists there.
func add_tile(x: int, y: int) -> int:
	var plot_id := state.add_plot(x, y)
	if plot_id != -1:
		plot_added.emit(plot_id)
	return plot_id

## Permanently removes the plot at (x, y), including whatever crop was
## growing on it. Returns false if there was no plot there.
func remove_tile(x: int, y: int) -> bool:
	var plot_id := state.get_plot_id_at(x, y)
	if plot_id == -1:
		return false
	state.remove_plot(plot_id)
	plot_removed.emit(plot_id)
	return true

## Resets the plot at (x, y) to empty/untilled without removing it from the
## grid - for reorganizing without changing the grid's shape.
func clear_tile(x: int, y: int) -> bool:
	var plot_id := state.get_plot_id_at(x, y)
	var plot := get_plot(plot_id)
	if plot == null:
		return false
	plot.reset()
	plot_changed.emit(plot_id)
	return true

func get_crop_data(crop_id: String) -> CropData:
	return _crop_registry.get(crop_id)

func get_all_crop_ids() -> Array:
	return _crop_registry.keys()

func get_animal_data(species: AnimalData.Species) -> AnimalData:
	return _animal_registry.get(species)

func get_animal(animal_id: String) -> AnimalState:
	return state.animals.get(animal_id)

func get_all_animal_ids() -> Array:
	return state.animals.keys()

## can_till()/can_plant()/can_water()/can_harvest() are read-only mirrors of
## each action's guard - lets callers (FarmingController walking the player
## up to the plot, tool animations) check eligibility before mutating.
func can_till(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop == null

func till(plot_id: int) -> bool:
	if not can_till(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.tilled = true
	plot_changed.emit(plot_id)
	return true

func can_plant(plot_id: int, crop_id: String) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or not plot.tilled or plot.crop != null:
		return false
	return get_crop_data(crop_id) != null and state.get_inventory_count(crop_id + "_seed") > 0

func plant(plot_id: int, crop_id: String) -> bool:
	if not can_plant(plot_id, crop_id):
		return false
	var plot := get_plot(plot_id)
	var crop_data := get_crop_data(crop_id)
	var seed_key := crop_id + "_seed"
	state.add_inventory(seed_key, -1)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	plot.crop = CropState.new(crop_id, crop_data.growth_days)
	plot_changed.emit(plot_id)
	return true

func can_water(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null

func water(plot_id: int) -> bool:
	if not can_water(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.watered = true
	plot_changed.emit(plot_id)
	return true

## Also what the harvest swing animation checks, since it must play before
## the crop is actually removed, not after.
func can_harvest(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null and plot.crop.is_mature()

func harvest(plot_id: int) -> bool:
	if not can_harvest(plot_id):
		return false
	var plot := get_plot(plot_id)
	var crop_id := plot.crop.crop_id
	var crop_data := get_crop_data(crop_id)
	var quantity := _compute_harvest_quantity(plot.crop, crop_data)
	state.add_inventory(crop_id, quantity)
	plot.crop = null
	plot.watered = false
	inventory_changed.emit(crop_id, state.get_inventory_count(crop_id))
	plot_changed.emit(plot_id)
	return true

## Base yield is a random amount in [yield_min, yield_max]. Watering the crop
## less than its min_watered_ratio_for_quality caps it a notch lower, and
## harvesting outside its ideal_season shrinks it further - both floored at 1
## so a successful harvest never returns nothing.
func _compute_harvest_quantity(crop: CropState, crop_data: CropData) -> int:
	var quantity := randi_range(crop_data.yield_min, crop_data.yield_max)
	if crop.get_watered_ratio() < crop_data.min_watered_ratio_for_quality:
		quantity = max(1, quantity - 1)
	var ideal_season := crop_data.ideal_season
	if ideal_season != CropData.Season.TOUTE_SAISON and int(ideal_season) != state.clock.get_season():
		quantity = max(1, int(round(quantity * crop_data.off_season_yield_multiplier)))
	return quantity

func advance_day() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.crop != null:
			plot.crop.days_total += 1
			if plot.watered:
				plot.crop.days_watered += 1
				plot.crop.age += 1
		plot.watered = false
		plot_changed.emit(plot_id)
	_advance_animals()
	state.clock.advance_day()
	day_changed.emit(state.day)

## Ticks hunger/thirst decay, the product cycle, and breeding for every
## animal. Called once per advance_day() - fed_today/watered_today (set
## throughout the day by feed_animal()/water_animal()) are consumed here and
## reset for the next day, exactly like PlotState.watered.
func _advance_animals() -> void:
	var qualifying_by_species: Dictionary = {} # AnimalData.Species -> count
	for animal_id in state.animals.keys():
		var animal: AnimalState = state.animals[animal_id]
		var animal_data := get_animal_data(animal.species)
		if animal_data == null:
			continue

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
			product_ready.emit(animal_id, animal_data.product_id)

		if animal.days_well_cared >= animal_data.breeding_days_required:
			qualifying_by_species[animal.species] = qualifying_by_species.get(animal.species, 0) + 1

		animal_changed.emit(animal_id)

	for species in qualifying_by_species:
		if qualifying_by_species[species] >= 2:
			_attempt_breeding(species)

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
	animal_added.emit(baby_id)

func build_coop() -> bool:
	if state.has_coop or state.money < COOP_COST:
		return false
	state.money -= COOP_COST
	money_changed.emit(state.money)
	state.has_coop = true
	return true

## Pure economy transaction - buying doesn't materialize an animal in the
## world. place_animal() does that and requires the coop to exist. Species
## with no AnimalData registered (nothing passed to FarmSimulation._init()
## for them) simply can't be bought yet - fails closed rather than crash.
func buy_animal(species: AnimalData.Species, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var animal_data := get_animal_data(species)
	if animal_data == null:
		return false
	var cost := animal_data.purchase_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	var key := _unplaced_key(species)
	state.add_inventory(key, quantity)
	inventory_changed.emit(key, state.get_inventory_count(key))
	return true

## Converts one purchased-but-unplaced animal of this species into a real
## animal in the coop. Returns the new animal's id, or "" if it couldn't be
## placed.
func place_animal(species: AnimalData.Species) -> String:
	if not state.has_coop:
		return ""
	if state.animals.size() >= state.coop_capacity:
		return ""
	var key := _unplaced_key(species)
	if state.get_inventory_count(key) <= 0:
		return ""
	state.add_inventory(key, -1)
	inventory_changed.emit(key, state.get_inventory_count(key))
	var animal_id := state.generate_animal_id(species)
	state.animals[animal_id] = AnimalState.new(animal_id, species)
	animal_added.emit(animal_id)
	return animal_id

func _unplaced_key(species: AnimalData.Species) -> String:
	return "%s_unplaced" % FarmState.species_prefix(species)

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
	state.add_inventory(product_id, quantity)
	inventory_changed.emit(product_id, state.get_inventory_count(product_id))

func feed_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.fed_today:
		return false
	animal.hunger = 100.0
	animal.fed_today = true
	animal_changed.emit(animal_id)
	return true

func water_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.watered_today:
		return false
	animal.thirst = 100.0
	animal.watered_today = true
	animal_changed.emit(animal_id)
	return true

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null:
		return false
	if state.day < crop_data.unlock_day:
		return false
	var cost := crop_data.seed_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	var seed_key := crop_id + "_seed"
	state.add_inventory(seed_key, quantity)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	return true

## Generic purchase path for shop items that aren't crops (tools/food/animals):
## unlike buy_seed(), the caller supplies the price since these items have no
## entry in _crop_registry.
func buy_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0:
		return false
	var cost := unit_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	state.add_inventory(item_id, quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	return true

func sell(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(item_id)
	if crop_data == null:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	state.add_inventory(item_id, -quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.money += crop_data.sell_price * quantity
	money_changed.emit(state.money)
	return true

## Generic sell path for non-crop products (eggs, and future animal
## products): symmetric to buy_item() - the caller supplies the unit price
## since these items have no entry in _crop_registry.
func sell_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	state.add_inventory(item_id, -quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.money += unit_price * quantity
	money_changed.emit(state.money)
	return true

## Generic money-spending primitive for systems (like FarmLandManager) that need
## to charge the player without being a crop/animal/shop-item purchase.
## Centralizing it here keeps FarmSimulation the single place that mutates
## money and emits money_changed.
func spend_money(amount: int) -> bool:
	if amount < 0 or state.money < amount:
		return false
	state.money -= amount
	money_changed.emit(state.money)
	return true

func to_save_data() -> Dictionary:
	return state.to_dict()

## Restores state in-place and re-emits every signal so the presentation layer redraws itself.
func load_save_data(data: Dictionary) -> void:
	state.load_dict(data)

	var bounds := state.get_grid_bounds()
	grid_width = bounds.size.x
	grid_height = bounds.size.y

	money_changed.emit(state.money)
	day_changed.emit(state.day)
	# plot_added, not plot_changed: load_dict() rebuilt the plot set from
	# scratch, so as far as any listener is concerned every plot is new.
	for plot_id in state.plots:
		plot_added.emit(plot_id)
	for item_id in state.inventory:
		inventory_changed.emit(item_id, state.inventory[item_id])
