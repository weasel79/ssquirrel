extends CharacterBody2D
# Player character — top-down movement with stacking weapon mods.
# Each mod can be leveled 1→2→3 by collecting the same pickup again.
# All active mods apply simultaneously when shooting.

signal died
signal health_changed(new_health: int)
signal mods_changed(mods: Dictionary)

const SPEED := 120.0
const MAX_HEALTH := 5
const INVINCIBLE_DURATION := 0.8
const BASE_SHOOT_INTERVAL := 0.40
const MAX_MOD_LEVEL := 3

# Active weapon mods — 0 = not collected, 1-3 = level
var mods := {
	"spread":  0,
	"rapid":   0,
	"pierce":  0,
	"bigshot": 0,
	"homing":  0,
	"orbit":   0,
	"rear":    0,
}

var health: int = MAX_HEALTH
var invincible := false

# Orbit system state
var orbit_bullets: Array[Node2D] = []
var orbit_angle := 0.0

@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: Sprite2D = $Sprite2D

var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")
var orbit_scene: PackedScene = preload("res://scenes/projectile/orbit_bullet.tscn")


func _ready() -> void:
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	_recalculate_fire_rate()


func _physics_process(delta: float) -> void:
	# 8-directional movement
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	velocity = input_dir.normalized() * SPEED
	move_and_slide()

	# Keep player inside viewport
	var vp := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(12, 12), vp - Vector2(12, 12))

	# Flash while invincible
	if invincible:
		sprite.modulate.a = 0.4 if fmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0 else 1.0
	else:
		sprite.modulate.a = 1.0

	# Rotate orbit bullets around player
	if mods["orbit"] > 0:
		orbit_angle += delta * 3.0
		_update_orbit_bullets()


# ── Targeting ────────────────────────────────────────────────────────────

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


# ── Shooting (all mods stack) ────────────────────────────────────────────

func _on_shoot_timer_timeout() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		return

	var base_dir := (target.global_position - global_position).normalized()

	# Calculate stacked bullet properties
	var extra_damage := 0
	var pierce_count := 0
	var homing_str := 0.0
	var bullet_type := "normal"

	if mods["bigshot"] > 0:
		extra_damage = mods["bigshot"]
		bullet_type = "bigshot"
	if mods["pierce"] > 0:
		pierce_count = [2, 5, -1][mods["pierce"] - 1]  # -1 = infinite
		if bullet_type == "normal":
			bullet_type = "pierce"
	if mods["homing"] > 0:
		homing_str = [1.5, 3.0, 5.0][mods["homing"] - 1]
		if bullet_type == "normal":
			bullet_type = "homing"
	if mods["rapid"] > 0 and bullet_type == "normal":
		bullet_type = "rapid"
	if mods["spread"] > 0 and bullet_type == "normal":
		bullet_type = "spread"

	# Forward shot(s)
	var forward_count := 1
	var spread_angle := 0.0
	if mods["spread"] > 0:
		forward_count = [3, 5, 7][mods["spread"] - 1]
		spread_angle = [0.35, 0.5, 0.7][mods["spread"] - 1]

	_fire_fan(base_dir, forward_count, spread_angle, bullet_type, extra_damage, pierce_count, homing_str)

	# Rear shot(s)
	if mods["rear"] > 0:
		var rear_dir := -base_dir
		var rear_count: int = mods["rear"]
		var rear_spread := 0.0
		if rear_count > 1:
			rear_spread = 0.3
		_fire_fan(rear_dir, rear_count, rear_spread, bullet_type, extra_damage, pierce_count, homing_str)


# Spawn a fan of bullets around a direction
func _fire_fan(base_dir: Vector2, count: int, spread: float,
		b_type: String, extra_dmg: int, pierce: int, homing: float) -> void:
	for i in range(count):
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-spread, spread, float(i) / float(count - 1))
		var dir := base_dir.rotated(angle_offset)
		var bullet: Node2D = projectile_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		bullet.bullet_type = b_type
		bullet.extra_damage = extra_dmg
		bullet.pierce_count = pierce
		bullet.homing_strength = homing
		get_tree().current_scene.add_child(bullet)
	Stats.record_shot(count)


# ── Orbit bullets ────────────────────────────────────────────────────────

func _update_orbit_bullets() -> void:
	var desired_count: int = [2, 4, 6][clampi(mods["orbit"] - 1, 0, 2)]
	var orbit_radius := 40.0

	# Spawn missing orbit bullets
	while orbit_bullets.size() < desired_count:
		var ob: Node2D = orbit_scene.instantiate()
		get_tree().current_scene.add_child(ob)
		orbit_bullets.append(ob)

	# Remove excess orbit bullets
	while orbit_bullets.size() > desired_count:
		var ob: Node2D = orbit_bullets.pop_back()
		if is_instance_valid(ob):
			ob.queue_free()

	# Clean up freed bullets and position the rest
	var clean: Array[Node2D] = []
	for ob: Node2D in orbit_bullets:
		if is_instance_valid(ob):
			clean.append(ob)
	orbit_bullets = clean

	for idx in range(orbit_bullets.size()):
		var angle := orbit_angle + (TAU / orbit_bullets.size()) * idx
		var ob: Node2D = orbit_bullets[idx]
		ob.global_position = global_position + Vector2.from_angle(angle) * orbit_radius


# ── Mod management ───────────────────────────────────────────────────────

func add_mod(mod_name: String) -> void:
	if mod_name in mods and mods[mod_name] < MAX_MOD_LEVEL:
		mods[mod_name] += 1
		_recalculate_fire_rate()
		mods_changed.emit(mods)

		# Immediately rebuild orbits if orbit was just picked up
		if mod_name == "orbit":
			_update_orbit_bullets()


func _recalculate_fire_rate() -> void:
	var interval := BASE_SHOOT_INTERVAL
	if mods["rapid"] > 0:
		var multiplier: float = [0.65, 0.45, 0.30][mods["rapid"] - 1]
		interval *= multiplier
	if mods["bigshot"] > 0:
		interval *= 1.15  # slightly slower with big shots
	shoot_timer.wait_time = interval


# ── Damage ───────────────────────────────────────────────────────────────

func take_damage(amount: int = 1) -> void:
	if invincible:
		return
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		died.emit()
		return
	invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	invincible = false
