class_name OrderRules
extends SimRules

## Villagers' orders: offered each morning, accepted or declined, delivered or
## run out.
## A part of FarmSimulation (SimRules): simulation.orders.

## Villagers' orders (VillagerData.orders): every morning, a villager with
## no order (and no cooldown) may offer one - only one the player can
## fulfil in time. The player accepts or declines it, then has the
## template's days to bring the items; it pays the template's unit_reward
## each, above the shop's price. At most ORDER_MAX_ACTIVE accepted at once.
## An offer not taken stays ORDER_OFFER_DAYS; after a delivery, a refusal or
## an order that ran out, the villager waits ORDER_COOLDOWN_DAYS. Nothing
## is lost when an order runs out - a cosy game rewards, it doesn't punish.
const ORDER_MAX_ACTIVE := 3
const ORDER_OFFER_DAYS := 2
const ORDER_COOLDOWN_DAYS := 2
const ORDER_OFFER_CHANCE := 0.5
## How many offers can wait at once (not overwhelming the player).
const ORDER_MAX_OFFERS := 2
const ORDER_BONUS_PER_HEART := 0.05

var _order_givers: Dictionary = {} # villager_id: String -> Array[OrderTemplate]
## The chance a villager offers an order on a given morning (tests set 1.0
## or 0.0 to make it certain).
var order_offer_chance := ORDER_OFFER_CHANCE

## Registered by OrderManager for every villager (their VillagerData file's
## name and its orders), at the start of the game.
func register_order_giver(villager_id: String, templates: Array[OrderTemplate]) -> void:
	_order_givers[villager_id] = templates

## The order of `villager_id` ({} = none) - see FarmState.orders.
func get_order(villager_id: String) -> Dictionary:
	return state.orders.get(villager_id, {})

func is_order_offered(villager_id: String) -> bool:
	return get_order(villager_id).get("deadline", 0) == -1

func is_order_active(villager_id: String) -> bool:
	return get_order(villager_id).get("deadline", -1) >= 0

## Villagers with an accepted order, oldest deadline first.
func get_active_orders() -> Array[String]:
	var active: Array[String] = []
	for villager_id: String in state.orders:
		if is_order_active(villager_id):
			active.append(villager_id)
	active.sort_custom(func(a, b): return state.orders[a]["deadline"] < state.orders[b]["deadline"])
	return active

## Days left to deliver, today included (1 = today is the last day).
func get_order_days_left(villager_id: String) -> int:
	return get_order(villager_id).get("deadline", -1) - state.day + 1

func get_order_template(villager_id: String) -> OrderTemplate:
	var templates: Array = _order_givers.get(villager_id, [])
	var index: int = get_order(villager_id).get("template", -1)
	return templates[index] if index >= 0 and index < templates.size() else null

func can_accept_order(villager_id: String) -> bool:
	return is_order_offered(villager_id) and get_active_orders().size() < ORDER_MAX_ACTIVE

func accept_order(villager_id: String) -> bool:
	if not can_accept_order(villager_id):
		return false
	var order: Dictionary = state.orders[villager_id]
	var template := get_order_template(villager_id)
	order["deadline"] = state.day + (template.days if template else 5) - 1
	sim.order_changed.emit(villager_id)
	return true

func decline_order(villager_id: String) -> bool:
	if not is_order_offered(villager_id):
		return false
	_close_order(villager_id)
	return true

func can_deliver_order(villager_id: String) -> bool:
	var order := get_order(villager_id)
	return is_order_active(villager_id) and state.get_inventory_count(order["item"]) >= order["quantity"]

## What delivering the order pays: its reward, plus the friendship bonus
## (ORDER_BONUS_PER_HEART a heart), rounded to 100 Ar.
func get_order_payment(villager_id: String) -> int:
	var reward: int = get_order(villager_id).get("reward", 0)
	var bonus := reward * ORDER_BONUS_PER_HEART * sim.friendship.get_hearts(villager_id)
	return reward + roundi(bonus / 100.0) * 100

## Hands the items over. Returns the Ariary earned (0 if it can't be
## delivered). A delivered order brings the villager closer
## (FriendshipRules.FRIENDSHIP_ORDER).
func deliver_order(villager_id: String) -> int:
	if not can_deliver_order(villager_id):
		return 0
	var order := get_order(villager_id)
	var payment := get_order_payment(villager_id)
	sim.add_item(order["item"], -order["quantity"])
	sim.add_money(payment)
	day_log.orders_delivered.append(villager_id)
	_close_order(villager_id)
	sim.friendship.add_friendship(villager_id, FriendshipRules.FRIENDSHIP_ORDER)
	return payment

## Whether the player can have `quantity` of `item_id` within `days`:
## already in the inventory, or growable in time - a crop of this season
## (or of every season), quick enough, in a paddy if it needs one; eggs
## with hens; fruit in season from a tree of theirs.
func can_fulfil(item_id: String, quantity: int, days: int) -> bool:
	if state.get_inventory_count(item_id) >= quantity:
		return true
	var season := state.clock.get_season()
	var crop_data := sim.fields.get_crop_data(item_id)
	if crop_data != null:
		if crop_data.ideal_season != CropData.Season.ALL_YEAR and int(crop_data.ideal_season) != season:
			return false
		if crop_data.growth_days + 1 > days:
			return false
		if crop_data.grows_in_paddy:
			return state.plots.values().any(func(plot: PlotState): return plot.flooded)
		return true
	for animal: AnimalState in state.animals.values():
		var animal_data := sim.animals.get_animal_data(animal.species)
		if animal_data != null and animal_data.product_id == item_id:
			return true
	for tree: TreeState in state.trees.values():
		var tree_data := sim.trees.get_tree_data(tree.tree_type_id)
		if tree_data != null and tree_data.fruit_item_id == item_id and tree_data.is_in_season(season):
			return true
	return false

## Morning: expires what ran out, then offers new orders - once a day.
## Also called by OrderManager when the givers are registered, so the very
## first day has some.
func refresh_order_offers() -> void:
	if state.order_roll_day == state.day:
		return
	state.order_roll_day = state.day
	var offers := state.orders.keys().filter(func(id): return is_order_offered(id)).size()
	var givers := _order_givers.keys()
	givers.shuffle()
	for villager_id: String in givers:
		if offers >= ORDER_MAX_OFFERS:
			break
		if state.orders.has(villager_id) or state.order_cooldowns.get(villager_id, 0) > state.day:
			continue
		if randf() >= order_offer_chance:
			continue
		if _offer_order(villager_id):
			offers += 1

func _offer_order(villager_id: String) -> bool:
	var templates: Array = _order_givers[villager_id]
	var candidates: Array[int] = []
	for index in templates.size():
		var template: OrderTemplate = templates[index]
		if template != null and can_fulfil(template.item_id, template.quantity.x, template.days):
			candidates.append(index)
	if candidates.is_empty():
		return false
	var index: int = candidates.pick_random()
	var template: OrderTemplate = templates[index]
	var quantity := randi_range(template.quantity.x, template.quantity.y)
	if not can_fulfil(template.item_id, quantity, template.days):
		quantity = template.quantity.x
	state.orders[villager_id] = {
		"item": template.item_id, "quantity": quantity, "reward": template.unit_reward * quantity,
		"template": index, "since": state.day, "deadline": -1,
	}
	sim.order_changed.emit(villager_id)
	return true

func _close_order(villager_id: String) -> void:
	state.orders.erase(villager_id)
	state.order_cooldowns[villager_id] = state.day + ORDER_COOLDOWN_DAYS
	sim.order_changed.emit(villager_id)

func advance_orders() -> void:
	for villager_id: String in state.orders.keys():
		var order: Dictionary = state.orders[villager_id]
		if order["deadline"] >= 0 and order["deadline"] < state.day:
			_close_order(villager_id)
			sim.order_expired.emit(villager_id)
		elif order["deadline"] == -1 and state.day - order["since"] >= ORDER_OFFER_DAYS:
			_close_order(villager_id)
	refresh_order_offers()

## Accepted orders whose last day is tomorrow.
func get_orders_due_tomorrow() -> Array[String]:
	var due: Array[String] = []
	for villager_id in get_active_orders():
		if get_order_days_left(villager_id) == 2:
			due.append(villager_id)
	return due
