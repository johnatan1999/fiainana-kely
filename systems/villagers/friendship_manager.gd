class_name FriendshipManager
extends Node

## Friendship with the villagers, between FarmSimulation (the points, the
## gifts, saved) and the world: registers every villager's gifts
## (data/villagers/*.tres), counts talking to them (once a day), shows the
## hearts over their head when it matters (talking to them, friendship
## growing), and celebrates a new heart - a notification, and their gift
## handed over with a word when there is one. Orders and the neighbours'
## harvest add friendship through the simulation. See docs/friendship.md.

var simulation: FarmSimulation
var item_db: ItemDatabase

var _names: Dictionary = {} # villager_id -> display name
var _family: Dictionary = {} # villager_id -> true: no friendship with them

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager) -> void:
	simulation = p_simulation
	item_db = p_item_db
	simulation.friendship_changed.connect(_on_friendship_changed)
	simulation.friendship_level_up.connect(_on_level_up)
	world_manager.zone_loaded.connect(_on_zone_loaded)
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		var data: VillagerData = villagers[villager_id]
		_names[villager_id] = data.display_name
		if data.family:
			_family[villager_id] = true
			continue
		simulation.register_friend(villager_id, data.friendship_rewards)

func _on_zone_loaded(_zone: ZoneRoot) -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if not villager.interacted.is_connected(_on_talk):
			villager.interacted.connect(_on_talk.bind(villager))

## Talking: friendship once a day, and the hearts shown either way.
func _on_talk(villager: Villager) -> void:
	var villager_id := villager.get_villager_id()
	if _family.has(villager_id):
		return
	simulation.talk_to(villager_id)
	_show_hearts(villager_id)

func _on_friendship_changed(villager_id: String, _hearts: int) -> void:
	_show_hearts(villager_id)

func _on_level_up(villager_id: String, hearts: int, reward: FriendshipReward) -> void:
	var name: String = _names.get(villager_id, villager_id)
	var text := tr("%s et toi êtes plus proches : %d cœur(s).") % [name, hearts]
	if reward != null:
		text += " " + tr("Cadeau : %d %s.") % [reward.quantity, item_db.get_display_name(reward.item_id)]
	UIEvents.notify(text)
	if reward == null:
		return
	var villager := _villager(villager_id)
	if villager != null:
		# After whatever they're saying now (a greeting, a thank-you).
		villager.say.call_deferred(tr(reward.line))
		HarvestPopup.spawn(villager, villager.global_position + Vector2(0, -120),
			item_db.get_icon(reward.item_id), "+%d %s" % [reward.quantity, item_db.get_display_name(reward.item_id)])

func _show_hearts(villager_id: String) -> void:
	if _family.has(villager_id):
		return
	var villager := _villager(villager_id)
	if villager != null:
		villager.show_hearts(simulation.get_hearts(villager_id), FarmSimulation.FRIENDSHIP_MAX_HEARTS,
			simulation.get_heart_progress(villager_id))

## The villager in the current zone, out of doors - or null.
func _villager(villager_id: String) -> Villager:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == villager_id and not villager.is_inside():
			return villager
	return null
