class_name FarmState
extends RefCounted

var money: int = 100
var clock := GameClock.new()
var plots: Dictionary = {} # plot_id: int -> PlotState
var inventory: Dictionary = {} # item_id: String -> int

## Convenience read access - the clock is the single source of truth for the day.
var day: int:
	get:
		return clock.current_day

func _init(plot_count: int) -> void:
	for i in range(plot_count):
		plots[i] = PlotState.new()

func get_inventory_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func add_inventory(item_id: String, amount: int) -> void:
	inventory[item_id] = get_inventory_count(item_id) + amount

func to_dict() -> Dictionary:
	var plots_data := {}
	for plot_id in plots:
		var plot: PlotState = plots[plot_id]
		var crop_data = null
		if plot.crop != null:
			crop_data = {
				"crop_id": plot.crop.crop_id,
				"age": plot.crop.age,
				"growth_days": plot.crop.growth_days,
				"days_watered": plot.crop.days_watered,
				"days_total": plot.crop.days_total,
			}
		plots_data[str(plot_id)] = {
			"tilled": plot.tilled,
			"watered": plot.watered,
			"crop": crop_data,
		}
	return {
		"money": money,
		"day": day,
		"inventory": inventory.duplicate(),
		"plots": plots_data,
	}

## Restores state in-place from a dictionary produced by to_dict().
## Unknown/missing plot_ids are ignored - the grid shape always comes from the current run.
func load_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	clock.current_day = int(data.get("day", clock.current_day))

	inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for item_id in saved_inventory:
		inventory[item_id] = int(saved_inventory[item_id])

	var plots_data: Dictionary = data.get("plots", {})
	for key in plots_data:
		var plot_id := int(key)
		if not plots.has(plot_id):
			continue
		var plot: PlotState = plots[plot_id]
		var plot_data: Dictionary = plots_data[key]
		plot.tilled = plot_data.get("tilled", false)
		plot.watered = plot_data.get("watered", false)
		var crop_data = plot_data.get("crop")
		if crop_data != null:
			var crop := CropState.new(str(crop_data["crop_id"]), int(crop_data["growth_days"]))
			crop.age = int(crop_data["age"])
			crop.days_watered = int(crop_data.get("days_watered", crop.age))
			crop.days_total = int(crop_data.get("days_total", crop.age))
			plot.crop = crop
		else:
			plot.crop = null
