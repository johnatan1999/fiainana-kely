class_name FarmZoneData
extends Resource

## What one buy-in-one-shot land zone (macro progression) is called and
## costs. Its shape isn't here: it's painted in the zone scene, on the
## FarmField that references this resource.

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""
@export var description: String = ""
@export var price: int = 0
