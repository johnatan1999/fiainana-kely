class_name GameClock
extends RefCounted

## Two-season Malagasy agricultural calendar: Asara (hot/rainy) and Asotry
## (cool/dry), alternating every DAYS_PER_SEASON days.
enum Season { RAINY, DRY }
const DAYS_PER_SEASON := 30
## The Malagasy week; day 1 of the game is an Alatsinainy (Monday).
enum Weekday { MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY }
const WEEKDAY_NAMES: Array[String] = [
	"Alatsinainy", "Talata", "Alarobia", "Alakamisy", "Zoma", "Sabotsy", "Alahady",
]
## Market day: the weekly market in the market town is on Fridays.
const MARKET_DAY := Weekday.FRIDAY
## Every day starts at 6:00 - waking up.
const DAY_START_MINUTE := 6 * 60
## Time stops at 2:00 (the night after): the night goes on until the player
## sleeps - no forced faint, the cost of staying up is the dark.
const LATEST_MINUTE := 26 * 60

var current_day: int = 1
## Minutes since midnight of current_day: past 24:00 (1440) means the small
## hours of the night after, still the same day until the player sleeps.
var minute_of_day: int = DAY_START_MINUTE

func advance_day() -> void:
	current_day += 1
	minute_of_day = DAY_START_MINUTE

## Returns whether the time actually moved (it doesn't past LATEST_MINUTE).
func advance_minutes(minutes: int) -> bool:
	var before := minute_of_day
	minute_of_day = mini(minute_of_day + maxi(minutes, 0), LATEST_MINUTE)
	return minute_of_day != before

## 0..23, as shown on a clock.
func get_hour() -> int:
	return (minute_of_day / 60) % 24

func get_minute() -> int:
	return minute_of_day % 60

func get_season() -> Season:
	return get_season_on(current_day)

func get_season_on(day: int) -> Season:
	return Season.DRY if ((day - 1) / DAYS_PER_SEASON) % 2 == 1 else Season.RAINY

## 1..DAYS_PER_SEASON - the date players plan around ("Asara, day 9").
func get_day_of_season() -> int:
	return (current_day - 1) % DAYS_PER_SEASON + 1

## Days left in the current season after today (0 on its last day).
func get_days_left_in_season() -> int:
	return DAYS_PER_SEASON - get_day_of_season()

func get_weekday() -> Weekday:
	return get_weekday_on(current_day)

static func get_weekday_on(day: int) -> Weekday:
	return posmod(day - 1, WEEKDAY_NAMES.size()) as Weekday

static func get_weekday_name(weekday: Weekday) -> String:
	return WEEKDAY_NAMES[weekday]

func is_market_day() -> bool:
	return get_weekday() == MARKET_DAY

## Days from today to the next market day (0 = today).
func days_to_market() -> int:
	return posmod(MARKET_DAY - get_weekday(), WEEKDAY_NAMES.size())

## 1-based; a year is one Asara plus one Asotry.
func get_year() -> int:
	return (current_day - 1) / (DAYS_PER_SEASON * Season.size()) + 1
