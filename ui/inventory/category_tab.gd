class_name InventoryCategoryTab
extends Control

## One bookmark-style tab on the inventory's left page. Placed in
## inventory_ui.tscn (icon/category set per instance in the Inspector);
## InventoryUI finds them, fills in the item count and tells them which one
## is selected. The selected tab slides out to the right like a bookmark
## pulled from the book; the others sit back, slightly dimmed.

signal chosen(category: InventoryCatalog.Category)

@export var category: InventoryCatalog.Category = InventoryCatalog.Category.CROPS
@export var icon: Texture2D

const SELECTED_OFFSET := 14.0
const SLIDE_TIME := 0.12
const UNSELECTED_TINT := Color(0.8, 0.78, 0.75)

@onready var body: TextureButton = $Body
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel

var _tween: Tween

func _ready() -> void:
	icon_rect.texture = icon
	name_label.text = InventoryCatalog.CATEGORY_NAMES[category]
	body.pressed.connect(func(): chosen.emit(category))
	set_selected(false, false)

func set_count(count: int) -> void:
	if count == 0:
		count_label.text = tr("vide")
	else:
		count_label.text = (tr("%d objets") if count > 1 else tr("%d objet")) % count

func set_selected(selected: bool, animate := true) -> void:
	var target_x := SELECTED_OFFSET if selected else 0.0
	var tint := Color.WHITE if selected else UNSELECTED_TINT
	if _tween:
		_tween.kill()
	if not animate:
		body.position.x = target_x
		body.modulate = tint
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(body, "position:x", target_x, SLIDE_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(body, "modulate", tint, SLIDE_TIME)
