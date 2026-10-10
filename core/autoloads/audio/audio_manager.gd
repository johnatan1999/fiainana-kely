extends Node

## Autoload singleton (registered in project.godot [autoload]).
## Owns every audio player in the game: two crossfading BGM players,
## a pooled set of SFX players, and per-bus volume control.
## Scenes never touch AudioStreamPlayer directly - they call AudioManager.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const BGM_EXTERIOR: AudioStream = preload("res://assets/audio/BGM/Audio_BGM_Exterior_Vorona_Kely.mp3")
const BGM_INTERIOR: AudioStream = preload("res://assets/audio/BGM/Audio_BGM_vorona-o-barijaona.ogg")

const DEFAULT_CROSSFADE_TIME := 1.5
const BGM_EXTERIOR_VOLUME := -3.0
const BGM_INTERIOR_VOLUME := -20.0

const SILENT_DB := -80.0
const SFX_POOL_SIZE := 8

## Footsteps repeat constantly, so they sit well under the one-off SFX.
## Walk and run use their own recordings (all slices level-matched to the
## same loudness, so these two values are the only walk/run balance knob).
## Per-step variety (which sample, pitch and volume jitter, never the same
## sample twice in a row) comes from sfx_footstep_walk/_run being
## AudioStreamRandomizers - see assets/audio/SFX/footstep_*_randomizer.tres.
const FOOTSTEP_WALK_VOLUME_DB := -10.0
const FOOTSTEP_RUN_VOLUME_DB := -7.0
## The denied sound is mastered hot (peaks at 0 dBFS) and can be spammed by
## pressing E repeatedly - kept well under the regular SFX.
const ACTION_DENIED_VOLUME_DB := -8.0
## Birds taking off (AmbientBird). Several startled at once make one
## flutter, not a pile-up: at most one every BIRD_FLIGHT_MIN_INTERVAL.
const BIRD_FLIGHT_VOLUME_DB := -6.0
const BIRD_FLIGHT_MIN_INTERVAL := 0.6

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
@export var sfx_footstep_walk: AudioStream
@export var sfx_footstep_run: AudioStream
@export var sfx_action_denied: AudioStream
@export var sfx_bird_flight: AudioStream
## The family's dog barking (Dog). Empty = a bark generated in code
## (_make_bark) stands in until a recording is assigned.
@export var sfx_dog_bark: AudioStream
## Looping rain sound (WeatherController). Empty = a rain hiss generated in
## code stands in until a recording is assigned.
@export var bgs_rain: AudioStream

@onready var _bgm_players: Array[AudioStreamPlayer] = [$BGMPlayerA, $BGMPlayerB]

var _sfx_pool: Array[AudioStreamPlayer] = []
var _active_bgm_index := 0
var _current_bgm_stream: AudioStream
var _bgm_tween: Tween
var _last_bird_flight_msec := -100000

const RAIN_VOLUME_DB := -14.0
## Heard from indoors: quieter.
const RAIN_MUFFLED_VOLUME_DB := -24.0
const RAIN_FADE_TIME := 1.5
const RAIN_MIX_RATE := 22050.0
var _rain_player: AudioStreamPlayer
var _rain_playback: AudioStreamGeneratorPlayback
var _rain_tween: Tween
## Generated rain: filtered noise, plus the odd louder drop.
var _rain_lowpass := 0.0
var _rain_drop := 0.0


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

## Quitting with sounds playing: stop() doesn't free a playback at once - it
## hands it to the audio thread, which drops it on its next mix. If the
## engine shuts the AudioServer down with playbacks still waiting (many of
## them when the game runs faster than real time, --fixed-fps in the tests),
## they leak - and now and then the mix thread touches them while they're
## torn down: a crash on exit (signal 11, no trace). So every player is
## stopped here (called on every way out: window closed, "Quitter",
## get_tree().quit()), then the audio thread gets SHUTDOWN_FLUSH_MSEC of real
## time to drop them, before anything else is torn down.
const SHUTDOWN_FLUSH_MSEC := 120

func _exit_tree() -> void:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_bgm_players)
	players.append_array(_sfx_pool)
	if _rain_player != null:
		players.append(_rain_player)
	for player in players:
		player.stop()
		player.stream = null
	_rain_playback = null
	OS.delay_msec(SHUTDOWN_FLUSH_MSEC)


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


func play_bird_flight_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_bird_flight_msec < BIRD_FLIGHT_MIN_INTERVAL * 1000.0:
		return
	_last_bird_flight_msec = now
	play_sfx(sfx_bird_flight, BIRD_FLIGHT_VOLUME_DB, randf_range(0.9, 1.15))


## Starts or stops the rain's sound, fading. `muffled`: heard from indoors.
func set_rain_ambience(active: bool, muffled := false) -> void:
	if _rain_player == null:
		_rain_player = AudioStreamPlayer.new()
		_rain_player.bus = BUS_SFX
		_rain_player.volume_db = SILENT_DB
		add_child(_rain_player)
	if _rain_tween:
		_rain_tween.kill()
	if active and not _rain_player.playing:
		if bgs_rain:
			_rain_player.stream = bgs_rain
		else:
			var generator := AudioStreamGenerator.new()
			generator.mix_rate = RAIN_MIX_RATE
			generator.buffer_length = 0.3
			_rain_player.stream = generator
		_rain_player.play()
		_rain_playback = _rain_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var target := (RAIN_MUFFLED_VOLUME_DB if muffled else RAIN_VOLUME_DB) if active else SILENT_DB
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", target, RAIN_FADE_TIME)
	if not active:
		_rain_tween.tween_callback(_rain_player.stop)

func _process(_delta: float) -> void:
	if _rain_playback == null or not _rain_player.playing or bgs_rain != null:
		return
	# Brown-ish noise (low-passed) for the hiss, a little white noise on top,
	# and now and then a louder drop decaying fast.
	for i in _rain_playback.get_frames_available():
		var white := randf_range(-1.0, 1.0)
		_rain_lowpass = lerpf(_rain_lowpass, white, 0.12)
		if randf() < 0.0004:
			_rain_drop = randf_range(0.3, 0.6)
		_rain_drop *= 0.992
		var sample := _rain_lowpass * 0.9 + white * 0.08 + white * _rain_drop
		_rain_playback.push_frame(Vector2(sample, sample))


## One "woof", `volume_db` from how far the dog is (Dog). Pitch varies a
## little, so a run of barks doesn't sound like a loop.
func play_dog_bark_sfx(volume_db := 0.0) -> void:
	if sfx_dog_bark == null:
		sfx_dog_bark = _make_bark()
	play_sfx(sfx_dog_bark, volume_db + DOG_BARK_VOLUME_DB, randf_range(0.92, 1.1))

const DOG_BARK_VOLUME_DB := -6.0
const BARK_MIX_RATE := 22050

## A placeholder bark: a short buzzy tone (rising, then falling, as a
## bark's pitch does), a breath of noise at the attack, a fast decay -
## through a gentle low-pass.
func _make_bark() -> AudioStreamWAV:
	var length := int(BARK_MIX_RATE * 0.2)
	var data := PackedByteArray()
	data.resize(length * 2)
	var phase := 0.0
	var low := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in length:
		var t := float(i) / BARK_MIX_RATE
		var pitch := lerpf(330.0, 560.0, t / 0.03) if t < 0.03 else lerpf(560.0, 280.0, (t - 0.03) / 0.17)
		phase += TAU * pitch / BARK_MIX_RATE
		var tone := 0.0
		for h in 6:
			tone += sin(phase * (h + 1)) * [1.0, 0.8, 0.6, 0.45, 0.3, 0.2][h]
		var noise := rng.randf_range(-1.0, 1.0) * (0.9 if t < 0.025 else 0.25)
		var envelope := minf(t / 0.006, 1.0) * exp(-maxf(t - 0.04, 0.0) / 0.045)
		low = lerpf(low, (tone * 0.3 + noise) * envelope, 0.45)
		data.encode_s16(i * 2, int(clampf(low * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = BARK_MIX_RATE
	wav.data = data
	return wav

func play_chicken_sfx() -> void:
	play_sfx(sfx_chicken)


func play_egg_pickup_sfx() -> void:
	play_sfx(sfx_egg_pickup)


func play_coop_build_sfx() -> void:
	play_sfx(sfx_coop_build)


## Pressing E on something the current tool can't act on (red plot highlight).
func play_action_denied_sfx() -> void:
	play_sfx(sfx_action_denied, ACTION_DENIED_VOLUME_DB)


func play_footstep_sfx(running: bool) -> void:
	if running:
		play_sfx(sfx_footstep_run, FOOTSTEP_RUN_VOLUME_DB)
	else:
		play_sfx(sfx_footstep_walk, FOOTSTEP_WALK_VOLUME_DB)


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
