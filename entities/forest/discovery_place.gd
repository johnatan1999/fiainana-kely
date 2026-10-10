class_name DiscoveryPlace
extends Area2D

## A place to find (its Discovery: a place page of the notebook): walking
## into this area finds it - ForestManager writes the page. `size` is the
## area, centered on the node. Built in code. Group "discovery_places".

signal reached

const GROUP := "discovery_places"

## Which place (a Discovery id: "forest_spring", "sacred_fig"...).
@export var discovery_id := ""
@export var size := Vector2(200, 160)

func _ready() -> void:
	add_to_group(GROUP)
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			reached.emit())
