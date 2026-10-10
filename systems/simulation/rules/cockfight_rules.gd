class_name CockfightRules
extends SimRules

## The player's fighting rooster and the Sunday tournament (ady akoho).
## A part of FarmSimulation (SimRules): simulation.cockfight.

## The player's fighting rooster (akoho gasy), given by Rakoto: one at a
## time, tethered at the farm. Fed a grain a day (ROOSTER_FEED_ITEMS) it
## gains endurance; fed and trained, force too - by the day's end, up to
## ROOSTER_MAX_STAT each. Never loses anything: neglect only stalls it.
## Its power is force + endurance.
const ROOSTER_NAME := "Kotroka"
const ROOSTER_START_STAT := 20
const ROOSTER_MAX_STAT := 100
const ROOSTER_FEED_ITEMS := ["corn", "rice"]
const ROOSTER_FED_ENDURANCE := 1
const ROOSTER_TRAINED_FORCE := 2
const ROOSTER_TRAINED_ENDURANCE := 1
## The Sunday tournament (ady akoho), at the market town's ring: once a
## week, COCKFIGHT_HOURS. The player's rooster fights COCKFIGHT_BOUTS
## villagers' roosters (FightingRoosterData); each bout's winner is drawn
## from the powers (COCKFIGHT_POWER_SCALE: a gap that much wins ~73 %).
## No betting: entering pays a small prize, every bout brings the rooster's
## owner closer, and points (a win COCKFIGHT_WIN_POINTS, a loss
## COCKFIGHT_LOSS_POINTS) rank the roosters over the season. The villagers'
## roosters fight their bouts among themselves too. At the season's end, the
## top rooster is the village's best until the next one.
const PLAYER_ROOSTER_ID := "player"
const COCKFIGHT_DAY := GameClock.Weekday.SUNDAY
const COCKFIGHT_HOURS := Vector2i(14 * 60, 17 * 60)
const COCKFIGHT_BOUTS := 3
const COCKFIGHT_WIN_POINTS := 3
const COCKFIGHT_LOSS_POINTS := 1
const COCKFIGHT_ENTRY_PRIZE := 2000
const COCKFIGHT_POWER_SCALE := 20.0
const COCKFIGHT_NPC_MAX_POWER := 190
## A bout, as shown: the winner lands this many blows, the loser fewer.
const COCKFIGHT_HITS_TO_WIN := 3
enum CockfightCheck { OK, NO_ROOSTER, CLOSED, ALREADY_ENTERED }

var _fighting_roosters: Dictionary = {} # rooster_id: String -> FightingRoosterData

func has_rooster() -> bool:
	return not state.rooster.is_empty()

## {"name", "force", "endurance", "fed_day", "trained_day"} - {} without one.
func get_rooster() -> Dictionary:
	return state.rooster

## Rakoto's gift. False if the player already has one.
func adopt_rooster(rooster_name := ROOSTER_NAME) -> bool:
	if has_rooster():
		return false
	state.rooster = {"name": rooster_name, "force": ROOSTER_START_STAT, "endurance": ROOSTER_START_STAT,
		"fed_day": 0, "trained_day": 0}
	sim.rooster_changed.emit()
	sim.cockfight_changed.emit()
	return true

func get_rooster_power() -> int:
	return int(state.rooster.get("force", 0)) + int(state.rooster.get("endurance", 0))

func is_rooster_fed_today() -> bool:
	return has_rooster() and int(state.rooster["fed_day"]) == state.day

func is_rooster_trained_today() -> bool:
	return has_rooster() and int(state.rooster["trained_day"]) == state.day

func can_feed_rooster(item_id: String) -> bool:
	return has_rooster() and not is_rooster_fed_today() and item_id in ROOSTER_FEED_ITEMS \
		and state.get_inventory_count(item_id) > 0

## A grain of `item_id` for today.
func feed_rooster(item_id: String) -> bool:
	if not can_feed_rooster(item_id):
		return false
	sim.add_item(item_id, -1)
	state.rooster["fed_day"] = state.day
	sim.rooster_changed.emit()
	return true

func can_train_rooster() -> bool:
	return has_rooster() and not is_rooster_trained_today()

func train_rooster() -> bool:
	if not can_train_rooster():
		return false
	state.rooster["trained_day"] = state.day
	sim.rooster_changed.emit()
	return true

## The day that ends: what the day's care is worth.
func advance_rooster() -> void:
	if not is_rooster_fed_today():
		return
	var endurance := ROOSTER_FED_ENDURANCE
	if is_rooster_trained_today():
		endurance += ROOSTER_TRAINED_ENDURANCE
		state.rooster["force"] = mini(int(state.rooster["force"]) + ROOSTER_TRAINED_FORCE, ROOSTER_MAX_STAT)
	state.rooster["endurance"] = mini(int(state.rooster["endurance"]) + endurance, ROOSTER_MAX_STAT)
	sim.rooster_changed.emit()

## Registered by CockfightManager: the villagers' roosters (data/roosters/).
func register_fighting_rooster(rooster_id: String, data: FightingRoosterData) -> void:
	_fighting_roosters[rooster_id] = data

func get_fighting_rooster(rooster_id: String) -> FightingRoosterData:
	return _fighting_roosters.get(rooster_id)

## A rooster's power today: the player's, or a villager's (it grows weekly).
func get_cockfight_power(rooster_id: String) -> int:
	if rooster_id == PLAYER_ROOSTER_ID:
		return get_rooster_power()
	var data := get_fighting_rooster(rooster_id)
	if data == null:
		return 0
	var weeks := (state.day - 1) / GameClock.WEEKDAY_NAMES.size()
	return mini(data.base_power + data.power_per_week * weeks, COCKFIGHT_NPC_MAX_POWER)

func is_cockfight_on() -> bool:
	var minute := state.clock.minute_of_day
	return state.clock.get_weekday() == COCKFIGHT_DAY and minute >= COCKFIGHT_HOURS.x and minute < COCKFIGHT_HOURS.y

func check_cockfight() -> CockfightCheck:
	if not has_rooster():
		return CockfightCheck.NO_ROOSTER
	if not is_cockfight_on():
		return CockfightCheck.CLOSED
	if state.cockfight_entered_day == state.day:
		return CockfightCheck.ALREADY_ENTERED
	return CockfightCheck.OK

## The player's rooster fights today's tournament: COCKFIGHT_BOUTS of the
## villagers' roosters, weakest first. Returns the bouts, in order -
## {"opponent": id, "won": bool, "hits": [bool...] (true = the player's
## rooster lands the blow)} - or [] if it can't (check_cockfight()).
func enter_cockfight() -> Array:
	if check_cockfight() != CockfightCheck.OK or _fighting_roosters.is_empty():
		return []
	state.cockfight_entered_day = state.day
	var opponents := _fighting_roosters.keys()
	opponents.shuffle()
	opponents = opponents.slice(0, COCKFIGHT_BOUTS)
	opponents.sort_custom(func(a, b): return get_cockfight_power(a) < get_cockfight_power(b))
	var bouts := []
	for opponent: String in opponents:
		var bout := _bout(PLAYER_ROOSTER_ID, opponent)
		_score(opponent, not bout["won"])
		bout["opponent"] = opponent
		bouts.append(bout)
		state.cockfight_week_bouts[opponent] = int(state.cockfight_week_bouts.get(opponent, 0)) + 1
		var owner := get_fighting_rooster(opponent).owner_id
		if not owner.is_empty():
			sim.friendship.add_friendship(owner, FriendshipRules.FRIENDSHIP_COCKFIGHT)
	sim.add_money(COCKFIGHT_ENTRY_PRIZE)
	day_log.cockfight = {"bouts": bouts.size(), "wins": bouts.filter(func(bout): return bout["won"]).size()}
	sim.cockfight_changed.emit()
	return bouts

## Season points, by rooster id ("player" included once they have one).
func get_cockfight_points(rooster_id: String) -> int:
	return int(state.cockfight_points.get(rooster_id, 0))

## Every rooster, best first: points, then power. [{"id", "points", "power"}]
func get_cockfight_ranking() -> Array:
	var ids := _fighting_roosters.keys()
	if has_rooster():
		ids.append(PLAYER_ROOSTER_ID)
	var ranking := ids.map(func(id: String) -> Dictionary:
		return {"id": id, "points": get_cockfight_points(id), "power": get_cockfight_power(id)})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["points"] > b["points"] if a["points"] != b["points"] else a["power"] > b["power"])
	return ranking

## 1-based place of a rooster in the ranking (0 if it isn't in it).
func get_cockfight_rank(rooster_id: String) -> int:
	var ranking := get_cockfight_ranking()
	for i in ranking.size():
		if ranking[i]["id"] == rooster_id:
			return i + 1
	return 0

## The village's best rooster (last season's top), "" before the first.
func get_cockfight_champion() -> String:
	return state.cockfight_champion

## One bout between rooster `a` and rooster `b`: the winner drawn from
## their powers, `a`'s points counted (not `b`'s: the caller decides), and
## the blows as they'll be shown - the winner's last.
func _bout(a: String, b: String) -> Dictionary:
	var gap := get_cockfight_power(a) - get_cockfight_power(b)
	var won := randf() < 1.0 / (1.0 + exp(-gap / COCKFIGHT_POWER_SCALE))
	var hits := []
	for i in randi_range(0, COCKFIGHT_HITS_TO_WIN - 1):
		hits.append(not won)
	for i in COCKFIGHT_HITS_TO_WIN - 1:
		hits.append(won)
	hits.shuffle()
	hits.append(won)
	_score(a, won)
	return {"won": won, "hits": hits}

func _score(rooster_id: String, won: bool) -> void:
	state.cockfight_points[rooster_id] = get_cockfight_points(rooster_id) \
		+ (COCKFIGHT_WIN_POINTS if won else COCKFIGHT_LOSS_POINTS)

## The Sunday that ends: each villager's rooster fights the rest of its
## COCKFIGHT_BOUTS against the others (those against the player's count).
## Only its own result counts - its opponent has bouts of its own.
func play_villagers_bouts() -> void:
	var ids := _fighting_roosters.keys()
	if ids.size() < 2:
		return
	for rooster_id: String in ids:
		var others := ids.filter(func(id): return id != rooster_id)
		for i in COCKFIGHT_BOUTS - int(state.cockfight_week_bouts.get(rooster_id, 0)):
			_bout(rooster_id, others.pick_random())
	state.cockfight_week_bouts.clear()
	sim.cockfight_changed.emit()

## The new season's first morning: the top rooster of the one that ended is
## the village's best; points start again.
func end_cockfight_season() -> void:
	var ranking := get_cockfight_ranking()
	if ranking.is_empty() or ranking[0]["points"] <= 0:
		return
	state.cockfight_champion = ranking[0]["id"]
	if state.cockfight_champion == PLAYER_ROOSTER_ID:
		for data: FightingRoosterData in _fighting_roosters.values():
			if not data.owner_id.is_empty():
				sim.friendship.add_friendship(data.owner_id, FriendshipRules.FRIENDSHIP_CHAMPION)
	state.cockfight_points.clear()
	sim.cockfight_changed.emit()
	sim.cockfight_season_ended.emit(state.cockfight_champion)
