class_name ZebuMarket
extends Node2D

## The zebu dealer's stand, by the corral of the market town: open on market days
## (its ShopProfile's days and hours), it asks for the zebu market window
## (ZebuManager opens ZebuMarketPanel); closed, it says when to come back.
## Group "zebu_markets": ZebuManager finds it when the zone loads.

signal requested

const GROUP := "zebu_markets"

## Opening days and hours, title, closed message (only those are used).
@export var profile: ShopProfile

@onready var _interactable: InteractableComponent = $InteractableComponent

var _weekday := GameClock.Weekday.MONDAY
var _minute := GameClock.DAY_START_MINUTE

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DayNightController.CLOCK_GROUP)
	add_to_group(DayNightController.CALENDAR_GROUP)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var box := RectangleShape2D.new()
	box.size = Vector2(120, 80)
	area.shape = box
	area.position = Vector2(0, -20)
	_interactable.interacted.connect(_on_interacted)
	_refresh_prompt()

func set_time_of_day(minute_of_day: int) -> void:
	var was_open := is_open()
	_minute = minute_of_day
	if is_open() != was_open:
		_refresh_prompt()

func set_weekday(weekday: int) -> void:
	_weekday = weekday as GameClock.Weekday
	_refresh_prompt()

func is_open() -> bool:
	return profile != null and profile.is_open(_weekday, _minute)

func _refresh_prompt() -> void:
	_interactable.prompt_message = "Acheter et vendre des zébus" if is_open() else "Fermé"

func _on_interacted() -> void:
	if is_open():
		requested.emit()
	elif profile != null and not profile.closed_message.is_empty():
		UIEvents.notify(tr(profile.closed_message))
