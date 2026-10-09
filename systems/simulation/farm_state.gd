class_name FarmState
extends RefCounted

## Plots belong to a world zone (a ZoneData id: "village", "rice_fields"...)
## and sit at a cell of that zone's own grid - every zone with fields has its
## own, so two zones never share plots. DEFAULT_ZONE is for code that only
## ever deals with a single zone (the unit tests): the game always passes a
## real zone id.
const DEFAULT_ZONE := ""

## Today's weather, rolled each morning (FarmSimulation.advance_day()).
enum Weather { CLEAR, RAIN }

var money: int = 10000
var clock := GameClock.new()
var weather: Weather = Weather.CLEAR

## plot_id: int -> PlotState. Ids are stable and never reused - a plot's
## actual (x, y) lives in plot_positions, not encoded in the id itself, so
## tiles can be added or removed anywhere without disturbing every other
## plot's position (unlike the old "id = y * width + x" scheme, which broke
## the moment the grid's width changed).
var plots: Dictionary = {}
var plot_positions: Dictionary = {} # plot_id: int -> Vector2i (cell in its zone)
var plot_zones: Dictionary = {} # plot_id: int -> zone_id: String
var _position_to_plot_id: Dictionary = {} # zone_id: String -> {Vector2i -> plot_id: int}
var _next_plot_id: int = 0

var inventory: Dictionary = {} # item_id: String -> int

var animals: Dictionary = {} # animal_id: String -> AnimalState
## Animals bought but not settled yet - the seller keeps them until the
## player settles them in a pen of their choice (FarmSimulation.place_animal).
## Not inventory items: they're living animals, not things in the bag.
var pending_animals: Dictionary = {} # AnimalData.Species -> count
var has_coop: bool = false
var coop_capacity: int = 4
var _next_animal_index: int = 0

## Land management (FarmLandManager). unlocked_zone_ids is used as a set - only
## the keys matter. progressive_tiles_unlocked is how many tiles of the
## modulable expansion zone have been bought, in its fixed unlock order.
var unlocked_zone_ids: Dictionary = {} # zone_id: String -> true
var progressive_tiles_unlocked: int = 0

## Fruit trees, keyed by their place in the world ("<zone_id>:<node path>",
## see TreeManager) - registered the first time their zone loads.
var trees: Dictionary = {} # tree_id: String -> TreeState

## The tufts the player cut in the neighbours' paddies
## (FarmSimulation.help_neighbour_harvest), per paddy ("<zone_id>:<node
## name>"): {"season": index of the season (0, 1, 2...), "cells": ["x,y"]}.
## A season's entry is ignored once the season is over.
var neighbour_harvest: Dictionary = {}

## Villagers' orders (FarmSimulation's order API), one at most per villager
## (the VillagerData file's name): {"item": item id, "quantity": n,
## "reward": Ariary for all, "template": index in VillagerData.orders (for
## its lines), "since": day it was offered, "deadline": last day to deliver
## - -1 while it's only offered, not accepted yet}.
var orders: Dictionary = {}
## Villager -> first day they may offer a new order (after a delivery, a
## refusal, an order that ran out).
var order_cooldowns: Dictionary = {}
## The day new orders were last offered (once a day, in the morning).
var order_roll_day: int = 0

## Friendship with each villager (FarmSimulation's friendship API), in
## points: FarmSimulation.FRIENDSHIP_PER_HEART per heart.
var friendship: Dictionary = {} # villager_id -> points
## The last day the player talked to each villager (talking counts once a
## day).
var friendship_talk_day: Dictionary = {} # villager_id -> day

## The player's zebus (FarmSimulation's zebu API), bought at the market-day zebu
## market: zebu_id -> {"name": String, "coat": int (GrazingZebu.COATS),
## "grown_days": int (days of care so far)}.
var zebus: Dictionary = {}
var next_zebu_index: int = 0
## Today's water and hay in the farm pen's trough - for the whole herd.
var zebu_trough_full: bool = false
## Plots the zebu team has ploughed today (FarmSimulation.plough).
var plough_cells_today: int = 0
## Manure heaped by the farm pen, waiting to be picked up.
var manure_pile: int = 0
const HOTBAR_SIZE := 8
## Item id in each hotbar slot ("" = empty), saved with the game. Only ever
## modified through FarmSimulation's hotbar methods, which keep it valid.
## Empty array = not initialized yet (new game, or a save from before the
## hotbar) - see FarmSimulation.init_hotbar().
var hotbar: Array = []

## Convenience read access - the clock is the single source of truth for the day.
var day: int:
	get:
		return clock.current_day

func _init(grid_width: int, grid_height: int) -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			add_plot(x, y)

## Creates a new empty, untilled plot at (x, y) of zone_id. Returns its
## plot_id, or -1 if a plot already exists there.
func add_plot(x: int, y: int, zone_id := DEFAULT_ZONE) -> int:
	var pos := Vector2i(x, y)
	if get_plot_id_at(x, y, zone_id) != -1:
		return -1
	var plot_id := _next_plot_id
	_next_plot_id += 1
	plots[plot_id] = PlotState.new()
	_index(plot_id, pos, zone_id)
	return plot_id

func _index(plot_id: int, pos: Vector2i, zone_id: String) -> void:
	plot_positions[plot_id] = pos
	plot_zones[plot_id] = zone_id
	if not _position_to_plot_id.has(zone_id):
		_position_to_plot_id[zone_id] = {}
	_position_to_plot_id[zone_id][pos] = plot_id

## Permanently removes a plot - and whatever was growing on it. Returns
## false if it didn't exist.
func remove_plot(plot_id: int) -> bool:
	if not plots.has(plot_id):
		return false
	var pos: Vector2i = plot_positions[plot_id]
	var zone_id: String = plot_zones[plot_id]
	plots.erase(plot_id)
	plot_positions.erase(plot_id)
	plot_zones.erase(plot_id)
	_position_to_plot_id[zone_id].erase(pos)
	return true

## Returns the plot_id at (x, y) of zone_id, or -1 if no plot exists there.
func get_plot_id_at(x: int, y: int, zone_id := DEFAULT_ZONE) -> int:
	return _position_to_plot_id.get(zone_id, {}).get(Vector2i(x, y), -1)

func get_plot_zone(plot_id: int) -> String:
	return plot_zones.get(plot_id, DEFAULT_ZONE)

## Smallest axis-aligned rectangle (in grid cells) containing every plot of
## zone_id. Empty Rect2i if it has none.
func get_grid_bounds(zone_id := DEFAULT_ZONE) -> Rect2i:
	var positions: Array = _position_to_plot_id.get(zone_id, {}).keys()
	if positions.is_empty():
		return Rect2i()
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

## Id prefix of a species ("chicken" -> animal ids "chicken_3").
static func species_prefix(species: AnimalData.Species) -> String:
	return _SPECIES_PREFIXES[species]

## Animal ids are allocated sequentially and never reused, even across saves,
## so a stale reference from a Chicken node can never collide with a new animal.
func generate_animal_id(species: AnimalData.Species) -> String:
	var prefix := species_prefix(species)
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
			"zone": plot_zones[plot_id],
			"x": pos.x,
			"y": pos.y,
			"tilled": plot.tilled,
			"watered": plot.watered,
			"flooded": plot.flooded,
			"fertilized": plot.fertilized,
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

	var trees_data := {}
	for tree_id in trees:
		var tree: TreeState = trees[tree_id]
		trees_data[tree_id] = {
			"type": tree.tree_type_id,
			"fruit_ready": tree.fruit_ready,
			"days_growing": tree.days_growing,
		}

	return {
		"money": money,
		"day": day,
		"minute": clock.minute_of_day,
		"weather": weather,
		"inventory": inventory.duplicate(),
		"plots": plots_data,
		"next_plot_id": _next_plot_id,
		"has_coop": has_coop,
		"coop_capacity": coop_capacity,
		"next_animal_index": _next_animal_index,
		"animals": animals_data,
		"pending_animals": _pending_animals_to_dict(),
		"unlocked_zone_ids": unlocked_zone_ids.keys(),
		"progressive_tiles_unlocked": progressive_tiles_unlocked,
		"hotbar": hotbar.duplicate(),
		"trees": trees_data,
		"neighbour_harvest": neighbour_harvest.duplicate(true),
		"orders": orders.duplicate(true),
		"order_cooldowns": order_cooldowns.duplicate(),
		"order_roll_day": order_roll_day,
		"friendship": friendship.duplicate(),
		"friendship_talk_day": friendship_talk_day.duplicate(),
		"zebus": zebus.duplicate(true),
		"next_zebu_index": next_zebu_index,
		"zebu_trough_full": zebu_trough_full,
		"plough_cells_today": plough_cells_today,
		"manure_pile": manure_pile,
	}

## JSON object keys are strings: species saved as "0", "4"...
func _pending_animals_to_dict() -> Dictionary:
	var out := {}
	for species in pending_animals:
		out[str(species)] = pending_animals[species]
	return out

## Restores state in-place from a dictionary produced by to_dict(). Unlike
## the old fixed-grid version, this fully rebuilds the plot grid to match
## whatever shape was actually saved - a dynamically resized farm must be
## restored at its real size, not the current run's default.
func load_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	clock.current_day = int(data.get("day", clock.current_day))
	# Optional key (older saves have none): they wake up at dawn.
	clock.minute_of_day = clampi(int(data.get("minute", GameClock.DAY_START_MINUTE)), 0, GameClock.LATEST_MINUTE)
	# Optional key (older saves have none): a clear day.
	weather = clampi(int(data.get("weather", Weather.CLEAR)), 0, Weather.size() - 1) as Weather

	inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for item_id in saved_inventory:
		inventory[item_id] = int(saved_inventory[item_id])

	plots.clear()
	plot_positions.clear()
	plot_zones.clear()
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
		plot.flooded = plot_data.get("flooded", false)
		# Optional key (older saves have none): not fertilized.
		plot.fertilized = plot_data.get("fertilized", false)
		var crop_data = plot_data.get("crop")
		if crop_data != null:
			var crop := CropState.new(str(crop_data["crop_id"]), int(crop_data["growth_days"]))
			crop.age = int(crop_data["age"])
			crop.days_watered = int(crop_data.get("days_watered", crop.age))
			crop.days_total = int(crop_data.get("days_total", crop.age))
			plot.crop = crop

		plots[plot_id] = plot
		# Every plot has a zone since save v6 (SaveController migrates older saves).
		_index(plot_id, pos, str(plot_data.get("zone", DEFAULT_ZONE)))

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

	pending_animals.clear()
	var pending_data: Dictionary = data.get("pending_animals", {})
	for species in pending_data:
		if int(pending_data[species]) > 0:
			pending_animals[int(species)] = int(pending_data[species])

	unlocked_zone_ids.clear()
	for zone_id in data.get("unlocked_zone_ids", []):
		unlocked_zone_ids[zone_id] = true
	progressive_tiles_unlocked = int(data.get("progressive_tiles_unlocked", 0))
	hotbar = Array(data.get("hotbar", [])).map(func(item_id): return str(item_id))

	# Optional keys (older saves have none): no orders yet.
	orders.clear()
	var orders_data = data.get("orders", {})
	if orders_data is Dictionary:
		for villager_id in orders_data:
			var order: Dictionary = orders_data[villager_id]
			orders[str(villager_id)] = {
				"item": str(order.get("item", "")),
				"quantity": int(order.get("quantity", 1)),
				"reward": int(order.get("reward", 0)),
				"template": int(order.get("template", -1)),
				"since": int(order.get("since", 0)),
				"deadline": int(order.get("deadline", -1)),
			}
	order_cooldowns.clear()
	var cooldowns_data = data.get("order_cooldowns", {})
	if cooldowns_data is Dictionary:
		for villager_id in cooldowns_data:
			order_cooldowns[str(villager_id)] = int(cooldowns_data[villager_id])
	order_roll_day = int(data.get("order_roll_day", 0))
	# Optional keys (older saves have none): strangers to everyone.
	friendship.clear()
	var friendship_data = data.get("friendship", {})
	if friendship_data is Dictionary:
		for villager_id in friendship_data:
			friendship[str(villager_id)] = int(friendship_data[villager_id])
	friendship_talk_day.clear()
	var talk_data = data.get("friendship_talk_day", {})
	if talk_data is Dictionary:
		for villager_id in talk_data:
			friendship_talk_day[str(villager_id)] = int(talk_data[villager_id])
	# Optional keys (older saves have none): no zebus yet.
	zebus.clear()
	var zebus_data = data.get("zebus", {})
	if zebus_data is Dictionary:
		for zebu_id in zebus_data:
			var zebu: Dictionary = zebus_data[zebu_id]
			zebus[str(zebu_id)] = {
				"name": str(zebu.get("name", "")),
				"coat": int(zebu.get("coat", 0)),
				"grown_days": int(zebu.get("grown_days", 0)),
			}
	next_zebu_index = int(data.get("next_zebu_index", zebus.size()))
	zebu_trough_full = bool(data.get("zebu_trough_full", false))
	plough_cells_today = int(data.get("plough_cells_today", 0))
	manure_pile = int(data.get("manure_pile", 0))

	# Optional key (older saves have none): no tufts cut yet.
	neighbour_harvest.clear()
	var harvest_data = data.get("neighbour_harvest", {})
	if harvest_data is Dictionary:
		for paddy_id in harvest_data:
			var entry: Dictionary = harvest_data[paddy_id]
			neighbour_harvest[str(paddy_id)] = {
				"season": int(entry.get("season", -1)),
				"cells": Array(entry.get("cells", [])).map(func(cell): return str(cell)),
			}

	# Optional key (older saves have none): their trees register fresh on load.
	trees.clear()
	var trees_data = data.get("trees", {})
	if trees_data is Dictionary:
		for tree_id in trees_data:
			var tree_data: Dictionary = trees_data[tree_id]
			var tree := TreeState.new(str(tree_data.get("type", "")))
			tree.fruit_ready = tree_data.get("fruit_ready", false)
			tree.days_growing = int(tree_data.get("days_growing", 0))
			trees[str(tree_id)] = tree
