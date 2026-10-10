class_name SimRules
extends RefCounted

## One domain of the farm's rules (the zebus, the quests, the dog...): a part
## of FarmSimulation, reached through it (simulation.zebus, simulation.quests).
## FarmSimulation holds what they share - the state (FarmState), the day's
## log, every signal, the clock and the weather - and calls each domain's
## day hooks in order (advance_day). A domain holds its own rules, its
## constants and the data registered with it (quests, recipes...).
##
## The simulation is held weakly: it holds its domains, and two RefCounted
## holding each other would never be freed.

var _sim_ref: WeakRef

## The simulation this is a part of.
var sim: FarmSimulation:
	get:
		return _sim_ref.get_ref()

var state: FarmState:
	get:
		return sim.state

var day_log: DayLog:
	get:
		return sim.day_log

func _init(simulation: FarmSimulation) -> void:
	_sim_ref = weakref(simulation)
