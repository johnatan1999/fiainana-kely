class_name ZoneData
extends Resource

## One entry in WorldManager's zone registry, auto-loaded from every .tres
## under data/world_zones/. Adding a new zone to the game is just adding one
## of these files (plus its scene) here - no code file needs editing.
##
## Distinct from FarmZoneData (data/zones/) - that one is a purchasable
## rectangle of farm tiles inside a zone, this one is a whole explorable
## scene WorldManager can switch to.

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
