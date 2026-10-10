class_name Recipe
extends Resource

## A dish cooked in the farm's kitchen (FamilyProject "kitchen"): harvests
## in, a dish out - worth more than what went in, to sell or to keep. One
## .tres per recipe in data/recipes/; its id is the file's name.

const DIR := "res://data/recipes/"

## In French and in Malagasy.
@export var display_name := ""
@export var malagasy_name := ""
## What goes in: item id -> how many.
@export var ingredients: Dictionary = {}
## What comes out (an ItemData id, data/items/), and how many.
@export var result := ""
@export var quantity := 1

## Every recipe: id (the file's name) -> Recipe, by name.
static func load_all() -> Dictionary:
	var all := {}
	var files := Array(DirAccess.get_files_at(DIR)).filter(func(file): return file.ends_with(".tres"))
	files.sort()
	for file: String in files:
		var data := load(DIR + file) as Recipe
		if data != null:
			all[file.get_basename()] = data
	return all
