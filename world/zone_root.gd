class_name ZoneRoot
extends Node2D

## Root script for every zone scene (House/Exterior).
## Exposes camera bounds/zoom so WorldManager can fit the camera to each map's size,
## and which BGM track (if any) AudioManager should crossfade to on entry.

enum BGM { NONE, EXTERIOR, INTERIOR }

@export var camera_limit_left: int = -10000
@export var camera_limit_top: int = -10000
@export var camera_limit_right: int = 10000
@export var camera_limit_bottom: int = 10000
## Exteriors 1.05 (~23 x 13 tiles in view: room to plan fields and find
## your way), interiors ~1.4 (closer, cosier). One consistent value per kind
## of place - the player's on-screen size shouldn't jump around.
@export var camera_zoom: float = 1.05
@export var bgm: BGM = BGM.NONE
