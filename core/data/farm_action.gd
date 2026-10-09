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
	## Tills up to FarmSimulation.PLOUGH_REACH plots in a row at once, with
	## the zebu team (the plough, angadin'omby).
	PLOUGH = 5,
	## Spreads zebu manure on a plot: a bigger harvest
	## (FarmSimulation.MANURE_YIELD_MULTIPLIER).
	FERTILIZE = 6,
}
