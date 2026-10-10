class_name QuestRules
extends SimRules

## Side quests (fangatahana): offered, under way step by step, finished and
## rewarded.
## A part of FarmSimulation (SimRules): simulation.quests.

## What a quest's reward_unlock can give the farm (_unlock).
const QUEST_UNLOCKS := ["dog"]
## Story conditions (FarmSimulation.get_conditions()) for each side quest: under way, or
## finished - a villager's day can depend on them (VillagerStop.only_if /
## unless).
const QUEST_ACTIVE_PREFIX := "quest_active:"
const QUEST_DONE_PREFIX := "quest_done:"

var _quests: Dictionary = {} # quest_id: String -> Quest

## What a quest's reward_unlock gives the farm.
func _unlock(what: String) -> void:
	match what:
		"dog":
			sim.dog.adopt_dog()
		_:
			push_warning("FarmSimulation: unknown quest unlock '%s'." % what)

## Registered by QuestManager (data/quests/).
## The story conditions of the quests: "quest_active:<id>" while under way,
## "quest_done:<id>" once finished (FarmSimulation.get_conditions()).
func get_conditions() -> Dictionary:
	var conditions := {}
	for quest_id: String in state.quests:
		conditions[QUEST_ACTIVE_PREFIX + quest_id] = true
	for quest_id: String in state.quests_done:
		conditions[QUEST_DONE_PREFIX + quest_id] = true
	return conditions

func register_quest(quest_id: String, quest: Quest) -> void:
	_quests[quest_id] = quest

func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id)

func get_quest_ids() -> Array:
	var ids := _quests.keys()
	ids.sort()
	return ids

func is_quest_active(quest_id: String) -> bool:
	return state.quests.has(quest_id)

func is_quest_done(quest_id: String) -> bool:
	return state.quests_done.has(quest_id)

## Whether its giver offers it now: not taken yet, and its requirements met
## (the day, the giver's friendship, the quests and pages before it, the
## season).
func is_quest_available(quest_id: String) -> bool:
	var quest := get_quest(quest_id)
	if quest == null or quest.steps.is_empty() or is_quest_active(quest_id) or is_quest_done(quest_id):
		return false
	if state.day < quest.min_day or sim.friendship.get_hearts(quest.giver) < quest.min_hearts:
		return false
	if not quest.is_in_season(state.clock.get_season()):
		return false
	for before: String in quest.after_quests:
		if not is_quest_done(before):
			return false
	for page: String in quest.after_discoveries:
		if not sim.notebook.is_discovered(page):
			return false
	return true

## The quest `villager_id` offers now ("" for none) - the first by id.
func get_quest_offered_by(villager_id: String) -> String:
	for quest_id: String in get_quest_ids():
		if _quests[quest_id].giver == villager_id and is_quest_available(quest_id):
			return quest_id
	return ""

## The quests under way, in the order they were accepted.
func get_active_quests() -> Array:
	var ids := state.quests.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: int = state.quests[a]["since"]
		var db: int = state.quests[b]["since"]
		return da < db if da != db else a < b)
	return ids

## The step the quest is at (null when it isn't under way).
func get_quest_step(quest_id: String) -> QuestStep:
	var quest := get_quest(quest_id)
	if quest == null or not is_quest_active(quest_id):
		return null
	var index: int = state.quests[quest_id]["step"]
	return quest.steps[index] if index < quest.steps.size() else null

func get_quest_step_index(quest_id: String) -> int:
	return int(state.quests[quest_id]["step"]) if is_quest_active(quest_id) else -1

## The current step's items: how many the player has, out of how many
## (Vector2i.ZERO if it takes none).
func get_quest_item_progress(quest_id: String) -> Vector2i:
	var step := get_quest_step(quest_id)
	if step == null or not step.needs_items():
		return Vector2i.ZERO
	return Vector2i(state.get_inventory_count(step.item_id), step.quantity)

## The quest whose current step is with `villager_id` (talk to them, bring
## them something) - "" for none.
func get_quest_waiting_on(villager_id: String) -> String:
	for quest_id: String in get_active_quests():
		var step := get_quest_step(quest_id)
		if step != null and step.kind in [QuestStep.Kind.TALK, QuestStep.Kind.BRING] and step.villager == villager_id:
			return quest_id
	return ""

## The quest whose current step is at the QuestTarget `target_id` ("" for
## none).
func get_quest_at_target(target_id: String) -> String:
	for quest_id: String in get_active_quests():
		var step := get_quest_step(quest_id)
		if step != null and step.kind in [QuestStep.Kind.REACH, QuestStep.Kind.INTERACT] and step.target == target_id:
			return quest_id
	return ""

## Whether the current step can be done now: its items in the bag.
func can_do_quest_step(quest_id: String) -> bool:
	var step := get_quest_step(quest_id)
	if step == null:
		return false
	if step.kind == QuestStep.Kind.DISCOVER:
		return sim.notebook.is_discovered(step.discovery_id)
	return not step.needs_items() or state.get_inventory_count(step.item_id) >= step.quantity

## The player accepts it: on to its first step.
func start_quest(quest_id: String) -> bool:
	if not is_quest_available(quest_id):
		return false
	state.quests[quest_id] = {"step": 0, "since": state.day}
	sim.quest_changed.emit(quest_id)
	check_quest_discovery(quest_id)
	return true

## Talking to `villager_id`: does the step of a quest waiting on them, if
## it can be done (BRING: the items given). Returns the quest ("" for none).
func quest_talk(villager_id: String) -> String:
	var quest_id := get_quest_waiting_on(villager_id)
	if quest_id.is_empty() or not can_do_quest_step(quest_id):
		return ""
	_do_quest_step(quest_id)
	return quest_id

## At the QuestTarget `target_id` (walked into, or used): does the step of
## the quest waiting there, if it can be done (INTERACT: the items used).
## Returns the quest ("" for none).
func quest_trigger(target_id: String) -> String:
	var quest_id := get_quest_at_target(target_id)
	if quest_id.is_empty() or not can_do_quest_step(quest_id):
		return ""
	_do_quest_step(quest_id)
	return quest_id

## A DISCOVER step is done as soon as the page is in the notebook.
func check_quest_discovery(quest_id: String) -> void:
	var step := get_quest_step(quest_id)
	if step != null and step.kind == QuestStep.Kind.DISCOVER and sim.notebook.is_discovered(step.discovery_id):
		_do_quest_step(quest_id)

## The step done (its items taken), on to the next - or, after the last,
## the quest finished and its reward given.
func _do_quest_step(quest_id: String) -> void:
	var quest := get_quest(quest_id)
	var step := get_quest_step(quest_id)
	if step.needs_items():
		sim.add_item(step.item_id, -step.quantity)
	var next: int = state.quests[quest_id]["step"] + 1
	if next < quest.steps.size():
		state.quests[quest_id]["step"] = next
		sim.quest_changed.emit(quest_id)
		check_quest_discovery(quest_id)
		return
	state.quests.erase(quest_id)
	state.quests_done[quest_id] = state.day
	if quest.reward_money > 0:
		sim.add_money(quest.reward_money)
	for item_id: String in quest.reward_items:
		sim.add_item(item_id, int(quest.reward_items[item_id]))
	day_log.quests_done.append(quest_id)
	if quest.reward_friendship > 0:
		sim.friendship.add_friendship(quest.giver, quest.reward_friendship)
	# All of the reward given before anyone hears the quest is over.
	if not quest.reward_unlock.is_empty():
		_unlock(quest.reward_unlock)
	sim.quest_changed.emit(quest_id)
	sim.quest_completed.emit(quest_id)
