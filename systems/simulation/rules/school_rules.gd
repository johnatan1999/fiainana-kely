class_name SchoolRules
extends SimRules

## Fara's school fees: the bill each season, paying it in Ariary or in rice.
## A part of FarmSimulation (SimRules): simulation.school.

## Fara's school fees (ecolage) - the player's share, the parents pay the
## rest. One bill a season: it comes SCHOOL_NOTICE_DAYS before the season
## starts and is due SCHOOL_GRACE_DAYS into it. The parents paid the first
## season. Paid at the school, in Ariary or in rice (SCHOOL_RICE_ITEM, taken
## at the weekly market's price - the change is given back). Unpaid past
## the due day, Fara is sent home until it is (CONDITION_SCHOOL_FEES_OVERDUE):
## nothing else is lost, and a new bill adds up without moving the due day.
const SCHOOL_FEE := 10000
const SCHOOL_NOTICE_DAYS := 7
const SCHOOL_GRACE_DAYS := 7
const SCHOOL_RICE_ITEM := "rice"
const SCHOOL_RICE_PRICE_MULTIPLIER := 1.25
## A story condition (FarmSimulation.get_conditions()): villagers' steps can depend on it
## (VillagerStop.only_if / unless).
const CONDITION_SCHOOL_FEES_OVERDUE := "school_fees_overdue"

## What the player still owes the school (0 = all paid).
func get_school_debt() -> int:
	return state.school_debt

## Days left to pay, today included (1 = today is the last day, 0 or less =
## overdue). Only meaningful while there's a debt.
func get_school_days_left() -> int:
	return state.school_due_day - state.day + 1

func is_school_fee_due() -> bool:
	return state.school_debt > 0

## Past the due day and not all paid: Fara stays home from school.
func is_school_fees_overdue() -> bool:
	return state.school_debt > 0 and state.day > state.school_due_day

## What the school takes a rice for (the weekly market's price), 0 if rice
## isn't a known crop.
func get_school_rice_price() -> int:
	var rice := sim.fields.get_crop_data(SCHOOL_RICE_ITEM)
	return roundi(rice.sell_price * SCHOOL_RICE_PRICE_MULTIPLIER) if rice != null else 0

## Rice it would take to pay off the debt.
func get_school_rice_needed() -> int:
	var price := get_school_rice_price()
	return ceili(float(state.school_debt) / price) if price > 0 else 0

## Pays up to `amount` Ariary towards the fees - never more than owed or
## owned. Returns what was paid.
func pay_school_fees(amount: int) -> int:
	var paid := mini(amount, mini(state.school_debt, state.money))
	if paid <= 0:
		return 0
	state.school_debt -= paid
	day_log.school_paid += paid
	sim.add_money(-paid)
	sim.school_fees_changed.emit()
	return paid

## Pays with up to `count` rice - never more than owned or than the debt
## needs; what the last one is worth over the debt comes back in Ariary.
## Returns how many rice were given.
func pay_school_fees_in_rice(count: int) -> int:
	var price := get_school_rice_price()
	count = mini(count, mini(state.get_inventory_count(SCHOOL_RICE_ITEM), get_school_rice_needed()))
	if count <= 0 or price <= 0:
		return 0
	var value := count * price
	sim.add_item(SCHOOL_RICE_ITEM, -count)
	day_log.school_paid += mini(value, state.school_debt)
	if value > state.school_debt:
		sim.add_money(value - state.school_debt)
	state.school_debt = maxi(state.school_debt - value, 0)
	sim.school_fees_changed.emit()
	return count

## Morning: the bill for the coming season, SCHOOL_NOTICE_DAYS ahead - at
## least SCHOOL_GRACE_DAYS to pay it. An unpaid debt keeps its due day.
func advance_school_fees() -> void:
	var changed := false
	var season := (state.day + SCHOOL_NOTICE_DAYS - 1) / GameClock.DAYS_PER_SEASON
	if season > state.school_billed_season:
		state.school_billed_season = season
		if state.school_debt <= 0:
			var season_start := season * GameClock.DAYS_PER_SEASON + 1
			state.school_due_day = maxi(season_start, state.day) + SCHOOL_GRACE_DAYS - 1
		state.school_debt += SCHOOL_FEE
		changed = true
	if state.school_debt > 0 and state.day == state.school_due_day + 1:
		changed = true # just fell overdue
	if changed:
		sim.school_fees_changed.emit()
