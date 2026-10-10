class_name ResourceDir
extends RefCounted

## The data folders' resources (data/quests/, data/discoveries/...): one
## .tres per entry, its id the file's name.
##
## In an exported game, a folder doesn't list "quest.tres" any more but
## "quest.tres.remap" (the resource was converted at export), or ".import"
## files for some types - so a scan for ".tres" finds nothing. This lists
## them by their original path, which load() resolves either way.

## The .tres paths in `dir` (ending with "/"), sorted by name.
static func list(dir: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		var original := file.trim_suffix(".remap")
		if original.ends_with(".tres") and not paths.has(dir + original):
			paths.append(dir + original)
	paths.sort()
	return paths

## Every resource in `dir` of `type` (a script class, e.g. Quest): id (the
## file's name) -> resource. Others are skipped, with a warning.
static func load_all(dir: String, type: Script) -> Dictionary:
	var all := {}
	for path in list(dir):
		var resource := load(path)
		if resource != null and is_instance_of(resource, type):
			all[path.get_file().get_basename()] = resource
		else:
			push_warning("ResourceDir: %s isn't a %s - skipped." % [path, type.get_global_name()])
	return all
