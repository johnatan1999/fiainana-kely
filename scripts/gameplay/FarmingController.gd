class_name FarmingController
extends Node

## Translates player interactions into FarmSimulation commands.
## Holds no farming rules itself - it only decides *which* simulation call to make.

const SELECTED_CROP_ID := "turnip" # single-crop prototype; revisit once a seed-selection UI exists

var simulation: FarmSimulation
var player: PlayerController
var farm_view: FarmView

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_farm_view: FarmView) -> void:
	simulation = p_simulation
	player = p_player
	farm_view = p_farm_view
	player.interact_requested.connect(_on_interact_requested)

func advance_day() -> void:
	simulation.advance_day()

func _on_interact_requested(tool: PlayerController.Tool) -> void:
	var plot_id := farm_view.get_plot_id_at(player.global_position)
	if plot_id == -1:
		return
	match tool:
		PlayerController.Tool.HOE:
			simulation.till(plot_id)
		PlayerController.Tool.WATERING_CAN:
			simulation.water(plot_id)
		PlayerController.Tool.SEEDS:
			simulation.plant(plot_id, SELECTED_CROP_ID)
		PlayerController.Tool.HARVEST:
			simulation.harvest(plot_id)
