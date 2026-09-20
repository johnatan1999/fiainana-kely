class_name AnimalData
extends Resource

## Static definition of one livestock species. Runtime state (hunger, age,
## breeding progress) lives in AnimalState - this Resource never changes.
## Species beyond CHICKEN are declared now so the enum/UI never has to change
## when Sprint 4+ adds them, but no rules are implemented for them yet.

enum Species { CHICKEN, DUCK, GOOSE, PIG, ZEBU }

@export var species: Species = Species.CHICKEN
@export var display_name: String
@export var malagasy_name: String = ""

@export var purchase_price: int = 0

## What this animal produces once well cared-for, and how often.
@export var product_id: String = ""
@export var product_sell_price: int = 0
@export var product_cycle_days: int = 2

@export var hunger_decay_per_day: float = 25.0
@export var thirst_decay_per_day: float = 30.0

## Consecutive fed+watered days required before a breeding roll is attempted.
@export var breeding_days_required: int = 5
@export var breeding_chance: float = 0.25

@export var icon: Texture2D
