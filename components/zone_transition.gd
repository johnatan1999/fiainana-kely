class_name ZoneTransition
extends Area2D

## Placed at doors/exits. Walking into it asks WorldManager to switch zones.
## Both fields are meant to always be set explicitly per door instance -
## there's no implicit fallback here (WorldManager warns loudly if either is
## missing instead of silently guessing a destination).
##
## Shared interiors: one interior can serve many houses, so its exit can't
## name a single house door. Its exit sets `back_to_entrance`: it leads back
## through whichever door the player came in by (see `return_point`), and
## target_zone/target_spawn are only the fallback when that's unknown.

signal triggered(target_zone: String, target_spawn: String)

const DEFAULT_TRANSITION_SOUND := preload("res://assets/audio/SFX/Audio_SFX_Transition.wav")

@export var target_zone: String = ""
@export var target_spawn: String = ""
## Leads back out through the door the player came in by (shared interiors).
@export var back_to_entrance: bool = false
## A door that doesn't open (decorative house): walking into it only gives a
## "locked" cue. Door checks skip it - it leads nowhere on purpose.
@export var locked: bool = false

## Where the player reappears when they come back out through a
## `back_to_entrance` exit - set by whoever owns the door (House), not
## saved in scenes.
var return_point: Marker2D

@export_group("Sound")
## Played the moment the player walks in, in sync with the fade to black.
## Defaults to the generic transition whoosh - doors override it (see
## components/door/entrance_door.tscn and House.tscn's EnterHouse). Clear it
## for a silent transition.
@export var transition_sound: AudioStream = DEFAULT_TRANSITION_SOUND
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var transition_volume_db: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		if locked:
			AudioManager.play_action_denied_sfx()
			return
		# Through AudioManager's pooled players, not a player on this node:
		# the zone (and this node) is freed mid-transition, the sound isn't.
		AudioManager.play_sfx(transition_sound, transition_volume_db)
		triggered.emit(target_zone, target_spawn)
