class_name TreeState
extends RefCounted

## Runtime state of one fruit tree placed in a zone. Static definitions live
## in TreeData. Never touches Node2D - WorldTree only reads it.

var tree_type_id: String
var fruit_ready: bool = false
## Days in season since the last harvest (or since the fruit rotted).
var days_growing: int = 0

func _init(p_tree_type_id: String) -> void:
	tree_type_id = p_tree_type_id
