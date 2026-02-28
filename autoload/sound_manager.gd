extends Node
# SoundManager — centralized audio for background music and sound effects.
# Preloads all audio files, provides play_*() methods for gameplay events.
# Uses a pool of AudioStreamPlayer nodes for overlapping SFX.
# Alternating counters ensure consecutive sounds always differ.

const SFX_POOL_SIZE := 8
const MUSIC_VOLUME_DB := -8.0      # music 100% (original level)
const SFX_VOLUME_DB := -16.0

# Music tracks
var _music_tracks: Array[AudioStream] = []
var _music_player: AudioStreamPlayer = null
var _current_track_index := -1

# SFX pool — shared AudioStreamPlayer nodes for overlapping sounds
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0

# Preloaded sound effects
var _sfx := {
	"shoot_pistol":  preload("res://audio/sfx/shoot_pistol.wav"),
	"shoot_rifle":   preload("res://audio/sfx/shoot_rifle.wav"),
	"shoot_heavy":   preload("res://audio/sfx/shoot_heavy.wav"),
	"shoot_auto":    preload("res://audio/sfx/shoot_auto.wav"),
	"headshot":      preload("res://audio/sfx/headshot.wav"),
	"ricochet1":     preload("res://audio/sfx/ricochet1.wav"),
	"ricochet2":     preload("res://audio/sfx/ricochet2.wav"),
	"boss_alarm":    preload("res://audio/sfx/boss_alarm.wav"),
	"powerup":       preload("res://audio/sfx/powerup.wav"),
	"coin":          preload("res://audio/sfx/coin.wav"),
	"player_die":    preload("res://audio/sfx/player_die.wav"),
	"game_over":     preload("res://audio/sfx/game_over.wav"),
	"stage_clear":   preload("res://audio/sfx/stage_clear.wav"),
	"fireball":      preload("res://audio/sfx/fireball.wav"),
	"oneup":         preload("res://audio/sfx/oneup.wav"),
	"warning":       preload("res://audio/sfx/warning.wav"),
	"its_me":        preload("res://audio/sfx/its_me.wav"),
	"countdown":     preload("res://audio/sfx/countdown.wav"),
	"jump":          preload("res://audio/sfx/jump.wav"),
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
		preload("res://audio/music/Foxholes & Hickory Trees.mp3"),
		preload("res://audio/music/Foxholes & Hickory 2.mp3"),
		preload("res://audio/music/Disco in the Trees.mp3"),
		preload("res://audio/music/Disco in the2.mp3"),
		preload("res://audio/music/Fighting Squirrel National Anthem.mp3"),
		preload("res://audio/music/Fighting Squirrel National Anthem(1).mp3"),
		preload("res://audio/music/Pixel Palace in 8 Bits.mp3"),
		preload("res://audio/music/Pixel Palace in 8 Bits(1).mp3"),
		preload("res://audio/music/Pixel Party em 8 Bits.mp3"),
		preload("res://audio/music/Pixel Party em 8 Bits(1).mp3"),
	]

	# Shuffle music order each run
	_music_tracks.shuffle()

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


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("skip_track"):
		skip_track()


# ── Music ─────────────────────────────────────────────────────────────────

func play_music() -> void:
	_play_next_track()


func stop_music() -> void:
	_music_player.stop()


func skip_track() -> void:
	_music_player.stop()
	_play_next_track()


func _play_next_track() -> void:
	if _music_tracks.is_empty():
		return
	_current_track_index = (_current_track_index + 1) % _music_tracks.size()
	_music_player.stream = _music_tracks[_current_track_index]
	_music_player.play()


func _on_music_finished() -> void:
	_play_next_track()


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

# Gunshots — 50% volume (-6 dB from previous -8 = -14 offset)
func play_shoot(bullet_type: String = "normal") -> void:
	_play_alternating(_shoot_all, "shoot", -14.0, 0.12)


# Called when any enemy dies — short impact
func play_enemy_death() -> void:
	_play_alternating(_enemy_death_sounds, "death", -4.0, 0.15)


# Called when player takes damage
func play_player_hit() -> void:
	_play_alternating(_hit_sounds, "hit", -2.0, 0.12)


# Called when player dies — SMB death jingle (200%)
func play_player_death() -> void:
	_play_sfx("player_die", 6.0, 0.0)


# Called when boss spawns — loud alarm siren
func play_boss_alarm() -> void:
	_play_sfx("boss_alarm", 16.0, 0.0)


# Power-up collected — SMB powerup sound (200%)
func play_powerup() -> void:
	_play_sfx("powerup", 6.0, 0.0)


# Coin/score bonus — SMB coin (200%)
func play_coin() -> void:
	_play_sfx("coin", 6.0, 0.0)


# Game over — SMB game over jingle (200%)
func play_game_over() -> void:
	_play_sfx("game_over", 6.0, 0.0)


# Boss defeated / stage clear — SMB stage clear (200%)
func play_stage_clear() -> void:
	_play_sfx("stage_clear", 6.0, 0.0)


# Thunder scroll AoE — fireball sound (200%)
func play_thunder() -> void:
	_play_sfx("fireball", 8.0, 0.05)


# 1-up / heal — SMB 1-up (200%)
func play_oneup() -> void:
	_play_sfx("oneup", 6.0, 0.0)


# Boss fight — SMB running out of time warning (200%)
func play_warning() -> void:
	_play_sfx("warning", 10.0, 0.0)


# Title screen — SM64 "It's-a me, Mario!" (200%)
func play_its_me() -> void:
	_play_sfx("its_me", 12.0, 0.0)


# Game start — MK64 countdown (200%)
func play_countdown() -> void:
	_play_sfx("countdown", 10.0, 0.0)


# Jump — SMB super jump (200%)
func play_jump() -> void:
	_play_sfx("jump", 6.0, 0.05)
