class_name HomeScreen
extends Node2D

## The game's first screen (the main scene): night over the village, a
## campfire crackling in front of the south house, the player crouched by
## it warming up - lanterns lit, fireflies about - and, on the left, the
## game's name and its menu:
## - Continuer: the list of games (SaveSlotsPanel) - greyed with none;
## - Nouveau jeu: a new game in the first free slot (all taken: the list,
##   to free one);
## - Paramètres: language, volumes, full screen (SettingsPanel);
## - Quitter.
## Playing a slot sets SaveSlots.current and opens the world, which loads it
## or starts the new game. The village is the real zone scene, told it's
## night (its lanterns, fireflies, villagers home). Built in code.

const WORLD := "res://world/world.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"
## The fire, in the village (the red earth between the market house and the
## grocery, by the cooking pot), the player beside it, and where the camera
## looks: the fire on the right, the menu's side on the left.
const FIRE_AT := Vector2(1110, 1150)
const PLAYER_AT := Vector2(1066, 1155)
const CAMERA_AT := Vector2(930, 1080)
const ZOOM := 1.25
## The village late at night - a little darker than the game's night sky,
## for the fire to stand out.
const NIGHT := Color(0.22, 0.25, 0.45)
const NIGHT_MINUTE := 22 * 60
const TITLE_COLOR := Color(0.98, 0.86, 0.55)
const SUBTITLE_COLOR := Color(0.92, 0.82, 0.68)
const FADE_IN := 1.4

var _continue: Button
var _new_game: Button
var _saves: SaveSlotsPanel
var _settings: SettingsPanel
var _menu: Control

func _ready() -> void:
	get_tree().paused = false
	SaveSlots.migrate_legacy()
	_build_scene()
	_build_ui()
	_refresh()
	AudioManager.play_interior_bgm()

## Plays `slot`: its save, or a new game there.
func play(slot: int) -> void:
	SaveSlots.current = slot
	AudioManager.play_click_menu_sfx()
	get_tree().change_scene_to_file(WORLD)

func has_any_save() -> bool:
	return range(SaveSlots.SLOT_COUNT).any(func(slot): return SaveSlots.exists(slot))

## The first slot without a game, -1 if all are taken.
func first_free_slot() -> int:
	for slot in SaveSlots.SLOT_COUNT:
		if not SaveSlots.exists(slot):
			return slot
	return -1

func _refresh() -> void:
	_continue.disabled = not has_any_save()
	_menu.visible = not _saves.visible and not _settings.visible
	if _menu.visible:
		(_new_game if _continue.disabled else _continue).grab_focus()

func _on_new_game() -> void:
	var slot := first_free_slot()
	if slot >= 0:
		play(slot)
		return
	AudioManager.play_click_menu_sfx()
	_menu.visible = false
	_saves.open(tr("Les trois parties sont prises : supprimes-en une pour en commencer une nouvelle."))

# --- the night scene ------------------------------------------------------------------------

func _build_scene() -> void:
	var village: Node2D = load(VILLAGE).instantiate()
	add_child(village)
	var fire := Campfire.new()
	fire.name = "Campfire"
	fire.position = FIRE_AT
	village.add_child(fire)
	var player := FiresidePlayer.new()
	player.name = "FiresidePlayer"
	player.position = PLAYER_AT
	village.add_child(player)
	var night := CanvasModulate.new()
	night.color = NIGHT
	add_child(night)
	var camera := Camera2D.new()
	camera.position = CAMERA_AT
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	camera.make_current()
	# The village's own nodes, told it's a late evening: lanterns lit,
	# fireflies out, villagers and hens home.
	_tell_the_hour.call_deferred()

func _tell_the_hour() -> void:
	var tree := get_tree()
	tree.call_group(DayNightController.CALENDAR_GROUP, "set_weekday", GameClock.Weekday.SATURDAY)
	tree.call_group(DayNightController.CLOCK_GROUP, "set_time_of_day", NIGHT_MINUTE)
	tree.call_group(DayNightController.LIGHT_GROUP, "set_night", 1.0)

# --- the menu --------------------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# A shadow on the left, for the menu to read on.
	var shadow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04, 0.03, 0.06, 0.85), Color(0.04, 0.03, 0.06, 0.0)])
	var shadow_texture := GradientTexture2D.new()
	shadow_texture.gradient = gradient
	shadow_texture.fill_to = Vector2(1, 0)
	shadow.texture = shadow_texture
	shadow.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shadow.anchor_right = 0.55
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	_menu = MarginContainer.new()
	_menu.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_menu.add_theme_constant_override("margin_left", 80)
	root.add_child(_menu)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	_menu.add_child(column)
	var title := _label(column, "Fiainana kely", 64, TITLE_COLOR)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	var subtitle := _label(column, tr("Une petite vie à Madagascar"), 20, SUBTITLE_COLOR)
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	column.add_child(gap)
	_continue = _button(column, tr("Continuer"))
	_continue.name = "Continue"
	_continue.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		_menu.visible = false
		_saves.open())
	_new_game = _button(column, tr("Nouveau jeu"))
	_new_game.name = "NewGame"
	_new_game.pressed.connect(_on_new_game)
	var settings := _button(column, tr("Paramètres"))
	settings.name = "Settings"
	settings.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		_menu.visible = false
		_settings.open())
	var quit := _button(column, tr("Quitter"))
	quit.name = "Quit"
	quit.pressed.connect(get_tree().quit)

	_saves = SaveSlotsPanel.new()
	_saves.name = "SaveSlotsPanel"
	_saves.play_requested.connect(play)
	_saves.closed.connect(_refresh)
	root.add_child(_saves)
	_settings = SettingsPanel.new()
	_settings.name = "SettingsPanel"
	_settings.closed.connect(_refresh)
	root.add_child(_settings)

	# Out of the dark.
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	var tween := fade.create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(fade.queue_free)

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
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 20)
	parent.add_child(button)
	return button
