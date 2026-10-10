class_name QuestManager
extends Node

## Side quests (fangatahana), between FarmSimulation (the rules, the state)
## and the world. Decides nothing itself:
## - registers the quests (data/quests/*.tres, Quest.load_all());
## - the givers: a quest to offer -> a "!" over their head, and talking to
##   them opens the QuestPanel; a step waiting on a villager (talk, bring)
##   -> "?" (or the prompt alone while the items are missing), and talking
##   to them does it: what they say;
## - the QuestTargets of the zone: shown while a step is there (walk in, or
##   use them), or once their quest is done;
## - the OrdersTracker's quests: each one's next step;
## - the story conditions handed to the villagers (quest_active:<id>,
##   quest_done:<id>);
## - in the morning, who has a new quest; at the end, the reward.
## OrderManager steps aside for a villager a quest waits on
## (has_quest_business). See docs/quests.md.

## The marks over a villager's head, for a quest: not the orders' gold.
const MARK_COLOR := Color(0.4, 0.85, 0.9)

var simulation: FarmSimulation
var item_db: ItemDatabase

var _panel: QuestPanel
var _tracker: OrdersTracker
var _names: Dictionary = {} # villager_id -> display name
## The quests available last time it was looked: a new one is announced.
var _available: Array[String] = []
## The quest shown in the panel.
var _offering := ""

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager,
		panel: QuestPanel, tracker: OrdersTracker) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_panel = panel
	_tracker = tracker
	var quests := Quest.load_all()
	for quest_id: String in quests:
		simulation.register_quest(quest_id, quests[quest_id])
	_load_names()
	_panel.accepted.connect(_on_accepted)
	simulation.quest_changed.connect(func(_quest_id: String): _refresh())
	simulation.quest_completed.connect(_on_completed)
	simulation.inventory_changed.connect(func(_item: String, _amount: int): _refresh())
	simulation.friendship_changed.connect(func(_villager: String, _hearts: int): _refresh())
	simulation.discovery_made.connect(func(_page: String): _refresh())
	simulation.state_loaded.connect(func():
		_available.clear()
		_refresh.call_deferred())
	world_manager.zone_loaded.connect(_on_zone_loaded)
	_refresh.call_deferred()

func _load_names() -> void:
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		_names[villager_id] = villagers[villager_id].display_name

## Whether a side quest has something to do with `villager_id` now: one to
## offer, or a step with them. OrderManager leaves them to QuestManager.
static func has_quest_business(p_simulation: FarmSimulation, villager_id: String) -> bool:
	return not p_simulation.get_quest_offered_by(villager_id).is_empty() \
		or not p_simulation.get_quest_waiting_on(villager_id).is_empty()

func _on_zone_loaded(zone: ZoneRoot) -> void:
	# Connected after OrderManager's (world.gd sets QuestManager up later):
	# it has already stepped aside when this answers.
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if not villager.interacted.is_connected(_on_villager_interacted):
			villager.interacted.connect(_on_villager_interacted.bind(villager))
	for node in zone.find_children("*", "", true, false):
		if node is QuestTarget and not node.triggered.is_connected(_on_target_triggered):
			node.triggered.connect(_on_target_triggered.bind(node))
	_refresh()

# --- talking to a villager --------------------------------------------------------------

func _on_villager_interacted(villager: Villager) -> void:
	var villager_id := villager.get_villager_id()
	var waiting := simulation.get_quest_waiting_on(villager_id)
	if not waiting.is_empty():
		villager.turn_to_player()
		var step := simulation.get_quest_step(waiting)
		if simulation.quest_talk(villager_id).is_empty():
			villager.say(tr(step.waiting_line) if not step.waiting_line.is_empty()
				else tr("Tu m'apportes %d %s ?") % [step.quantity, _item_name(step.item_id)])
		elif not step.line.is_empty():
			villager.say(tr(step.line))
		return
	var offered := simulation.get_quest_offered_by(villager_id)
	if offered.is_empty():
		return
	villager.turn_to_player()
	var quest := simulation.get_quest(offered)
	_offering = offered
	_panel.open(tr(quest.title), _names.get(quest.giver, quest.giver), tr(quest.offer_line),
		_objective(quest.steps[0]), _reward_text(quest))

func _on_accepted() -> void:
	var quest := simulation.get_quest(_offering)
	if not simulation.start_quest(_offering):
		return
	_say(quest.giver, tr("Merci ! Je savais que je pouvais compter sur toi."))
	UIEvents.notify(tr("Nouvelle quête : %s") % tr(quest.title))

# --- quest targets ----------------------------------------------------------------------

func _on_target_triggered(target: QuestTarget) -> void:
	var quest_id := simulation.get_quest_at_target(target.target_id)
	if quest_id.is_empty():
		return
	var step := simulation.get_quest_step(quest_id)
	if simulation.quest_trigger(target.target_id).is_empty():
		UIEvents.notify(tr(step.waiting_line) if not step.waiting_line.is_empty()
			else tr("Il te faut %d %s.") % [step.quantity, _item_name(step.item_id)])
		return
	if not step.line.is_empty():
		UIEvents.notify(tr(step.line))

# --- the end ----------------------------------------------------------------------------

func _on_completed(quest_id: String) -> void:
	var quest := simulation.get_quest(quest_id)
	AudioManager.play_harvest_sfx()
	var reward := _reward_text(quest)
	UIEvents.notify(tr("Quête terminée : %s") % tr(quest.title)
		+ (" (%s)" % reward if not reward.is_empty() else ""))
	if quest.reward_money > 0:
		for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
			if villager.get_villager_id() == quest.giver and not villager.is_inside():
				HarvestPopup.spawn(villager, villager.global_position + Vector2(0, -110), null,
					"+%s" % Currency.format(quest.reward_money))

# --- marks, prompts, targets, tracker, conditions -----------------------------------------

func _refresh() -> void:
	if simulation == null or not is_inside_tree():
		return
	_announce_new()
	var conditions := simulation.get_conditions()
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		var villager_id := villager.get_villager_id()
		villager.set_conditions(conditions)
		var name: String = _names.get(villager_id, villager_id)
		var waiting := simulation.get_quest_waiting_on(villager_id)
		if not waiting.is_empty():
			var step := simulation.get_quest_step(waiting)
			var ready := simulation.can_do_quest_step(waiting)
			villager.set_order_mark("?" if ready else "", MARK_COLOR)
			villager.set_prompt(tr(step.prompt) if not step.prompt.is_empty()
				else (tr("Donner %d %s à %s") % [step.quantity, _item_name(step.item_id), name] if step.kind == QuestStep.Kind.BRING
				else tr("Parler à %s") % name))
		elif not simulation.get_quest_offered_by(villager_id).is_empty():
			villager.set_order_mark("!", MARK_COLOR)
			villager.set_prompt(tr("Écouter %s") % name)
	for target: QuestTarget in get_tree().get_nodes_in_group(QuestTarget.GROUP):
		if target.appears == QuestTarget.Show.AFTER_DONE:
			target.set_shown(simulation.is_quest_done(target.quest_id))
			continue
		var quest_id := simulation.get_quest_at_target(target.target_id)
		var step := simulation.get_quest_step(quest_id) if not quest_id.is_empty() else null
		target.set_shown(step != null, tr(step.prompt) if step != null and not step.prompt.is_empty() else tr("Regarder"))
	var rows := []
	for quest_id: String in simulation.get_active_quests():
		var step := simulation.get_quest_step(quest_id)
		var progress := simulation.get_quest_item_progress(quest_id)
		var objective := _objective(step)
		if progress != Vector2i.ZERO:
			objective += " (%d/%d)" % [mini(progress.x, progress.y), progress.y]
		rows.append({"title": tr(simulation.get_quest(quest_id).title), "objective": objective,
			"ready": step.needs_items() and simulation.can_do_quest_step(quest_id)})
	_tracker.show_quests(rows)

## A quest newly offered (a new day, a heart more, a quest finished): who
## has one - said once.
func _announce_new() -> void:
	var available: Array[String] = []
	for quest_id: String in simulation.get_quest_ids():
		if simulation.is_quest_available(quest_id):
			available.append(quest_id)
			if not _available.has(quest_id):
				var giver: String = simulation.get_quest(quest_id).giver
				UIEvents.notify(tr("%s a besoin d'un coup de main.") % _names.get(giver, giver))
	_available = available

func _objective(step: QuestStep) -> String:
	return tr(step.objective) if step != null else ""

## "10 000 Ar, 2 Graines de riz, l'amitié de Rakoto" ("" for nothing).
func _reward_text(quest: Quest) -> String:
	var parts: Array[String] = []
	if quest.reward_money > 0:
		parts.append(Currency.format(quest.reward_money))
	for item_id: String in quest.reward_items:
		parts.append("%d %s" % [int(quest.reward_items[item_id]), _item_name(item_id)])
	if quest.reward_friendship > 0:
		parts.append(tr("l'amitié de %s") % _names.get(quest.giver, quest.giver))
	return ", ".join(parts)

func _say(villager_id: String, text: String) -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == villager_id and not villager.is_inside():
			villager.say(text)

func _item_name(item_id: String) -> String:
	return item_db.get_display_name(item_id).to_lower()
