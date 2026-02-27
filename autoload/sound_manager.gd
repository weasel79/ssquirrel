extends Node
# SoundManager — centralized audio for background music and sound effects.
# Preloads all audio files, provides play_*() methods for gameplay events.
# Uses a pool of AudioStreamPlayer nodes for overlapping SFX.
# Alternating counters ensure consecutive sounds always differ.

const SFX_POOL_SIZE := 8
const MUSIC_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0

# Music tracks
var _music_tracks: Array[AudioStream] = []
var _music_player: AudioStreamPlayer = null
var _current_track_index := -1

# SFX pool — shared AudioStreamPlayer nodes for overlapping sounds
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0

# Preloaded sound effects — short, punchy sounds only
var _sfx := {
	"shoot_pistol":  preload("res://audio/sfx/shoot_pistol.wav"),
	"shoot_rifle":   preload("res://audio/sfx/shoot_rifle.wav"),
	"shoot_heavy":   preload("res://audio/sfx/shoot_heavy.wav"),
	"shoot_auto":    preload("res://audio/sfx/shoot_auto.wav"),
	"headshot":      preload("res://audio/sfx/headshot.wav"),
	"ricochet1":     preload("res://audio/sfx/ricochet1.wav"),
	"ricochet2":     preload("res://audio/sfx/ricochet2.wav"),
}

# Alternating counters — each category cycles through its list
var _shoot_alt := 0
var _death_alt := 0
var _hit_alt := 0

# Shoot sounds: all 4 guns alternate in round-robin
var _shoot_all: Array[String] = ["shoot_pistol", "shoot_rifle", "shoot_auto", "shoot_heavy"]
# Enemy death: short impact sounds, alternating
var _enemy_death_sounds: Array[String] = ["ricochet1", "headshot", "ricochet2"]
# Player hit: alternating ricochets
var _hit_sounds: Array[String] = ["ricochet1", "ricochet2"]


func _ready() -> void:
	# Load music tracks
	_music_tracks = [
		preload("res://audio/music/fight_club_in_the_trees.mp3"),
		preload("res://audio/music/fight_club_in_the_trees_2.mp3"),
		preload("res://audio/music/neon_nut_rage.mp3"),
		preload("res://audio/music/neon_nut_rage_2.mp3"),
	]

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_pool.append(player)


# ── Music ─────────────────────────────────────────────────────────────────

func play_music() -> void:
	_play_random_track()


func stop_music() -> void:
	_music_player.stop()


func _play_random_track() -> void:
	if _music_tracks.is_empty():
		return
	var idx := randi() % _music_tracks.size()
	while idx == _current_track_index and _music_tracks.size() > 1:
		idx = randi() % _music_tracks.size()
	_current_track_index = idx
	_music_player.stream = _music_tracks[idx]
	_music_player.play()


func _on_music_finished() -> void:
	_play_random_track()


# ── SFX helpers ───────────────────────────────────────────────────────────

func _play_sfx(sound_name: String, volume_offset: float = 0.0, pitch_vary: float = 0.1) -> void:
	if sound_name not in _sfx:
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = _sfx[sound_name]
	player.volume_db = SFX_VOLUME_DB + volume_offset
	player.pitch_scale = randf_range(1.0 - pitch_vary, 1.0 + pitch_vary)
	player.play()


# Play next sound in a list using an alternating counter
func _play_alternating(list: Array[String], counter_name: String,
		volume_offset: float = 0.0, pitch_vary: float = 0.1) -> void:
	if list.is_empty():
		return
	var idx := 0
	match counter_name:
		"shoot":
			idx = _shoot_alt % list.size()
			_shoot_alt += 1
		"death":
			idx = _death_alt % list.size()
			_death_alt += 1
		"hit":
			idx = _hit_alt % list.size()
			_hit_alt += 1
	_play_sfx(list[idx], volume_offset, pitch_vary)


# ── Public gameplay SFX methods ───────────────────────────────────────────

# Called when player shoots — cycles through all 4 gun sounds
func play_shoot(bullet_type: String = "normal") -> void:
	_play_alternating(_shoot_all, "shoot", -8.0, 0.12)


# Called when any enemy dies — short impact, no explosions
func play_enemy_death() -> void:
	_play_alternating(_enemy_death_sounds, "death", -4.0, 0.15)


# Called when player takes damage
func play_player_hit() -> void:
	_play_alternating(_hit_sounds, "hit", -2.0, 0.12)


# Called when player dies
func play_player_death() -> void:
	_play_sfx("headshot", 0.0, 0.05)
