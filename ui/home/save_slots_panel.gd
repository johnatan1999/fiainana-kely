class_name SaveSlotsPanel
extends Control

## The home screen's list of games (SaveSlots): for each slot, the date
## reached, money, time played and when it was saved, to continue it - or,
## empty, to start a new game there. A slot can be deleted (a second press
## to confirm). Picking one asks the home screen to play it (`play_requested`).
## Built in code.

signal play_requested(slot: int)
signal closed

const SEASON_NAMES := {GameClock.Season.RAINY: "Asara", GameClock.Season.DRY: "Asotry"}
const CARD_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const MUTED_COLOR := Color(0.5, 0.38, 0.26)
const TITLE_COLOR := Color(0.98, 0.86, 0.55)
const NOTE_COLOR := Color(1.0, 0.8, 0.6)
const CARD_WIDTH := 560.0

var _slots: VBoxContainer
var _note: Label
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		refresh()

## `note`: a word above the slots (why the list opened), or "".
func open(note := "") -> void:
	_note.text = note
	_note.visible = not note.is_empty()
	visible = true
	refresh()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Rebuilds the slot cards from the files.
func refresh() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var first: Button = null
	for slot in SaveSlots.SLOT_COUNT:
		var button := _add_card(slot)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()

func _add_card(slot: int) -> Button:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_slots.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var summary := SaveSlots.read_summary(slot)
	_label(texts, tr("Partie %d") % (slot + 1), 19, TEXT_COLOR)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	var play_button := _button(buttons, tr("Nouvelle partie") if summary.is_empty() else tr("Continuer"))
	play_button.name = "Play"
	play_button.pressed.connect(func(): play_requested.emit(slot))
	if summary.is_empty():
		_label(texts, tr("Emplacement libre"), 15, MUTED_COLOR)
		return play_button
	var clock := GameClock.new()
	clock.current_day = summary["day"]
	_label(texts, tr("%s, jour %d · année %d · %s") % [SEASON_NAMES[clock.get_season()], clock.get_day_of_season(),
		clock.get_year(), Currency.format(summary["money"])], 15, TEXT_COLOR)
	var played := _played_text(summary)
	if not played.is_empty():
		_label(texts, played, 13, MUTED_COLOR)
	var delete := _button(buttons, tr("Supprimer"))
	delete.name = "Delete"
	delete.pressed.connect(_on_delete.bind(slot, delete))
	return play_button

## "Joué 3 h 20 · sauvegardée le 09/10/2026 à 21:40" - what's known of it
## (a save from before summaries has neither).
func _played_text(summary: Dictionary) -> String:
	var parts := []
	var minutes: int = summary["play_seconds"] / 60
	if summary["play_seconds"] > 0:
		parts.append(tr("Joué %d h %02d") % [minutes / 60, minutes % 60] if minutes >= 60 else tr("Joué %d min") % maxi(minutes, 1))
	if summary["saved_at"] > 0:
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var at := Time.get_datetime_dict_from_unix_time(summary["saved_at"] + bias)
		parts.append(tr("sauvegardée le %02d/%02d/%d à %02d:%02d") % [at["day"], at["month"], at["year"],
			at["hour"], at["minute"]])
	return " · ".join(parts)

## A second press deletes it: the first only asks.
func _on_delete(slot: int, button: Button) -> void:
	AudioManager.play_click_menu_sfx()
	if not button.has_meta("armed"):
		button.set_meta("armed", true)
		button.text = tr("Vraiment ?")
		return
	SaveSlots.delete(slot)
	refresh()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := _label(box, tr("Tes parties"), 30, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = _label(box, "", 15, NOTE_COLOR)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	box.add_child(_slots)
	var hint := _label(box, tr("La partie se sauvegarde chaque soir, quand tu vas te coucher."), 14, NOTE_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back = _button(box, tr("Retour"))
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		close())

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
	button.custom_minimum_size = Vector2(160, 36)
	parent.add_child(button)
	return button
