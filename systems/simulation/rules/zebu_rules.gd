class_name ZebuRules
extends SimRules

## The player's zebus: bought and sold at the zebu market, the trough, growing,
## ploughing, manure.
## A part of FarmSimulation (SimRules): simulation.zebus.

## The player's zebus: bought young at the market-day zebu market (in the market town),
## they live in the farm's pen and graze on their own. Each day the pen's
## trough is filled (by the player, or by the rain), every zebu grows a day;
## grown, a zebu is worth far more than its price - the Malagasy savings
## bank on four legs. Sold back at the zebu market, at their worth.
## Places in the pen, by its level (FamilyProject "zebu_pen" - 1 at start).
const ZEBU_CAPACITY_BY_LEVEL := [0, 4, 6, 8]
const ZEBU_PRICE := 25000
## What a zebu is worth when bought (the dealer's margin) and full grown.
const ZEBU_CALF_VALUE := 18000
const ZEBU_ADULT_VALUE := 60000
const ZEBU_GROW_DAYS := 30
## Names by coat (GrazingZebu.COATS): brown, fawn, grey, near-black, white.
const ZEBU_NAMES := ["Mena", "Mavo", "Lavenona", "Mainty", "Fotsy"]
const ZEBU_COATS := 5
## Ploughing (the plough tool, FarmAction.PLOUGH): a team of ZEBU_TEAM_SIZE
## zebus, each with at least ZEBU_WORK_MIN_DAYS of growth, tills up to
## PLOUGH_REACH plots in a row in one go - PLOUGH_CELLS_PER_DAY a day, then
## the team is tired until tomorrow.
const ZEBU_TEAM_SIZE := 2
const ZEBU_WORK_MIN_DAYS := 15
const PLOUGH_REACH := 4
const PLOUGH_CELLS_PER_DAY := 24
enum PloughCheck { OK, NO_TEAM, TIRED }
## Manure (zezik'omby): each zebu leaves MANURE_PER_ZEBU a day on the heap by
## the pen - only on days it was cared for (trough full) - up to
## get_manure_max() (by the pen's level). Picked up as the "manure" item, spread on a plot
## (fertilize), it multiplies that plot's next harvest.
const MANURE_ITEM := "manure"
const MANURE_PER_ZEBU := 1
## What the heap by the pen holds, by the pen's level.
const MANURE_MAX_BY_LEVEL := [0, 12, 18, 24]
const MANURE_YIELD_MULTIPLIER := 1.5

func get_zebu_capacity() -> int:
	return ZEBU_CAPACITY_BY_LEVEL[clampi(sim.projects.get_building_level("zebu_pen"), 1, ZEBU_CAPACITY_BY_LEVEL.size() - 1)]

func get_manure_max() -> int:
	return MANURE_MAX_BY_LEVEL[clampi(sim.projects.get_building_level("zebu_pen"), 1, MANURE_MAX_BY_LEVEL.size() - 1)]

## Zebu ids, in the order they were bought.
func get_zebu_ids() -> Array:
	var ids := state.zebus.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(a.get_slice("_", 1)) < int(b.get_slice("_", 1)))
	return ids

func get_zebu(zebu_id: String) -> Dictionary:
	return state.zebus.get(zebu_id, {})

func can_buy_zebu() -> bool:
	return state.zebus.size() < get_zebu_capacity() and state.money >= ZEBU_PRICE

## A young zebu for ZEBU_PRICE, straight to the farm pen. `coat` -1 = at
## random. Returns its id, "" if the pen is full or money short.
func buy_zebu(coat: int = -1) -> String:
	if not can_buy_zebu():
		return ""
	sim.add_money(-ZEBU_PRICE)
	if coat < 0 or coat >= ZEBU_COATS:
		coat = randi() % ZEBU_COATS
	var zebu_id := "zebu_%d" % state.next_zebu_index
	state.next_zebu_index += 1
	state.zebus[zebu_id] = {"name": _zebu_name(coat), "coat": coat, "grown_days": 0}
	sim.zebus_changed.emit()
	return zebu_id

## The coat's name, numbered if the herd already has one.
func _zebu_name(coat: int) -> String:
	var base: String = ZEBU_NAMES[coat]
	var taken := state.zebus.values().map(func(zebu: Dictionary) -> String: return zebu["name"])
	if not base in taken:
		return base
	var number := 2
	while "%s %d" % [base, number] in taken:
		number += 1
	return "%s %d" % [base, number]

## What the zebu market pays for it today: from ZEBU_CALF_VALUE to
## ZEBU_ADULT_VALUE over ZEBU_GROW_DAYS days of care, by 500 Ar.
func get_zebu_value(zebu_id: String) -> int:
	var zebu := get_zebu(zebu_id)
	if zebu.is_empty():
		return 0
	var t := clampf(float(zebu["grown_days"]) / ZEBU_GROW_DAYS, 0.0, 1.0)
	return roundi(lerpf(ZEBU_CALF_VALUE, ZEBU_ADULT_VALUE, t) / 500.0) * 500

func is_zebu_grown(zebu_id: String) -> bool:
	return int(get_zebu(zebu_id).get("grown_days", 0)) >= ZEBU_GROW_DAYS

## Sells it at its worth. Returns what it paid, 0 for an unknown id.
func sell_zebu(zebu_id: String) -> int:
	var value := get_zebu_value(zebu_id)
	if value <= 0:
		return 0
	state.zebus.erase(zebu_id)
	sim.add_money(value)
	sim.zebus_changed.emit()
	return value

## Water and hay for today. False if there's no zebu or it's already full.
func fill_zebu_trough() -> bool:
	if state.zebus.is_empty() or is_zebu_trough_full():
		return false
	state.zebu_trough_full = true
	# The big pen's trough: tomorrow's water and hay too.
	state.zebu_trough_spare = sim.projects.get_building_level("zebu_pen") >= ProjectRules.ZEBU_TROUGH_TWO_DAYS_LEVEL
	sim.zebus_changed.emit()
	return true

## Full today - filled by the player, or by the rain.
func is_zebu_trough_full() -> bool:
	return state.zebu_trough_full or sim.is_raining()

## Zebus strong enough to pull the plough.
func get_work_zebu_count() -> int:
	return state.zebus.values().filter(func(zebu: Dictionary) -> bool:
		return int(zebu["grown_days"]) >= ZEBU_WORK_MIN_DAYS).size()

func check_plough() -> PloughCheck:
	if get_work_zebu_count() < ZEBU_TEAM_SIZE:
		return PloughCheck.NO_TEAM
	if state.plough_cells_today >= PLOUGH_CELLS_PER_DAY:
		return PloughCheck.TIRED
	return PloughCheck.OK

func get_plough_cells_left() -> int:
	return maxi(PLOUGH_CELLS_PER_DAY - state.plough_cells_today, 0)

## Fallow ground the plough can turn: no crop, not tilled yet - the team
## isn't wasted on worked soil.
func is_ploughable(plot_id: int) -> bool:
	return sim.fields.can_till(plot_id) and not sim.fields.get_plot(plot_id).tilled

func can_plough(plot_id: int) -> bool:
	return check_plough() == PloughCheck.OK and is_ploughable(plot_id)

## Tills one plot with the team - FarmingController calls it for each plot
## of the furrow as the team reaches it. False if it can't (anymore).
func plough(plot_id: int) -> bool:
	if not can_plough(plot_id):
		return false
	state.plough_cells_today += 1
	return sim.fields.till(plot_id)

func get_manure_pile() -> int:
	return state.manure_pile

## Takes the whole heap into the inventory. Returns how much.
func collect_manure() -> int:
	var amount := state.manure_pile
	if amount <= 0:
		return 0
	state.manure_pile = 0
	sim.add_item(MANURE_ITEM, amount)
	sim.zebus_changed.emit()
	return amount

## The day that ends: a day of growth for each zebu if the trough was full,
## and its manure on the heap; the team is rested.
func advance_zebus() -> void:
	state.plough_cells_today = 0
	if state.zebus.is_empty():
		state.zebu_trough_full = false
		state.zebu_trough_spare = false
		return
	if is_zebu_trough_full():
		state.manure_pile = mini(state.manure_pile + MANURE_PER_ZEBU * state.zebus.size(), get_manure_max())
		for zebu: Dictionary in state.zebus.values():
			zebu["grown_days"] = mini(int(zebu["grown_days"]) + 1, ZEBU_GROW_DAYS)
	state.zebu_trough_full = state.zebu_trough_spare
	state.zebu_trough_spare = false
	sim.zebus_changed.emit()
