class_name FamilyProjectManager
extends Node

## The family's projects - taking the farm's buildings to their next level
## (FamilyProject, data/projects/) - between FarmSimulation (the levels, the
## building site, saved) and the world. Decides nothing itself:
## - Dada (FATHER_ID) keeps them: talking to him opens FamilyProjectsPanel,
##   to start one;
## - on the farm, the buildings as their level says: the coop's look
##   (Coop.set_level), the zebu pen's size (PEN_LEVELS: its scene replaces
##   the level 1 placed in the zone), the house's annexes once built
##   (HouseAnnex: granary, kitchen), and a ConstructionSite on the one being
##   worked on;
## - the news: work starting (and the friends who come to help), work done.
## See docs/family_projects.md.

const FATHER_ID := "father"
## The farm's buildings in the zone scenes.
const COOP_NODE := "ChickenCoopBuilding"
const PEN_NODE := "ZebuPen"
## The zebu pen by level (tools/build_zebu_pen.gd): its scene, and where its
## origin is from the level 1's - the bigger ones grow west, then north.
const PEN_LEVELS := {
	2: {"scene": "res://entities/zebu/zebu_pen_2.tscn", "offset": Vector2(-96, 0), "size": Vector2(384, 192)},
	3: {"scene": "res://entities/zebu/zebu_pen_3.tscn", "offset": Vector2(-96, -48), "size": Vector2(384, 240)},
}
const PEN_SIZE := Vector2(288, 192)
## The coop's footprint, from its origin (the ruin's art and the levels').
const COOP_AREA := Rect2(0, -172, 224, 172)
const BUILDING_NAMES := {"coop": "Le poulailler", "zebu_pen": "Le parc à zébus",
	"granary": "Le grenier à riz", "kitchen": "La cuisine"}
## The house's annexes in the farm scene (HouseAnnex), by building.
const ANNEX_NODES := {"granary": "Granary", "kitchen": "Kitchen"}

var simulation: FarmSimulation

var _panel: FamilyProjectsPanel
var _names: Dictionary = {} # villager_id -> display name
var _zone: ZoneRoot
## The level 1 pen's place in the zone, before any bigger one replaced it.
var _pen_origin := Vector2.ZERO
var _site: ConstructionSite

func setup(p_simulation: FarmSimulation, world_manager: WorldManager, panel: FamilyProjectsPanel) -> void:
	simulation = p_simulation
	_panel = panel
	var projects := FamilyProject.load_all()
	for project_id: String in projects:
		simulation.projects.register_project(project_id, projects[project_id])
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		_names[villager_id] = villagers[villager_id].display_name
	_panel.start_requested.connect(_on_start_requested)
	simulation.project_started.connect(_on_project_started)
	simulation.project_completed.connect(_on_project_completed)
	simulation.state_loaded.connect(func():
		_sync_coop_interior()
		_dress_zone())
	simulation.coop_built.connect(func():
		_sync_coop_interior()
		_dress_zone())
	_sync_coop_interior()
	simulation.money_changed.connect(func(_money: int):
		if _panel.is_open():
			_show_panel())
	world_manager.zone_loaded.connect(_on_zone_loaded)
	world_manager.zone_unloading.connect(func(_zone_root: ZoneRoot):
		_zone = null
		_site = null)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_zone = zone
	_site = null
	var pen := zone.get_node_or_null(PEN_NODE) as Node2D
	if pen != null:
		_pen_origin = pen.position
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == FATHER_ID and not villager.interacted.is_connected(_on_father_interacted):
			villager.interacted.connect(_on_father_interacted)
			villager.talk_prompt = tr("Parler des projets de la famille")
			villager.set_prompt(villager.talk_prompt)
	_dress_zone(true)

## The farm's buildings as their level says, and the building site.
## `fresh`: the zone just loaded - the only time the pen can be swapped,
## before its zebus pair with it (on their first clock tick).
func _dress_zone(fresh := false) -> void:
	if _zone == null or not is_instance_valid(_zone):
		return
	var coop := _zone.get_node_or_null(COOP_NODE) as Coop
	if coop != null:
		coop.set_level(simulation.projects.get_building_level("coop"))
	if fresh and _zone.get_node_or_null("ZebuPasture") != null:
		_size_pen(simulation.projects.get_building_level("zebu_pen"))
	for building: String in ANNEX_NODES:
		var annex := _zone.get_node_or_null(ANNEX_NODES[building]) as HouseAnnex
		if annex != null:
			annex.set_level(simulation.projects.get_building_level(building))
	_place_site()

## The farm's pen at `level`: its scene in place of the one there.
func _size_pen(level: int) -> void:
	var pen := _zone.get_node_or_null(PEN_NODE) as Node2D
	if pen == null or int(pen.get_meta("level", 1)) == level or not PEN_LEVELS.has(level):
		return
	var bigger: Node2D = load(PEN_LEVELS[level]["scene"]).instantiate()
	bigger.name = PEN_NODE
	bigger.position = _pen_origin + PEN_LEVELS[level]["offset"]
	bigger.set_meta("level", level)
	_zone.remove_child(pen)
	pen.queue_free()
	_zone.add_child(bigger)
	# ZebuPen.nearest() pairs zebus with the pens of their own zone.
	bigger.owner = _zone

## Scaffolding on the building being worked on, if it's in this zone.
func _place_site() -> void:
	if _site != null and is_instance_valid(_site):
		_site.queue_free()
	_site = null
	var site := simulation.projects.get_construction()
	if site.is_empty() or _zone == null:
		return
	var project := simulation.projects.get_project(site["project"])
	if project == null:
		return
	var at := Vector2.ZERO
	var area := Rect2()
	match project.building:
		"coop":
			var coop := _zone.get_node_or_null(COOP_NODE) as Node2D
			if coop == null:
				return
			at = coop.position
			area = COOP_AREA
		"zebu_pen":
			var pen := _zone.get_node_or_null(PEN_NODE) as Node2D
			if pen == null or _zone.get_node_or_null("ZebuPasture") == null:
				return
			var level := simulation.projects.get_building_level("zebu_pen")
			var size: Vector2 = PEN_LEVELS[level]["size"] if PEN_LEVELS.has(level) else PEN_SIZE
			at = pen.position + Vector2(0, size.y)
			area = Rect2(0, -70, size.x, 70)
		var annex_building when ANNEX_NODES.has(annex_building):
			var annex := _zone.get_node_or_null(ANNEX_NODES[annex_building]) as Node2D
			if annex == null:
				return
			at = annex.position
			area = HouseAnnex.AREA
		_:
			return
	_site = ConstructionSite.new()
	_site.name = "ConstructionSite"
	_site.area = area
	_site.position = at
	_zone.add_child(_site)

# --- Dada and the panel -----------------------------------------------------------------------

func _on_father_interacted() -> void:
	_show_panel()

func _show_panel() -> void:
	var sections := []
	for building: String in ProjectRules.BUILDINGS:
		var level := simulation.projects.get_building_level(building)
		var title := tr(BUILDING_NAMES[building])
		if building in ANNEX_NODES:
			title += " — " + (tr("à construire") if level == 0 else tr("construit"))
		else:
			title += " — " + (tr("en ruine") if level == 0 else tr("niveau %d") % level)
		var projects := []
		for project_id: String in simulation.projects.get_project_ids():
			var project := simulation.projects.get_project(project_id)
			if project.building == building:
				projects.append(_describe(project_id, project))
		sections.append({"title": title, "projects": projects})
	_panel.show_projects(_dada_line(), sections)

func _describe(project_id: String, project: FamilyProject) -> Dictionary:
	var state := simulation.projects.get_project_state(project_id)
	var helpers := simulation.projects.get_project_helpers()
	var entry := {
		"id": project_id, "name": tr(project.display_name), "malagasy": project.malagasy_name,
		"description": tr(project.description), "cost": project.cost, "days": project.build_days,
		"helpers": "", "button": false, "can_start": false, "status": "", "status_color": FamilyProjectsPanel.MUTED_COLOR,
	}
	match state:
		ProjectRules.ProjectState.DONE:
			entry["status"] = tr("Terminé ✓")
			entry["status_color"] = FamilyProjectsPanel.DONE_COLOR
		ProjectRules.ProjectState.BUILDING:
			var days := int(simulation.projects.get_construction()["done_day"]) - simulation.state.day
			entry["status"] = tr("En chantier : prêt dans %d jour(s)") % days
			entry["status_color"] = FamilyProjectsPanel.BUSY_COLOR
		ProjectRules.ProjectState.BUSY:
			entry["status"] = tr("Un chantier à la fois")
		ProjectRules.ProjectState.LOCKED:
			entry["status"] = _locked_text(project)
		ProjectRules.ProjectState.AVAILABLE:
			entry["button"] = true
			entry["can_start"] = simulation.projects.can_start_project(project_id)
			if not entry["can_start"]:
				entry["status"] = tr("Il manque %s") % Currency.format(project.cost - simulation.state.money)
				entry["status_color"] = FamilyProjectsPanel.BUSY_COLOR
			if not helpers.is_empty():
				entry["helpers"] = tr("%s viendront aider : %d jour(s) au lieu de %d.") % [_names_list(helpers),
					simulation.projects.get_project_days(project_id), project.build_days]
	return entry

func _locked_text(project: FamilyProject) -> String:
	if project.building == "coop" and simulation.projects.get_building_level("coop") == 0:
		return tr("Reconstruis d'abord le poulailler (dedans).")
	for project_id: String in simulation.projects.get_project_ids():
		var before := simulation.projects.get_project(project_id)
		if before.building == project.building and before.level == project.level - 1:
			return tr("Après : %s") % tr(before.display_name)
	return tr("Pas encore")

func _dada_line() -> String:
	var site := simulation.projects.get_construction()
	if not site.is_empty():
		var project := simulation.projects.get_project(site["project"])
		return tr("Le chantier avance bien. On ne lance pas deux chantiers à la fois, ça coûte trop.") if project != null \
			else tr("Le chantier avance.")
	if simulation.projects.get_project_helpers().is_empty():
		return tr("On a des projets pour la ferme. Fais-toi des amis au village : ils viendront aider aux travaux.")
	return tr("On a des projets pour la ferme. Tes amis du village sont prêts à venir aider.")

func _on_start_requested(project_id: String) -> void:
	if simulation.projects.start_project(project_id):
		AudioManager.play_coop_build_sfx()
		_show_panel()

# --- the news ---------------------------------------------------------------------------------

func _on_project_started(project_id: String) -> void:
	var project := simulation.projects.get_project(project_id)
	var site := simulation.projects.get_construction()
	var days := int(site["done_day"]) - simulation.state.day
	var text := tr("Les travaux commencent : %s, prêt dans %d jour(s).") % [tr(project.display_name).to_lower(), days]
	if not site["helpers"].is_empty():
		text += " " + tr("%s viennent aider.") % _names_list(site["helpers"])
	UIEvents.notify(text)
	_place_site()

## The coop's inside is built from the coop's level when its zone loads -
## it reads CoopInterior.level; a room already there is rebuilt.
func _sync_coop_interior() -> void:
	CoopInterior.level = simulation.projects.get_building_level("coop")
	get_tree().call_group(CoopInterior.GROUP, "set_level", CoopInterior.level)

func _on_project_completed(project_id: String) -> void:
	_sync_coop_interior()
	var project := simulation.projects.get_project(project_id)
	UIEvents.notify(tr("C'est fini : %s ! %s") % [tr(project.display_name).to_lower(), tr(project.description)])
	_dress_zone()

func _names_list(ids: Array) -> String:
	var names := ids.map(func(id: String) -> String: return _names.get(id, id))
	return " et ".join(names)
