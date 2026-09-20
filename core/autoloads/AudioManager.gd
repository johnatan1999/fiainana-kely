extends Node

## Autoload singleton (registered in project.godot [autoload]).
## Owns every audio player in the game: two crossfading BGM players,
## a pooled set of SFX players, and per-bus volume control.
## Scenes never touch AudioStreamPlayer directly - they call AudioManager.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const BGM_EXTERIOR: AudioStream = preload("res://assets/audio/BGM/Audio_BGM_Exterieur_Vorona_Kely.mp3")
const BGM_INTERIOR: AudioStream = preload("res://assets/audio/BGM/Audio_BGM_vorona-o-barijaona.ogg")

const DEFAULT_CROSSFADE_TIME := 1.5
const BGM_EXTERIOR_VOLUME := -3.0
const BGM_INTERIOR_VOLUME := -20.0

const SILENT_DB := -80.0
const SFX_POOL_SIZE := 8

## Assign these in the AudioManager.tscn inspector once SFX files exist.
## play_*_sfx() is a safe no-op while a slot is empty.
@export var sfx_till: AudioStream
@export var sfx_plant: AudioStream
@export var sfx_watering: AudioStream
@export var sfx_harvest: AudioStream
@export var sfx_interact: AudioStream
@export var sfx_menu_click: AudioStream
@export var sfx_chicken: AudioStream
@export var sfx_egg_pickup: AudioStream
@export var sfx_coop_build: AudioStream

@onready var _bgm_players: Array[AudioStreamPlayer] = [$BGMPlayerA, $BGMPlayerB]

var _sfx_pool: Array[AudioStreamPlayer] = []
var _active_bgm_index := 0
var _current_bgm_stream: AudioStream
var _bgm_tween: Tween


func _ready() -> void:
	# Autoloads must keep playing music through the pause menu's tree pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)

	for player in _bgm_players:
		player.bus = BUS_MUSIC
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_sfx_pool()

## An actively-looping AudioStreamMP3/OggVorbis still playing when the engine
## tears down the scene tree doesn't get a chance to release its playback
## cleanly, which Godot reports as a leaked resource at exit. Stopping every
## player here (called for every shutdown path: window close, --quit, or
## get_tree().quit() from the pause menu) avoids that.
func _exit_tree() -> void:
	for player in _bgm_players:
		player.stop()
		player.stream = null
	for player in _sfx_pool:
		player.stop()
		player.stream = null


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)


# ---------------------------------------------------------------------------
# BGM
# ---------------------------------------------------------------------------

func play_exterior_bgm(fade_time: float = DEFAULT_CROSSFADE_TIME) -> void:
	play_bgm(BGM_EXTERIOR, fade_time)


func play_interior_bgm(fade_time: float = DEFAULT_CROSSFADE_TIME) -> void:
	play_bgm(BGM_INTERIOR, fade_time)


## Crossfades from whatever is currently playing to `stream`. Calling it again
## with the same stream that is already active/fading in is a no-op, so zone
## re-entries don't restart or double-fade the track.
func play_bgm(stream: AudioStream, fade_time: float = DEFAULT_CROSSFADE_TIME) -> void:
	if stream == null or stream == _current_bgm_stream:
		return
	_current_bgm_stream = stream

	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis or stream is AudioStreamWAV:
		stream.loop = true

	var outgoing := _bgm_players[_active_bgm_index]
	_active_bgm_index = 1 - _active_bgm_index
	var incoming := _bgm_players[_active_bgm_index]

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	if _bgm_tween:
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	var target_volume := BGM_INTERIOR_VOLUME if stream == BGM_INTERIOR else BGM_EXTERIOR_VOLUME
	_bgm_tween.tween_property(incoming, "volume_db", target_volume, fade_time)
	if outgoing.playing:
		_bgm_tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_time)
		_bgm_tween.chain().tween_callback(outgoing.stop)


func stop_bgm(fade_time: float = DEFAULT_CROSSFADE_TIME) -> void:
	_current_bgm_stream = null
	var player := _bgm_players[_active_bgm_index]
	if not player.playing:
		return

	if _bgm_tween:
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(player, "volume_db", SILENT_DB, fade_time)
	_bgm_tween.tween_callback(player.stop)


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

func play_till_sfx() -> void:
	play_sfx(sfx_till)


func play_plant_sfx() -> void:
	play_sfx(sfx_plant)


func play_watering_sfx() -> void:
	play_sfx(sfx_watering)


func play_harvest_sfx() -> void:
	play_sfx(sfx_harvest)


func play_interact_sfx() -> void:
	play_sfx(sfx_interact)
	
func play_click_menu_sfx() -> void:
	play_sfx(sfx_menu_click)


func play_chicken_sfx() -> void:
	play_sfx(sfx_chicken)


func play_egg_pickup_sfx() -> void:
	play_sfx(sfx_egg_pickup)


func play_coop_build_sfx() -> void:
	play_sfx(sfx_coop_build)


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	var player := _find_free_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _find_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	# Pool exhausted: steal the oldest voice rather than silently drop the cue.
	return _sfx_pool[0]


# ---------------------------------------------------------------------------
# Volume (linear 0.0-1.0, safe to bind directly to an HSlider.value)
# ---------------------------------------------------------------------------

func set_master_volume(linear: float) -> void:
	_set_bus_volume("Master", linear)


func set_music_volume(linear: float) -> void:
	_set_bus_volume(BUS_MUSIC, linear)


func set_sfx_volume(linear: float) -> void:
	_set_bus_volume(BUS_SFX, linear)


func get_master_volume() -> float:
	return _get_bus_volume("Master")


func get_music_volume() -> float:
	return _get_bus_volume(BUS_MUSIC)


func get_sfx_volume() -> float:
	return _get_bus_volume(BUS_SFX)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))


func _get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
