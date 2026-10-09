extends Node

## Autoload singleton (registered in project.godot [autoload]).
## Player preferences that belong to the player, not to a save slot: the
## display language, the music and sound effects volumes, full screen.
## Stored in user://settings.cfg, applied at startup before any scene shows
## text (the volumes once AudioManager has made its buses).
##
## Texts are translated through localization/translations.csv (keys are the
## French source texts). Changing the locale makes Godot re-translate every
## Control showing a plain key automatically; screens that build formatted
## text in code refresh on NOTIFICATION_TRANSLATION_CHANGED.

signal locale_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "fr"
## Cycle order of the language option, and each language's name written in
## that language (never translated - a player must recognize their own).
const LOCALES := ["fr", "mg", "en"]
const LOCALE_NAMES := {
	"fr": "Français",
	"mg": "Malagasy",
	"en": "English",
}
## The audio buses the player sets the volume of (AudioManager's).
const VOLUME_BUSES := ["Music", "SFX"]

func _ready() -> void:
	var config := ConfigFile.new()
	var locale := DEFAULT_LOCALE
	if config.load(SETTINGS_PATH) == OK:
		locale = config.get_value("display", "locale", DEFAULT_LOCALE)
	if not locale in LOCALES:
		locale = DEFAULT_LOCALE
	TranslationServer.set_locale(locale)
	# AudioManager (an autoload after this one) makes the buses in its _ready.
	_apply_volumes.call_deferred()
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func get_locale() -> String:
	var current := TranslationServer.get_locale()
	for locale in LOCALES:
		if current.begins_with(locale):
			return locale
	return DEFAULT_LOCALE

func get_locale_name() -> String:
	return LOCALE_NAMES[get_locale()]

func set_locale(locale: String) -> void:
	if not locale in LOCALES or locale == get_locale():
		return
	TranslationServer.set_locale(locale)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # keep any other section already saved
	config.set_value("display", "locale", locale)
	config.save(SETTINGS_PATH)
	locale_changed.emit(locale)

func cycle_locale() -> void:
	var index := LOCALES.find(get_locale())
	set_locale(LOCALES[(index + 1) % LOCALES.size()])

## A bus's volume as the player set it, 0 (muted) to 1 (full).
func get_volume(bus: String) -> float:
	return clampf(float(_load().get_value("audio", bus, 1.0)), 0.0, 1.0)

func set_volume(bus: String, volume: float) -> void:
	volume = clampf(volume, 0.0, 1.0)
	_apply_volume(bus, volume)
	_save_value("audio", bus, volume)

func is_fullscreen() -> bool:
	return bool(_load().get_value("display", "fullscreen", false))

func set_fullscreen(fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_value("display", "fullscreen", fullscreen)

func _apply_volumes() -> void:
	for bus: String in VOLUME_BUSES:
		_apply_volume(bus, get_volume(bus))

func _apply_volume(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))

func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config

## Keeps every other setting already saved.
func _save_value(section: String, key: String, value: Variant) -> void:
	var config := _load()
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)
