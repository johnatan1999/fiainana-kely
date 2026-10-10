class_name NotebookRules
extends SimRules

## The player's notebook (kahie) and the forest: pages found, wild animals
## about, wild plants gathered.
## A part of FarmSimulation (SimRules): simulation.notebook.

## A dish's page in the notebook: "cuisine:<recipe id>" - found when first
## cooked.
const CUISINE_PREFIX := "cuisine:"

var _discoveries: Dictionary = {} # discovery_id: String -> Discovery

## Registered by ForestManager (data/discoveries/).
func register_discovery(discovery_id: String, discovery: Discovery) -> void:
	_discoveries[discovery_id] = discovery

func get_discovery(discovery_id: String) -> Discovery:
	return _discoveries.get(discovery_id)

## The notebook's entries: the registered ones, then a page per recipe.
func get_discovery_ids() -> Array:
	var ids := _discoveries.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = _discoveries[a].category
		var cb: int = _discoveries[b].category
		return ca < cb if ca != cb else a < b)
	for recipe_id in sim.kitchen.get_recipe_ids():
		ids.append(CUISINE_PREFIX + recipe_id)
	return ids

func is_discovered(discovery_id: String) -> bool:
	return state.discoveries.has(discovery_id)

## How many of the notebook's entries are found, out of how many.
func get_notebook_progress() -> Vector2i:
	var ids := get_discovery_ids()
	return Vector2i(ids.filter(func(id): return is_discovered(id)).size(), ids.size())

## A new page in the notebook - false if it was already there, or isn't an
## entry at all.
func discover(discovery_id: String) -> bool:
	var known := _discoveries.has(discovery_id) or (discovery_id.begins_with(CUISINE_PREFIX)
		and sim.kitchen.get_recipe(discovery_id.trim_prefix(CUISINE_PREFIX)) != null)
	if not known or is_discovered(discovery_id):
		return false
	state.discoveries[discovery_id] = state.day
	day_log.discoveries.append(discovery_id)
	sim.discovery_made.emit(discovery_id)
	for quest_id: String in sim.quests.get_active_quests():
		sim.quests.check_quest_discovery(quest_id)
	return true

## Whether the animal (or plant) is about right now: its hours, its season,
## the weather.
func is_wildlife_active(discovery_id: String) -> bool:
	var discovery := get_discovery(discovery_id)
	return discovery != null and discovery.is_active(state.clock.minute_of_day, state.clock.get_season(), sim.is_raining())

## The player watches an animal: its page, if it's about.
func observe(discovery_id: String) -> bool:
	if not is_wildlife_active(discovery_id):
		return false
	discover(discovery_id)
	return true

## A wild plant at `spot_id` (the plant's Discovery: its item, season and
## regrowth): ready in its season, once grown back.
func can_forage(spot_id: String, discovery_id: String) -> bool:
	var plant := get_discovery(discovery_id)
	return plant != null and not plant.item_id.is_empty() and plant.is_in_season(state.clock.get_season()) \
		and state.day >= int(state.forage.get(spot_id, 0))

## Gathers it: the item in the bag, the plant grows back in its
## regrow_days, its page in the notebook. Returns how many were gathered.
func forage(spot_id: String, discovery_id: String) -> int:
	if not can_forage(spot_id, discovery_id):
		return 0
	var plant := get_discovery(discovery_id)
	sim.add_item(plant.item_id, plant.quantity)
	state.forage[spot_id] = state.day + plant.regrow_days
	day_log.add_harvest(plant.item_id, plant.quantity)
	sim.forage_changed.emit(spot_id)
	discover(discovery_id)
	return plant.quantity
