class_name FarmAction
extends RefCounted

## The one vocabulary for "what happens to a plot": what a tool item does
## (ItemData.tool_action), what a button press resolves to
## (FarmingController), which animation plays (PlayerController) and which
## verb/pictogram the UI shows. Values are stored in .tres files (tool items)
## - append new ones, never reorder.
enum Type {
	NONE = 0,
	TILL = 1,
	WATER = 2,
	PLANT = 3,
	HARVEST = 4,
}
