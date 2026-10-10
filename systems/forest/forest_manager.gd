class_name ForestManager
extends Node

## The forest and the player's notebook (the kahie), between FarmSimulation
## (the pages found, the plants growing back, saved) and the world. Decides
## nothing itself:
## - registers the notebook's entries (data/discoveries/);
## - the animals (WildAnimal): there in their hours and seasons, not in the
##   rain if they shy from it - checked each minute; watching one writes its
##   page;
## - the wild plants (ForageSpot): grown or gathered, in their season;
##   gathering one: the item, and its page;
## - the places (DiscoveryPlace): walking in writes their page;
## - every new page (cooked dishes too): a word, "drawn by Fara".
## See docs/forest.md.

var simulation: FarmSimulation
var item_db: ItemDatabase

var _animals: Array[WildAnimal] = []
var _plants: Array[ForageSpot] = []

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager) -> void:
	simulation = p_simulation
	item_db = p_item_db
	var discoveries := Discovery.load_all()
	for discovery_id: String in discoveries:
		simulation.register_discovery(discovery_id, discoveries[discovery_id])
	simulation.discovery_made.connect(_on_discovery_made)
	simulation.time_changed.connect(func(_minute: int): _refresh_animals())
	simulation.weather_changed.connect(func(_weather): _refresh_animals())
	simulation.day_changed.connect(func(_day: int): _refresh_plants())
	simulation.forage_changed.connect(func(_spot: String): _refresh_plants())
	world_manager.zone_loaded.connect(_on_zone_loaded)
	world_manager.zone_unloading.connect(func(_zone: ZoneRoot):
		_animals.clear()
		_plants.clear())

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_animals.clear()
	_plants.clear()
	for node in zone.find_children("*", "", true, false):
		if node is WildAnimal:
			_animals.append(node)
			node.observed.connect(_on_observed.bind(node))
			node.set_prompt(tr("Observer : %s") % _name(node.discovery_id))
		elif node is ForageSpot:
			_plants.append(node)
			node.gathered.connect(_on_gathered.bind(node))
		elif node is DiscoveryPlace:
			var place_id: String = node.discovery_id
			node.reached.connect(func(): simulation.discover(place_id))
	_refresh_animals(true)
	_refresh_plants()

func _name(discovery_id: String) -> String:
	var discovery := simulation.get_discovery(discovery_id)
	return tr(discovery.display_name).to_lower() if discovery != null else discovery_id

func _refresh_animals(instant := false) -> void:
	for animal in _animals:
		if is_instance_valid(animal):
			animal.set_present(simulation.is_wildlife_active(animal.discovery_id), instant)

func _refresh_plants() -> void:
	for plant in _plants:
		if not is_instance_valid(plant):
			continue
		var ready := simulation.can_forage(plant.get_spot_id(), plant.discovery_id)
		plant.show_state(ready, tr("Cueillir : %s") % _name(plant.discovery_id) if ready else "")

func _on_observed(animal: WildAnimal) -> void:
	var known := simulation.is_discovered(animal.discovery_id)
	# A first time: the new page says it (_on_discovery_made).
	if not simulation.observe(animal.discovery_id) or not known:
		return
	UIEvents.notify(tr("Tu observes le %s un moment. Il est déjà dans ton carnet.") % _name(animal.discovery_id))

func _on_gathered(plant: ForageSpot) -> void:
	var quantity := simulation.forage(plant.get_spot_id(), plant.discovery_id)
	if quantity <= 0:
		return
	var discovery := simulation.get_discovery(plant.discovery_id)
	AudioManager.play_harvest_sfx()
	HarvestPopup.spawn(plant, plant.global_position + Vector2(0, -60), item_db.get_icon(discovery.item_id),
		"+%d %s" % [quantity, item_db.get_display_name(discovery.item_id)])

## A new page: what it is, and Fara's word under her drawing.
func _on_discovery_made(discovery_id: String) -> void:
	var title := ""
	var line := ""
	if discovery_id.begins_with(FarmSimulation.CUISINE_PREFIX):
		var recipe := simulation.get_recipe(discovery_id.trim_prefix(FarmSimulation.CUISINE_PREFIX))
		if recipe == null:
			return
		title = tr(recipe.display_name)
		line = tr("Miam, ça a l'air bon !")
	else:
		var discovery := simulation.get_discovery(discovery_id)
		if discovery == null:
			return
		title = "%s (%s)" % [tr(discovery.display_name), discovery.malagasy_name]
		line = tr(discovery.fara_line)
	var progress := simulation.get_notebook_progress()
	UIEvents.notify(tr("Nouvelle page dans ton carnet : %s - Fara l'a dessinée : « %s » (%d/%d)")
		% [title, line, progress.x, progress.y])
