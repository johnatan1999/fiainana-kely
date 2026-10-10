class_name DogManager
extends Node

## The family's dog (alika), between FarmSimulation (its name, bowl,
## petting, the nights it keeps watch - the rules) and the world. Decides
## nothing itself:
## - the farm's DogHouse: there once the dog came, its bowl empty or full,
##   filled when the player asks;
## - the Dog in the zone: by day, at the player's heels everywhere outdoors
##   (not indoors: it waits outside). At night (GUARD_FROM to GUARD_UNTIL),
##   at its doghouse - if it has eaten; else it's off looking for food. The
##   player away from the farm at nightfall: it trots off home;
## - in the morning, at the farm: it comes running from its doghouse;
## - the puppy's name (DogNamePanel), the day it comes;
## - petting: a heart, and the dog's fondness growing.
## What the family says of it at dinner: EveningManager. The thieves it
## chases: FarmSimulation, ChickenThiefManager. See docs/dog.md.

const DOG_SCENE := preload("res://entities/dog/dog.tscn")
## The dog's night, at its doghouse (minutes of the day).
const GUARD_FROM := 20 * 60
const GUARD_UNTIL := 6 * 60

var simulation: FarmSimulation
var player: PlayerController

var _panel: DogNamePanel
var _zone: ZoneRoot
var _house: DogHouse
var _dog: Dog
var _night := false
## The day it last came running in the morning.
var _greeted_day := -1
var _giver_name := "Rakoto"

func setup(p_simulation: FarmSimulation, world_manager: WorldManager, p_player: PlayerController,
		panel: DogNamePanel) -> void:
	simulation = p_simulation
	player = p_player
	_panel = panel
	var villagers := VillagerData.load_all()
	if villagers.has("rakoto"):
		_giver_name = villagers["rakoto"].display_name
	_panel.named.connect(_on_named)
	simulation.dog_adopted.connect(_on_adopted)
	simulation.dog_changed.connect(_on_dog_changed)
	simulation.time_changed.connect(func(_minute: int): _update())
	simulation.thief_alert_started.connect(func(_villager: String): _update())
	simulation.state_loaded.connect(func(): _greeted_day = -1)
	world_manager.zone_loaded.connect(_on_zone_loaded)
	world_manager.zone_unloading.connect(func(_zone_root: ZoneRoot):
		_zone = null
		_house = null
		_dog = null)

func get_dog() -> Dog:
	return _dog if is_instance_valid(_dog) else null

func get_dog_house() -> DogHouse:
	return _house

static func is_night(minute: int) -> bool:
	return minute >= GUARD_FROM or minute < GUARD_UNTIL

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_zone = zone
	_dog = null
	_house = zone.get_node_or_null("DogHouse") as DogHouse
	if _house != null:
		_house.bowl_interacted.connect(_on_bowl_interacted)
	_night = is_night(simulation.state.clock.minute_of_day)
	_refresh_house()
	_update(true)

func _on_adopted() -> void:
	AudioManager.play_dog_bark_sfx()
	_panel.open.call_deferred(simulation.get_dog_name(), _giver_name)

func _on_named(dog_name: String) -> void:
	# An empty name keeps the one it had.
	simulation.rename_dog(dog_name)
	UIEvents.notify(tr("%s fait partie de la famille ! Remplis sa gamelle, devant sa niche près de la maison.") % simulation.get_dog_name())

func _on_dog_changed() -> void:
	_refresh_house()
	if get_dog() != null:
		_dog.set_dog_name(simulation.get_dog_name())
	_update()

func _refresh_house() -> void:
	if _house == null:
		return
	_house.set_owned(simulation.has_dog())
	if simulation.has_dog():
		_house.show_bowl(simulation.is_dog_fed())

func _on_bowl_interacted() -> void:
	if simulation.feed_dog():
		UIEvents.notify(tr("Gamelle remplie : %s gardera la ferme cette nuit.") % simulation.get_dog_name())

func _on_petted() -> void:
	var hearts := simulation.get_dog_hearts()
	if not simulation.pet_dog():
		return
	if simulation.get_dog_hearts() > hearts:
		UIEvents.notify(tr("%s s'attache à toi : %d/%d.") % [simulation.get_dog_name(),
			simulation.get_dog_hearts(), FarmSimulation.DOG_MAX_HEARTS])

## Where the dog should be, now: nowhere, at the player's heels, or at its
## doghouse. `arriving`: the zone just loaded.
func _update(arriving := false) -> void:
	if _zone == null or not is_inside_tree():
		return
	var minute := simulation.state.clock.minute_of_day
	var night := is_night(minute)
	var nightfall := night and not _night
	_night = night
	var dog := get_dog()
	if not simulation.has_dog() or _zone.indoor:
		_remove_dog()
		return
	if night:
		if _house != null and simulation.is_dog_fed():
			if dog == null:
				dog = _spawn(_house.get_bed_position())
				dog.guard(_house.get_bed_position(), true)
			elif not dog.is_guarding():
				dog.guard(_house.get_bed_position())
			dog.restless = simulation.is_thief_alert()
		elif dog != null and dog.is_following() and nightfall:
			# Away from the farm, or not fed: off it goes, for the night.
			dog.leave(player)
			_dog = null
			UIEvents.notify(tr("%s rentre garder la ferme pour la nuit.") % simulation.get_dog_name()
				if simulation.is_dog_fed() else
				tr("%s a faim : il part chercher à manger chez les voisins.") % simulation.get_dog_name())
		elif dog != null and not dog.is_following():
			_remove_dog()
		return
	if dog == null:
		if _house != null and _greeted_day != simulation.state.day:
			# The first time at the farm today: it comes running.
			dog = _spawn(_house.get_bed_position())
			dog.follow(player)
			dog.bark(2)
		else:
			dog = _spawn(player.global_position)
			dog.follow(player)
			dog.put_near_player()
		_greeted_day = simulation.state.day
	elif not dog.is_following():
		dog.follow(player)
		dog.bark(2)
		_greeted_day = simulation.state.day

func _spawn(at: Vector2) -> Dog:
	_dog = DOG_SCENE.instantiate()
	_dog.name = "PlayerDog"
	_zone.add_child(_dog)
	_dog.global_position = at
	_dog.setup(simulation.get_dog_coat(), simulation.get_dog_growth(), simulation.get_dog_name())
	_dog.petted.connect(_on_petted)
	return _dog

func _remove_dog() -> void:
	if get_dog() != null:
		_dog.queue_free()
	_dog = null
