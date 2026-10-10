class_name FamilyProjectsPanel
extends Control

## The family's projects, as Dada shows them: building by building, its
## level and each project - what it's called (in Malagasy too), what it
## brings, what it costs, how many days of work (and which friends will
## come to help), and where it stands: to start, under way, done, not yet.
## Only shows what FamilyProjectManager hands it and says what the player
## asked for (`start_requested`). Pauses the game. Built in code.

signal start_requested(project_id: String)

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const CARD_COLOR := Color(0.99, 0.95, 0.85)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const MUTED_COLOR := Color(0.5, 0.38, 0.26)
const DONE_COLOR := Color(0.2, 0.45, 0.15)
const BUSY_COLOR := Color(0.6, 0.3, 0.15)
const WIDTH := 600.0
## The projects' list, scrolling past this height.
const LIST_HEIGHT := 400.0

var _line: Label
var _sections: VBoxContainer
var _close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `line`: what Dada says. `sections`: [{"title", "projects": [{"id",
## "name", "malagasy", "description", "cost", "days", "helpers" (text),
## "button" (it can be started: a button, greyed unless "can_start"),
## "status" (text: under the button, or instead of it), "status_color"}]}].
## Opens the panel, or refreshes it if already open.
func show_projects(line: String, sections: Array) -> void:
	_line.text = "Dada : « %s »" % line
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	var first: Button = null
	for section: Dictionary in sections:
		_label(_sections, section["title"], 17, TEXT_COLOR)
		for project: Dictionary in section["projects"]:
			var button := _add_card(project)
			if first == null and button != null and not button.disabled:
				first = button
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()
	(first if first != null else _close).grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _add_card(project: Dictionary) -> Button:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	_sections.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	_label(texts, "%s · %s" % [project["name"], project["malagasy"]], 16, TEXT_COLOR)
	var description := _label(texts, project["description"], 13, MUTED_COLOR)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(WIDTH - 260, 0)
	var details := tr("%s · %d jour(s) de travaux") % [Currency.format(project["cost"]), project["days"]]
	_label(texts, details, 13, TEXT_COLOR)
	if not project["helpers"].is_empty():
		var helpers := _label(texts, project["helpers"], 12, DONE_COLOR)
		helpers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		helpers.custom_minimum_size = Vector2(WIDTH - 260, 0)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	if project["button"]:
		var button := Button.new()
		button.text = tr("Lancer les travaux")
		button.custom_minimum_size = Vector2(170, 36)
		button.disabled = not project["can_start"]
		var project_id: String = project["id"]
		button.pressed.connect(func(): start_requested.emit(project_id))
		side.add_child(button)
		if not project["status"].is_empty():
			var note := _label(side, project["status"], 12, project["status_color"])
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return button
	var status := _label(side, project["status"], 14, project["status_color"])
	status.custom_minimum_size = Vector2(170, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return null

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
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
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := _label(box, tr("Projets de la famille"), 22, TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line = _label(box, "", 14, MUTED_COLOR)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(WIDTH - 36, 0)
	box.add_child(HSeparator.new())
	# Four buildings and their projects don't fit a screen: they scroll.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH - 36, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 6)
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sections)
	_close = Button.new()
	_close.text = tr("Fermer")
	_close.custom_minimum_size = Vector2(150, 36)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	box.add_child(_close)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
