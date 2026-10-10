class_name FarmSimulation
extends RefCounted

## Owns FarmState and enforces every rule of the farm loop.
## Never touches Node2D/Sprite2D/UI - presentation only listens to the signals below.

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
## off_season say which penalties cut it (see _compute_harvest_quantity()),
## so the player can be told why a harvest came out small.
signal crop_harvested(plot_id: int, crop_id: String, quantity: int, under_watered: bool, off_season: bool)

signal animal_added(animal_id: String)
## Animals bought and waiting to be settled changed (see place_animal()).
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
## the actual pickup (e.g. Egg.tscn) in response; FarmSimulation never touches
## Node2D itself, so it doesn't put the product directly into inventory here.
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

const COOP_COST := 6000
## Chance of a rainy day, per season: Asara is the rainy season. A rainy day
## waters every tilled plot from the morning - see set_weather().
const RAIN_CHANCE := {GameClock.Season.RAINY: 0.45, GameClock.Season.DRY: 0.08}

## The neighbours' paddies (VillagePaddy - decor, not the player's): their
## rice follows the calendar, two crops a year. Planted out at the start of
## each season, it grows through NEIGHBOUR_RICE_STAGES (day of the season ->
## CropVisual stage), then the farmers cut it over NEIGHBOUR_HARVEST_DAYS
## from NEIGHBOUR_HARVEST_FROM_DAY, during their working hours, column by
## column from the west. The player can lend a hand: each tuft they cut
## earns NEIGHBOUR_HARVEST_REWARD - seed rice, the neighbours' way of
## sharing.
const NEIGHBOUR_RICE_STAGES := {1: 1, 9: 2, 22: 3}
const NEIGHBOUR_HARVEST_FROM_DAY := 26
const NEIGHBOUR_HARVEST_DAYS := 3
const NEIGHBOUR_WORK_HOURS := Vector2i(6 * 60 + 30, 16 * 60)
const NEIGHBOUR_HARVEST_REWARD := "rice_seed"

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

## Friendship with each villager: points, FRIENDSHIP_PER_HEART a heart, up
## to FRIENDSHIP_MAX_HEARTS. Earned by talking to them (once a day), by
## delivering their orders, and - for the farmers - by helping with the
## neighbours' harvest. Never lost. Each heart: a gift at some levels
## (VillagerData.friendship_rewards) and a better price on their orders
## (ORDER_BONUS_PER_HEART).
const FRIENDSHIP_PER_HEART := 100
const FRIENDSHIP_MAX_HEARTS := 5
const FRIENDSHIP_TALK := 10
const FRIENDSHIP_ORDER := 60
const FRIENDSHIP_HARVEST_HELP := 5
const ORDER_BONUS_PER_HEART := 0.05

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
## A story condition (get_conditions()): villagers' steps can depend on it
## (VillagerStop.only_if / unless).
const CONDITION_SCHOOL_FEES_OVERDUE := "school_fees_overdue"

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
const FRIENDSHIP_COCKFIGHT := 15
## Friendship with every rooster owner when the player's rooster is the
## season's best.
const FRIENDSHIP_CHAMPION := 40
enum CockfightCheck { OK, NO_ROOSTER, CLOSED, ALREADY_ENTERED }

## Family projects (FamilyProject, data/projects/): the farm's buildings
## and their level - the coop (0 = still a ruin, 1 once built, then 2, 3)
## and the zebu pen (1 to 3). One building site at a time: paid up front,
## finished PROJECT_DAYS later in the morning - a day less for each friend
## (PROJECT_HELPER_HEARTS hearts and up) who comes to help, at most
## PROJECT_MAX_HELPERS of them, never under a day: the valin-tanana.
const BUILDINGS := ["coop", "zebu_pen", "granary", "kitchen"]
## Each building's level at the start of a game: the coop is a ruin until
## built (has_coop), the pen is there, the house's annexes aren't yet.
const BUILDING_START_LEVELS := {"zebu_pen": 1, "granary": 0, "kitchen": 0}
## The granary on stilts: no more rice for the rats - this much more at
## each rice harvest.
const GRANARY_RICE_MULTIPLIER := 1.25
const GRANARY_CROP := "rice"
const COOP_CAPACITY_BY_LEVEL := [0, 4, 8, 12]
## From this coop level, the eggs go straight into the bag.
const COOP_BASKET_LEVEL := 3
## From this pen level, a filled trough lasts two days.
const ZEBU_TROUGH_TWO_DAYS_LEVEL := 3
const PROJECT_HELPER_HEARTS := 2
const PROJECT_MAX_HELPERS := 2
enum ProjectState { DONE, BUILDING, AVAILABLE, LOCKED, BUSY }

## Why an animal can or can't be settled right now - the UI turns it into a
## message ("Coop full (6/6)"...).
enum PlaceCheck { OK, NO_BUILDING, FULL, NONE_WAITING }

var state: FarmState
var grid_width: int
var grid_height: int

var _crop_registry: Dictionary = {} # crop_id: String -> CropData
var _animal_registry: Dictionary = {} # AnimalData.Species -> AnimalData
var _tree_registry: Dictionary = {} # tree_type_id: String -> TreeData
## Chance of rain per season for this game - RAIN_CHANCE; tests set it to {}
## (never rains) so advance_day() stays deterministic.
var rain_chance: Dictionary = RAIN_CHANCE.duplicate()
## Fraction of a minute accumulated by advance_time(), not saved.
var _minute_fraction := 0.0
var _neighbour_paddies: Dictionary = {} # paddy_id: String -> size in cells (Vector2i)
var _order_givers: Dictionary = {} # villager_id: String -> Array[OrderTemplate]
var _friendship_rewards: Dictionary = {} # villager_id: String -> Array[FriendshipReward]
var _fighting_roosters: Dictionary = {} # rooster_id: String -> FightingRoosterData
var _projects: Dictionary = {} # project_id: String -> FamilyProject
var _recipes: Dictionary = {} # recipe_id: String -> Recipe
var _discoveries: Dictionary = {} # discovery_id: String -> Discovery
var _quests: Dictionary = {} # quest_id: String -> Quest
## The chance a villager offers an order on a given morning (tests set 1.0
## or 0.0 to make it certain).
var order_offer_chance := ORDER_OFFER_CHANCE
## The chance thieves come round on a morning, and that they try the coop
## on a night they're about (tests set 1.0 or 0.0).
var thief_alert_chance := THIEF_ALERT_CHANCE
var thief_night_chance := THIEF_NIGHT_CHANCE
## What happened today (the evening meal tells it) - started afresh each
## morning and on load. See DayLog.
var day_log := DayLog.new()
## Laid overnight in the brick coop, waiting for the new day to begin.
var _basket: Dictionary = {}
## The money as last seen by _on_money_changed(), to tell what came in or
## went out.
var _last_money := 0

func _init(p_grid_width: int, p_grid_height: int, crop_registry: Dictionary, animal_registry: Dictionary = {}, tree_registry: Dictionary = {}) -> void:
	grid_width = p_grid_width
	grid_height = p_grid_height
	_crop_registry = crop_registry
	_animal_registry = animal_registry
	_tree_registry = tree_registry
	state = FarmState.new(p_grid_width, p_grid_height)
	# Whoever spends the last of an item, it leaves the hotbar. A method, not a
	# lambda: a lambda using self holds a strong reference to this RefCounted,
	# so connecting it to our own signal would keep the whole simulation (and
	# every resource it holds) alive forever - leaked at exit.
	inventory_changed.connect(_on_inventory_changed)
	_last_money = state.money
	money_changed.connect(_on_money_changed)

func get_plot(plot_id: int) -> PlotState:
	return state.plots.get(plot_id)

## Plots are addressed by (cell, world zone) - see FarmState.DEFAULT_ZONE.
func get_plot_id_at(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> int:
	return state.get_plot_id_at(x, y, zone_id)

## The plot's cell in its zone's grid.
func get_plot_position(plot_id: int) -> Vector2i:
	return state.plot_positions.get(plot_id, Vector2i(-1, -1))

func get_plot_zone(plot_id: int) -> String:
	return state.get_plot_zone(plot_id)

func get_all_plot_ids() -> Array:
	return state.plots.keys()

## Grows the farm to at least new_width x new_height, filling in any missing
## plot inside that rectangle with a fresh empty one. Never shrinks or
## removes anything - use remove_tile()/clear_tile() for that.
func expand_grid(new_width: int, new_height: int) -> void:
	var target_width: int = max(new_width, grid_width)
	var target_height: int = max(new_height, grid_height)
	for y in range(target_height):
		for x in range(target_width):
			add_tile(x, y) # no-op if a plot is already there
	grid_width = target_width
	grid_height = target_height

## Adds a single empty, untilled plot at (x, y) of zone_id. Returns the new
## plot_id, or -1 if a plot already exists there.
func add_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> int:
	var plot_id := state.add_plot(x, y, zone_id)
	if plot_id != -1:
		plot_added.emit(plot_id)
	return plot_id

## Permanently removes the plot at (x, y), including whatever crop was
## growing on it. Returns false if there was no plot there.
func remove_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	if plot_id == -1:
		return false
	state.remove_plot(plot_id)
	plot_removed.emit(plot_id)
	return true

## Marks the plot at (x, y) as a paddy (or not) - see PlotState.flooded.
## Set from the zone's FarmFields each time they register. Returns false if
## there's no plot there.
func set_tile_flooded(x: int, y: int, flooded: bool, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	var plot := get_plot(plot_id)
	if plot == null:
		return false
	if plot.flooded != flooded:
		plot.flooded = flooded
		plot_changed.emit(plot_id)
	return true

## Resets the plot at (x, y) to empty/untilled without removing it from the
## grid - for reorganizing without changing the grid's shape.
func clear_tile(x: int, y: int, zone_id := FarmState.DEFAULT_ZONE) -> bool:
	var plot_id := state.get_plot_id_at(x, y, zone_id)
	var plot := get_plot(plot_id)
	if plot == null:
		return false
	plot.reset()
	plot_changed.emit(plot_id)
	return true

func get_crop_data(crop_id: String) -> CropData:
	return _crop_registry.get(crop_id)

func get_all_crop_ids() -> Array:
	return _crop_registry.keys()

func get_animal_data(species: AnimalData.Species) -> AnimalData:
	return _animal_registry.get(species)

func get_animal(animal_id: String) -> AnimalState:
	return state.animals.get(animal_id)

func get_all_animal_ids() -> Array:
	return state.animals.keys()

## can_till()/can_plant()/can_water()/can_harvest() are read-only mirrors of
## each action's guard - lets callers (FarmingController walking the player
## up to the plot, tool animations) check eligibility before mutating.
func can_till(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop == null

func till(plot_id: int) -> bool:
	if not can_till(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.tilled = true
	plot_changed.emit(plot_id)
	return true

func can_plant(plot_id: int, crop_id: String) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or not plot.tilled or plot.crop != null:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null or (plot.flooded and not crop_data.grows_in_paddy):
		return false
	return state.get_inventory_count(crop_id + "_seed") > 0

func plant(plot_id: int, crop_id: String) -> bool:
	if not can_plant(plot_id, crop_id):
		return false
	var plot := get_plot(plot_id)
	var crop_data := get_crop_data(crop_id)
	var seed_key := crop_id + "_seed"
	state.add_inventory(seed_key, -1)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	plot.crop = CropState.new(crop_id, crop_data.growth_days)
	plot_changed.emit(plot_id)
	return true

## A paddy is always irrigated: the watering can has nothing to do there.
func can_water(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null and not plot.flooded

func water(plot_id: int) -> bool:
	if not can_water(plot_id):
		return false
	var plot := get_plot(plot_id)
	plot.watered = true
	plot_changed.emit(plot_id)
	return true

## Also what the harvest swing animation checks, since it must play before
## the crop is actually removed, not after.
func can_harvest(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.crop != null and plot.crop.is_mature()

func harvest(plot_id: int) -> bool:
	if not can_harvest(plot_id):
		return false
	var plot := get_plot(plot_id)
	var crop_id := plot.crop.crop_id
	var crop_data := get_crop_data(crop_id)
	var under_watered := plot.crop.get_watered_ratio() < crop_data.min_watered_ratio_for_quality
	var off_season := crop_data.ideal_season != CropData.Season.ALL_YEAR 			and int(crop_data.ideal_season) != state.clock.get_season()
	var quantity := _compute_harvest_quantity(crop_data, under_watered, off_season)
	if plot.fertilized:
		quantity = ceili(quantity * MANURE_YIELD_MULTIPLIER)
		plot.fertilized = false
	if crop_id == GRANARY_CROP and get_building_level("granary") >= 1:
		quantity = ceili(quantity * GRANARY_RICE_MULTIPLIER)
	state.add_inventory(crop_id, quantity)
	plot.crop = null
	plot.watered = false
	inventory_changed.emit(crop_id, state.get_inventory_count(crop_id))
	plot_changed.emit(plot_id)
	day_log.add_harvest(crop_id, quantity)
	crop_harvested.emit(plot_id, crop_id, quantity, under_watered, off_season)
	return true

## Base yield is a random amount in [yield_min, yield_max]. Watering the crop
## less than its min_watered_ratio_for_quality caps it a notch lower, and
## harvesting outside its ideal_season shrinks it further - both floored at 1
## so a successful harvest never returns nothing.
func _compute_harvest_quantity(crop_data: CropData, under_watered: bool, off_season: bool) -> int:
	var quantity := randi_range(crop_data.yield_min, crop_data.yield_max)
	if under_watered:
		quantity = max(1, quantity - 1)
	if off_season:
		quantity = max(1, int(round(quantity * crop_data.off_season_yield_multiplier)))
	return quantity

func advance_day() -> void:
	for plot_id in state.plots:
		var plot: PlotState = state.plots[plot_id]
		if plot.crop != null:
			plot.crop.days_total += 1
			if plot.watered or plot.flooded:
				plot.crop.days_watered += 1
				plot.crop.age += 1
		plot.watered = false
		plot_changed.emit(plot_id)
	_advance_animals()
	_advance_zebus()
	_advance_trees()
	_advance_rooster()
	if state.clock.get_weekday() == COCKFIGHT_DAY:
		_play_villagers_bouts()
	var season_before := state.clock.get_season()
	state.clock.advance_day()
	day_log = DayLog.new()
	if state.clock.get_season() != season_before:
		_end_cockfight_season()
	_minute_fraction = 0.0
	set_weather(_roll_weather())
	_advance_thieves()
	_advance_orders()
	_advance_school_fees()
	_advance_projects()
	# Quests that became available overnight (a new day, a new season).
	quest_changed.emit("")
	# The brick coop's basket, now that the new day's log has begun.
	for product_id: String in _basket:
		collect_product(product_id, _basket[product_id])
		basket_collected.emit(product_id, _basket[product_id])
	_basket = {}
	day_changed.emit(state.day)
	time_changed.emit(state.clock.minute_of_day)

## Ticks hunger/thirst decay, the product cycle, and breeding for every
## animal. Called once per advance_day() - fed_today/watered_today (set
## throughout the day by feed_animal()/water_animal()) are consumed here and
## reset for the next day, exactly like PlotState.watered.
func _advance_animals() -> void:
	var qualifying_by_species: Dictionary = {} # AnimalData.Species -> count
	var basket: Dictionary = {} # product_id -> laid overnight, for the basket
	for animal_id in state.animals.keys():
		var animal: AnimalState = state.animals[animal_id]
		var animal_data := get_animal_data(animal.species)
		if animal_data == null:
			continue

		animal.age_days += 1
		if animal.is_well_cared_today():
			animal.days_well_cared += 1
			animal.days_since_product += 1
		else:
			animal.days_well_cared = 0

		if not animal.fed_today:
			animal.hunger = max(0.0, animal.hunger - animal_data.hunger_decay_per_day)
		if not animal.watered_today:
			animal.thirst = max(0.0, animal.thirst - animal_data.thirst_decay_per_day)

		animal.fed_today = false
		animal.watered_today = false

		if animal_data.product_id != "" and animal.days_since_product >= animal_data.product_cycle_days:
			animal.days_since_product = 0
			if get_building_level("coop") >= COOP_BASKET_LEVEL:
				basket[animal_data.product_id] = int(basket.get(animal_data.product_id, 0)) + 1
			else:
				product_ready.emit(animal_id, animal_data.product_id)

		if animal.days_well_cared >= animal_data.breeding_days_required:
			qualifying_by_species[animal.species] = qualifying_by_species.get(animal.species, 0) + 1

		animal_changed.emit(animal_id)

	for species in qualifying_by_species:
		if qualifying_by_species[species] >= 2:
			_attempt_breeding(species)
	_basket = basket

## One roll per species per day (not per pair) once at least 2 adults qualify,
## so a full coop doesn't produce multiple babies from a single day's care.
func _attempt_breeding(species: AnimalData.Species) -> void:
	if state.animals.size() >= state.coop_capacity:
		return
	var animal_data := get_animal_data(species)
	if randf() > animal_data.breeding_chance:
		return
	var baby_id := state.generate_animal_id(species)
	state.animals[baby_id] = AnimalState.new(baby_id, species)
	for animal in state.animals.values():
		if animal.species == species and animal.days_well_cared >= animal_data.breeding_days_required:
			animal.days_well_cared = 0
	animal_added.emit(baby_id)

func is_raining() -> bool:
	return state.weather == FarmState.Weather.RAIN

## Sets today's weather. Rain waters every tilled plot right away - for the
## whole day: a crop planted after waking up still counts as watered. Only
## tilled plots: wet soil is drawn as worked soil, and fallow land isn't.
func set_weather(weather: FarmState.Weather) -> void:
	state.weather = weather
	if weather == FarmState.Weather.RAIN:
		for plot_id in state.plots:
			var plot: PlotState = state.plots[plot_id]
			if plot.tilled and not plot.watered:
				plot.watered = true
				plot_changed.emit(plot_id)
	weather_changed.emit(weather)

func _roll_weather() -> FarmState.Weather:
	var chance: float = rain_chance.get(state.clock.get_season(), 0.0)
	return FarmState.Weather.RAIN if randf() < chance else FarmState.Weather.CLEAR

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

# --- Fruit trees --------------------------------------------------------------
# Trees are placed in the zone scenes (WorldTree); TreeManager registers each
# one here the first time its zone loads. From then on they ripen every day,
# whichever zone the player is in.

func get_tree_data(tree_type_id: String) -> TreeData:
	return _tree_registry.get(tree_type_id)

func get_tree_state(tree_id: String) -> TreeState:
	return state.trees.get(tree_id)

## Starts tracking a tree. A tree discovered in season starts ripe - the
## player's first visit should show what it's for. Registering a known tree
## again is a no-op, unless its species was changed in the editor since.
## Returns false for unknown or decorative (fruitless) species.
func register_tree(tree_id: String, tree_type_id: String) -> bool:
	var tree_data := get_tree_data(tree_type_id)
	if tree_data == null or not tree_data.bears_fruit():
		return false
	var tree := get_tree_state(tree_id)
	if tree != null and tree.tree_type_id == tree_type_id:
		return true
	tree = TreeState.new(tree_type_id)
	tree.fruit_ready = tree_data.is_in_season(state.clock.get_season())
	state.trees[tree_id] = tree
	tree_changed.emit(tree_id)
	return true

func can_harvest_tree(tree_id: String) -> bool:
	var tree := get_tree_state(tree_id)
	return tree != null and tree.fruit_ready and get_tree_data(tree.tree_type_id) != null

## Picks every fruit. Returns how many were added to the inventory (0 if
## nothing was ripe).
func harvest_tree(tree_id: String) -> int:
	if not can_harvest_tree(tree_id):
		return 0
	var tree := get_tree_state(tree_id)
	var tree_data := get_tree_data(tree.tree_type_id)
	var quantity := randi_range(tree_data.yield_min, tree_data.yield_max)
	tree.fruit_ready = false
	tree.days_growing = 0
	state.add_inventory(tree_data.fruit_item_id, quantity)
	inventory_changed.emit(tree_data.fruit_item_id, state.get_inventory_count(tree_data.fruit_item_id))
	day_log.add_harvest(tree_data.fruit_item_id, quantity)
	tree_changed.emit(tree_id)
	return quantity

## Days of growth left before the fruit is ripe, counting only today's
## season: 0 if ripe now, -1 if out of season (no fruit until it returns).
func get_tree_days_until_fruit(tree_id: String) -> int:
	var tree := get_tree_state(tree_id)
	if tree == null or tree.fruit_ready:
		return 0
	var tree_data := get_tree_data(tree.tree_type_id)
	if tree_data == null or not tree_data.is_in_season(state.clock.get_season()):
		return -1
	return maxi(1, tree_data.fruit_cycle_days - tree.days_growing)

# --- Friendship ------------------------------------------------------------------------

## Registered by FriendshipManager for every villager (their VillagerData
## file's name and its gifts).
func register_friend(villager_id: String, rewards: Array[FriendshipReward]) -> void:
	_friendship_rewards[villager_id] = rewards

func get_friendship(villager_id: String) -> int:
	return state.friendship.get(villager_id, 0)

func get_hearts(villager_id: String) -> int:
	return mini(get_friendship(villager_id) / FRIENDSHIP_PER_HEART, FRIENDSHIP_MAX_HEARTS)

## Progress towards the next heart, 0..1 (1 at the most hearts).
func get_heart_progress(villager_id: String) -> float:
	if get_hearts(villager_id) >= FRIENDSHIP_MAX_HEARTS:
		return 1.0
	return float(get_friendship(villager_id) % FRIENDSHIP_PER_HEART) / FRIENDSHIP_PER_HEART

## Adds friendship points; each heart reached gives its gift (if any).
func add_friendship(villager_id: String, points: int) -> void:
	if points <= 0:
		return
	var before := get_hearts(villager_id)
	var cap := FRIENDSHIP_PER_HEART * FRIENDSHIP_MAX_HEARTS
	var gained := mini(get_friendship(villager_id) + points, cap) - get_friendship(villager_id)
	state.friendship[villager_id] = get_friendship(villager_id) + gained
	day_log.friendship[villager_id] = int(day_log.friendship.get(villager_id, 0)) + gained
	var after := get_hearts(villager_id)
	if after > before:
		day_log.new_hearts[villager_id] = after
	friendship_changed.emit(villager_id, after)
	for hearts in range(before + 1, after + 1):
		var reward := _friendship_reward(villager_id, hearts)
		if reward != null:
			state.add_inventory(reward.item_id, reward.quantity)
			inventory_changed.emit(reward.item_id, state.get_inventory_count(reward.item_id))
		friendship_level_up.emit(villager_id, hearts, reward)

## Talking to a villager: friendship once a day. Returns whether it counted.
func talk_to(villager_id: String) -> bool:
	if state.friendship_talk_day.get(villager_id, 0) == state.day:
		return false
	state.friendship_talk_day[villager_id] = state.day
	add_friendship(villager_id, FRIENDSHIP_TALK)
	return true

func _friendship_reward(villager_id: String, hearts: int) -> FriendshipReward:
	for reward: FriendshipReward in _friendship_rewards.get(villager_id, []):
		if reward != null and reward.hearts == hearts:
			return reward
	return null

# --- The fighting rooster and the Sunday tournament ------------------------------------

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
	rooster_changed.emit()
	cockfight_changed.emit()
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
	state.add_inventory(item_id, -1)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.rooster["fed_day"] = state.day
	rooster_changed.emit()
	return true

func can_train_rooster() -> bool:
	return has_rooster() and not is_rooster_trained_today()

func train_rooster() -> bool:
	if not can_train_rooster():
		return false
	state.rooster["trained_day"] = state.day
	rooster_changed.emit()
	return true

## The day that ends: what the day's care is worth.
func _advance_rooster() -> void:
	if not is_rooster_fed_today():
		return
	var endurance := ROOSTER_FED_ENDURANCE
	if is_rooster_trained_today():
		endurance += ROOSTER_TRAINED_ENDURANCE
		state.rooster["force"] = mini(int(state.rooster["force"]) + ROOSTER_TRAINED_FORCE, ROOSTER_MAX_STAT)
	state.rooster["endurance"] = mini(int(state.rooster["endurance"]) + endurance, ROOSTER_MAX_STAT)
	rooster_changed.emit()

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
			add_friendship(owner, FRIENDSHIP_COCKFIGHT)
	state.money += COCKFIGHT_ENTRY_PRIZE
	money_changed.emit(state.money)
	day_log.cockfight = {"bouts": bouts.size(), "wins": bouts.filter(func(bout): return bout["won"]).size()}
	cockfight_changed.emit()
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
func _play_villagers_bouts() -> void:
	var ids := _fighting_roosters.keys()
	if ids.size() < 2:
		return
	for rooster_id: String in ids:
		var others := ids.filter(func(id): return id != rooster_id)
		for i in COCKFIGHT_BOUTS - int(state.cockfight_week_bouts.get(rooster_id, 0)):
			_bout(rooster_id, others.pick_random())
	state.cockfight_week_bouts.clear()
	cockfight_changed.emit()

## The new season's first morning: the top rooster of the one that ended is
## the village's best; points start again.
func _end_cockfight_season() -> void:
	var ranking := get_cockfight_ranking()
	if ranking.is_empty() or ranking[0]["points"] <= 0:
		return
	state.cockfight_champion = ranking[0]["id"]
	if state.cockfight_champion == PLAYER_ROOSTER_ID:
		for data: FightingRoosterData in _fighting_roosters.values():
			if not data.owner_id.is_empty():
				add_friendship(data.owner_id, FRIENDSHIP_CHAMPION)
	state.cockfight_points.clear()
	cockfight_changed.emit()
	cockfight_season_ended.emit(state.cockfight_champion)

# --- Family projects (the farm's buildings) ----------------------------------------------

## Registered by FamilyProjectManager (data/projects/).
func register_project(project_id: String, project: FamilyProject) -> void:
	_projects[project_id] = project

func get_project(project_id: String) -> FamilyProject:
	return _projects.get(project_id)

## Projects ids, building by building, level by level.
func get_project_ids() -> Array:
	var ids := _projects.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: FamilyProject = _projects[a]
		var pb: FamilyProject = _projects[b]
		if pa.building != pb.building:
			return BUILDINGS.find(pa.building) < BUILDINGS.find(pb.building)
		return pa.level < pb.level)
	return ids

## The coop: 0 while it's a ruin, 1 once built (build_coop()), then what
## projects brought it to. The zebu pen: 1 to start with.
func get_building_level(building: String) -> int:
	if building == "coop" and not state.has_coop:
		return 0
	return int(state.building_levels.get(building, BUILDING_START_LEVELS.get(building, 1)))

func get_zebu_capacity() -> int:
	return ZEBU_CAPACITY_BY_LEVEL[clampi(get_building_level("zebu_pen"), 1, ZEBU_CAPACITY_BY_LEVEL.size() - 1)]

func get_manure_max() -> int:
	return MANURE_MAX_BY_LEVEL[clampi(get_building_level("zebu_pen"), 1, MANURE_MAX_BY_LEVEL.size() - 1)]

## The building site under way: {"project", "done_day", "helpers": [ids]},
## {} with none.
func get_construction() -> Dictionary:
	return state.construction

func get_project_state(project_id: String) -> ProjectState:
	var project := get_project(project_id)
	if project == null:
		return ProjectState.LOCKED
	if get_building_level(project.building) >= project.level:
		return ProjectState.DONE
	if state.construction.get("project", "") == project_id:
		return ProjectState.BUILDING
	if get_building_level(project.building) < project.level - 1:
		return ProjectState.LOCKED
	if not state.construction.is_empty():
		return ProjectState.BUSY
	return ProjectState.AVAILABLE

## The friends who'd come and help build (villager ids, the closest first).
func get_project_helpers() -> Array[String]:
	var friends: Array[String] = []
	for villager_id: String in state.friendship:
		if get_hearts(villager_id) >= PROJECT_HELPER_HEARTS:
			friends.append(villager_id)
	friends.sort_custom(func(a, b): return get_friendship(a) > get_friendship(b))
	return friends.slice(0, PROJECT_MAX_HELPERS)

## Days the work would take, starting today, with the friends who'd help.
func get_project_days(project_id: String) -> int:
	var project := get_project(project_id)
	if project == null:
		return 0
	return maxi(project.build_days - get_project_helpers().size(), 1)

func can_start_project(project_id: String) -> bool:
	return get_project_state(project_id) == ProjectState.AVAILABLE \
		and state.money >= get_project(project_id).cost

## Pays and starts the work: finished get_project_days() later, in the
## morning.
func start_project(project_id: String) -> bool:
	if not can_start_project(project_id):
		return false
	var project := get_project(project_id)
	state.money -= project.cost
	money_changed.emit(state.money)
	state.construction = {"project": project_id, "done_day": state.day + get_project_days(project_id),
		"helpers": get_project_helpers()}
	project_started.emit(project_id)
	return true

## Morning: the building site finished today, if any.
func _advance_projects() -> void:
	if state.construction.is_empty() or state.day < int(state.construction["done_day"]):
		return
	var project_id: String = state.construction["project"]
	var project := get_project(project_id)
	state.construction = {}
	if project == null:
		return
	state.building_levels[project.building] = project.level
	if project.building == "coop":
		state.coop_capacity = COOP_CAPACITY_BY_LEVEL[project.level]
	project_completed.emit(project_id)
	zebus_changed.emit()

# --- The kitchen (cooking) ------------------------------------------------------------------

## Registered by KitchenManager (data/recipes/).
func register_recipe(recipe_id: String, recipe: Recipe) -> void:
	_recipes[recipe_id] = recipe

func get_recipe(recipe_id: String) -> Recipe:
	return _recipes.get(recipe_id)

func get_recipe_ids() -> Array:
	var ids := _recipes.keys()
	ids.sort()
	return ids

func has_kitchen() -> bool:
	return get_building_level("kitchen") >= 1

## How many times the recipe can be cooked with what's in the bag.
func get_cookable_count(recipe_id: String) -> int:
	var recipe := get_recipe(recipe_id)
	if recipe == null or recipe.ingredients.is_empty():
		return 0
	var count := 1 << 30
	for item_id: String in recipe.ingredients:
		count = mini(count, state.get_inventory_count(item_id) / int(recipe.ingredients[item_id]))
	return count

func can_cook(recipe_id: String) -> bool:
	return has_kitchen() and get_cookable_count(recipe_id) > 0

## The ingredients out of the bag, the dish in. Returns whether it cooked.
func cook(recipe_id: String) -> bool:
	if not can_cook(recipe_id):
		return false
	var recipe := get_recipe(recipe_id)
	for item_id: String in recipe.ingredients:
		state.add_inventory(item_id, -int(recipe.ingredients[item_id]))
		inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.add_inventory(recipe.result, recipe.quantity)
	inventory_changed.emit(recipe.result, state.get_inventory_count(recipe.result))
	day_log.cooked[recipe_id] = int(day_log.cooked.get(recipe_id, 0)) + recipe.quantity
	discover(CUISINE_PREFIX + recipe_id)
	return true

# --- The notebook (kahie) and the forest ----------------------------------------------------

## A dish's page in the notebook: "cuisine:<recipe id>" - found when first
## cooked.
const CUISINE_PREFIX := "cuisine:"

## Registered by ForestManager (data/discoveries/).
func register_discovery(discovery_id: String, discovery: Discovery) -> void:
	_discoveries[discovery_id] = discovery

func get_discovery(discovery_id: String) -> Discovery:
	return _discoveries.get(discovery_id)

## The notebook's entries: the registered ones, then a page per recipe.
func get_discovery_ids() -> Array:
	var ids := _discoveries.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = _discoveries[a].category
		var cb: int = _discoveries[b].category
		return ca < cb if ca != cb else a < b)
	for recipe_id in get_recipe_ids():
		ids.append(CUISINE_PREFIX + recipe_id)
	return ids

func is_discovered(discovery_id: String) -> bool:
	return state.discoveries.has(discovery_id)

## How many of the notebook's entries are found, out of how many.
func get_notebook_progress() -> Vector2i:
	var ids := get_discovery_ids()
	return Vector2i(ids.filter(func(id): return is_discovered(id)).size(), ids.size())

## A new page in the notebook - false if it was already there, or isn't an
## entry at all.
func discover(discovery_id: String) -> bool:
	var known := _discoveries.has(discovery_id) or (discovery_id.begins_with(CUISINE_PREFIX)
		and _recipes.has(discovery_id.trim_prefix(CUISINE_PREFIX)))
	if not known or is_discovered(discovery_id):
		return false
	state.discoveries[discovery_id] = state.day
	day_log.discoveries.append(discovery_id)
	discovery_made.emit(discovery_id)
	for quest_id: String in get_active_quests():
		_check_quest_discovery(quest_id)
	return true

## Whether the animal (or plant) is about right now: its hours, its season,
## the weather.
func is_wildlife_active(discovery_id: String) -> bool:
	var discovery := get_discovery(discovery_id)
	return discovery != null and discovery.is_active(state.clock.minute_of_day, state.clock.get_season(), is_raining())

## The player watches an animal: its page, if it's about.
func observe(discovery_id: String) -> bool:
	if not is_wildlife_active(discovery_id):
		return false
	discover(discovery_id)
	return true

## A wild plant at `spot_id` (the plant's Discovery: its item, season and
## regrowth): ready in its season, once grown back.
func can_forage(spot_id: String, discovery_id: String) -> bool:
	var plant := get_discovery(discovery_id)
	return plant != null and not plant.item_id.is_empty() and plant.is_in_season(state.clock.get_season()) \
		and state.day >= int(state.forage.get(spot_id, 0))

## Gathers it: the item in the bag, the plant grows back in its
## regrow_days, its page in the notebook. Returns how many were gathered.
func forage(spot_id: String, discovery_id: String) -> int:
	if not can_forage(spot_id, discovery_id):
		return 0
	var plant := get_discovery(discovery_id)
	state.add_inventory(plant.item_id, plant.quantity)
	inventory_changed.emit(plant.item_id, state.get_inventory_count(plant.item_id))
	state.forage[spot_id] = state.day + plant.regrow_days
	day_log.add_harvest(plant.item_id, plant.quantity)
	forage_changed.emit(spot_id)
	discover(discovery_id)
	return plant.quantity

# --- Chicken thieves (mpangalatra akoho) ------------------------------------------------------

## Not in the first weeks: the player has barely started.
const THIEF_FROM_DAY := 15
const THIEF_ALERT_CHANCE := 0.12
## Nights the thieves are about once the rumour starts.
const THIEF_ALERT_NIGHTS := 3
const THIEF_NIGHT_CHANCE := 0.4
## Days after an alert before another can start.
const THIEF_COOLDOWN_DAYS := 12
## Not with fewer hens: the last one is never taken.
const THIEF_MIN_HENS := 2
## Bought, it goes straight on the coop's door (never in the bag).
const PADLOCK_ITEM := "coop_padlock"
## Whose hens went missing, in the morning's rumour.
const THIEF_RUMOUR_NEIGHBOURS := ["naivo", "rakoto", "ravao", "neny_soa"]

## The thieves are about (the nights after the rumour).
func is_thief_alert() -> bool:
	return state.day <= state.thief_alert_until

## Thieves can't get in: the brick coop, or a padlock on the door.
func is_coop_safe() -> bool:
	return get_building_level("coop") >= 3 or state.coop_padlock

func get_hen_ids() -> Array:
	return state.animals.keys().filter(func(id: String) -> bool:
		return (state.animals[id] as AnimalState).species == AnimalData.Species.CHICKEN)

## Whether the shop offers it: the padlock only for a built coop that
## isn't safe yet.
func is_item_on_sale(item_id: String) -> bool:
	if item_id == PADLOCK_ITEM:
		return state.has_coop and not is_coop_safe()
	return true

## Morning (advance_day): the night that just passed, if the thieves were
## about - then maybe a new rumour.
func _advance_thieves() -> void:
	if state.thief_alert_until > 0 and state.day - 1 <= state.thief_alert_until and randf() < thief_night_chance:
		_thieves_come()
	if is_thief_alert() or state.day < THIEF_FROM_DAY or state.day < state.thief_next_alert_day:
		return
	if not state.has_coop or get_hen_ids().size() < THIEF_MIN_HENS or randf() >= thief_alert_chance:
		return
	state.thief_alert_until = state.day + THIEF_ALERT_NIGHTS - 1
	state.thief_next_alert_day = state.thief_alert_until + 1 + THIEF_COOLDOWN_DAYS
	state.thief_rumour = THIEF_RUMOUR_NEIGHBOURS[randi() % THIEF_RUMOUR_NEIGHBOURS.size()]
	day_log.thief_rumour = true
	thief_alert_started.emit(state.thief_rumour)

## A thief at the coop: it holds if it's safe; else a hen is gone (never
## the last). Either way, the thieves move on.
func _thieves_come() -> void:
	var hens := get_hen_ids()
	if hens.size() < THIEF_MIN_HENS:
		return
	state.thief_alert_until = state.day - 1
	if dog_kept_watch():
		day_log.dog_chased_thieves = true
		thieves_chased.emit()
		return
	if is_coop_safe():
		day_log.thieves_foiled = true
		thieves_foiled.emit()
		return
	hens.sort()
	var animal_id: String = hens[randi() % hens.size()]
	state.animals.erase(animal_id)
	state.thief_stolen_day = state.day
	day_log.chicken_stolen = true
	animal_removed.emit(animal_id)
	chicken_stolen.emit(animal_id)

## The padlock goes on the coop's door.
func _secure_coop() -> void:
	state.coop_padlock = true
	coop_secured.emit()

# --- The dog (alika) ------------------------------------------------------------------------

## The puppy's name until the player gives it one.
const DOG_NAMES := ["Tsiky", "Bobaka", "Kintana", "Kely", "Soa", "Tsara", "Mavo", "Rary"]
const DOG_NAME_MAX_LENGTH := 14
## Coats (Dog.COATS).
const DOG_COATS := 4
## A puppy grows into a dog in this many days.
const DOG_GROWN_DAYS := 14
## Days petted, for a heart; and the most there is.
const DOG_BOND_PER_HEART := 4
const DOG_MAX_HEARTS := 5

func has_dog() -> bool:
	return not state.dog.is_empty()

## The puppy comes to the farm. False if there's one already.
func adopt_dog(coat := -1) -> bool:
	if has_dog():
		return false
	state.dog = {
		"name": DOG_NAMES[randi() % DOG_NAMES.size()],
		"coat": coat if coat >= 0 else randi() % DOG_COATS,
		"since": state.day,
		"fed_day": 0,
		"petted_day": 0,
		"bond": 0,
	}
	dog_adopted.emit()
	dog_changed.emit()
	return true

func get_dog_name() -> String:
	return str(state.dog.get("name", ""))

## Named by the player: trimmed, DOG_NAME_MAX_LENGTH at most. False for an
## empty name.
func rename_dog(dog_name: String) -> bool:
	var clean := dog_name.strip_edges().left(DOG_NAME_MAX_LENGTH).strip_edges()
	if not has_dog() or clean.is_empty():
		return false
	state.dog["name"] = clean
	dog_changed.emit()
	return true

func get_dog_coat() -> int:
	return int(state.dog.get("coat", 0))

## 0 (a puppy, the day it came) to 1 (grown, after DOG_GROWN_DAYS).
func get_dog_growth() -> float:
	if not has_dog():
		return 1.0
	return clampf(float(state.day - int(state.dog["since"])) / DOG_GROWN_DAYS, 0.0, 1.0)

## Its bowl filled today: tonight it stays at the farm and keeps watch. The
## family's leftover rice - nothing to buy, a daily care like the zebus'
## trough.
func feed_dog() -> bool:
	if not has_dog() or is_dog_fed():
		return false
	state.dog["fed_day"] = state.day
	dog_changed.emit()
	return true

func is_dog_fed() -> bool:
	return has_dog() and int(state.dog["fed_day"]) == state.day

## Last night (asked in the morning, from advance_day): it had eaten, so it
## stayed and kept watch. Not fed, it went looking for food in the village.
func dog_kept_watch() -> bool:
	return has_dog() and int(state.dog["fed_day"]) == state.day - 1

## Petted: the first time in a day, it grows fonder of the player (true).
func pet_dog() -> bool:
	if not has_dog() or is_dog_petted():
		return false
	state.dog["petted_day"] = state.day
	state.dog["bond"] = mini(int(state.dog["bond"]) + 1, DOG_BOND_PER_HEART * DOG_MAX_HEARTS)
	dog_changed.emit()
	return true

func is_dog_petted() -> bool:
	return has_dog() and int(state.dog["petted_day"]) == state.day

## How fond of the player it is: 0 to DOG_MAX_HEARTS.
func get_dog_hearts() -> int:
	return int(state.dog.get("bond", 0)) / DOG_BOND_PER_HEART

## What a quest's reward_unlock gives the farm.
func _unlock(what: String) -> void:
	match what:
		"dog":
			adopt_dog()
		_:
			push_warning("FarmSimulation: unknown quest unlock '%s'." % what)

# --- Side quests (fangatahana) ------------------------------------------------------------

## Story conditions (get_conditions()) for each side quest: under way, or
## finished - a villager's day can depend on them (VillagerStop.only_if /
## unless).
const QUEST_ACTIVE_PREFIX := "quest_active:"
const QUEST_DONE_PREFIX := "quest_done:"

## Registered by QuestManager (data/quests/).
func register_quest(quest_id: String, quest: Quest) -> void:
	_quests[quest_id] = quest

func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id)

func get_quest_ids() -> Array:
	var ids := _quests.keys()
	ids.sort()
	return ids

func is_quest_active(quest_id: String) -> bool:
	return state.quests.has(quest_id)

func is_quest_done(quest_id: String) -> bool:
	return state.quests_done.has(quest_id)

## Whether its giver offers it now: not taken yet, and its requirements met
## (the day, the giver's friendship, the quests and pages before it, the
## season).
func is_quest_available(quest_id: String) -> bool:
	var quest := get_quest(quest_id)
	if quest == null or quest.steps.is_empty() or is_quest_active(quest_id) or is_quest_done(quest_id):
		return false
	if state.day < quest.min_day or get_hearts(quest.giver) < quest.min_hearts:
		return false
	if not quest.is_in_season(state.clock.get_season()):
		return false
	for before: String in quest.after_quests:
		if not is_quest_done(before):
			return false
	for page: String in quest.after_discoveries:
		if not is_discovered(page):
			return false
	return true

## The quest `villager_id` offers now ("" for none) - the first by id.
func get_quest_offered_by(villager_id: String) -> String:
	for quest_id: String in get_quest_ids():
		if _quests[quest_id].giver == villager_id and is_quest_available(quest_id):
			return quest_id
	return ""

## The quests under way, in the order they were accepted.
func get_active_quests() -> Array:
	var ids := state.quests.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: int = state.quests[a]["since"]
		var db: int = state.quests[b]["since"]
		return da < db if da != db else a < b)
	return ids

## The step the quest is at (null when it isn't under way).
func get_quest_step(quest_id: String) -> QuestStep:
	var quest := get_quest(quest_id)
	if quest == null or not is_quest_active(quest_id):
		return null
	var index: int = state.quests[quest_id]["step"]
	return quest.steps[index] if index < quest.steps.size() else null

func get_quest_step_index(quest_id: String) -> int:
	return int(state.quests[quest_id]["step"]) if is_quest_active(quest_id) else -1

## The current step's items: how many the player has, out of how many
## (Vector2i.ZERO if it takes none).
func get_quest_item_progress(quest_id: String) -> Vector2i:
	var step := get_quest_step(quest_id)
	if step == null or not step.needs_items():
		return Vector2i.ZERO
	return Vector2i(state.get_inventory_count(step.item_id), step.quantity)

## The quest whose current step is with `villager_id` (talk to them, bring
## them something) - "" for none.
func get_quest_waiting_on(villager_id: String) -> String:
	for quest_id: String in get_active_quests():
		var step := get_quest_step(quest_id)
		if step != null and step.kind in [QuestStep.Kind.TALK, QuestStep.Kind.BRING] and step.villager == villager_id:
			return quest_id
	return ""

## The quest whose current step is at the QuestTarget `target_id` ("" for
## none).
func get_quest_at_target(target_id: String) -> String:
	for quest_id: String in get_active_quests():
		var step := get_quest_step(quest_id)
		if step != null and step.kind in [QuestStep.Kind.REACH, QuestStep.Kind.INTERACT] and step.target == target_id:
			return quest_id
	return ""

## Whether the current step can be done now: its items in the bag.
func can_do_quest_step(quest_id: String) -> bool:
	var step := get_quest_step(quest_id)
	if step == null:
		return false
	if step.kind == QuestStep.Kind.DISCOVER:
		return is_discovered(step.discovery_id)
	return not step.needs_items() or state.get_inventory_count(step.item_id) >= step.quantity

## The player accepts it: on to its first step.
func start_quest(quest_id: String) -> bool:
	if not is_quest_available(quest_id):
		return false
	state.quests[quest_id] = {"step": 0, "since": state.day}
	quest_changed.emit(quest_id)
	_check_quest_discovery(quest_id)
	return true

## Talking to `villager_id`: does the step of a quest waiting on them, if
## it can be done (BRING: the items given). Returns the quest ("" for none).
func quest_talk(villager_id: String) -> String:
	var quest_id := get_quest_waiting_on(villager_id)
	if quest_id.is_empty() or not can_do_quest_step(quest_id):
		return ""
	_do_quest_step(quest_id)
	return quest_id

## At the QuestTarget `target_id` (walked into, or used): does the step of
## the quest waiting there, if it can be done (INTERACT: the items used).
## Returns the quest ("" for none).
func quest_trigger(target_id: String) -> String:
	var quest_id := get_quest_at_target(target_id)
	if quest_id.is_empty() or not can_do_quest_step(quest_id):
		return ""
	_do_quest_step(quest_id)
	return quest_id

## A DISCOVER step is done as soon as the page is in the notebook.
func _check_quest_discovery(quest_id: String) -> void:
	var step := get_quest_step(quest_id)
	if step != null and step.kind == QuestStep.Kind.DISCOVER and is_discovered(step.discovery_id):
		_do_quest_step(quest_id)

## The step done (its items taken), on to the next - or, after the last,
## the quest finished and its reward given.
func _do_quest_step(quest_id: String) -> void:
	var quest := get_quest(quest_id)
	var step := get_quest_step(quest_id)
	if step.needs_items():
		state.add_inventory(step.item_id, -step.quantity)
		inventory_changed.emit(step.item_id, state.get_inventory_count(step.item_id))
	var next: int = state.quests[quest_id]["step"] + 1
	if next < quest.steps.size():
		state.quests[quest_id]["step"] = next
		quest_changed.emit(quest_id)
		_check_quest_discovery(quest_id)
		return
	state.quests.erase(quest_id)
	state.quests_done[quest_id] = state.day
	if quest.reward_money > 0:
		state.money += quest.reward_money
		money_changed.emit(state.money)
	for item_id: String in quest.reward_items:
		state.add_inventory(item_id, int(quest.reward_items[item_id]))
		inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	day_log.quests_done.append(quest_id)
	if quest.reward_friendship > 0:
		add_friendship(quest.giver, quest.reward_friendship)
	quest_changed.emit(quest_id)
	quest_completed.emit(quest_id)
	if not quest.reward_unlock.is_empty():
		_unlock(quest.reward_unlock)

# --- Fara's school fees -----------------------------------------------------------------

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
	var rice := get_crop_data(SCHOOL_RICE_ITEM)
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
	state.money -= paid
	state.school_debt -= paid
	day_log.school_paid += paid
	money_changed.emit(state.money)
	school_fees_changed.emit()
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
	state.add_inventory(SCHOOL_RICE_ITEM, -count)
	inventory_changed.emit(SCHOOL_RICE_ITEM, state.get_inventory_count(SCHOOL_RICE_ITEM))
	day_log.school_paid += mini(value, state.school_debt)
	if value > state.school_debt:
		state.money += value - state.school_debt
		money_changed.emit(state.money)
	state.school_debt = maxi(state.school_debt - value, 0)
	school_fees_changed.emit()
	return count

## Story conditions true today (name -> true), for the villagers' steps
## (VillagerStop.only_if / unless).
func get_conditions() -> Dictionary:
	var conditions := {}
	if is_school_fees_overdue():
		conditions[CONDITION_SCHOOL_FEES_OVERDUE] = true
	# Side quests: "quest_active:<id>", "quest_done:<id>".
	for quest_id: String in state.quests:
		conditions[QUEST_ACTIVE_PREFIX + quest_id] = true
	for quest_id: String in state.quests_done:
		conditions[QUEST_DONE_PREFIX + quest_id] = true
	return conditions

## Morning: the bill for the coming season, SCHOOL_NOTICE_DAYS ahead - at
## least SCHOOL_GRACE_DAYS to pay it. An unpaid debt keeps its due day.
func _advance_school_fees() -> void:
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
		school_fees_changed.emit()

# --- Villagers' orders --------------------------------------------------------------

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
	order_changed.emit(villager_id)
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
	var bonus := reward * ORDER_BONUS_PER_HEART * get_hearts(villager_id)
	return reward + roundi(bonus / 100.0) * 100

## Hands the items over. Returns the Ariary earned (0 if it can't be
## delivered). A delivered order brings the villager closer
## (FRIENDSHIP_ORDER).
func deliver_order(villager_id: String) -> int:
	if not can_deliver_order(villager_id):
		return 0
	var order := get_order(villager_id)
	var payment := get_order_payment(villager_id)
	state.add_inventory(order["item"], -order["quantity"])
	inventory_changed.emit(order["item"], state.get_inventory_count(order["item"]))
	state.money += payment
	money_changed.emit(state.money)
	day_log.orders_delivered.append(villager_id)
	_close_order(villager_id)
	add_friendship(villager_id, FRIENDSHIP_ORDER)
	return payment

## Whether the player can have `quantity` of `item_id` within `days`:
## already in the inventory, or growable in time - a crop of this season
## (or of every season), quick enough, in a paddy if it needs one; eggs
## with hens; fruit in season from a tree of theirs.
func can_fulfil(item_id: String, quantity: int, days: int) -> bool:
	if state.get_inventory_count(item_id) >= quantity:
		return true
	var season := state.clock.get_season()
	var crop_data := get_crop_data(item_id)
	if crop_data != null:
		if crop_data.ideal_season != CropData.Season.ALL_YEAR and int(crop_data.ideal_season) != season:
			return false
		if crop_data.growth_days + 1 > days:
			return false
		if crop_data.grows_in_paddy:
			return state.plots.values().any(func(plot: PlotState): return plot.flooded)
		return true
	for animal: AnimalState in state.animals.values():
		var animal_data := get_animal_data(animal.species)
		if animal_data != null and animal_data.product_id == item_id:
			return true
	for tree: TreeState in state.trees.values():
		var tree_data := get_tree_data(tree.tree_type_id)
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
	order_changed.emit(villager_id)
	return true

func _close_order(villager_id: String) -> void:
	state.orders.erase(villager_id)
	state.order_cooldowns[villager_id] = state.day + ORDER_COOLDOWN_DAYS
	order_changed.emit(villager_id)

func _advance_orders() -> void:
	for villager_id: String in state.orders.keys():
		var order: Dictionary = state.orders[villager_id]
		if order["deadline"] >= 0 and order["deadline"] < state.day:
			_close_order(villager_id)
			order_expired.emit(villager_id)
		elif order["deadline"] == -1 and state.day - order["since"] >= ORDER_OFFER_DAYS:
			_close_order(villager_id)
	refresh_order_offers()

# --- The neighbours' paddies -----------------------------------------------------

## Registered by NeighbourPaddyManager when its zone loads.
func register_neighbour_paddy(paddy_id: String, size: Vector2i) -> void:
	_neighbour_paddies[paddy_id] = size

## The CropVisual stage of the neighbours' rice still standing today.
func get_neighbour_rice_stage() -> int:
	var day := state.clock.get_day_of_season()
	var stage := 1
	for from_day: int in NEIGHBOUR_RICE_STAGES:
		if day >= from_day:
			stage = NEIGHBOUR_RICE_STAGES[from_day]
	return stage

## How much of the farmers' harvest is done, 0..1: through the working
## hours of the harvest days.
func get_neighbour_harvest_progress() -> float:
	var day := state.clock.get_day_of_season()
	if day < NEIGHBOUR_HARVEST_FROM_DAY:
		return 0.0
	var hours := NEIGHBOUR_WORK_HOURS
	var today := clampf(float(state.clock.minute_of_day - hours.x) / (hours.y - hours.x), 0.0, 1.0)
	return clampf((day - NEIGHBOUR_HARVEST_FROM_DAY + today) / NEIGHBOUR_HARVEST_DAYS, 0.0, 1.0)

## Harvest time: from its first day until all is cut.
func is_neighbour_harvest_on() -> bool:
	return state.clock.get_day_of_season() >= NEIGHBOUR_HARVEST_FROM_DAY \
			and get_neighbour_harvest_progress() < 1.0

func is_neighbour_tuft_cut(paddy_id: String, cell: Vector2i) -> bool:
	var size: Vector2i = _neighbour_paddies.get(paddy_id, Vector2i.ZERO)
	var order := _harvest_index(size, cell)
	if order < 0:
		return false
	var cut_by_farmers := int(get_neighbour_harvest_progress() * size.x * size.y)
	return order < cut_by_farmers or _player_cut_cells(paddy_id).has(_cell_key(cell))

## The player cuts the tuft at `cell` of a neighbours' paddy. Returns the
## seed rice earned (0 when it can't be cut: not harvest time, already cut,
## not a cell of that paddy).
func help_neighbour_harvest(paddy_id: String, cell: Vector2i) -> int:
	var size: Vector2i = _neighbour_paddies.get(paddy_id, Vector2i.ZERO)
	if not is_neighbour_harvest_on() or _harvest_index(size, cell) < 0 \
			or is_neighbour_tuft_cut(paddy_id, cell):
		return 0
	var season := _season_index()
	var entry: Dictionary = state.neighbour_harvest.get(paddy_id, {})
	if entry.get("season", -1) != season:
		entry = {"season": season, "cells": []}
		state.neighbour_harvest[paddy_id] = entry
	entry["cells"].append(_cell_key(cell))
	state.add_inventory(NEIGHBOUR_HARVEST_REWARD, 1)
	inventory_changed.emit(NEIGHBOUR_HARVEST_REWARD, state.get_inventory_count(NEIGHBOUR_HARVEST_REWARD))
	day_log.neighbour_tufts += 1
	neighbour_paddy_changed.emit(paddy_id)
	return 1

## How many tufts the player cut in that paddy this season.
func get_neighbour_tufts_helped(paddy_id: String) -> int:
	return _player_cut_cells(paddy_id).size()

func _player_cut_cells(paddy_id: String) -> Array:
	var entry: Dictionary = state.neighbour_harvest.get(paddy_id, {})
	return entry.get("cells", []) if entry.get("season", -1) == _season_index() else []

func _season_index() -> int:
	return (state.clock.current_day - 1) / GameClock.DAYS_PER_SEASON

## The order the farmers cut the tufts in - column by column from the west,
## top to bottom - or -1 outside the paddy.
static func _harvest_index(size: Vector2i, cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	return cell.x * size.y + cell.y

static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

## Run before the clock advances, so "in season" means the day that just
## ended. Fruit only grows in season, and whatever is left on the tree when
## the season ends rots - picking is a seasonal rush, not a stockpile.
# --- zebus ---------------------------------------------------------------------

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
	state.money -= ZEBU_PRICE
	money_changed.emit(state.money)
	if coat < 0 or coat >= ZEBU_COATS:
		coat = randi() % ZEBU_COATS
	var zebu_id := "zebu_%d" % state.next_zebu_index
	state.next_zebu_index += 1
	state.zebus[zebu_id] = {"name": _zebu_name(coat), "coat": coat, "grown_days": 0}
	zebus_changed.emit()
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
	state.money += value
	money_changed.emit(state.money)
	zebus_changed.emit()
	return value

## Water and hay for today. False if there's no zebu or it's already full.
func fill_zebu_trough() -> bool:
	if state.zebus.is_empty() or is_zebu_trough_full():
		return false
	state.zebu_trough_full = true
	# The big pen's trough: tomorrow's water and hay too.
	state.zebu_trough_spare = get_building_level("zebu_pen") >= ZEBU_TROUGH_TWO_DAYS_LEVEL
	zebus_changed.emit()
	return true

## Full today - filled by the player, or by the rain.
func is_zebu_trough_full() -> bool:
	return state.zebu_trough_full or is_raining()

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
	return can_till(plot_id) and not get_plot(plot_id).tilled

func can_plough(plot_id: int) -> bool:
	return check_plough() == PloughCheck.OK and is_ploughable(plot_id)

## Tills one plot with the team - FarmingController calls it for each plot
## of the furrow as the team reaches it. False if it can't (anymore).
func plough(plot_id: int) -> bool:
	if not can_plough(plot_id):
		return false
	state.plough_cells_today += 1
	return till(plot_id)

# --- manure ----------------------------------------------------------------------

func get_manure_pile() -> int:
	return state.manure_pile

## Takes the whole heap into the inventory. Returns how much.
func collect_manure() -> int:
	var amount := state.manure_pile
	if amount <= 0:
		return 0
	state.manure_pile = 0
	state.add_inventory(MANURE_ITEM, amount)
	inventory_changed.emit(MANURE_ITEM, state.get_inventory_count(MANURE_ITEM))
	zebus_changed.emit()
	return amount

## Worked soil or a growing crop, not fertilized yet, and manure in hand.
func can_fertilize(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and not plot.fertilized and (plot.tilled or plot.crop != null) \
		and state.get_inventory_count(MANURE_ITEM) > 0

func fertilize(plot_id: int) -> bool:
	if not can_fertilize(plot_id):
		return false
	get_plot(plot_id).fertilized = true
	state.add_inventory(MANURE_ITEM, -1)
	inventory_changed.emit(MANURE_ITEM, state.get_inventory_count(MANURE_ITEM))
	plot_changed.emit(plot_id)
	return true

## The day that ends: a day of growth for each zebu if the trough was full,
## and its manure on the heap; the team is rested.
func _advance_zebus() -> void:
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
	zebus_changed.emit()

func _advance_trees() -> void:
	var season := state.clock.get_season()
	var next_season := state.clock.get_season_on(state.day + 1)
	for tree_id in state.trees:
		var tree: TreeState = state.trees[tree_id]
		var tree_data := get_tree_data(tree.tree_type_id)
		if tree_data == null:
			continue # species removed from the registry - kept as-is in the save
		var before := [tree.fruit_ready, tree.days_growing]
		if tree_data.is_in_season(season) and not tree.fruit_ready:
			tree.days_growing += 1
			if tree.days_growing >= tree_data.fruit_cycle_days:
				tree.fruit_ready = true
		if not tree_data.is_in_season(next_season):
			tree.fruit_ready = false
			tree.days_growing = 0
		if before != [tree.fruit_ready, tree.days_growing]:
			tree_changed.emit(tree_id)

func build_coop() -> bool:
	if state.has_coop or state.money < COOP_COST:
		return false
	state.money -= COOP_COST
	money_changed.emit(state.money)
	state.has_coop = true
	state.coop_capacity = COOP_CAPACITY_BY_LEVEL[1]
	coop_built.emit()
	return true

## Buying doesn't put the animal anywhere yet: it waits (the seller keeps it)
## until the player settles it in the pen of their choice - place_animal().
## Species with no AnimalData registered simply can't be bought yet - fails
## closed rather than crash.
func buy_animal(species: AnimalData.Species, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var animal_data := get_animal_data(species)
	if animal_data == null:
		return false
	var cost := animal_data.purchase_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	state.pending_animals[species] = get_pending_count(species) + quantity
	pending_animals_changed.emit()
	return true

func get_pending_count(species: AnimalData.Species) -> int:
	return state.pending_animals.get(species, 0)

## Whether place_animal(species) would succeed, and if not, why.
func check_place_animal(species: AnimalData.Species) -> PlaceCheck:
	if not state.has_coop:
		return PlaceCheck.NO_BUILDING
	if get_pending_count(species) <= 0:
		return PlaceCheck.NONE_WAITING
	if state.animals.size() >= state.coop_capacity:
		return PlaceCheck.FULL
	return PlaceCheck.OK

## Settles one waiting animal of this species in the coop. Returns the new
## animal's id, or "" if it couldn't be settled (see check_place_animal()).
func place_animal(species: AnimalData.Species) -> String:
	if check_place_animal(species) != PlaceCheck.OK:
		return ""
	state.pending_animals[species] -= 1
	if state.pending_animals[species] <= 0:
		state.pending_animals.erase(species)
	pending_animals_changed.emit()
	var animal_id := state.generate_animal_id(species)
	state.animals[animal_id] = AnimalState.new(animal_id, species)
	animal_added.emit(animal_id)
	return animal_id

## Thin chicken-specific wrappers over buy_animal()/place_animal() - every
## current call site (Coop.gd, the shop) only ever deals in chickens, and
## these keep that call surface unchanged.
func buy_chicken(quantity: int = 1) -> bool:
	return buy_animal(AnimalData.Species.CHICKEN, quantity)

func place_chicken() -> String:
	return place_animal(AnimalData.Species.CHICKEN)

## Called by the world-layer Egg pickup once the player actually walks over
## it - product_ready only announces that an egg is ready to spawn, it never
## touches inventory itself (FarmSimulation never touches Node2D/pickups).
func collect_product(product_id: String, quantity: int = 1) -> void:
	day_log.add_product(product_id, quantity)
	state.add_inventory(product_id, quantity)
	inventory_changed.emit(product_id, state.get_inventory_count(product_id))

func feed_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.fed_today:
		return false
	animal.hunger = 100.0
	animal.fed_today = true
	animal_changed.emit(animal_id)
	return true

func water_animal(animal_id: String) -> bool:
	var animal: AnimalState = state.animals.get(animal_id)
	if animal == null or animal.watered_today:
		return false
	animal.thirst = 100.0
	animal.watered_today = true
	animal_changed.emit(animal_id)
	return true

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := get_crop_data(crop_id)
	if crop_data == null:
		return false
	if state.day < crop_data.unlock_day:
		return false
	var cost := crop_data.seed_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	var seed_key := crop_id + "_seed"
	state.add_inventory(seed_key, quantity)
	inventory_changed.emit(seed_key, state.get_inventory_count(seed_key))
	return true

## Generic purchase path for shop items that aren't crops (tools/food/animals):
## unlike buy_seed(), the caller supplies the price since these items have no
## entry in _crop_registry.
func buy_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0 or not is_item_on_sale(item_id):
		return false
	if item_id == PADLOCK_ITEM:
		if state.money < unit_price:
			return false
		state.money -= unit_price
		money_changed.emit(state.money)
		_secure_coop()
		return true
	var cost := unit_price * quantity
	if state.money < cost:
		return false
	state.money -= cost
	money_changed.emit(state.money)
	state.add_inventory(item_id, quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	return true

## `price_multiplier`: what the shop pays on top of the crop's sell_price
## (ShopProfile.sell_multiplier - the weekly market pays more).
func sell(item_id: String, quantity: int = 1, price_multiplier: float = 1.0) -> bool:
	if quantity <= 0 or price_multiplier <= 0.0:
		return false
	var crop_data := get_crop_data(item_id)
	if crop_data == null:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	state.add_inventory(item_id, -quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.money += roundi(crop_data.sell_price * price_multiplier) * quantity
	money_changed.emit(state.money)
	return true

## Generic sell path for non-crop products (eggs, and future animal
## products): symmetric to buy_item() - the caller supplies the unit price
## since these items have no entry in _crop_registry.
func sell_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	state.add_inventory(item_id, -quantity)
	inventory_changed.emit(item_id, state.get_inventory_count(item_id))
	state.money += unit_price * quantity
	money_changed.emit(state.money)
	return true

## Generic money-spending primitive for systems (like FarmLandManager) that need
## to charge the player without being a crop/animal/shop-item purchase.
## Centralizing it here keeps FarmSimulation the single place that mutates
## money and emits money_changed.
func spend_money(amount: int) -> bool:
	if amount < 0 or state.money < amount:
		return false
	state.money -= amount
	money_changed.emit(state.money)
	return true

func to_save_data() -> Dictionary:
	return state.to_dict()

## Restores state in-place and re-emits every signal so the presentation layer redraws itself.
func load_save_data(data: Dictionary) -> void:
	state.load_dict(data)
	day_log = DayLog.new()
	_last_money = state.money
	_normalize_hotbar()
	state_loaded.emit()
	hotbar_changed.emit()
	pending_animals_changed.emit()
	zebus_changed.emit()
	school_fees_changed.emit()
	rooster_changed.emit()
	cockfight_changed.emit()

	var bounds := state.get_grid_bounds()
	grid_width = bounds.size.x
	grid_height = bounds.size.y

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

# --- Hotbar layout -----------------------------------------------------------
# Which item sits in which of the HOTBAR_SIZE slots. The rules that always
# hold - enforced here, whoever changes the bar: exactly HOTBAR_SIZE slots,
# only items the player owns, never the same item twice. *Which* items are
# worth putting there, and selection/controls, are Hotbar's business.

func get_hotbar_item(index: int) -> String:
	if index < 0 or index >= state.hotbar.size():
		return ""
	return state.hotbar[index]

func find_in_hotbar(item_id: String) -> int:
	return state.hotbar.find(item_id) if item_id != "" else -1

func is_hotbar_initialized() -> bool:
	return not state.hotbar.is_empty()

## First layout of a new game (or a save from before the hotbar): the owned
## items of `item_ids`, in order. Does nothing once the bar has a layout.
func init_hotbar(item_ids: Array) -> void:
	if is_hotbar_initialized():
		return
	for item_id in item_ids:
		if state.hotbar.size() < FarmState.HOTBAR_SIZE and state.get_inventory_count(item_id) > 0 and not item_id in state.hotbar:
			state.hotbar.append(item_id)
	state.hotbar.resize(FarmState.HOTBAR_SIZE)
	_normalize_hotbar()
	hotbar_changed.emit()

## Puts an owned item in slot `index`. If it was already in another slot the
## two slots swap; otherwise whatever was in `index` leaves the bar (it stays
## in the inventory). Returns whether the bar changed.
func place_in_hotbar(item_id: String, index: int) -> bool:
	if not is_hotbar_initialized() or index < 0 or index >= FarmState.HOTBAR_SIZE:
		return false
	if state.get_inventory_count(item_id) <= 0:
		return false
	var previous := find_in_hotbar(item_id)
	if previous == index:
		return false
	if previous != -1:
		state.hotbar[previous] = state.hotbar[index]
	state.hotbar[index] = item_id
	hotbar_changed.emit()
	return true

## Takes an item out of the bar (it stays in the inventory).
func remove_from_hotbar(item_id: String) -> bool:
	var index := find_in_hotbar(item_id)
	if index == -1:
		return false
	state.hotbar[index] = ""
	hotbar_changed.emit()
	return true

## Every change of money goes through money_changed: what came in or went
## out today, whatever the cause.
func _on_money_changed(money: int) -> void:
	day_log.add_money(money - _last_money)
	_last_money = money

# --- Tomorrow (the evening meal's plans) --------------------------------------------------

## Crops that will be ripe tomorrow morning: growing, watered today (or in a
## paddy), one day short. crop_id -> plots.
func get_ripening_tomorrow() -> Dictionary:
	var ripening := {}
	for plot: PlotState in state.plots.values():
		var crop := plot.crop
		if crop != null and not crop.is_mature() and (plot.watered or plot.flooded) and crop.age + 1 >= crop.growth_days:
			ripening[crop.crop_id] = int(ripening.get(crop.crop_id, 0)) + 1
	return ripening

## Growing crops not watered today: they won't grow tonight.
func get_unwatered_plots() -> int:
	return state.plots.values().filter(func(plot: PlotState) -> bool:
		return plot.crop != null and not plot.crop.is_mature() and not plot.watered and not plot.flooded).size()

## Accepted orders whose last day is tomorrow.
func get_orders_due_tomorrow() -> Array[String]:
	var due: Array[String] = []
	for villager_id in get_active_orders():
		if get_order_days_left(villager_id) == 2:
			due.append(villager_id)
	return due

func _on_inventory_changed(item_id: String, count: int) -> void:
	if count <= 0:
		remove_from_hotbar(item_id)

## Brings a loaded/initialized layout back within the rules above.
func _normalize_hotbar() -> void:
	if not is_hotbar_initialized():
		return
	state.hotbar.resize(FarmState.HOTBAR_SIZE)
	var seen := {}
	for i in FarmState.HOTBAR_SIZE:
		var item_id = state.hotbar[i]
		if item_id == null or seen.has(item_id) or state.get_inventory_count(str(item_id)) <= 0:
			state.hotbar[i] = ""
		else:
			seen[item_id] = true

