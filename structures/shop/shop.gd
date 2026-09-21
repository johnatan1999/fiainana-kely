class_name Shop extends Node2D

@onready var shop_trigger: ShopTrigger = $ShopTrigger

func setup(player: PlayerController, shop_ui: ShopUI) -> void:
	if shop_trigger:
		shop_trigger.setup(player, shop_ui)
		 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	StructureEvents.shop_spawned.emit(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
