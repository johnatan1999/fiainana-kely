class_name RoosterPanel
extends Control

## Caring for the player's fighting rooster, at its stake on the farm: its
## force and endurance, today's care (a grain, a training), the season's
## ranking and when the next tournament is. Only shows what
## CockfightManager hands it and says what the player asked for (signals) -
## the rules are FarmSimulation's. Pauses the game while open. Built in code.

signal feed_requested(item_id: String)
signal train_requested

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const NOTE_COLOR := Color(0.6, 0.3, 0.15)
const DONE_COLOR := Color(0.2, 0.45, 0.15)
const WIDTH := 460.0
const PORTRAIT_SIZE := 96.0

var _title: Label
var _portrait: TextureRect
var _force: ProgressBar
var _force_label: Label
var _endurance: ProgressBar
var _endurance_label: Label
var _power: Label
var _care: Label
var _feed_buttons: HBoxContainer
var _train: Button
var _ranking: CockfightRankingList
var _note: Label
var _close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `rooster`: {"name", "portrait" (Texture2D), "force", "endurance", "max",
## "power", "fed", "trained", "feeds": [{"item_id", "name", "count",
## "enabled"}], "can_train"}. `ranking`: see CockfightRankingList. Opens the
## panel, or refreshes it if already open.
func show_rooster(rooster: Dictionary, ranking: Array, note: String) -> void:
	_title.text = rooster["name"]
	_portrait.texture = rooster["portrait"]
	_force.max_value = rooster["max"]
	_force.value = rooster["force"]
	_force_label.text = tr("Force : %d/%d") % [rooster["force"], rooster["max"]]
	_endurance.max_value = rooster["max"]
	_endurance.value = rooster["endurance"]
	_endurance_label.text = tr("Endurance : %d/%d") % [rooster["endurance"], rooster["max"]]
	_power.text = tr("Puissance : %d") % rooster["power"]
	var fed := tr("nourri ✓") if rooster["fed"] else tr("pas encore nourri")
	var trained := tr("entraîné ✓") if rooster["trained"] else tr("pas encore entraîné")
	_care.text = tr("Aujourd'hui : %s, %s.") % [fed, trained]
	_care.add_theme_color_override("font_color", DONE_COLOR if rooster["fed"] and rooster["trained"] else TEXT_COLOR)
	for child in _feed_buttons.get_children():
		_feed_buttons.remove_child(child)
		child.queue_free()
	var first_enabled: Button = null
	for feed: Dictionary in rooster["feeds"]:
		var button := _button(_feed_buttons, tr("Donner 1 %s (%d)") % [feed["name"], feed["count"]])
		button.disabled = not feed["enabled"]
		var item_id: String = feed["item_id"]
		button.pressed.connect(func(): feed_requested.emit(item_id))
		if first_enabled == null and not button.disabled:
			first_enabled = button
	_train.disabled = not rooster["can_train"]
	_ranking.show_ranking(ranking)
	_note.text = note
	_note.visible = not note.is_empty()
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()
	if first_enabled != null:
		first_enabled.grab_focus()
	elif not _train.disabled:
		_train.grab_focus()
	else:
		_close.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = _label(box, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(box, 14)
	subtitle.text = tr("Ton coq de combat (akoho gasy)")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_portrait)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(stats)
	_force_label = _label(stats, 15)
	_force = _bar(stats, Color(0.75, 0.3, 0.2))
	_endurance_label = _label(stats, 15)
	_endurance = _bar(stats, Color(0.3, 0.55, 0.3))
	_power = _label(stats, 16)

	_care = _label(box, 15)
	_care.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(box, 13)
	hint.text = tr("Un grain par jour le fait grandir ; nourri et entraîné, il gagne aussi en force.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH - 36, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feed_buttons = HBoxContainer.new()
	_feed_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_feed_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_feed_buttons)
	_train = _button(box, tr("Entraîner"))
	_train.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_train.pressed.connect(func(): train_requested.emit())

	box.add_child(HSeparator.new())
	var ranking_title := _label(box, 16)
	ranking_title.text = tr("Classement de la saison")
	_ranking = CockfightRankingList.new()
	box.add_child(_ranking)
	_note = _label(box, 14)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH - 36, 0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	_close = _button(box, tr("Fermer"))
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	return style

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.15)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	parent.add_child(bar)
	return bar

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 34)
	parent.add_child(button)
	return button
