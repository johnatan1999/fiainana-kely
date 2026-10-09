class_name EveningManager
extends Node

## The evening meal (sakafo hariva): when the player lies down on the bed
## (WorldManager.bedtime_requested), the family has dinner together and
## talks about the day - from FarmSimulation.day_log - and about tomorrow:
## - Dada: the fields (what was harvested) and the money;
## - Neny: the village (orders delivered, who likes the player more) and
##   the plots left dry - there's still time to water them;
## - Fara: the hens, the rooster, the tournament, her school;
## - and what tomorrow brings (ripe crops, an order's last day, the zoma,
##   the tournament, a new season).
## The dish on the mat is the day's: the rice and what was harvested most
## ("vary sy tsaramaso"), chicken after a big day. "Pas encore" goes back to
## the evening; "Dormir" sleeps (WorldManager.sleep(): the night, the save).
## Decides nothing: it only reads the simulation. See docs/evening.md.

const MOTHER_ID := "mother"
const FATHER_ID := "father"
const SISTER_ID := "fara"
## At most this many lines at dinner: the day's best, not a report.
const MAX_LINES := 6
## What the family eats after a day harvesting it most: rice and [laoka],
## in Malagasy, and in plain words.
const DISHES := {
	"rice": ["vary vaovao", "le riz nouveau de la récolte"],
	"bean": ["vary sy tsaramaso", "riz et haricots"],
	"cassava": ["vary sy mangahazo", "riz et manioc"],
	"sweet_potato": ["vary sy vomanga", "riz et patates douces"],
	"corn": ["vary sy katsaka", "riz et maïs"],
	"groundnut": ["vary sy voanjo", "riz et arachides"],
	"tomato": ["vary sy lasary voatabia", "riz et rougail de tomates"],
	"potato": ["vary sy ovy", "riz et pommes de terre"],
	"mango": ["vary amin'anana sy manga", "riz aux brèdes, des mangues au dessert"],
	"egg": ["vary sy atody", "riz et œufs"],
}
const DEFAULT_DISH := ["vary amin'anana", "riz aux brèdes"]
## A day that brought in this much: Neny kills a chicken.
const FEAST_EARNINGS := 20000
const FEAST_DISH := ["vary sy akoho", "riz et poulet, pour fêter la journée"]
const SEASON_NAMES := {GameClock.Season.RAINY: "Asara", GameClock.Season.DRY: "Asotry"}

var simulation: FarmSimulation
var item_db: ItemDatabase

var _world_manager: WorldManager
var _panel: EveningPanel
var _family: Dictionary = {} # villager_id -> VillagerData
var _names: Dictionary = {} # villager_id -> display name

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager,
		panel: EveningPanel) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_world_manager = world_manager
	_panel = panel
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		_names[villager_id] = villagers[villager_id].display_name
		if villagers[villager_id].family:
			_family[villager_id] = villagers[villager_id]
	world_manager.bedtime_requested.connect(_on_bedtime)
	_panel.sleep_confirmed.connect(_world_manager.sleep)

func _on_bedtime() -> void:
	var clock := simulation.state.clock
	var date := tr("%s · %s, jour %d") % [GameClock.get_weekday_name(clock.get_weekday()),
		SEASON_NAMES[clock.get_season()], clock.get_day_of_season()]
	var dish := get_dish()
	_panel.open(date, tr("Ce soir : %s (%s)") % [dish[0], tr(dish[1])], get_lines(),
		simulation.day_log.earned, simulation.day_log.spent)

## [malagasy, plain words] - the day's dish.
func get_dish() -> Array:
	var log := simulation.day_log
	if log.earned >= FEAST_EARNINGS:
		return FEAST_DISH
	var main := log.get_main_harvest()
	if DISHES.has(main):
		return DISHES[main]
	if log.products.has("egg"):
		return DISHES["egg"]
	return DEFAULT_DISH

## What's said at dinner, in order: [{"speaker": villager_id, "name",
## "portrait", "text"}], at most MAX_LINES - the plots left dry first (there's
## still time), then the day, then two words about tomorrow at most. A
## speaker's lines one after the other make a single turn.
func get_lines() -> Array:
	var tomorrow := _tomorrow_lines().slice(0, 2)
	var day := _dry_lines() + _field_lines() + _village_lines() + _sister_lines()
	var lines := day.slice(0, MAX_LINES - tomorrow.size()) + tomorrow
	# Someone who goes on talking: one turn, not their name twice.
	var turns := []
	for line: Array in lines:
		if not turns.is_empty() and turns[-1][0] == line[0]:
			turns[-1][1] += " " + line[1]
		else:
			turns.append(line.duplicate())
	return turns.map(func(line: Array) -> Dictionary: return _line(line[0], line[1]))

func _line(speaker: String, text: String) -> Dictionary:
	var data: VillagerData = _family.get(speaker)
	return {"speaker": speaker, "name": _names.get(speaker, speaker),
		"portrait": VillagerPortrait.make(data.look) if data != null else null, "text": text}

# --- Dada: the fields and the money ---------------------------------------------------------

func _field_lines() -> Array:
	var log := simulation.day_log
	var lines := []
	if not log.harvested.is_empty():
		lines.append([FATHER_ID, tr("Tu as récolté %s aujourd'hui. Bon travail.") % _list(log.harvested)])
	elif log.neighbour_tufts > 0:
		lines.append([FATHER_ID, tr("Rakoto m'a dit que tu les as aidés à moissonner. C'est bien, ils s'en souviendront.")])
	if log.earned > 0 and log.spent > 0:
		var text := tr("La journée a rapporté %s, et on a dépensé %s.") % [Currency.format(log.earned), Currency.format(log.spent)]
		if log.spent > log.earned:
			text += " " + tr("Ce qu'on sème aujourd'hui, on le récolte demain.")
		lines.append([FATHER_ID, text])
	elif log.earned > 0:
		lines.append([FATHER_ID, tr("%s de gagnés aujourd'hui !") % Currency.format(log.earned)])
	elif log.spent > 0:
		lines.append([FATHER_ID, tr("On a dépensé %s aujourd'hui. Ça finira par rapporter.") % Currency.format(log.spent)])
	if log.is_quiet():
		lines.append([FATHER_ID, tr("Une journée calme. La terre aussi a besoin de repos.")])
	return lines

# --- Neny: the village, and the plots left dry ------------------------------------------------

func _dry_lines() -> Array:
	var dry := simulation.get_unwatered_plots()
	if dry <= 0 or simulation.is_raining():
		return []
	return [[MOTHER_ID, tr("Tu as oublié d'arroser %d case(s)... Il est encore temps, avant de dormir.") % dry]]

func _village_lines() -> Array:
	var log := simulation.day_log
	var lines := []
	if not log.orders_delivered.is_empty():
		var who := log.orders_delivered.map(func(id: String) -> String: return _names.get(id, id))
		if who.size() == 1:
			lines.append([MOTHER_ID, tr("%s te remercie pour sa commande.") % who[0]])
		else:
			lines.append([MOTHER_ID, tr("%s te remercient pour leurs commandes.") % ", ".join(who)])
	if not log.new_hearts.is_empty():
		var who: String = log.new_hearts.keys()[0]
		lines.append([MOTHER_ID, tr("%s t'apprécie de plus en plus, on me l'a dit au point d'eau.") % _names.get(who, who)])
	elif log.orders_delivered.is_empty() and not log.friendship.is_empty():
		lines.append([MOTHER_ID, tr("Tu as pris le temps de parler aux voisins. C'est comme ça qu'on se fait des amis.")])
	if log.school_paid > 0:
		lines.append([MOTHER_ID, tr("Merci pour l'écolage de Fara. Dada et moi, on est fiers de toi.")])
	return lines

# --- Fara: the hens, the rooster, school --------------------------------------------------------

func _sister_lines() -> Array:
	var log := simulation.day_log
	var lines := []
	if simulation.is_school_fees_overdue():
		lines.append([SISTER_ID, tr("J'aimerais tellement retourner à l'école...")])
	elif simulation.is_school_fee_due() and simulation.get_school_days_left() <= 3:
		lines.append([SISTER_ID, tr("La maîtresse a rappelé l'écolage : encore %d jour(s).") % simulation.get_school_days_left()])
	if not simulation.has_rooster():
		pass
	elif not log.cockfight.is_empty():
		var rooster_name: String = simulation.get_rooster()["name"]
		lines.append([SISTER_ID, tr("%s a gagné %d combat(s) ! Tout le bourg l'a vu !") % [rooster_name, log.cockfight["wins"]]
			if log.cockfight["wins"] > 0 else tr("%s n'a rien gagné, mais il s'est bien battu.") % rooster_name])
	else:
		var rooster_name: String = simulation.get_rooster()["name"]
		lines.append([SISTER_ID, tr("J'ai vu %s picorer son grain !") % rooster_name if simulation.is_rooster_fed_today()
			else tr("%s n'a rien mangé aujourd'hui... Il a l'air triste.") % rooster_name])
	if log.products.has("egg"):
		lines.append([SISTER_ID, tr("J'ai compté %d œuf(s) dans le panier !") % log.products["egg"]])
	return lines.slice(0, 2)

# --- tomorrow --------------------------------------------------------------------------------------

func _tomorrow_lines() -> Array:
	var clock := simulation.state.clock
	var lines := []
	var tomorrow := GameClock.get_weekday_on(clock.current_day + 1)
	if clock.get_days_left_in_season() == 0:
		var next: String = SEASON_NAMES[clock.get_season_on(clock.current_day + 1)]
		lines.append([FATHER_ID, tr("Demain commence %s. Pense à ce que tu vas planter.") % next])
	for villager_id in simulation.get_orders_due_tomorrow():
		lines.append([MOTHER_ID, tr("Demain, c'est le dernier jour pour la commande de %s.") % _names.get(villager_id, villager_id)])
	var ripening := simulation.get_ripening_tomorrow()
	if not ripening.is_empty():
		lines.append([FATHER_ID, tr("Demain matin, %s seront mûrs.") % _list(ripening, true)])
	if tomorrow == FarmSimulation.COCKFIGHT_DAY and simulation.has_rooster():
		lines.append([SISTER_ID, tr("Demain c'est l'Alahady ! %s va combattre au bourg !") % simulation.get_rooster()["name"]])
	elif tomorrow == GameClock.MARKET_DAY:
		lines.append([MOTHER_ID, tr("Demain c'est le zoma : au tsena du bourg, tout se vend mieux.")])
	return lines

## A French item name for `count` of it: "haricot" -> "haricots", "patate
## douce" -> "patates douces", "pomme de terre" -> "pommes de terre", "maïs"
## and "riz" unchanged.
static func plural(item_name: String, count: int) -> String:
	if count <= 1 or TranslationServer.get_locale().begins_with("en"):
		return item_name
	var words := item_name.split(" ")
	var last := words.size() if words.size() < 2 or not words[1] in ["de", "d'", "à"] else 1
	for i in last:
		var word := words[i]
		if word.ends_with("eau"):
			words[i] = word + "x"
		elif not (word.ends_with("s") or word.ends_with("x") or word.ends_with("z")):
			words[i] = word + "s"
	return " ".join(words)

## "9 maïs, 5 riz et 2 mangues" - the biggest first, at most three.
## `plots`: counts are plots ("4 cases de tomates").
func _list(counts: Dictionary, plots := false) -> String:
	var ids := counts.keys()
	ids.sort_custom(func(a, b): return counts[a] > counts[b])
	var parts := []
	for item_id: String in ids.slice(0, 3):
		var item_name := item_db.get_display_name(item_id).to_lower()
		parts.append(tr("%d case(s) de %s") % [counts[item_id], plural(item_name, 2)] if plots
			else "%d %s" % [counts[item_id], plural(item_name, counts[item_id])])
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, -1)) + " " + tr("et") + " " + parts[-1]
