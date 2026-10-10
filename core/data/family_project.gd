class_name FamilyProject
extends Resource

## A family project (see docs/family_projects.md): taking one of the farm's
## buildings to its next level. The family decides it with Dada, the player
## pays for it, and it's built in a few days - fewer with friends helping.
## One .tres per project in data/projects/; its id is the file's name.

const DIR := "res://data/projects/"

## What it's called, in French and in Malagasy, and what it brings - in
## French (tr()).
@export var display_name := ""
@export var malagasy_name := ""
@export_multiline var description := ""
## The building it improves (ProjectRules.BUILDINGS: "coop", "zebu_pen")
## and the level it takes it to; the level below must be reached first.
@export var building := ""
@export var level := 2
@export var cost := 10000
## Days of work, before friends come and help (FarmSimulation.PROJECT_*).
@export var build_days := 3

## Every project: id (the file's name) -> FamilyProject, by name.
static func load_all() -> Dictionary:
	return ResourceDir.load_all(DIR, FamilyProject)
