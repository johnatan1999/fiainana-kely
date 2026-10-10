class_name ZebuManager
extends Node

## Bridges FarmSimulation's zebus (the player's herd) to the world, like
## AnimalManager for the hens - never decides anything itself:
## - in a zone with a "ZebuPasture" marker (the farm), one GrazingZebu per
##   zebu the player owns, grazing around it and penned at night in the
##   zone's ZebuPen (GrazingZebu's own behaviour), under a "PlayerZebus" node;
## - the zone's "ZebuTrough": shows it full or empty, and fills it when the
##   player asks;
## - the zone's "ManureHeap": shows the manure waiting by the pen, and picks
##   it up when the player asks;
## - the zone's ZebuMarket stands (the market town): open the ZebuMarketPanel, and
##   buy or sell through it.

const ZEBU_SCENE := preload("res://entities/zebu/grazing_zebu.tscn")
## How far around the pasture marker the zebus stand, and graze.
const SPREAD := 70.0
const WANDER_RADIUS := 90.0

var simulation: FarmSimulation
var panel: ZebuMarketPanel

var _zone: ZoneRoot
var _herd: Node2D
var _pasture := Vector2.ZERO
var _trough: ZebuTrough
var _heap: ManureHeap
var _market_title := "Tsena omby"
var _nodes: Dictionary = {} # zebu_id -> GrazingZebu

func setup(p_simulation: FarmSimulation, world_manager: WorldManager, p_panel: ZebuMarketPanel) -> void:
	simulation = p_simulation
	panel = p_panel
	simulation.zebus_changed.connect(_on_zebus_changed)
	simulation.weather_changed.connect(func(_weather): _refresh_trough())
	simulation.day_changed.connect(func(_day: int): _refresh_trough())
	world_manager.zone_loaded.connect(_on_zone_loaded)
	world_manager.zone_unloading.connect(_on_zone_unloading)
	panel.buy_requested.connect(_on_buy_requested)
	panel.sell_requested.connect(_on_sell_requested)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_zone = zone
	_nodes.clear()
	_herd = null
	var pasture := zone.get_node_or_null("ZebuPasture") as Marker2D
	if pasture != null:
		_pasture = pasture.global_position
		_herd = zone.get_node_or_null("PlayerZebus") as Node2D
		if _herd == null:
			_herd = Node2D.new()
			_herd.name = "PlayerZebus"
			_herd.y_sort_enabled = true
			zone.add_child(_herd)
	_trough = zone.get_node_or_null("ZebuTrough") as ZebuTrough
	if _trough != null:
		_trough.interacted.connect(_on_trough_interacted)
	_heap = zone.get_node_or_null("ManureHeap") as ManureHeap
	if _heap != null:
		_heap.interacted.connect(_on_heap_interacted)
	for node in zone.find_children("*", "Node2D", true, false):
		if node is ZebuMarket:
			(node as ZebuMarket).requested.connect(_open_market.bind(node))
	_sync_herd()
	_refresh_trough()

func _on_zone_unloading(_old_zone: ZoneRoot) -> void:
	_zone = null
	_herd = null
	_trough = null
	_heap = null
	_nodes.clear()

func _on_zebus_changed() -> void:
	_sync_herd()
	_refresh_trough()

## One GrazingZebu per zebu owned - added for new ones, removed for sold ones.
func _sync_herd() -> void:
	if _herd == null:
		return
	var ids := simulation.get_zebu_ids()
	for zebu_id: String in _nodes.keys():
		if not zebu_id in ids:
			(_nodes[zebu_id] as Node).queue_free()
			_nodes.erase(zebu_id)
	for i in ids.size():
		var zebu_id: String = ids[i]
		if _nodes.has(zebu_id):
			continue
		var zebu: GrazingZebu = ZEBU_SCENE.instantiate()
		zebu.name = "Zebu_" + zebu_id
		zebu.coat = simulation.get_zebu(zebu_id)["coat"]
		zebu.wander_radius = WANDER_RADIUS
		# Each its own place around the pasture, the same every time.
		var angle := TAU * i / simulation.get_zebu_capacity() + 0.4
		zebu.position = _herd.to_local(_pasture + Vector2.from_angle(angle) * SPREAD)
		_herd.add_child(zebu)
		# ZebuPen.nearest() only pairs a zebu with a pen of its own zone.
		zebu.owner = _zone
		_nodes[zebu_id] = zebu

func get_zebu_node(zebu_id: String) -> GrazingZebu:
	return _nodes.get(zebu_id)

func _refresh_trough() -> void:
	if _heap != null:
		_heap.show_amount(simulation.get_manure_pile())
	if _trough == null:
		return
	var full := simulation.is_zebu_trough_full()
	_trough.show_state(full, not full and not simulation.get_zebu_ids().is_empty())

func _on_trough_interacted() -> void:
	if simulation.fill_zebu_trough():
		UIEvents.notify(tr("Abreuvoir rempli : les zébus grandiront aujourd'hui."))

func _on_heap_interacted() -> void:
	var amount := simulation.collect_manure()
	if amount > 0:
		UIEvents.notify(tr("+%d Fumier de zébu : épands-le sur tes parcelles pour une plus grosse récolte.") % amount)

func _open_market(market: ZebuMarket) -> void:
	_market_title = market.profile.title if market.profile != null else "Tsena omby"
	_show_market()

func _show_market() -> void:
	var zebus := []
	for zebu_id: String in simulation.get_zebu_ids():
		var zebu := simulation.get_zebu(zebu_id)
		zebus.append({
			"id": zebu_id,
			"name": zebu["name"],
			"coat": zebu["coat"],
			"growth": tr("adulte") if simulation.is_zebu_grown(zebu_id)
				else tr("%d/%d jours") % [zebu["grown_days"], FarmSimulation.ZEBU_GROW_DAYS],
			"value": simulation.get_zebu_value(zebu_id),
		})
	var note := ""
	if zebus.size() >= simulation.get_zebu_capacity():
		note = tr("Ton parc est plein.")
	elif simulation.state.money < FarmSimulation.ZEBU_PRICE:
		note = tr("Pas assez d'argent.")
	panel.show_market(_market_title, FarmSimulation.ZEBU_PRICE, simulation.can_buy_zebu(), note, zebus,
		simulation.get_zebu_capacity())

func _on_buy_requested() -> void:
	var zebu_id := simulation.buy_zebu()
	if zebu_id.is_empty():
		return
	UIEvents.notify(tr("%s t'attend au parc de la ferme. Remplis son abreuvoir chaque jour !")
		% simulation.get_zebu(zebu_id)["name"])
	_show_market()

func _on_sell_requested(zebu_id: String) -> void:
	var zebu_name: String = simulation.get_zebu(zebu_id).get("name", "")
	var paid := simulation.sell_zebu(zebu_id)
	if paid > 0:
		UIEvents.notify(tr("%s vendu %s.") % [zebu_name, Currency.format(paid)])
	_show_market()
