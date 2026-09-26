class_name PlotHighlight
extends Node2D

## A gently pulsing outline showing which plot a farming action (till/water/
## plant/harvest) will affect if the player interacts right now - the tile
## in front of the player, see FarmView.get_plot_id_in_front_of().
## Purely visual: FarmView owns and positions it, FarmingController just
## drives visibility/position every frame from the player's position.
## White when a button would do something there, red when neither would
## (e.g. watering an empty plot with nothing to harvest). A small hand in the
## corner means "interact" harvests it - whatever item is held.

const SIZE := PlotView.CELL_SIZE
const MARGIN := 1.0
const BORDER_WIDTH := 2.0
const VALID_COLOR := Color(1.0, 1.0, 1.0)
const INVALID_COLOR := Color(1.0, 0.3, 0.25)
const PULSE_SPEED := 4.0
const PULSE_MIN_ALPHA := 0.55
const PULSE_MAX_ALPHA := 0.9
## Hand badge (top-right corner of the cell), drawn in code like the other
## placeholder pictograms until there's icon art for it.
const HAND_BADGE_RADIUS := 8.0
const HAND_BADGE_COLOR := Color(0.2, 0.12, 0.06, 0.85)
const HAND_COLOR := Color(1.0, 0.9, 0.75)

var _pulse_time := 0.0

var can_act := true:
	set(value):
		if value == can_act:
			return
		can_act = value
		queue_redraw()

var show_hand := false:
	set(value):
		if value == show_hand:
			return
		show_hand = value
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
	if show_hand:
		_draw_hand_badge(Vector2(SIZE - HAND_BADGE_RADIUS - 2.0, HAND_BADGE_RADIUS + 2.0))

## An open hand: palm, four fingers, thumb - on a dark disc for contrast.
func _draw_hand_badge(center: Vector2) -> void:
	draw_circle(center, HAND_BADGE_RADIUS, HAND_BADGE_COLOR)
	var palm := center + Vector2(0.4, 1.8)
	draw_circle(palm, 2.8, HAND_COLOR)
	for i in 4:
		var x := palm.x - 2.1 + i * 1.45
		draw_line(Vector2(x, palm.y - 1.0), Vector2(x, palm.y - 5.2 + absf(i - 1.5) * 0.7), HAND_COLOR, 1.2)
	draw_line(palm + Vector2(-2.2, 0.4), palm + Vector2(-4.4, -2.0), HAND_COLOR, 1.2)
