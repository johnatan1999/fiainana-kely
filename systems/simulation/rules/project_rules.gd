class_name ProjectRules
extends SimRules

## Family projects: the farm's buildings and their level, and the building site
## under way.
## A part of FarmSimulation (SimRules): simulation.projects.

## Family projects (FamilyProject, data/projects/): the farm's buildings
## and their level - the coop (0 = still a ruin, 1 once built, then 2, 3)
## and the zebu pen (1 to 3). One building site at a time: paid up front,
## finished PROJECT_DAYS later in the morning - a day less for each friend
## (PROJECT_HELPER_HEARTS hearts and up) who comes to help, at most
## PROJECT_MAX_HELPERS of them, never under a day: the valin-tanana.
const BUILDINGS := ["coop", "zebu_pen", "granary", "kitchen"]
## Each building's level at the start of a game: the coop is a ruin until
## built (has_coop), the pen is there, the house's annexes aren't yet.
const BUILDING_START_LEVELS := {"zebu_pen": 1, "granary": 0, "kitchen": 0}
## The granary on stilts: no more rice for the rats - this much more at
## each rice harvest.
const GRANARY_RICE_MULTIPLIER := 1.25
const GRANARY_CROP := "rice"
const COOP_CAPACITY_BY_LEVEL := [0, 4, 8, 12]
## From this coop level, the eggs go straight into the bag.
const COOP_BASKET_LEVEL := 3
## From this pen level, a filled trough lasts two days.
const ZEBU_TROUGH_TWO_DAYS_LEVEL := 3
const PROJECT_HELPER_HEARTS := 2
const PROJECT_MAX_HELPERS := 2
enum ProjectState { DONE, BUILDING, AVAILABLE, LOCKED, BUSY }

var _projects: Dictionary = {} # project_id: String -> FamilyProject

## Registered by FamilyProjectManager (data/projects/).
func register_project(project_id: String, project: FamilyProject) -> void:
	_projects[project_id] = project

func get_project(project_id: String) -> FamilyProject:
	return _projects.get(project_id)

## Projects ids, building by building, level by level.
func get_project_ids() -> Array:
	var ids := _projects.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: FamilyProject = _projects[a]
		var pb: FamilyProject = _projects[b]
		if pa.building != pb.building:
			return BUILDINGS.find(pa.building) < BUILDINGS.find(pb.building)
		return pa.level < pb.level)
	return ids

## The coop: 0 while it's a ruin, 1 once built (AnimalRules.build_coop()), then what
## projects brought it to. The zebu pen: 1 to start with.
func get_building_level(building: String) -> int:
	if building == "coop" and not state.has_coop:
		return 0
	return int(state.building_levels.get(building, BUILDING_START_LEVELS.get(building, 1)))

## The building site under way: {"project", "done_day", "helpers": [ids]},
## {} with none.
func get_construction() -> Dictionary:
	return state.construction

func get_project_state(project_id: String) -> ProjectState:
	var project := get_project(project_id)
	if project == null:
		return ProjectState.LOCKED
	if get_building_level(project.building) >= project.level:
		return ProjectState.DONE
	if state.construction.get("project", "") == project_id:
		return ProjectState.BUILDING
	if get_building_level(project.building) < project.level - 1:
		return ProjectState.LOCKED
	if not state.construction.is_empty():
		return ProjectState.BUSY
	return ProjectState.AVAILABLE

## The friends who'd come and help build (villager ids, the closest first).
func get_project_helpers() -> Array[String]:
	var friends: Array[String] = []
	for villager_id: String in state.friendship:
		if sim.friendship.get_hearts(villager_id) >= PROJECT_HELPER_HEARTS:
			friends.append(villager_id)
	friends.sort_custom(func(a, b): return sim.friendship.get_friendship(a) > sim.friendship.get_friendship(b))
	return friends.slice(0, PROJECT_MAX_HELPERS)

## Days the work would take, starting today, with the friends who'd help.
func get_project_days(project_id: String) -> int:
	var project := get_project(project_id)
	if project == null:
		return 0
	return maxi(project.build_days - get_project_helpers().size(), 1)

func can_start_project(project_id: String) -> bool:
	return get_project_state(project_id) == ProjectState.AVAILABLE \
		and state.money >= get_project(project_id).cost

## Pays and starts the work: finished get_project_days() later, in the
## morning.
func start_project(project_id: String) -> bool:
	if not can_start_project(project_id):
		return false
	var project := get_project(project_id)
	sim.add_money(-project.cost)
	state.construction = {"project": project_id, "done_day": state.day + get_project_days(project_id),
		"helpers": get_project_helpers()}
	sim.project_started.emit(project_id)
	return true

## Morning: the building site finished today, if any.
func advance_projects() -> void:
	if state.construction.is_empty() or state.day < int(state.construction["done_day"]):
		return
	var project_id: String = state.construction["project"]
	var project := get_project(project_id)
	state.construction = {}
	if project == null:
		return
	state.building_levels[project.building] = project.level
	if project.building == "coop":
		state.coop_capacity = COOP_CAPACITY_BY_LEVEL[project.level]
	sim.project_completed.emit(project_id)
	sim.zebus_changed.emit()
