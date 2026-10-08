class_name Shop extends StaticBody2D

## A stall the player buys and sells at: interacting opens the one ShopUI
## (UIEvents.shop_requested) with this shop's ShopProfile - its shelves, its
## prices, its opening days and hours. Closed, it says when to come back
## instead. Keeps the clock and the weekday (DayNightController groups) to
## know.

const DEFAULT_PROFILE := preload("res://data/shops/village_shop.tres")

## Empty = the village grocery's profile.
@export var profile: ShopProfile
## Size of the area the player can interact from, standing at the front;
## zero = the one in the scene. Set in code: an instanced
## InteractableComponent's shape override isn't kept by generated scenes.
@export var reach := Vector2.ZERO

@onready var interactable_component: InteractableComponent = $InteractableComponent

var _weekday := GameClock.Weekday.ALATSINAINY
var _minute := GameClock.DAY_START_MINUTE

func _ready() -> void:
	if profile == null:
		profile = DEFAULT_PROFILE
	add_to_group(DayNightController.CLOCK_GROUP)
	add_to_group(DayNightController.CALENDAR_GROUP)
	interactable_component.interacted.connect(_on_interacted)
	if reach != Vector2.ZERO:
		var area: CollisionShape2D = interactable_component.get_node("InteractableCollision2D")
		var box := RectangleShape2D.new()
		box.size = reach
		area.shape = box
		area.position = Vector2(0, -reach.y / 2.0 + 20.0)
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
	return profile.is_open(_weekday, _minute)

func _refresh_prompt() -> void:
	interactable_component.prompt_message = "Acheter et vendre" if is_open() else "Fermé"

func _on_interacted() -> void:
	if is_open():
		UIEvents.shop_requested.emit(self)
	elif not profile.closed_message.is_empty():
		UIEvents.notify(tr(profile.closed_message))
