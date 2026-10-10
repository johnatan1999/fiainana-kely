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
	return ResourceDir.load_all(DIR, Recipe)
