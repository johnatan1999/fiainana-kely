class_name PlotHighlight
extends Node2D

## A gently pulsing outline showing which plot a farming action (till/water/
## plant/harvest) will affect if the player interacts right now - the tile
## in front of the player, see FarmView.get_plot_id_in_front_of().
## Purely visual: FarmView owns and positions it, FarmingController just
## drives visibility/position every frame from the player's position.
## White when the current tool can act on that plot, red when pressing E
## would do nothing (e.g. watering an empty plot, harvesting an unripe crop).

const SIZE := PlotView.CELL_SIZE
const MARGIN := 1.0
const BORDER_WIDTH := 2.0
const VALID_COLOR := Color(1.0, 1.0, 1.0)
const INVALID_COLOR := Color(1.0, 0.3, 0.25)
const PULSE_SPEED := 4.0
const PULSE_MIN_ALPHA := 0.55
const PULSE_MAX_ALPHA := 0.9

var _pulse_time := 0.0

var can_act := true:
	set(value):
		if value == can_act:
			return
		can_act = value
		queue_redraw()

func _ready() -> void:
	z_index = 10 # always above plot crops, regardless of add order

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var alpha := lerpf(PULSE_MIN_ALPHA, PULSE_MAX_ALPHA, (sin(_pulse_time * PULSE_SPEED) + 1.0) / 2.0)
	var color := VALID_COLOR if can_act else INVALID_COLOR
	color.a = alpha
	draw_rect(Rect2(MARGIN, MARGIN, SIZE - MARGIN * 2.0, SIZE - MARGIN * 2.0), color, false, BORDER_WIDTH)
