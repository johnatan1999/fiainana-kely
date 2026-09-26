class_name Toast
extends PanelContainer

## One short message at the top of the screen - "New animal! Go to the
## coop...", "Coop full (6/6)" - from UIEvents.notify(). A newer message
## replaces the one on screen instead of queueing: they answer what the
## player just did, and an old answer is worth less than the latest.
## Keeps running under menus (bought from the shop, which pauses the game).

const SHOW_TIME := 3.5
const FADE_TIME := 0.25
const SLIDE := 8.0

@onready var label: Label = %Label

var _tween: Tween
var _rest_y := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest_y = position.y
	modulate.a = 0.0
	visible = false
	UIEvents.notification_requested.connect(show_message)

func show_message(text: String) -> void:
	label.text = text
	visible = true
	reset_size()
	# Centered on the screen's width, whatever the text's length.
	position.x = (get_viewport_rect().size.x - size.x) / 2.0
	if _tween:
		_tween.kill()
	position.y = _rest_y - SLIDE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_property(self, "position:y", _rest_y, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(SHOW_TIME)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.chain().tween_callback(func(): visible = false)
