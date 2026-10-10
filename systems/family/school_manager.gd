class_name SchoolManager
extends Node

## Fara's school fees, between FarmSimulation (the bill, the debt, saved)
## and the world - never decides anything itself:
## - the head teacher (TEACHER_ID, at the village school) takes the fees:
##   talking to her while some are owed opens the SchoolPanel;
## - the morning news: a new bill, the last day to pay, Fara sent home;
## - the reminder in the OrdersTracker, and what the family says about it
##   (Villager.call_out);
## - the story conditions (FarmSimulation.get_conditions()) handed to every
##   villager: Fara skips school and helps at home while the fees are
##   overdue (VillagerStop.only_if / unless).
## See docs/school.md.

const TEACHER_ID := "hanta"
const SISTER_ID := "fara"
const MOTHER_ID := "mother"
const FATHER_ID := "father"

var simulation: FarmSimulation
var item_db: ItemDatabase

var _panel: SchoolPanel
var _tracker: OrdersTracker
var _teacher_name := "Ramatoa Hanta"
## The last bill already announced (FarmState.school_billed_season).
var _announced_season := 0

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager,
		panel: SchoolPanel, tracker: OrdersTracker) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_panel = panel
	_tracker = tracker
	var teacher: VillagerData = VillagerData.load_all().get(TEACHER_ID)
	if teacher != null:
		_teacher_name = teacher.display_name
	_announced_season = simulation.state.school_billed_season
	_panel.pay_money_requested.connect(_on_pay_money)
	_panel.pay_rice_requested.connect(_on_pay_rice)
	simulation.school_fees_changed.connect(_refresh)
	simulation.day_changed.connect(func(_day: int): _on_morning())
	simulation.state_loaded.connect(func(): _announced_season = simulation.state.school_billed_season)
	world_manager.zone_loaded.connect(_on_zone_loaded)
	_refresh()

func _on_zone_loaded(_zone: ZoneRoot) -> void:
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.get_villager_id() == TEACHER_ID and not villager.interacted.is_connected(_on_teacher_interacted):
			villager.interacted.connect(_on_teacher_interacted.bind(villager))
	_refresh()

## The day's news about the fees, once, in the morning.
func _on_morning() -> void:
	_refresh()
	var debt := simulation.school.get_school_debt()
	if simulation.state.school_billed_season > _announced_season:
		_announced_season = simulation.state.school_billed_season
		UIEvents.notify(tr("Écolage de Fara : %s à payer à %s, à l'école du village, d'ici %d jours.")
			% [Currency.format(debt), _teacher_name, simulation.school.get_school_days_left()])
	elif debt > 0 and simulation.school.get_school_days_left() == 1:
		UIEvents.notify(tr("Dernier jour pour payer l'écolage de Fara (%s).") % Currency.format(debt))
	elif debt > 0 and simulation.school.get_school_days_left() == 0:
		UIEvents.notify(tr("L'écolage n'est pas payé : Fara est renvoyée à la maison jusqu'au paiement."))

# --- paying, at the school -------------------------------------------------------------

func _on_teacher_interacted(_teacher: Villager) -> void:
	if simulation.school.is_school_fee_due():
		_show_panel(tr("Bonjour ! Tu viens pour l'écolage de Fara ?"))

func _show_panel(line: String, note := "") -> void:
	var debt := simulation.school.get_school_debt()
	var money_payment := mini(debt, simulation.state.money)
	var rice_count := mini(simulation.school.get_school_rice_needed(),
		simulation.state.get_inventory_count(SchoolRules.SCHOOL_RICE_ITEM))
	if note.is_empty() and debt > 0:
		if money_payment <= 0 and rice_count <= 0:
			note = tr("Tu n'as ni argent ni riz pour l'instant. Reviens vite !")
		elif money_payment < debt and rice_count * simulation.school.get_school_rice_price() < debt:
			note = tr("Tu peux payer une partie maintenant, et le reste plus tard.")
	_panel.show_fees(_teacher_name, line, debt, simulation.school.get_school_days_left(), money_payment,
		rice_count, simulation.school.get_school_rice_price(), note)

func _on_pay_money() -> void:
	var paid := simulation.school.pay_school_fees(simulation.school.get_school_debt())
	if paid > 0:
		_after_payment(Currency.format(paid))

func _on_pay_rice() -> void:
	var given := simulation.school.pay_school_fees_in_rice(simulation.school.get_school_rice_needed())
	if given > 0:
		_after_payment("%d %s" % [given, item_db.get_display_name(SchoolRules.SCHOOL_RICE_ITEM).to_lower()])

func _after_payment(what: String) -> void:
	AudioManager.play_harvest_sfx()
	if simulation.school.is_school_fee_due():
		_show_panel(tr("Merci pour ces %s. Il reste encore un peu à payer.") % what)
		return
	_show_panel(tr("Merci ! Fara sera toujours la bienvenue à l'école."))
	UIEvents.notify(tr("L'écolage de Fara est payé."))

# --- reminder, family talk, conditions ---------------------------------------------------

func _refresh() -> void:
	var debt := simulation.school.get_school_debt()
	var overdue := simulation.school.is_school_fees_overdue()
	var days_left := simulation.school.get_school_days_left()
	var reminders := []
	if debt > 0:
		var when := tr("en retard") if overdue else (tr("dernier jour") if days_left <= 1 else tr("%d j") % days_left)
		reminders.append({"text": tr("Écolage de Fara : %s — %s") % [Currency.format(debt), when],
			"urgent": days_left <= 1})
	_tracker.show_reminders(reminders)

	var lines := {}
	if overdue:
		lines[MOTHER_ID] = tr("Fara n'a pas pu aller à l'école... Il faut payer %s.") % _teacher_name
		lines[FATHER_ID] = tr("Une enfant doit être à l'école, pas au mortier.")
		lines[SISTER_ID] = tr("La maîtresse m'a renvoyée tant que l'écolage n'est pas payé...")
	elif debt > 0 and days_left <= SchoolRules.SCHOOL_GRACE_DAYS:
		lines[MOTHER_ID] = tr("N'oublie pas l'écolage de Fara : %s, à porter à %s.") % [Currency.format(debt), _teacher_name]
	if debt > 0:
		lines[TEACHER_ID] = tr("Tu viens pour l'écolage de Fara ?")
	var conditions := simulation.get_conditions()
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		var villager_id := villager.get_villager_id()
		villager.set_conditions(conditions)
		if villager_id in [MOTHER_ID, FATHER_ID, SISTER_ID, TEACHER_ID]:
			villager.call_out = lines.get(villager_id, "")
		if villager_id == TEACHER_ID:
			villager.talk_prompt = tr("Payer l'écolage de Fara") if debt > 0 else ""
			villager.set_prompt(villager.talk_prompt if debt > 0 else tr("Parler à %s") % _teacher_name)
