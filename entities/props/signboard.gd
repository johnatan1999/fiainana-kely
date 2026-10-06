@tool
class_name Signboard
extends Prop

## A wooden signboard with a word painted on it ("SEKOLY", "HOTELY"...):
## the board is the prop's art, the text a Label made in code, centered on
## the board. @tool: the text shows in the editor too.

## The board's center, from the prop's origin (its feet) - matches the art.
const BOARD_CENTER := Vector2(0, -40)
const TEXT_COLOR := Color(0.25, 0.13, 0.05)

@export var text := "":
	set(value):
		text = value
		if _label != null:
			_label.text = value

var _label: Label

func _ready() -> void:
	super()
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.font_color = TEXT_COLOR
	_label.label_settings = settings
	_label.size = Vector2(70, 22)
	_label.position = BOARD_CENTER - _label.size / 2.0
	add_child(_label)
