class_name Egg
extends Area2D

## A physical pickup spawned by AnimalManager when a chicken's product_ready
## fires. Walking into it (like ZoneTransition/ShopTrigger/SleepSpot) collects
## it - no tool needed, matching how a player naturally picks up an object.

var _simulation: FarmSimulation
var _product_id: String = "egg"
var _collected := false

func setup(simulation: FarmSimulation, product_id: String) -> void:
	_simulation = simulation
	_product_id = product_id

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected or not body is PlayerController:
		return
	_collected = true
	_simulation.animals.collect_product(_product_id)
	AudioManager.play_egg_pickup_sfx()
	queue_free()
