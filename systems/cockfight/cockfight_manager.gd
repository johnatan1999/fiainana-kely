class_name CockfightManager
extends Node

## The fighting rooster and the Sunday tournament, between FarmSimulation
## (the rooster, the ranking, saved) and the world - never decides anything
## itself:
## - Rakoto, the village's great amateur, offers the player a young rooster
##   (from GIFT_FROM_DAY): he calls out, and talking to him hands it over;
## - in a zone with a "RoosterStake" marker (the farm), the player's
##   rooster tied there (TetheredRooster): caring for it opens RoosterPanel;
## - the market town's CockfightRing: the tournament on Sunday afternoons
##   (CockfightPanel plays the bouts), the ranking the rest of the week;
## - the news: the tournament on Sunday morning, the season's best rooster.
## Registers the villagers' roosters (data/roosters/). See docs/cockfight.md.

const GIFTER_ID := "rakoto"
## Rakoto waits a day or two: the first days are for the fields.
const GIFT_FROM_DAY := 3
const GIFT_CALL := "Hé ! Tu t'intéresses aux coqs de combat ?"
## After a season won, the amateurs congratulate the player this many days.
const CHAMPION_PRAISE_DAYS := 3

var simulation: FarmSimulation
var item_db: ItemDatabase

var _rooster_panel: RoosterPanel
var _fight_panel: CockfightPanel
var _names: Dictionary = {} # villager_id -> display name
var _amateurs: Dictionary = {} # villager_id -> true: they own a fighting rooster
var _stake: Marker2D
var _rooster: TetheredRooster
## The day the player's rooster became the village's best (praise for a
## few days), 0 = not lately.
var _champion_day := 0

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager,
		rooster_panel: RoosterPanel, fight_panel: CockfightPanel) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_rooster_panel = rooster_panel
	_fight_panel = fight_panel
	var roosters := FightingRoosterData.load_all()
	for rooster_id: String in roosters:
		simulation.register_fighting_rooster(rooster_id, roosters[rooster_id])
		_amateurs[roosters[rooster_id].owner_id] = true
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		_names[villager_id] = villagers[villager_id].display_name
	_rooster_panel.feed_requested.connect(_on_feed)
	_rooster_panel.train_requested.connect(_on_train)
	simulation.rooster_changed.connect(_refresh)
	simulation.cockfight_changed.connect(_refresh)
	simulation.inventory_changed.connect(func(item_id: String, _count: int):
		if item_id in FarmSimulation.ROOSTER_FEED_ITEMS and _rooster_panel.is_open():
			_show_rooster_panel())
	simulation.day_changed.connect(func(_day: int): _on_morning())
	simulation.cockfight_season_ended.connect(_on_season_ended)
	world_manager.zone_loaded.connect(_on_zone_loaded)
	world_manager.zone_unloading.connect(func(_zone: ZoneRoot):
		_stake = null
		_rooster = null)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_stake = zone.get_node_or_null("RoosterStake") as Marker2D
	_rooster = null
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == GIFTER_ID and not villager.interacted.is_connected(_on_gifter_interacted):
			villager.interacted.connect(_on_gifter_interacted.bind(villager))
	for ring: CockfightRing in get_tree().get_nodes_in_group(CockfightRing.GROUP):
		if not ring.interacted.is_connected(_on_ring_interacted):
			ring.interacted.connect(_on_ring_interacted)
	_refresh()

## The rooster at its stake, the prompts, who says what.
func _refresh() -> void:
	if _stake != null and simulation.has_rooster() and _rooster == null:
		_rooster = TetheredRooster.new()
		_rooster.name = "PlayerRooster"
		_rooster.position = _stake.position
		_stake.get_parent().add_child(_rooster)
		_rooster.interacted.connect(_show_rooster_panel)
	if _rooster != null:
		_rooster.show_state(tr("S'occuper de %s") % simulation.get_rooster()["name"],
			not simulation.is_rooster_fed_today())
	var entering := simulation.has_rooster() and simulation.check_cockfight() != FarmSimulation.CockfightCheck.ALREADY_ENTERED
	for ring: CockfightRing in get_tree().get_nodes_in_group(CockfightRing.GROUP):
		ring.set_prompts(tr("Inscrire ton coq au tournoi") if entering else tr("Voir le classement des coqs"),
			tr("Voir le classement des coqs"))
	var gift_offered := _gift_offered()
	var praising := _champion_day > 0 and simulation.state.day - _champion_day < CHAMPION_PRAISE_DAYS
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		var villager_id := villager.get_villager_id()
		if villager_id == GIFTER_ID:
			villager.talk_prompt = tr("Écouter Rakoto") if gift_offered else ""
			if not simulation.is_order_offered(GIFTER_ID) and not simulation.can_deliver_order(GIFTER_ID):
				villager.set_prompt(villager.talk_prompt if gift_offered else tr("Parler à %s") % villager.data.display_name)
			if gift_offered:
				villager.call_out = tr(GIFT_CALL)
			elif villager.call_out == tr(GIFT_CALL):
				villager.call_out = ""
		if _amateurs.has(villager_id):
			var praise := tr("Voilà le maître du meilleur coq du village !")
			if praising:
				villager.call_out = praise
			elif villager.call_out == praise:
				villager.call_out = ""

func _gift_offered() -> bool:
	return not simulation.has_rooster() and simulation.state.day >= GIFT_FROM_DAY

func _on_morning() -> void:
	_refresh()
	if simulation.has_rooster() and simulation.state.clock.get_weekday() == FarmSimulation.COCKFIGHT_DAY:
		UIEvents.notify(tr("Alahady : tournoi de coqs au bourg, de %d:00 à %d:00.")
			% [FarmSimulation.COCKFIGHT_HOURS.x / 60, FarmSimulation.COCKFIGHT_HOURS.y / 60])

# --- Rakoto's gift -----------------------------------------------------------------------

func _on_gifter_interacted(villager: Villager) -> void:
	# An order to offer or deliver comes first (OrderManager answers it).
	if not _gift_offered() or simulation.is_order_offered(GIFTER_ID) or simulation.can_deliver_order(GIFTER_ID):
		return
	simulation.adopt_rooster()
	var rooster_name: String = simulation.get_rooster()["name"]
	villager.say.call_deferred(tr("Prends ce jeune coq, je l'appelle %s. Nourris-le, entraîne-le, et viens au bourg l'Alahady !") % rooster_name)
	UIEvents.notify(tr("Rakoto t'a offert un jeune coq de combat, %s : il t'attend attaché devant la maison, à la ferme.") % rooster_name)
	_refresh()

# --- caring for the rooster ---------------------------------------------------------------

func _show_rooster_panel(note := "") -> void:
	if not simulation.has_rooster():
		return
	var rooster := simulation.get_rooster()
	var feeds := []
	for item_id: String in FarmSimulation.ROOSTER_FEED_ITEMS:
		feeds.append({"item_id": item_id, "name": item_db.get_display_name(item_id).to_lower(),
			"count": simulation.state.get_inventory_count(item_id), "enabled": simulation.can_feed_rooster(item_id)})
	if note.is_empty():
		note = _next_tournament_text()
		if not simulation.is_rooster_fed_today() and feeds.all(func(feed): return feed["count"] <= 0):
			note = tr("Il te faut du maïs ou du riz pour le nourrir.")
	_rooster_panel.show_rooster({
		"name": rooster["name"],
		"portrait": CockfightPanel.FRAMES.get_frame_texture("idle_down", 0),
		"force": rooster["force"], "endurance": rooster["endurance"], "max": FarmSimulation.ROOSTER_MAX_STAT,
		"power": simulation.get_rooster_power(),
		"fed": simulation.is_rooster_fed_today(), "trained": simulation.is_rooster_trained_today(),
		"feeds": feeds, "can_train": simulation.can_train_rooster(),
	}, _ranking_rows(), note)

func _on_feed(item_id: String) -> void:
	if simulation.feed_rooster(item_id):
		AudioManager.play_chicken_sfx()
		_show_rooster_panel(tr("%s picore son grain.") % simulation.get_rooster()["name"])

func _on_train() -> void:
	if simulation.train_rooster():
		AudioManager.play_chicken_sfx()
		var rooster_name: String = simulation.get_rooster()["name"]
		_show_rooster_panel(tr("%s court, saute et bat des ailes.") % rooster_name
			+ ("" if simulation.is_rooster_fed_today() else " " + tr("Nourris-le aussi pour qu'il progresse.")))

# --- the tournament ------------------------------------------------------------------------

func _on_ring_interacted() -> void:
	match simulation.check_cockfight():
		FarmSimulation.CockfightCheck.OK:
			_play_tournament()
		FarmSimulation.CockfightCheck.NO_ROOSTER:
			_fight_panel.show_ranking(tr("Il te faut un coq de combat pour participer. Rakoto, au village, est un grand amateur."), _ranking_rows())
		FarmSimulation.CockfightCheck.ALREADY_ENTERED:
			_fight_panel.show_ranking(tr("%s a déjà combattu aujourd'hui. Reviens l'Alahady prochain !") % simulation.get_rooster()["name"], _ranking_rows())
		_:
			_fight_panel.show_ranking(_next_tournament_text(), _ranking_rows())

func _play_tournament() -> void:
	var rank_before := simulation.get_cockfight_rank(FarmSimulation.PLAYER_ROOSTER_ID)
	var points_before := simulation.get_cockfight_points(FarmSimulation.PLAYER_ROOSTER_ID)
	var bouts := simulation.enter_cockfight()
	if bouts.is_empty():
		return
	var shown := []
	var wins := 0
	for bout: Dictionary in bouts:
		var data := simulation.get_fighting_rooster(bout["opponent"])
		shown.append({"opponent": data.display_name, "owner": _names.get(data.owner_id, data.owner_id),
			"color": data.color, "won": bout["won"], "hits": bout["hits"]})
		if bout["won"]:
			wins += 1
	var rank := simulation.get_cockfight_rank(FarmSimulation.PLAYER_ROOSTER_ID)
	var summary := tr("%d victoire(s), %d défaite(s) : +%d points, %de au classement.") % [wins, bouts.size() - wins,
		simulation.get_cockfight_points(FarmSimulation.PLAYER_ROOSTER_ID) - points_before, rank]
	if rank < rank_before and wins > 0:
		summary += " " + tr("Tu gagnes des places !")
	summary += "\n" + tr("Prime de participation : %s. Les amateurs ont apprécié le spectacle.") % Currency.format(FarmSimulation.COCKFIGHT_ENTRY_PRIZE)
	_fight_panel.play_tournament(simulation.get_rooster()["name"], shown, summary, _ranking_rows())

func _on_season_ended(champion_id: String) -> void:
	if champion_id == FarmSimulation.PLAYER_ROOSTER_ID:
		_champion_day = simulation.state.day
		UIEvents.notify(tr("%s est le meilleur coq du village ! Les amateurs te félicitent.") % simulation.get_rooster()["name"])
	else:
		var data := simulation.get_fighting_rooster(champion_id)
		if data != null and simulation.has_rooster():
			UIEvents.notify(tr("Fin de saison : %s, le coq de %s, est le meilleur coq du village.")
				% [data.display_name, _names.get(data.owner_id, data.owner_id)])
	_refresh()

## [{"rank", "name", "owner", "points", "is_player", "is_champion"}].
func _ranking_rows() -> Array:
	var rows := []
	var ranking := simulation.get_cockfight_ranking()
	for i in ranking.size():
		var rooster_id: String = ranking[i]["id"]
		var is_player := rooster_id == FarmSimulation.PLAYER_ROOSTER_ID
		var data := simulation.get_fighting_rooster(rooster_id)
		rows.append({
			"rank": i + 1,
			"name": simulation.get_rooster()["name"] if is_player else data.display_name,
			"owner": "" if is_player else _names.get(data.owner_id, data.owner_id),
			"points": ranking[i]["points"],
			"is_player": is_player,
			"is_champion": rooster_id == simulation.get_cockfight_champion(),
		})
	return rows

func _next_tournament_text() -> String:
	var days := posmod(FarmSimulation.COCKFIGHT_DAY - simulation.state.clock.get_weekday(), GameClock.WEEKDAY_NAMES.size())
	var hours := "%d:00–%d:00" % [FarmSimulation.COCKFIGHT_HOURS.x / 60, FarmSimulation.COCKFIGHT_HOURS.y / 60]
	if days == 0 and simulation.state.clock.minute_of_day < FarmSimulation.COCKFIGHT_HOURS.y:
		return tr("Tournoi aujourd'hui, au bourg, %s.") % hours
	if days == 0:
		days = GameClock.WEEKDAY_NAMES.size()
	return tr("Prochain tournoi : l'Alahady, au bourg, %s (dans %d jour(s)).") % [hours, days]
