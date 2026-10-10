class_name CockfightPanel
extends Control

## The Sunday tournament at the ring, as the player watches it: each bout
## between their rooster and a villager's, blow by blow - the attacker
## flies at the other, feathers fly, the struck one's vigour drops - until
## the beaten one runs off. Then the day's summary and the season's
## ranking. The outcome is already decided (CockfightRules.enter_cockfight):
## this only plays it back. "Passer" jumps to the end. Also shows the
## ranking alone (outside the tournament). Pauses the game. Built in code.

signal finished

const FRAMES := preload("res://data/rooster.tres")
const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const NOTE_COLOR := Color(0.6, 0.3, 0.15)
const WIN_COLOR := Color(0.2, 0.45, 0.15)
const LOSE_COLOR := Color(0.65, 0.25, 0.12)
const WIDTH := 520.0
const ARENA_SIZE := Vector2(480, 190)
const ROOSTER_SIZE := 112.0
## Where each rooster stands, from the arena's center.
const STAND_GAP := 95.0
## Timing of a blow, in seconds.
const LUNGE_TIME := 0.18
const RECOIL_TIME := 0.28
const BETWEEN_BLOWS := 0.45
const FLEE_TIME := 0.7
const FEATHERS := 7
const FEATHER_COLORS := [Color(0.95, 0.92, 0.85), Color(0.75, 0.45, 0.2), Color(0.15, 0.15, 0.2)]

var _title: Label
var _bout_label: Label
var _fight_box: VBoxContainer
var _sides: HBoxContainer
var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _arena: Control
var _roosters: Array[TextureRect] = []
var _log: Label
var _next: Button
var _skip: Button
var _summary: Label
var _ranking: CockfightRankingList
var _note: Label
var _close: Button
var _skipping := false
var _playing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

func is_playing() -> bool:
	return _playing

## Plays the day's bouts. `player_name`: the player's rooster.
## `bouts`: [{"opponent", "owner", "color", "won", "hits"}] (hits: true = the
## player's rooster lands the blow). `summary`: the day's result, written.
func play_tournament(player_name: String, bouts: Array, summary: String, ranking: Array) -> void:
	_open(tr("Ady akoho — le tournoi du bourg"))
	_playing = true
	_skipping = false
	_fight_box.visible = true
	_sides.visible = true
	_arena.visible = true
	_summary.visible = false
	_ranking.visible = false
	_note.visible = false
	_close.visible = false
	_skip.visible = true
	for i in bouts.size():
		var bout: Dictionary = bouts[i]
		_bout_label.text = tr("Combat %d/%d : %s contre %s (à %s)") % [i + 1, bouts.size(), player_name,
			bout["opponent"], bout["owner"]]
		await _play_bout(player_name, bout)
		if i < bouts.size() - 1 and not _skipping:
			_next.visible = true
			_next.grab_focus()
			await _next.pressed
			_next.visible = false
	_skip.visible = false
	# The summary and the ranking take the arena's place: it all fits.
	_sides.visible = false
	_arena.visible = false
	_summary.text = summary
	_summary.visible = true
	_ranking.show_ranking(ranking)
	_ranking.visible = true
	_close.visible = true
	_close.grab_focus()
	_playing = false

## The ranking alone, with a word (when the next tournament is...).
func show_ranking(note: String, ranking: Array) -> void:
	_open(tr("Classement des coqs"))
	_fight_box.visible = false
	_summary.visible = false
	_skip.visible = false
	_next.visible = false
	_ranking.show_ranking(ranking)
	_ranking.visible = true
	_note.text = note
	_note.visible = not note.is_empty()
	_close.visible = true
	_close.grab_focus()

## Jumps to the end of the tournament.
func skip() -> void:
	_skipping = true
	if _next.visible:
		_next.pressed.emit()

func close() -> void:
	if _playing:
		return
	visible = false
	get_tree().paused = false
	finished.emit()

func _open(title: String) -> void:
	_title.text = title
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _playing:
			skip()
		else:
			close()
		get_viewport().set_input_as_handled()

# --- a bout ----------------------------------------------------------------------------

func _play_bout(player_name: String, bout: Dictionary) -> void:
	var colors := [Color.WHITE, bout["color"]]
	var names := [player_name, bout["opponent"]]
	var vigour := [100.0, 100.0]
	for side in 2:
		_names[side].text = names[side]
		_bars[side].value = 100.0
		_roosters[side].modulate = colors[side]
		_roosters[side].flip_h = false
		_roosters[side].position = _stand(side)
		_roosters[side].visible = true
	_log.text = tr("Les deux coqs se jaugent...")
	await _wait(BETWEEN_BLOWS * 1.5)
	var hits: Array = bout["hits"]
	var damage := 100.0 / CockfightRules.COCKFIGHT_HITS_TO_WIN
	for hit: bool in hits:
		var attacker := 0 if hit else 1
		var defender := 1 - attacker
		_log.text = tr("%s frappe !") % names[attacker]
		await _lunge(attacker)
		vigour[defender] = maxf(vigour[defender] - damage, 0.0)
		_bars[defender].value = vigour[defender]
		_feathers(_roosters[defender].position + Vector2(ROOSTER_SIZE / 2.0, ROOSTER_SIZE * 0.45))
		await _wait(BETWEEN_BLOWS)
	var loser := 1 if bout["won"] else 0
	await _flee(loser)
	_log.text = tr("%s gagne le combat !") % player_name if bout["won"] \
		else tr("%s l'emporte.") % bout["opponent"]
	_log.add_theme_color_override("font_color", WIN_COLOR if bout["won"] else LOSE_COLOR)
	await _wait(BETWEEN_BLOWS)
	_log.add_theme_color_override("font_color", TEXT_COLOR)

func _stand(side: int) -> Vector2:
	var center := ARENA_SIZE / 2.0 - Vector2(ROOSTER_SIZE, ROOSTER_SIZE) / 2.0 + Vector2(0, 10)
	return center + Vector2(-STAND_GAP if side == 0 else STAND_GAP, 0)

## The attacker flies at the other, wings up, and falls back.
func _lunge(side: int) -> void:
	if _skipping:
		return
	var rooster := _roosters[side]
	var home := _stand(side)
	var toward := Vector2(STAND_GAP * 1.1 * (1 if side == 0 else -1), -26)
	var tween := create_tween()
	tween.tween_property(rooster, "position", home + toward, LUNGE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(rooster, "position", home, RECOIL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var struck := _roosters[1 - side]
	var struck_home := _stand(1 - side)
	tween.parallel().tween_property(struck, "position", struck_home + Vector2(toward.x * 0.15, 0), RECOIL_TIME * 0.5)
	tween.tween_property(struck, "position", struck_home, RECOIL_TIME * 0.5)
	await tween.finished

## The beaten one turns tail and runs out of the ring.
func _flee(side: int) -> void:
	var rooster := _roosters[side]
	rooster.flip_h = true
	var away := Vector2(-ARENA_SIZE.x if side == 0 else ARENA_SIZE.x, 0)
	if _skipping:
		rooster.visible = false
		return
	var tween := create_tween()
	tween.tween_property(rooster, "position", rooster.position + away, FLEE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	rooster.visible = false

func _feathers(at: Vector2) -> void:
	if _skipping:
		return
	for i in FEATHERS:
		var feather := ColorRect.new()
		feather.color = FEATHER_COLORS.pick_random()
		feather.size = Vector2(5, 3)
		feather.position = at
		feather.rotation = randf() * TAU
		feather.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arena.add_child(feather)
		var drift := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(25.0, 60.0)
		var tween := feather.create_tween()
		tween.tween_property(feather, "position", at + drift + Vector2(0, 30), 0.8).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(feather, "modulate:a", 0.0, 0.8)
		tween.tween_callback(feather.queue_free)

func _wait(seconds: float) -> void:
	if _skipping:
		return
	await get_tree().create_timer(seconds, true).timeout

# --- building ----------------------------------------------------------------------------

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
	_title = _label(box, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_fight_box = VBoxContainer.new()
	_fight_box.add_theme_constant_override("separation", 6)
	box.add_child(_fight_box)
	_bout_label = _label(_fight_box, 15)
	_bout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sides = HBoxContainer.new()
	_sides.add_theme_constant_override("separation", 40)
	_fight_box.add_child(_sides)
	for side in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sides.add_child(column)
		var name_label := _label(column, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_names.append(name_label)
		_bars.append(_bar(column, Color(0.3, 0.55, 0.3) if side == 0 else Color(0.75, 0.35, 0.2)))
	_arena = _Arena.new()
	_arena.custom_minimum_size = ARENA_SIZE
	_arena.clip_contents = true
	_fight_box.add_child(_arena)
	for side in 2:
		var rooster := TextureRect.new()
		rooster.texture = FRAMES.get_frame_texture("idle_right" if side == 0 else "idle_left", 0)
		rooster.size = Vector2(ROOSTER_SIZE, ROOSTER_SIZE)
		rooster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rooster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rooster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arena.add_child(rooster)
		_roosters.append(rooster)
	_log = _label(_fight_box, 17)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	_fight_box.add_child(buttons)
	_next = _button(buttons, tr("Combat suivant"))
	_next.visible = false
	_skip = _button(buttons, tr("Passer"))
	_skip.pressed.connect(skip)

	_summary = _label(box, 16)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(WIDTH - 36, 0)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

## The ring's trampled earth, inside its cord.
class _Arena extends Control:
	func _draw() -> void:
		var center := size / 2.0 + Vector2(0, 30)
		var radii := Vector2(size.x * 0.46, size.y * 0.3)
		_ellipse(center, radii + Vector2(5, 3), Color(0.42, 0.28, 0.17))
		_ellipse(center, radii, Color(0.6, 0.43, 0.27))
		_ellipse(center, radii * 0.7, Color(0.64, 0.47, 0.3))

	func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 48:
			var angle := TAU * i / 48.0
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, color)
