class_name FeedingBowl
extends StaticBody2D

## Player interacts (E) nearby to refill it for free. Chicken.gd's AI walks
## here when hungry and self-serves - each visit consumes one serving.

signal refilled

const MAX_SERVINGS := 6
@export var empty_bowl_texture: Texture2D
@export var full_bowl_texture: Texture2D

var servings: int = 0:
	set(value):
		servings = clamp(value, 0, MAX_SERVINGS)
		_update_visual()

@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	# Connect to the component's interaction signal
	interactable_component.interacted.connect(_on_interacted)
	_update_visual()


## Middle of the bowl's solid footprint - where chickens aim and measure
## their reach from. The node origin itself is the bowl's base (its y-sort
## point), which sits at the footprint's bottom edge.
func get_center() -> Vector2:
	return $CollisionShape2D.global_position


func is_full() -> bool:
	return servings > 0


## Called by a chicken once it actually reaches the bowl.
func consume() -> void:
	servings = max(0, servings - 1)


func _on_interacted() -> void:
	if servings >= MAX_SERVINGS:
		return
		
	servings = MAX_SERVINGS
	refilled.emit()

func _update_visual() -> void:
	if not is_node_ready():
		await ready

	if visual and empty_bowl_texture and full_bowl_texture:
		visual.texture = full_bowl_texture if servings > 0 else empty_bowl_texture
