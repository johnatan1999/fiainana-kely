class_name FarmState
extends RefCounted

var money: int = 100
var clock := GameClock.new()

## plot_id: int -> PlotState. Ids are stable and never reused - a plot's
## actual (x, y) lives in plot_positions, not encoded in the id itself, so
## tiles can be added or removed anywhere without disturbing every other
## plot's position (unlike the old "id = y * width + x" scheme, which broke
## the moment the grid's width changed).
var plots: Dictionary = {}
var plot_positions: Dictionary = {} # plot_id: int -> Vector2i
var _position_to_plot_id: Dictionary = {} # Vector2i -> plot_id: int
var _next_plot_id: int = 0

var inventory: Dictionary = {} # item_id: String -> int

var animals: Dictionary = {} # animal_id: String -> AnimalState
var has_coop: bool = false
var coop_capacity: int = 4
var _next_animal_index: int = 0

## Land management (ZoneManager). unlocked_zone_ids is used as a set - only
## the keys matter. progressive_tiles_unlocked is how many tiles of the
## modulable expansion zone have been bought, in its fixed unlock order.
var unlocked_zone_ids: Dictionary = {} # zone_id: String -> true
var progressive_tiles_unlocked: int = 0

## Convenience read access - the clock is the single source of truth for the day.
var day: int:
	get:
		return clock.current_day

func _init(grid_width: int, grid_height: int) -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			add_plot(x, y)

## Creates a new empty, untilled plot at (x, y). Returns its plot_id, or -1
## if a plot already exists there.
func add_plot(x: int, y: int) -> int:
	var pos := Vector2i(x, y)
	if _position_to_plot_id.has(pos):
		return -1
	var plot_id := _next_plot_id
	_next_plot_id += 1
	plots[plot_id] = PlotState.new()
	plot_positions[plot_id] = pos
	_position_to_plot_id[pos] = plot_id
	return plot_id

## Permanently removes a plot - and whatever was growing on it. Returns
## false if it didn't exist.
func remove_plot(plot_id: int) -> bool:
	if not plots.has(plot_id):
		return false
	var pos: Vector2i = plot_positions[plot_id]
	plots.erase(plot_id)
	plot_positions.erase(plot_id)
	_position_to_plot_id.erase(pos)
	return true

## Returns the plot_id at (x, y), or -1 if no plot exists there.
func get_plot_id_at(x: int, y: int) -> int:
	return _position_to_plot_id.get(Vector2i(x, y), -1)

## Smallest axis-aligned rectangle (in grid cells) containing every plot.
## Empty Rect2i if there are no plots left.
func get_grid_bounds() -> Rect2i:
	if plot_positions.is_empty():
		return Rect2i()
	var positions: Array = plot_positions.values()
	var min_pos: Vector2i = positions[0]
	var max_pos: Vector2i = positions[0]
	for pos: Vector2i in positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	return Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE)

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
		var pos: Vector2i = plot_positions[plot_id]
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
			"x": pos.x,
			"y": pos.y,
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
		"next_plot_id": _next_plot_id,
		"has_coop": has_coop,
		"coop_capacity": coop_capacity,
		"next_animal_index": _next_animal_index,
		"animals": animals_data,
		"unlocked_zone_ids": unlocked_zone_ids.keys(),
		"progressive_tiles_unlocked": progressive_tiles_unlocked,
	}

## Restores state in-place from a dictionary produced by to_dict(). Unlike
## the old fixed-grid version, this fully rebuilds the plot grid to match
## whatever shape was actually saved - a dynamically resized farm must be
## restored at its real size, not the current run's default.
func load_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	clock.current_day = int(data.get("day", clock.current_day))

	inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for item_id in saved_inventory:
		inventory[item_id] = int(saved_inventory[item_id])

	plots.clear()
	plot_positions.clear()
	_position_to_plot_id.clear()
	_next_plot_id = int(data.get("next_plot_id", 0))

	var plots_data: Dictionary = data.get("plots", {})
	for key in plots_data:
		var plot_id := int(key)
		var plot_data: Dictionary = plots_data[key]
		var pos := Vector2i(int(plot_data.get("x", 0)), int(plot_data.get("y", 0)))

		var plot := PlotState.new()
		plot.tilled = plot_data.get("tilled", false)
		plot.watered = plot_data.get("watered", false)
		var crop_data = plot_data.get("crop")
		if crop_data != null:
			var crop := CropState.new(str(crop_data["crop_id"]), int(crop_data["growth_days"]))
			crop.age = int(crop_data["age"])
			crop.days_watered = int(crop_data.get("days_watered", crop.age))
			crop.days_total = int(crop_data.get("days_total", crop.age))
			plot.crop = crop

		plots[plot_id] = plot
		plot_positions[plot_id] = pos
		_position_to_plot_id[pos] = plot_id

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

	unlocked_zone_ids.clear()
	for zone_id in data.get("unlocked_zone_ids", []):
		unlocked_zone_ids[zone_id] = true
	progressive_tiles_unlocked = int(data.get("progressive_tiles_unlocked", 0))
