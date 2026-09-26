extends Node

## Autoload singleton (registered in project.godot [autoload]).
## Player preferences that belong to the player, not to a save slot - for now
## the display language. Stored in user://settings.cfg, applied at startup
## before any scene shows text.
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

func _ready() -> void:
	var config := ConfigFile.new()
	var locale := DEFAULT_LOCALE
	if config.load(SETTINGS_PATH) == OK:
		locale = config.get_value("display", "locale", DEFAULT_LOCALE)
	if not locale in LOCALES:
		locale = DEFAULT_LOCALE
	TranslationServer.set_locale(locale)

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
