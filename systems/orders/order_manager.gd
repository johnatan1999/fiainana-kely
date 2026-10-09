class_name OrderManager
extends Node

## Villagers' orders, between FarmSimulation (the rules, the state) and the
## world: registers every villager's orders (data/villagers/*.tres) in the
## simulation (VillagerData.load_all()), answers when the player talks to a villager (an order to
## offer -> OrderPanel, one to deliver -> delivered, one in progress -> a
## reminder, else a greeting), keeps the marks over their heads ("!", "?")
## and the OrdersTracker up to date, and says in the morning who has an
## order to offer. Never enforces rules itself. See docs/orders.md.

var simulation: FarmSimulation
var item_db: ItemDatabase

var _world_manager: WorldManager
var _player: Node2D
var _panel: OrderPanel
var _tracker: OrdersTracker
var _names: Dictionary = {} # villager_id -> display name
## Offered since the last announcement (said in the morning).
var _new_offers: Array[String] = []
## The villager whose offer is shown in the panel.
var _offering := ""

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, p_world_manager: WorldManager,
		player: Node2D, panel: OrderPanel, tracker: OrdersTracker) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_world_manager = p_world_manager
	_player = player
	_panel = panel
	_tracker = tracker
	_panel.accepted.connect(_on_accepted)
	_panel.declined.connect(_on_declined)
	simulation.order_changed.connect(_on_order_changed)
	simulation.order_expired.connect(_on_order_expired)
	simulation.inventory_changed.connect(func(_item: String, _amount: int): _refresh())
	simulation.day_changed.connect(func(_day: int): _on_morning())
	# A save from an earlier day: this morning's offers.
	simulation.state_loaded.connect(func():
		_new_offers.clear()
		simulation.refresh_order_offers()
		_on_morning.call_deferred())
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	_register_villagers()
	simulation.refresh_order_offers()
	_on_morning.call_deferred()

func _register_villagers() -> void:
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		var data: VillagerData = villagers[villager_id]
		_names[villager_id] = data.display_name
		simulation.register_order_giver(villager_id, data.orders)

func _on_zone_loaded(_zone: ZoneRoot) -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if not villager.interacted.is_connected(_on_villager_interacted):
			villager.interacted.connect(_on_villager_interacted.bind(villager))
	_refresh()

func _on_order_changed(villager_id: String) -> void:
	if simulation.is_order_offered(villager_id) and not _new_offers.has(villager_id):
		_new_offers.append(villager_id)
	_refresh()

func _on_order_expired(villager_id: String) -> void:
	UIEvents.notify(tr("%s n'a pas reçu sa commande à temps.") % _names.get(villager_id, villager_id))

## Who has an order to offer this morning.
func _on_morning() -> void:
	_refresh()
	for villager_id in _new_offers:
		if simulation.is_order_offered(villager_id):
			UIEvents.notify(tr("%s a une commande pour toi.") % _names.get(villager_id, villager_id))
	_new_offers.clear()

# --- talking to a villager ------------------------------------------------------------

func _on_villager_interacted(villager: Villager) -> void:
	var villager_id := villager.get_villager_id()
	villager.turn_to_player()
	if simulation.is_order_offered(villager_id):
		_offer(villager, villager_id)
	elif simulation.can_deliver_order(villager_id):
		_deliver(villager, villager_id)
	elif simulation.is_order_active(villager_id):
		var order := simulation.get_order(villager_id)
		var days := simulation.get_order_days_left(villager_id)
		villager.say(tr("J'attends toujours %d %s. Encore %d jour(s) !") % [order["quantity"], _item_name(order["item"]).to_lower(), days])
	else:
		villager.greet()

func _offer(villager: Villager, villager_id: String) -> void:
	var order := simulation.get_order(villager_id)
	var template := simulation.get_order_template(villager_id)
	var line := tr("Tu pourrais m'apporter %d %s ?") % [order["quantity"], _item_name(order["item"]).to_lower()]
	if template != null and not template.request_line.is_empty():
		line = tr(template.request_line) % order["quantity"]
	var can_accept := simulation.can_accept_order(villager_id)
	var note := "" if can_accept else tr("Tu as déjà %d commandes en cours.") % FarmSimulation.ORDER_MAX_ACTIVE
	_offering = villager_id
	var bonus := roundi(FarmSimulation.ORDER_BONUS_PER_HEART * 100.0 * simulation.get_hearts(villager_id))
	_panel.open(villager.data.display_name, line, _item_icon(order["item"]), _item_name(order["item"]),
		order["quantity"], simulation.get_order_payment(villager_id), template.days if template else 5,
		can_accept, note, bonus)

func _on_accepted() -> void:
	if simulation.accept_order(_offering):
		_say_to_player(_offering, tr("Merci ! Je compte sur toi."))

func _on_declined() -> void:
	if simulation.decline_order(_offering):
		_say_to_player(_offering, tr("Tant pis, une autre fois."))

func _deliver(villager: Villager, villager_id: String) -> void:
	var template := simulation.get_order_template(villager_id)
	var reward := simulation.deliver_order(villager_id)
	if reward <= 0:
		return
	AudioManager.play_harvest_sfx()
	HarvestPopup.spawn(villager, villager.global_position + Vector2(0, -110), null,
		"+%s" % Currency.format(reward))
	villager.say(tr(template.thanks_line) if template != null and not template.thanks_line.is_empty() else tr("Merci beaucoup !"))

func _say_to_player(villager_id: String, text: String) -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == villager_id and not villager.is_inside():
			villager.say(text)

# --- marks, prompts, tracker ------------------------------------------------------------

func _refresh() -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		var villager_id := villager.get_villager_id()
		var name: String = villager.data.display_name if villager.data else villager_id
		if simulation.is_order_offered(villager_id):
			villager.set_order_mark("!")
			villager.set_prompt(tr("Voir la commande de %s") % name)
		elif simulation.can_deliver_order(villager_id):
			villager.set_order_mark("?")
			var order := simulation.get_order(villager_id)
			villager.set_prompt(tr("Livrer %d %s") % [order["quantity"], _item_name(order["item"]).to_lower()])
		else:
			villager.set_order_mark("")
			villager.set_prompt(villager.talk_prompt if not villager.talk_prompt.is_empty() else tr("Parler à %s") % name)
	var rows := []
	for villager_id in simulation.get_active_orders():
		var order := simulation.get_order(villager_id)
		rows.append({
			"villager": _names.get(villager_id, villager_id),
			"icon": _item_icon(order["item"]),
			"item": _item_name(order["item"]).to_lower(),
			"have": simulation.state.get_inventory_count(order["item"]),
			"need": order["quantity"],
			"days_left": simulation.get_order_days_left(villager_id),
		})
	_tracker.show_orders(rows)

func _item_name(item_id: String) -> String:
	return item_db.get_display_name(item_id)

func _item_icon(item_id: String) -> Texture2D:
	return item_db.get_icon(item_id)
