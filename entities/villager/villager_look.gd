@tool
class_name VillagerLook
extends Resource

## What a villager looks like: the base body tinted with a skin color, then
## the layers drawn over it, first to last (e.g. trousers, shirt, lamba,
## hair, hat). Save one per villager in data/villagers/looks/ - or share
## one between several, changing only the colors.

const DEFAULT_BODY := preload("res://assets/sprites/characters/villager/base_body.png")

@export var skin_color := Color(0.55, 0.36, 0.24):
	set(value):
		skin_color = value
		emit_changed()
## Leave empty for the default base body; a different build (child,
## elder...) is a sheet on the same grid.
@export var body: Texture2D:
	set(value):
		body = value
		emit_changed()
@export var layers: Array[VillagerLayer] = []:
	set(value):
		for layer in layers:
			if layer != null and layer.changed.is_connected(emit_changed):
				layer.changed.disconnect(emit_changed)
		layers = value
		for layer in layers:
			if layer != null:
				layer.changed.connect(emit_changed)
		emit_changed()

func get_body() -> Texture2D:
	return body if body != null else DEFAULT_BODY
