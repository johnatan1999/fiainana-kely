class_name SaveSlots
extends RefCounted

## The save slots: SLOT_COUNT games side by side, one JSON file each in
## `dir`. Only files - what goes in a save is SaveController's business.
## - Written safely: to a temporary file first, then swapped in; the
##   previous save is kept as "<file>.bak" (the night before), and reading
##   falls back to it if the save is missing or unreadable.
## - `current`: the slot being played, chosen on the title screen. -1 = none:
##   a game that is never saved (tests, the world scene run on its own).
## - A save from before the slots (`legacy_path`) becomes the first slot.

const SLOT_COUNT := 3
const BACKUP := ".bak"
const TEMP := ".tmp"

## Where the slots live, and the single save of earlier versions - tests
## point them elsewhere, never at the player's.
static var dir := "user://saves/"
static var legacy_path := "user://savegame.json"
static var current := -1

static func path(slot: int) -> String:
	return dir + "slot_%d.json" % (slot + 1)

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot) + BACKUP)

## Writes `data` as the slot's save. Returns whether it worked - on a
## failure, the previous save is untouched.
static func write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var target := path(slot)
	var file := FileAccess.open(target + TEMP, FileAccess.WRITE)
	if file == null:
		push_error("SaveSlots: can't write %s (%s)" % [target + TEMP, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(target):
		if FileAccess.file_exists(target + BACKUP):
			DirAccess.remove_absolute(target + BACKUP)
		DirAccess.rename_absolute(target, target + BACKUP)
	var error := DirAccess.rename_absolute(target + TEMP, target)
	if error != OK:
		push_error("SaveSlots: can't move %s into place (%s)" % [target + TEMP, error_string(error)])
	return error == OK

## The slot's save ({} if there's none, or nothing readable): the save
## itself, or else the one before it.
static func read(slot: int) -> Dictionary:
	for file_path in [path(slot), path(slot) + BACKUP]:
		if not FileAccess.file_exists(file_path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if data is Dictionary:
			return data
		push_warning("SaveSlots: %s is unreadable - trying the save before it." % file_path)
	return {}

## What the title screen shows of a slot: {"day", "money", "play_seconds",
## "saved_at" (Unix time, 0 = unknown)} - {} for an empty slot. Written by
## SaveController; a save from before summaries gets what's in it.
static func read_summary(slot: int) -> Dictionary:
	var data := read(slot)
	if data.is_empty():
		return {}
	var summary = data.get("summary", {})
	if not summary is Dictionary:
		summary = {}
	return {
		"day": int(summary.get("day", data.get("day", 1))),
		"money": int(summary.get("money", data.get("money", 0))),
		"play_seconds": int(summary.get("play_seconds", 0)),
		"saved_at": int(summary.get("saved_at", 0)),
	}

static func delete(slot: int) -> void:
	for suffix in ["", BACKUP, TEMP]:
		if FileAccess.file_exists(path(slot) + suffix):
			DirAccess.remove_absolute(path(slot) + suffix)

## The single save of earlier versions becomes the first slot (if that one
## is free); the old file stays, renamed "<file>.migrated".
static func migrate_legacy() -> bool:
	if not FileAccess.file_exists(legacy_path) or exists(0):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	if DirAccess.copy_absolute(legacy_path, path(0)) != OK:
		return false
	DirAccess.rename_absolute(legacy_path, legacy_path + ".migrated")
	return true
