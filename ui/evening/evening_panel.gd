class_name EveningPanel
extends Control

## The evening meal, around the family's mat by the light of the oil lamp:
## the day's dish in its bowl, then what the family says about the day and
## tomorrow - one line after the other, each with the speaker's portrait,
## as a conversation (any key shows them all) - and, small, the money in
## and out. "Pas encore" goes back to the evening (water a plot left dry);
## "Dormir" sleeps. Only shows what EveningManager hands it. Pauses the
## game. Built in code.

signal sleep_confirmed
signal cancelled

const NIGHT_SHADE := Color(0.03, 0.02, 0.05, 0.7)
const PANEL_COLOR := Color(0.16, 0.1, 0.06, 0.97)
const BORDER_COLOR := Color(0.55, 0.36, 0.18)
const MAT_COLOR := Color(0.62, 0.5, 0.3)
const MAT_WEAVE := Color(0.5, 0.39, 0.22)
const TITLE_COLOR := Color(1.0, 0.84, 0.5)
const TEXT_COLOR := Color(0.95, 0.9, 0.8)
const NAME_COLOR := Color(1.0, 0.75, 0.42)
const MUTED_COLOR := Color(0.75, 0.66, 0.55)
const LAMP_COLOR := Color(1.0, 0.7, 0.35)
const WIDTH := 560.0
const PORTRAIT_SIZE := 44.0
## A line every this many seconds, as people speak.
const LINE_EVERY := 0.55

var _date: Label
var _dish: Label
var _lines: VBoxContainer
var _money: Label
var _sleep: Button
var _not_yet: Button
var _reveal: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `lines`: [{"name", "portrait" (Texture2D or null), "text"}], said in order.
func open(date: String, dish: String, lines: Array, earned: int, spent: int) -> void:
	_date.text = date
	_dish.text = dish
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line: Dictionary in lines:
		_add_line(line)
	var money := []
	if earned > 0:
		money.append("+%s" % Currency.format(earned))
	if spent > 0:
		money.append("−%s" % Currency.format(spent))
	_money.text = " · ".join(money)
	_money.visible = not money.is_empty()
	visible = true
	get_tree().paused = true
	AudioManager.play_click_menu_sfx()
	_sleep.grab_focus()
	# One after the other, as people speak.
	if _reveal != null:
		_reveal.kill()
	_reveal = create_tween()
	for row in _lines.get_children():
		row.modulate.a = 0.0
		_reveal.tween_interval(LINE_EVERY)
		_reveal.tween_property(row, "modulate:a", 1.0, 0.3)

## Every line at once (any key while they're coming).
func show_all() -> void:
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	for row in _lines.get_children():
		row.modulate.a = 1.0

func is_revealing() -> bool:
	return _reveal != null and _reveal.is_running()

func close() -> void:
	show_all()
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		cancelled.emit()
		get_viewport().set_input_as_handled()
	elif is_revealing() and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		show_all()
		get_viewport().set_input_as_handled()

func _add_line(line: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_lines.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = line["portrait"]
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_label(words, line["name"], 14, NAME_COLOR)
	var text := _label(words, "« %s »" % line["text"], 16, TEXT_COLOR)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - PORTRAIT_SIZE - 60, 0)

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = NIGHT_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	# The lamp's warm light on the mat, the dish in its bowl.
	var header := _MatHeader.new()
	header.custom_minimum_size = Vector2(0, 92)
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var title := _label(titles, "Sakafo hariva", 28, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_date = _label(titles, "", 14, MUTED_COLOR)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dish = _label(box, "", 15, TITLE_COLOR)
	_dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dish.custom_minimum_size = Vector2(WIDTH - 40, 0)

	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 10)
	box.add_child(_lines)
	_money = _label(box, "", 14, MUTED_COLOR)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_not_yet = _button(buttons, tr("Pas encore"))
	_not_yet.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		close()
		cancelled.emit())
	_sleep = _button(buttons, tr("Dormir"))
	_sleep.pressed.connect(func():
		close()
		sleep_confirmed.emit())

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 38)
	parent.add_child(button)
	return button

## The header: a woven mat (tsihy) under the lamp's glow, the rice bowl at
## its middle - drawn in code.
class _MatHeader extends Control:
	var _t := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		clip_contents = true

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var flicker := 1.0 + 0.05 * sin(_t * 7.0) + 0.03 * sin(_t * 17.0)
		# The lamp's glow.
		for i in 6:
			var radius := (size.x * 0.45) * (1.0 - i / 6.0) * flicker
			draw_circle(Vector2(size.x / 2.0, size.y * 0.35), radius, Color(EveningPanel.LAMP_COLOR, 0.035 + i * 0.012))
		# The mat, woven.
		var mat := Rect2(size.x * 0.12, size.y * 0.72, size.x * 0.76, size.y * 0.24)
		draw_rect(mat, EveningPanel.MAT_COLOR)
		var x := mat.position.x
		while x < mat.end.x:
			draw_line(Vector2(x, mat.position.y), Vector2(x + 6, mat.end.y), EveningPanel.MAT_WEAVE, 1.5)
			x += 9.0
		# The bowl of rice on it.
		var bowl := Vector2(size.x * 0.8, mat.position.y + 4)
		draw_circle(bowl + Vector2(0, -6), 9.0, Color(0.97, 0.95, 0.88))
		var points := PackedVector2Array()
		for i in 13:
			var angle := PI * i / 12.0
			points.append(bowl + Vector2(cos(angle) * 15.0, sin(angle) * 10.0 - 4.0))
		draw_colored_polygon(points, Color(0.45, 0.27, 0.15))
