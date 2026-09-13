class_name PlotState
extends RefCounted

var tilled: bool = false
var watered: bool = false
var crop: CropState = null

func is_empty() -> bool:
	return crop == null
