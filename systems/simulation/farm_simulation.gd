class_name FarmSimulation
extends RefCounted

## The farm's simulation: every rule of the game, and nothing of how it looks
## - never a Node2D, a Sprite2D or a UI. The presentation listens to the
## signals below and calls the rules.
##
## This is the hub. It holds what every domain shares - the state
## (FarmState: everything saved), today's log (DayLog), the clock and the
## weather, the bag and the money, saving and loading - and the night
## (advance_day), which calls each domain's day hooks in order. And every
## signal, so a listener needn't know which domain changed things.
##
## The rules themselves live in one domain each (SimRules,
## systems/simulation/rules/), reached by name: simulation.fields.till(id),
## simulation.zebus.buy_zebu(), simulation.quests.start_quest(id)... Each holds
## its constants (ZebuRules.ZEBU_PRICE) and the data registered with it (the
## quests, the recipes...).

signal money_changed(money: int)
signal day_changed(day: int)
## The time of day moved on to a new minute (GameClock.minute_of_day).
signal time_changed(minute_of_day: int)
## Today's weather is set - each morning, and when a save is loaded.
signal weather_changed(weather: FarmState.Weather)
signal plot_changed(plot_id: int)
## A new plot came into existence (grid expansion, or a loaded save) - the
## presentation layer should create a PlotView for it. Distinct from
## plot_changed, which only updates a PlotView that already exists.
signal plot_added(plot_id: int)
## A plot was permanently removed - the presentation layer should free its
## PlotView.
signal plot_removed(plot_id: int)
signal inventory_changed(item_id: String, amount: int)
## A crop was harvested: `quantity` went into the inventory. under_watered /
## off_season say which penalties cut it (see FieldRules.harvest()), so the
## player can be told why a harvest came out small.
signal crop_harvested(plot_id: int, crop_id: String, quantity: int, under_watered: bool, off_season: bool)

signal animal_added(animal_id: String)
## Animals bought and waiting to be settled changed (see AnimalRules.place_animal()).
signal pending_animals_changed
signal animal_changed(animal_id: String)
## An animal is gone from the farm (a hen taken by a thief).
signal animal_removed(animal_id: String)
## A save was just loaded into `state` - fired right after it's replaced and
## before the per-item/per-plot change signals that follow, so listeners can
## tell "loaded as it was saved" apart from "just acquired".
signal state_loaded
## The hotbar layout (which item is in which slot) changed.
signal hotbar_changed
## Fired once an animal's product is ready - the presentation layer spawns
## the actual pickup (e.g. Egg.tscn) in response; the simulation never
## touches Node2D itself, so it doesn't put the product directly into
## inventory here.
signal product_ready(animal_id: String, product_id: String)
## A fruit tree ripened, was picked, or its fruit rotted at season's end.
signal tree_changed(tree_id: String)
## The player cut a tuft in a neighbours' paddy (help_neighbour_harvest).
signal neighbour_paddy_changed(paddy_id: String)
## A villager's order changed: offered, accepted, declined, delivered...
signal order_changed(villager_id: String)
## An accepted order ran out before it was delivered.
signal order_expired(villager_id: String)
## Friendship with a villager grew (points); `hearts` is the new count.
signal friendship_changed(villager_id: String, hearts: int)
## The player's zebus changed: one bought or sold, the trough filled, a day
## of growth.
signal zebus_changed
## A new heart was reached; `reward` is the gift for it (already in the
## inventory), or null.
signal friendship_level_up(villager_id: String, hearts: int, reward: FriendshipReward)
## Fara's school fees changed: a new bill, a payment, or they fell overdue.
signal school_fees_changed
## The player's fighting rooster changed: given, fed, trained, a day of care.
signal rooster_changed
## The cockfight ranking changed: a tournament, the villagers' weekly bouts,
## a new season.
signal cockfight_changed
## A season of cockfights is over: `champion_id` ("player" or a
## FightingRoosterData id) is the village's best rooster until the next.
signal cockfight_season_ended(champion_id: String)
## A family project: work started on it, or the building is finished (its
## new level in place).
signal project_started(project_id: String)
## The ruined coop was rebuilt (build_coop): level 1.
signal coop_built
signal project_completed(project_id: String)
## The brick coop's basket (coop level 3): the eggs laid overnight went
## straight into the bag.
signal basket_collected(item_id: String, quantity: int)
## A new page in the player's notebook (Discovery id, or "cuisine:<recipe>").
signal discovery_made(discovery_id: String)
## A wild plant was gathered at a forage spot (it grows back later).
signal forage_changed(spot_id: String)
## A side quest was accepted, went on to its next step, or was finished -
## and, each morning, quests may have become available (quest_id "").
signal quest_changed(quest_id: String)
## A side quest's last step done: its reward given.
signal quest_completed(quest_id: String)
## Chicken thieves (mpangalatra akoho) about: a rumour this morning, from
## `villager_id`'s yard - for THIEF_ALERT_NIGHTS nights.
signal thief_alert_started(villager_id: String)
## Overnight, a thief took a hen from the coop (gone from state.animals).
signal chicken_stolen(animal_id: String)
## Overnight, thieves tried the coop - locked, it held.
signal thieves_foiled
## The padlock is on the coop's door (bought: put straight on).
signal coop_secured
## Overnight, the dog barked the chicken thieves away.
signal thieves_chased
## The family's dog came (a side quest's reward: Rakoto's puppy).
signal dog_adopted
## The dog's name, bowl, petting...
signal dog_changed

## Chance of a rainy day, per season: Asara is the rainy season. A rainy day
## waters every tilled plot from the morning - see set_weather().
const RAIN_CHANCE := {GameClock.Season.RAINY: 0.45, GameClock.Season.DRY: 0.08}

var state: FarmState
## What happened today (the evening meal tells it) - started afresh each
## morning and on load. See DayLog.
var day_log := DayLog.new()
## Chance of rain per season for this game - RAIN_CHANCE; tests set it to {}
## (never rains) so advance_day() stays deterministic.
var rain_chance: Dictionary = RAIN_CHANCE.duplicate()

# The domains of the rules (SimRules).
var fields: FieldRules
var animals: AnimalRules
var zebus: ZebuRules
var trees: TreeRules
var cockfight: CockfightRules
var friendship: FriendshipRules
var projects: ProjectRules
var kitchen: KitchenRules
var notebook: NotebookRules
var thieves: ThiefRules
var dog: DogRules
var quests: QuestRules
var school: SchoolRules
var orders: OrderRules
var neighbours: NeighbourRules
var market: MarketRules
var hotbar: HotbarRules

## Fraction of a minute accumulated by advance_time(), not saved.
var _minute_fraction := 0.0
## The money as last seen by _on_money_changed(), to tell what came in or
## went out.
var _last_money := 0

func _init(p_grid_width: int, p_grid_height: int, crop_registry: Dictionary, animal_registry: Dictionary = {}, tree_registry: Dictionary = {}) -> void:
	state = FarmState.new(p_grid_width, p_grid_height)
	fields = FieldRules.new(self)
	fields.grid_width = p_grid_width
	fields.grid_height = p_grid_height
	fields._crop_registry = crop_registry
	animals = AnimalRules.new(self)
	animals._animal_registry = animal_registry
	zebus = ZebuRules.new(self)
	trees = TreeRules.new(self)
	trees._tree_registry = tree_registry
	cockfight = CockfightRules.new(self)
	friendship = FriendshipRules.new(self)
	projects = ProjectRules.new(self)
	kitchen = KitchenRules.new(self)
	notebook = NotebookRules.new(self)
	thieves = ThiefRules.new(self)
	dog = DogRules.new(self)
	quests = QuestRules.new(self)
	school = SchoolRules.new(self)
	orders = OrderRules.new(self)
	neighbours = NeighbourRules.new(self)
	market = MarketRules.new(self)
	hotbar = HotbarRules.new(self)
	# Whoever spends the last of an item, it leaves the hotbar. A method, not a
	# lambda: a lambda using self holds a strong reference to this RefCounted,
	# so connecting it to our own signal would keep the whole simulation (and
	# every resource it holds) alive forever - leaked at exit.
	inventory_changed.connect(_on_inventory_changed)
	_last_money = state.money
	money_changed.connect(_on_money_changed)

# --- What every domain shares: the bag and the money -----------------------------------------

## `quantity` of `item_id` into the bag (negative: out of it), and said.
func add_item(item_id: String, quantity: int) -> void:
	state.add_inventory(item_id, quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))

## Money in (negative: out), and said - today's earnings and spendings are
## counted from it (DayLog).
func add_money(amount: int) -> void:
	state.money += amount
	money_changed.emit(state.money)

## Pays `amount` if the player has it - for what isn't a purchase of
## something (FarmLandManager's new land). Returns whether it was paid.
func spend_money(amount: int) -> bool:
	if amount < 0 or state.money < amount:
		return false
	add_money(-amount)
	return true

## Every change of money goes through money_changed: what came in or went
## out today, whatever the cause.
func _on_money_changed(money: int) -> void:
	day_log.add_money(money - _last_money)
	_last_money = money

func _on_inventory_changed(item_id: String, count: int) -> void:
	if count <= 0:
		hotbar.remove_from_hotbar(item_id)

# --- The night, the clock, the weather ---------------------------------------------------------

## The night: the day that ends (what today's care was worth), then the new
## morning (the weather, the village's news, what's due). The order matters:
## each domain's hooks run where the story needs them.
func advance_day() -> void:
	fields.advance_plots()
	animals.advance_animals()
	zebus.advance_zebus()
	trees.advance_trees()
	cockfight.advance_rooster()
	if state.clock.get_weekday() == CockfightRules.COCKFIGHT_DAY:
		cockfight.play_villagers_bouts()
	var season_before := state.clock.get_season()
	state.clock.advance_day()
	day_log = DayLog.new()
	if state.clock.get_season() != season_before:
		cockfight.end_cockfight_season()
	_minute_fraction = 0.0
	set_weather(_roll_weather())
	thieves.advance_thieves()
	orders.advance_orders()
	school.advance_school_fees()
	projects.advance_projects()
	# Quests that became available overnight (a new day, a new season).
	quest_changed.emit("")
	# The brick coop's basket, now that the new day's log has begun.
	animals.collect_basket()
	day_changed.emit(state.day)
	time_changed.emit(state.clock.minute_of_day)

## Moves the time of day on by `minutes` (fractions add up across calls) -
## driven by DayNightController from real time. Stops at
## GameClock.LATEST_MINUTE.
func advance_time(minutes: float) -> void:
	_minute_fraction += minutes
	var whole := int(_minute_fraction)
	if whole <= 0:
		return
	_minute_fraction -= whole
	if state.clock.advance_minutes(whole):
		time_changed.emit(state.clock.minute_of_day)
	else:
		_minute_fraction = 0.0

func is_raining() -> bool:
	return state.weather == FarmState.Weather.RAIN

## Sets today's weather. Rain waters every tilled plot right away - for the
## whole day: a crop planted after waking up still counts as watered.
func set_weather(weather: FarmState.Weather) -> void:
	state.weather = weather
	if weather == FarmState.Weather.RAIN:
		fields.water_all_tilled()
	weather_changed.emit(weather)

func _roll_weather() -> FarmState.Weather:
	var chance: float = rain_chance.get(state.clock.get_season(), 0.0)
	return FarmState.Weather.RAIN if randf() < chance else FarmState.Weather.CLEAR

## Story conditions true today (name -> true), for the villagers' steps
## (VillagerStop.only_if / unless).
func get_conditions() -> Dictionary:
	var conditions := {}
	if school.is_school_fees_overdue():
		conditions[SchoolRules.CONDITION_SCHOOL_FEES_OVERDUE] = true
	conditions.merge(quests.get_conditions())
	return conditions

# --- Saving ----------------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return state.to_dict()

## Restores state in-place and re-emits every signal so the presentation layer redraws itself.
func load_save_data(data: Dictionary) -> void:
	state.load_dict(data)
	day_log = DayLog.new()
	_last_money = state.money
	hotbar.normalize()
	state_loaded.emit()
	hotbar_changed.emit()
	pending_animals_changed.emit()
	zebus_changed.emit()
	school_fees_changed.emit()
	rooster_changed.emit()
	cockfight_changed.emit()

	var bounds := state.get_grid_bounds()
	fields.grid_width = bounds.size.x
	fields.grid_height = bounds.size.y

	money_changed.emit(state.money)
	day_changed.emit(state.day)
	_minute_fraction = 0.0
	time_changed.emit(state.clock.minute_of_day)
	weather_changed.emit(state.weather)
	# plot_added, not plot_changed: load_dict() rebuilt the plot set from
	# scratch, so as far as any listener is concerned every plot is new.
	for plot_id in state.plots:
		plot_added.emit(plot_id)
	for item_id in state.inventory:
		inventory_changed.emit(item_id, state.inventory[item_id])
