class_name FarmState
extends RefCounted

var money: int = 100
var clock := GameClock.new()
var plots: Dictionary = {} # plot_id: int -> PlotState
var inventory: Dictionary = {} # item_id: String -> int

var animals: Dictionary = {} # animal_id: String -> AnimalState
var has_coop: bool = false
var coop_capacity: int = 4
var _next_animal_index: int = 0

## Convenience read access - the clock is the single source of truth for the day.
var day: int:
	get:
		return clock.current_day

func _init(plot_count: int) -> void:
	for i in range(plot_count):
		plots[i] = PlotState.new()

func get_inventory_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func add_inventory(item_id: String, amount: int) -> void:
	inventory[item_id] = get_inventory_count(item_id) + amount

## Order must match AnimalData.Species. Not using AnimalData.Species.keys() -
## calling .keys() on an enum nested in another class fails to resolve from
## outside that class.
const _SPECIES_PREFIXES := ["chicken", "duck", "goose", "pig", "zebu"]

## Animal ids are allocated sequentially and never reused, even across saves,
## so a stale reference from a Chicken node can never collide with a new animal.
func generate_animal_id(species: AnimalData.Species) -> String:
	var prefix: String = _SPECIES_PREFIXES[species]
	var id := "%s_%d" % [prefix, _next_animal_index]
	_next_animal_index += 1
	return id

func to_dict() -> Dictionary:
	var plots_data := {}
	for plot_id in plots:
		var plot: PlotState = plots[plot_id]
		var crop_data = null
		if plot.crop != null:
			crop_data = {
				"crop_id": plot.crop.crop_id,
				"age": plot.crop.age,
				"growth_days": plot.crop.growth_days,
				"days_watered": plot.crop.days_watered,
				"days_total": plot.crop.days_total,
			}
		plots_data[str(plot_id)] = {
			"tilled": plot.tilled,
			"watered": plot.watered,
			"crop": crop_data,
		}
	var animals_data := {}
	for animal_id in animals:
		var animal: AnimalState = animals[animal_id]
		animals_data[animal_id] = {
			"species": animal.species,
			"age_days": animal.age_days,
			"hunger": animal.hunger,
			"thirst": animal.thirst,
			"fed_today": animal.fed_today,
			"watered_today": animal.watered_today,
			"days_well_cared": animal.days_well_cared,
			"days_since_product": animal.days_since_product,
		}

	return {
		"money": money,
		"day": day,
		"inventory": inventory.duplicate(),
		"plots": plots_data,
		"has_coop": has_coop,
		"coop_capacity": coop_capacity,
		"next_animal_index": _next_animal_index,
		"animals": animals_data,
	}

## Restores state in-place from a dictionary produced by to_dict().
## Unknown/missing plot_ids are ignored - the grid shape always comes from the current run.
func load_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	clock.current_day = int(data.get("day", clock.current_day))

	inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for item_id in saved_inventory:
		inventory[item_id] = int(saved_inventory[item_id])

	var plots_data: Dictionary = data.get("plots", {})
	for key in plots_data:
		var plot_id := int(key)
		if not plots.has(plot_id):
			continue
		var plot: PlotState = plots[plot_id]
		var plot_data: Dictionary = plots_data[key]
		plot.tilled = plot_data.get("tilled", false)
		plot.watered = plot_data.get("watered", false)
		var crop_data = plot_data.get("crop")
		if crop_data != null:
			var crop := CropState.new(str(crop_data["crop_id"]), int(crop_data["growth_days"]))
			crop.age = int(crop_data["age"])
			crop.days_watered = int(crop_data.get("days_watered", crop.age))
			crop.days_total = int(crop_data.get("days_total", crop.age))
			plot.crop = crop
		else:
			plot.crop = null

	has_coop = data.get("has_coop", false)
	coop_capacity = int(data.get("coop_capacity", coop_capacity))
	_next_animal_index = int(data.get("next_animal_index", 0))

	animals.clear()
	var animals_data: Dictionary = data.get("animals", {})
	for animal_id in animals_data:
		var animal_data: Dictionary = animals_data[animal_id]
		var animal := AnimalState.new(animal_id, int(animal_data.get("species", 0)) as AnimalData.Species)
		animal.age_days = int(animal_data.get("age_days", 0))
		animal.hunger = float(animal_data.get("hunger", 100.0))
		animal.thirst = float(animal_data.get("thirst", 100.0))
		animal.fed_today = animal_data.get("fed_today", false)
		animal.watered_today = animal_data.get("watered_today", false)
		animal.days_well_cared = int(animal_data.get("days_well_cared", 0))
		animal.days_since_product = int(animal_data.get("days_since_product", 0))
		animals[animal_id] = animal
