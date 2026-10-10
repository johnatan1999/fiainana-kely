class_name DogState
extends RefCounted

## The family's dog (FarmState.dog, null until it comes). The rules are
## FarmSimulation's dog API; the dog in the world is Dog, never this.

## Given by the player (DogNamePanel), or the puppy's first name.
var name := ""
## Index in Dog.COATS.
var coat := 0
## The day it came to the farm.
var since := 0
## The day its bowl was last filled, and it was last petted (0: never).
var fed_day := 0
var petted_day := 0
## Days it was petted: its fondness for the player.
var bond := 0

func _init(p_name := "", p_coat := 0, p_since := 0) -> void:
	name = p_name
	coat = p_coat
	since = p_since

func to_dict() -> Dictionary:
	return {"name": name, "coat": coat, "since": since, "fed_day": fed_day,
		"petted_day": petted_day, "bond": bond}

## From a save: missing or odd values fall back to a fresh dog's.
static func from_dict(data: Dictionary) -> DogState:
	var dog := DogState.new(str(data.get("name", "")), int(data.get("coat", 0)), int(data.get("since", 0)))
	dog.fed_day = int(data.get("fed_day", 0))
	dog.petted_day = int(data.get("petted_day", 0))
	dog.bond = int(data.get("bond", 0))
	return dog
