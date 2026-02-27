extends Node2D
# Main game scene — spawns multiple enemy types in escalating waves,
# drops stacking weapon upgrades, tracks score and stats.
# Batch spawning increases over time for more enemies on screen.
# Background music plays random tracks in a loop via SoundManager.

const SPAWN_MARGIN := 50.0
const MIN_SPAWN_INTERVAL := 0.30
const BASE_SPAWN_INTERVAL := 1.0
const UPGRADE_DROP_CHANCE := 0.3

var enemy_scenes := {
	"squirrel": preload("res://scenes/enemies/squirrel.tscn"),
	"rat":      preload("res://scenes/enemies/rat.tscn"),
	"mole":     preload("res://scenes/enemies/mole.tscn"),
	"raccoon":  preload("res://scenes/enemies/raccoon.tscn"),
}

var pickup_scene: PackedScene = preload("res://scenes/pickup/pickup.tscn")

var score: int = 0
var game_over := false
var elapsed_time := 0.0
var enemies_killed := 0

# Spawn weights: [current_weight, seconds_until_unlocked]
# Earlier unlocks: rat at 5s, mole at 20s, raccoon at 35s
var enemy_weights := {
	"squirrel": [10, 0.0],
	"rat":      [0,  5.0],
	"mole":     [0,  20.0],
	"raccoon":  [0,  35.0],
}

var upgrade_types := ["spread", "rapid", "pierce", "bigshot", "homing", "orbit", "rear"]

@onready var player: CharacterBody2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	Stats.reset()
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.mods_changed.connect(_on_mods_changed)
	spawn_timer.wait_time = BASE_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	hud.update_health(player.health)
	hud.update_mods(player.mods)

	# Start background music
	SoundManager.play_music()


func _process(delta: float) -> void:
	if game_over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if game_over:
		return

	elapsed_time += delta
	_update_enemy_weights()

	# Continuously reduce spawn interval
	var new_interval := BASE_SPAWN_INTERVAL - (elapsed_time * 0.012)
	spawn_timer.wait_time = maxf(new_interval, MIN_SPAWN_INTERVAL)


# ── Enemy weight ramping ─────────────────────────────────────────────────

func _update_enemy_weights() -> void:
	for enemy_name: String in enemy_weights:
		var data: Array = enemy_weights[enemy_name]
		var min_time: float = data[1]
		if elapsed_time >= min_time:
			match enemy_name:
				"squirrel":
					data[0] = 10
				"rat":
					data[0] = mini(int((elapsed_time - min_time) * 0.5), 10)
				"mole":
					data[0] = mini(int((elapsed_time - min_time) * 0.2), 5)
				"raccoon":
					data[0] = mini(int((elapsed_time - min_time) * 0.15), 5)


func _pick_enemy_type() -> String:
	var total_weight := 0
	for data: Array in enemy_weights.values():
		total_weight += data[0] as int
	if total_weight <= 0:
		return "squirrel"
	var roll := randi() % total_weight
	var cumulative := 0
	for enemy_name: String in enemy_weights:
		cumulative += enemy_weights[enemy_name][0] as int
		if roll < cumulative:
			return enemy_name
	return "squirrel"


# ── Spawning — batch spawns scale with time ──────────────────────────────

func _on_spawn_timer_timeout() -> void:
	if game_over:
		return

	# Batch size: start at 2, ramp faster — 3 at 20s, 4 at 50s, 5 at 90s
	var batch := 2
	if elapsed_time > 20.0:
		batch = 3
	if elapsed_time > 50.0:
		batch = 4
	if elapsed_time > 90.0:
		batch = 5

	var vp := get_viewport_rect().size
	for _i in range(batch):
		_spawn_one_enemy(vp)


func _spawn_one_enemy(vp: Vector2) -> void:
	var enemy_type := _pick_enemy_type()
	var scene: PackedScene = enemy_scenes[enemy_type]
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = _random_edge_position(vp)
	enemy.killed.connect(_on_enemy_killed.bind(enemy, enemy_type))
	add_child(enemy)

	# Rats sometimes bring a friend
	if enemy_type == "rat" and randf() < 0.4:
		var rat_scene: PackedScene = enemy_scenes["rat"]
		var rat2: Node2D = rat_scene.instantiate()
		rat2.global_position = _random_edge_position(vp)
		rat2.killed.connect(_on_enemy_killed.bind(rat2, "rat"))
		add_child(rat2)


func _random_edge_position(vp: Vector2) -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, vp.x), -SPAWN_MARGIN)
		1: return Vector2(randf_range(0, vp.x), vp.y + SPAWN_MARGIN)
		2: return Vector2(-SPAWN_MARGIN, randf_range(0, vp.y))
		3: return Vector2(vp.x + SPAWN_MARGIN, randf_range(0, vp.y))
	return Vector2.ZERO


# ── Kill handling + upgrade drops ────────────────────────────────────────

func _on_enemy_killed(value: int, enemy: Node2D, enemy_type: String) -> void:
	score += value
	enemies_killed += 1
	hud.update_score(score)

	# Record in stats tracker
	Stats.record_kill(enemy_type.capitalize(), value)

	# Play death explosion sound
	SoundManager.play_enemy_death()

	# Drop chance — tougher enemies drop more often
	var drop_chance := UPGRADE_DROP_CHANCE
	match enemy_type:
		"mole":    drop_chance = 0.55
		"raccoon": drop_chance = 0.45
		"rat":     drop_chance = 0.20

	if randf() < drop_chance and is_instance_valid(enemy):
		_spawn_pickup(enemy.global_position)


func _spawn_pickup(pos: Vector2) -> void:
	var pickup: Node2D = pickup_scene.instantiate()
	pickup.global_position = pos
	pickup.weapon_type = upgrade_types[randi() % upgrade_types.size()]
	pickup.collected.connect(_on_pickup_collected)
	add_child(pickup)


func _on_pickup_collected(mod_name: String) -> void:
	player.add_mod(mod_name)
	Stats.record_pickup(mod_name, player.mods[mod_name])


func _on_player_health_changed(new_health: int) -> void:
	hud.update_health(new_health)


func _on_mods_changed(mods: Dictionary) -> void:
	hud.update_mods(mods)


func _on_player_died() -> void:
	game_over = true
	spawn_timer.stop()
	hud.show_game_over(score, enemies_killed)
	player.set_physics_process(false)
	# Play player death sound
	SoundManager.play_player_death()
