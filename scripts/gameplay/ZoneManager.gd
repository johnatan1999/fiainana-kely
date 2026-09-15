class_name ZoneManager
extends Node

## Bridges on-site land purchase panels (ZoneSign/ModularZoneSign) to
## FarmSimulation's dynamic tile grid (FarmSimulation.add_tile/expand_grid).
## Land is no longer sold through the Shop - the player buys it by walking
## up to a physical panel in the world.
##
## Two purchase modes:
## - Predefined zones (macro progression): a fixed rectangle of tiles,
##   unlocked all at once for a flat price. The player picks WHICH zone to
##   buy, never where its tiles land - that's baked into FarmZoneData.
## - The progressive zone (micro progression): one large dedicated area the
##   player expands into a few tiles at a time (1 / 3x3 / 5x5 patches). Tiles
##   always unlock in a fixed left-to-right, row-by-row order - the player
##   never chooses the location, only how many tiles to buy.
##
## Never touches Node2D directly except the small visual markers/signs it's
## handed via set_zone_markers() - all economy rules go through
## FarmSimulation.

signal zone_unlocked(zone_id: String)
signal progressive_tiles_changed(unlocked_count: int)

## load(), not preload(): preloading a custom-scripted Resource from inside
## another class's top-level const can race that script's own compilation
## during a fresh project scan, silently loading it with its exports unset.
## Deferring to a runtime load() in setup() sidesteps that entirely.
const PREDEFINED_ZONE_PATHS := [
	"res://data/zones/zone_east.tres",
	"res://data/zones/zone_south.tres",
]

## Rectangle (in the same grid space as FarmSimulation plot positions) set
## aside for progressive, tile-by-tile expansion.
const PROGRESSIVE_ORIGIN := Vector2i(0, 9)
const PROGRESSIVE_WIDTH := 8
const PROGRESSIVE_HEIGHT := 6

var simulation: FarmSimulation
var player: PlayerController

var _predefined_zones: Array = [] # Array[FarmZoneData], loaded in setup()
var _zone_by_id: Dictionary = {} # zone_id: String -> FarmZoneData
var _progressive_sequence: Array = [] # Array[Vector2i], fixed unlock order

## zone_id -> {rect: ColorRect, label: Label} for the currently loaded zone
## (Exterior). Rebuilt by set_zone_markers() each time that zone loads.
var _predefined_markers: Dictionary = {}
var _progressive_marker_rect: ColorRect
var _progressive_marker_label: Label

func setup(p_simulation: FarmSimulation, p_player: PlayerController) -> void:
	simulation = p_simulation
	player = p_player
	for path in PREDEFINED_ZONE_PATHS:
		var zone_data = load(path)
		_predefined_zones.append(zone_data)
		_zone_by_id[zone_data.id] = zone_data
	_progressive_sequence = _build_progressive_sequence()

func _build_progressive_sequence() -> Array:
	var sequence: Array = []
	for y in range(PROGRESSIVE_HEIGHT):
		for x in range(PROGRESSIVE_WIDTH):
			sequence.append(PROGRESSIVE_ORIGIN + Vector2i(x, y))
	return sequence

func get_predefined_zones() -> Array:
	return _predefined_zones

func get_zone_data(zone_id: String) -> FarmZoneData:
	return _zone_by_id.get(zone_id)

func is_zone_unlocked(zone_id: String) -> bool:
	return simulation.state.unlocked_zone_ids.has(zone_id)

func get_progressive_unlocked_count() -> int:
	return simulation.state.progressive_tiles_unlocked

func get_progressive_capacity() -> int:
	return _progressive_sequence.size()

## Unlocks every tile of a predefined zone at once. Fails if it's already
## owned, unknown, or unaffordable.
func buy_zone(zone_id: String) -> bool:
	if is_zone_unlocked(zone_id):
		return false
	var zone_data := get_zone_data(zone_id)
	if zone_data == null:
		return false
	if not simulation.spend_money(zone_data.price):
		return false

	simulation.state.unlocked_zone_ids[zone_id] = true
	for coordinates: Vector2i in zone_data.get_tile_coordinates():
		simulation.add_tile(coordinates.x, coordinates.y)

	zone_unlocked.emit(zone_id)
	_refresh_predefined_marker(zone_id)
	return true

## Unlocks the next `patch_size` tiles of the progressive zone, in their
## fixed order. Fails if that would run past the zone's capacity, or the
## player can't afford total_price. total_price is supplied by the caller
## (the ShopItemData's price) rather than computed here, so there's a single
## source of truth for pricing - the shop catalog.
func buy_progressive_patch(patch_size: int, total_price: int) -> bool:
	if patch_size <= 0:
		return false
	var unlocked := get_progressive_unlocked_count()
	if unlocked + patch_size > _progressive_sequence.size():
		return false
	if not simulation.spend_money(total_price):
		return false

	for i in range(patch_size):
		var coordinates: Vector2i = _progressive_sequence[unlocked + i]
		simulation.add_tile(coordinates.x, coordinates.y)
	simulation.state.progressive_tiles_unlocked = unlocked + patch_size

	progressive_tiles_changed.emit(simulation.state.progressive_tiles_unlocked)
	_refresh_progressive_marker()
	return true

## Called by WorldManager whenever a zone containing land markers/signs
## (Exterior) is loaded/unloaded, exactly like AnimalManager.set_farm_area().
## Markers and signs are both optional - a zone without them still works,
## it just shows/offers nothing.
func set_zone_markers(zone: Node) -> void:
	_predefined_markers.clear()
	_progressive_marker_rect = null
	_progressive_marker_label = null
	if zone == null:
		return

	for zone_data in _predefined_zones:
		var marker_root: Node = zone.get_node_or_null("ZoneMarker_%s" % zone_data.id)
		if marker_root == null:
			continue
		var rect: ColorRect = marker_root.get_node_or_null("Rect")
		var label: Label = marker_root.get_node_or_null("Label")
		if rect and label:
			_predefined_markers[zone_data.id] = {"rect": rect, "label": label}

	var progressive_root: Node = zone.get_node_or_null("ProgressiveZoneMarker")
	if progressive_root:
		_progressive_marker_rect = progressive_root.get_node_or_null("Rect")
		_progressive_marker_label = progressive_root.get_node_or_null("Label")

	for zone_id in _predefined_markers:
		_refresh_predefined_marker(zone_id)
	_refresh_progressive_marker()

	_setup_signs(zone)

## Purchases now happen exclusively through on-site ZoneSign/ModularZoneSign
## panels (no more Shop integration) - wire up whichever of them exist in
## the freshly-loaded zone.
func _setup_signs(zone: Node) -> void:
	for child in zone.get_children():
		if child is ZoneSign:
			child.setup(player, self)
		elif child is ModularZoneSign:
			child.setup(player, self)

func _refresh_predefined_marker(zone_id: String) -> void:
	var marker: Dictionary = _predefined_markers.get(zone_id, {})
	if marker.is_empty():
		return
	var zone_data := get_zone_data(zone_id)
	var unlocked := is_zone_unlocked(zone_id)
	var rect: ColorRect = marker["rect"]
	var label: Label = marker["label"]

	if unlocked:
		rect.color = Color(0.45, 0.65, 0.25, 0.35)
		label.text = "%s (débloqué)" % zone_data.display_name
		_play_unlock_flash(rect)
	else:
		rect.color = Color(0.3, 0.3, 0.3, 0.55)
		label.text = "%s — %d $ (voir le panneau)" % [zone_data.display_name, zone_data.price]

func _refresh_progressive_marker() -> void:
	if _progressive_marker_label == null:
		return
	_progressive_marker_label.text = "Zone d'expansion : %d / %d parcelles (voir le panneau)" % [
		get_progressive_unlocked_count(), get_progressive_capacity(),
	]
	if _progressive_marker_rect:
		_play_unlock_flash(_progressive_marker_rect)

## Small visual "feedback" pulse on the marker rect when land is unlocked.
func _play_unlock_flash(rect: ColorRect) -> void:
	var base_color := rect.color
	var tween := create_tween()
	tween.tween_property(rect, "color", Color(1.0, 1.0, 0.6, 0.7), 0.15)
	tween.tween_property(rect, "color", base_color, 0.3)
