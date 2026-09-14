class_name InventorySlot
extends PanelContainer

## One read-only tile in the inventory grid. Purely presentational - shows
## whatever InventoryUI resolves for an item_id (name/color/icon/quantity),
## never touches FarmSimulation itself.

@onready var icon_rect: TextureRect = %IconRect
@onready var icon_placeholder: ColorRect = %IconPlaceholder
@onready var name_label: Label = %NameLabel
@onready var malagasy_label: Label = %MalagasyLabel
@onready var quantity_label: Label = %QuantityLabel

var _tween: Tween

func _ready() -> void:
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(func(): _animate_scale(Vector2(1.05, 1.05)))
	mouse_exited.connect(func(): _animate_scale(Vector2.ONE))

func setup(display_name: String, malagasy_name: String, quantity: int, color: Color, icon: Texture2D) -> void:
	name_label.text = display_name
	malagasy_label.text = malagasy_name
	malagasy_label.visible = malagasy_name != ""
	quantity_label.text = "x %d" % quantity

	if icon:
		icon_rect.texture = icon
		icon_rect.visible = true
		icon_placeholder.visible = false
	else:
		icon_rect.visible = false
		icon_placeholder.visible = true
		icon_placeholder.color = color

func _animate_scale(target: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, 0.12).set_trans(Tween.TRANS_SINE)
