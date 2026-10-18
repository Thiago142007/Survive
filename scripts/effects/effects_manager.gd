extends Node

const MAX_WORLD_PLAYERS := 12
const MAX_UI_PLAYERS := 4
const MAX_VFX := 24

signal effect_requested(effect_id: StringName, position: Vector3, spatial: bool)

var _catalog: Dictionary = {
	&"attack_swing": [
		preload("res://assets/audio/sfx/attack_swing_01.ogg"),
		preload("res://assets/audio/sfx/attack_swing_02.ogg"),
	],
	&"footstep_grass": [
		preload("res://assets/audio/sfx/footstep_grass_01.ogg"),
		preload("res://assets/audio/sfx/footstep_grass_02.ogg"),
		preload("res://assets/audio/sfx/footstep_grass_03.ogg"),
		preload("res://assets/audio/sfx/footstep_grass_04.ogg"),
	],
	&"wood_hit": [
		preload("res://assets/audio/sfx/wood_hit_01.ogg"),
		preload("res://assets/audio/sfx/wood_hit_02.ogg"),
		preload("res://assets/audio/sfx/wood_hit_03.ogg"),
	],
	&"stone_hit": [
		preload("res://assets/audio/sfx/stone_hit_01.ogg"),
		preload("res://assets/audio/sfx/stone_hit_02.ogg"),
		preload("res://assets/audio/sfx/stone_hit_03.ogg"),
	],
	&"animal_hit": [
		preload("res://assets/audio/sfx/animal_hit_01.ogg"),
		preload("res://assets/audio/sfx/animal_hit_02.ogg"),
		preload("res://assets/audio/sfx/animal_hit_03.ogg"),
	],
	&"animal_death": [preload("res://assets/audio/sfx/animal_death.ogg")],
	&"build_place": [
		preload("res://assets/audio/sfx/build_place_01.ogg"),
		preload("res://assets/audio/sfx/build_place_02.ogg"),
	],
	&"build_remove": [
		preload("res://assets/audio/sfx/build_remove_01.ogg"),
		preload("res://assets/audio/sfx/build_remove_02.ogg"),
	],
	&"build_repair": [preload("res://assets/audio/sfx/repair.ogg")],
	&"build_upgrade": [preload("res://assets/audio/sfx/upgrade.ogg")],
	&"player_hurt": [
		preload("res://assets/audio/sfx/player_hurt_01.ogg"),
		preload("res://assets/audio/sfx/player_hurt_02.ogg"),
	],
	&"player_down": [preload("res://assets/audio/sfx/player_down.ogg")],
	&"collect": [preload("res://assets/audio/sfx/collect.ogg")],
	&"ui_click": [preload("res://assets/audio/ui/ui_click.ogg")],
	&"ui_confirm": [preload("res://assets/audio/ui/ui_confirm.ogg")],
	&"ui_error": [preload("res://assets/audio/ui/ui_error.ogg")],
	&"ocean": [preload("res://assets/audio/ambience/ocean_loop.ogg")],
	&"wind": [preload("res://assets/audio/ambience/wind_loop.ogg")],
}

var _world_players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _ambience_players: Dictionary = {}
var _active_vfx: Array[Node3D] = []
var _world_recycle_cursor := 0
var _ui_recycle_cursor := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

func has_effect(effect_id: StringName) -> bool:
	return _catalog.has(effect_id)

func play_world(effect_id: StringName, position: Vector3) -> bool:
	if not has_effect(effect_id):
		push_warning("Unknown world effect: %s" % effect_id)
		return false
	var player := _acquire_world_player()
	player.global_position = position
	_configure_short_player(player, effect_id)
	player.play()
	effect_requested.emit(effect_id, position, true)
	return true

func play_ui(effect_id: StringName) -> bool:
	if not has_effect(effect_id):
		push_warning("Unknown UI effect: %s" % effect_id)
		return false
	var player := _acquire_ui_player()
	player.stream = _choose_stream(effect_id)
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.play()
	effect_requested.emit(effect_id, Vector3.ZERO, false)
	return true

func start_ambience(effect_id: StringName) -> bool:
	if not has_effect(effect_id):
		push_warning("Unknown ambience effect: %s" % effect_id)
		return false
	if _ambience_players.has(effect_id):
		var existing := _ambience_players[effect_id] as AudioStreamPlayer
		if not existing.playing:
			existing.play()
		return true
	var player := AudioStreamPlayer.new()
	player.name = "Ambience_%s" % effect_id
	player.bus = &"Ambience"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream := _choose_stream(effect_id).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	player.stream = stream
	add_child(player)
	_ambience_players[effect_id] = player
	player.play()
	effect_requested.emit(effect_id, Vector3.ZERO, false)
	return true

func stop_ambience(effect_id: StringName = &"") -> void:
	if effect_id == &"":
		for player in _ambience_players.values():
			(player as AudioStreamPlayer).stop()
			(player as AudioStreamPlayer).queue_free()
		_ambience_players.clear()
		return
	if not _ambience_players.has(effect_id):
		return
	var player := _ambience_players[effect_id] as AudioStreamPlayer
	player.stop()
	player.queue_free()
	_ambience_players.erase(effect_id)

func spawn_vfx(vfx_id: StringName, _position: Vector3) -> bool:
	push_warning("Unknown VFX: %s" % vfx_id)
	return false

func get_world_pool_size() -> int:
	return _world_players.size()

func get_ui_pool_size() -> int:
	return _ui_players.size()

func get_ambience_count() -> int:
	return _ambience_players.size()

func get_active_vfx_count() -> int:
	return _active_vfx.size()

func _acquire_world_player() -> AudioStreamPlayer3D:
	for player in _world_players:
		if not player.playing:
			return player
	if _world_players.size() < MAX_WORLD_PLAYERS:
		var player := AudioStreamPlayer3D.new()
		player.name = "WorldSFX_%02d" % _world_players.size()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.max_distance = 32.0
		player.unit_size = 3.0
		add_child(player)
		_world_players.append(player)
		return player
	var recycled := _world_players[_world_recycle_cursor]
	_world_recycle_cursor = (_world_recycle_cursor + 1) % MAX_WORLD_PLAYERS
	return recycled

func _acquire_ui_player() -> AudioStreamPlayer:
	for player in _ui_players:
		if not player.playing:
			return player
	if _ui_players.size() < MAX_UI_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "UISFX_%02d" % _ui_players.size()
		player.bus = &"UI"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_ui_players.append(player)
		return player
	var recycled := _ui_players[_ui_recycle_cursor]
	_ui_recycle_cursor = (_ui_recycle_cursor + 1) % MAX_UI_PLAYERS
	return recycled

func _configure_short_player(player: AudioStreamPlayer3D, effect_id: StringName) -> void:
	player.stream = _choose_stream(effect_id)
	player.pitch_scale = _rng.randf_range(0.94, 1.06)
	player.volume_db = _rng.randf_range(-1.5, 0.5)

func _choose_stream(effect_id: StringName) -> AudioStream:
	var streams: Array = _catalog[effect_id]
	return streams[_rng.randi_range(0, streams.size() - 1)] as AudioStream
