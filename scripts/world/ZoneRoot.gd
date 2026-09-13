class_name ZoneRoot
extends Node2D

## Root script for every zone scene (House/Exterior).
## Exposes camera bounds/zoom so WorldManager can fit the camera to each map's size.

@export var camera_limit_left: int = -10000
@export var camera_limit_top: int = -10000
@export var camera_limit_right: int = 10000
@export var camera_limit_bottom: int = 10000
@export var camera_zoom: float = 2.0
