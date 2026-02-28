extends CharacterBody2D
# Player character — top-down movement with stacking weapon mods.
# Each mod can be leveled 1→2→3 by collecting the same pickup again.
# All active mods apply simultaneously when shooting.
# Mario animated sprite with idle, run, hit, death + flip_h for direction.

signal died
signal health_changed(new_health: int)
signal mods_changed(mods: Dictionary)
signal buff_changed(buff_name: String, active: bool, duration: float)

const SPEED := 120.0
const MAX_HEALTH := 5
const INVINCIBLE_DURATION := 0.8
const BASE_SHOOT_INTERVAL := 0.40
const MAX_MOD_LEVEL := 3

# Hazard constants
const ICE_FRICTION := 0.92        # velocity retention per frame on ice (1.0 = no friction)
const POISON_DPS := 0.8           # damage per second on poison
const ACID_DPS := 1.5             # damage per second on acid
const LAVA_DPS := 2.5             # damage per second on lava
const HAZARD_DMG_INTERVAL := 0.4  # seconds between hazard damage ticks

# Jump constants
const JUMP_DURATION := 0.4        # total jump arc time
const JUMP_HEIGHT := 20.0         # max pixel offset at peak
const JUMP_COOLDOWN := 0.0        # no cooldown — bunny hop allowed

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
var _is_dead := false

# Hazard state
var _on_ice := false
var _ice_velocity := Vector2.ZERO   # momentum carried on ice
var _hazard_dmg_timer := 0.0        # accumulates delta for DOT ticks
var _current_tile_type := 0          # cached tile type under player

# Orbit system state
var orbit_bullets: Array[Node2D] = []
var orbit_angle := 0.0

# Temporary buffs — timers count down each frame
var buff_speed_timer := 0.0       # gem_green: 1.5x speed
var buff_damage_timer := 0.0      # scroll_fire: 2x damage
var buff_shield_timer := 0.0      # gem_purple: invincibility

# Jump state
var _jumping := false
var _jump_timer := 0.0
var _jump_cooldown_timer := 0.0

# Preloaded Mario sprite strip textures
var _tex := {
	"idle":  preload("res://art/sprites/player/mario_idle.png"),
	"run":   preload("res://art/sprites/player/mario_run.png"),
	"hit":   preload("res://art/sprites/player/mario_hit.png"),
	"death": preload("res://art/sprites/player/mario_death.png"),
}

@onready var shoot_timer: Timer = $ShootTimer
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")
var orbit_scene: PackedScene = preload("res://scenes/projectile/orbit_bullet.tscn")


func _ready() -> void:
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	_recalculate_fire_rate()
	_build_animations()
	anim_sprite.play("idle")


# Build 4 Mario animations from sprite strips at runtime
func _build_animations() -> void:
	var defs := {
		"idle": {
			"texture": _tex["idle"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 2,
			"fps": 4.0,
			"loop": true,
		},
		"run": {
			"texture": _tex["run"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 8,
			"fps": 12.0,
			"loop": true,
		},
		"hit": {
			"texture": _tex["hit"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 4,
			"fps": 10.0,
			"loop": false,
		},
		"death": {
			"texture": _tex["death"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 6,
			"fps": 8.0,
			"loop": false,
		},
	}
	anim_sprite.sprite_frames = SpriteHelper.build_sprite_frames(defs)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Query tile type under player from WorldGenerator
	var world_gen := get_parent().get_node_or_null("WorldGenerator")
	if world_gen and world_gen.has_method("get_tile_type"):
		_current_tile_type = world_gen.get_tile_type(global_position)
	else:
		_current_tile_type = 0

	# 8-directional movement with hazard modifiers
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var move_speed := SPEED
	if buff_speed_timer > 0.0:
		move_speed *= 1.5

	# Ice: slippery momentum — input blends with carried velocity
	_on_ice = (_current_tile_type == 2)  # Tile.ICE
	if _on_ice:
		var desired_vel := input_dir.normalized() * move_speed
		_ice_velocity = _ice_velocity * ICE_FRICTION + desired_vel * (1.0 - ICE_FRICTION)
		velocity = _ice_velocity
	else:
		# Poison slows movement by 30%
		if _current_tile_type == 3:  # Tile.POISON
			move_speed *= 0.7
		velocity = input_dir.normalized() * move_speed
		_ice_velocity = velocity  # reset ice momentum to current velocity

	move_and_slide()

	# Hazard damage over time
	_process_hazard_damage(delta)

	# Hazard visual tint on sprite (skip while airborne)
	if not _jumping:
		_apply_hazard_tint()

	# Flash while invincible (overrides hazard tint alpha)
	if invincible:
		anim_sprite.modulate.a = 0.4 if fmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0 else 1.0

	# Flip sprite based on horizontal movement
	if input_dir.length() > 0.1 and absf(input_dir.x) > 0.1:
		anim_sprite.flip_h = input_dir.x < 0

	# Play run/idle animation (skip only while hit/death is actively playing)
	var cur: String = anim_sprite.animation
	var blocked: bool = cur == "death" or (cur == "hit" and anim_sprite.is_playing())
	if not blocked:
		var desired: String = "run" if input_dir.length() > 0.1 else "idle"
		if anim_sprite.animation != desired:
			anim_sprite.play(desired)

	# Rotate orbit bullets around player
	if mods["orbit"] > 0:
		orbit_angle += delta * 3.0
		_update_orbit_bullets()

	# Tick down temporary buffs
	_tick_buffs(delta)

	# Jump input and arc
	_process_jump(delta)


# ── Jump ────────────────────────────────────────────────────────────────

func _process_jump(delta: float) -> void:
	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	# Start jump on spacebar
	if Input.is_action_just_pressed("jump") and not _jumping and _jump_cooldown_timer <= 0.0:
		_jumping = true
		_jump_timer = 0.0
		SoundManager.play_jump()

	if _jumping:
		_jump_timer += delta
		var t := _jump_timer / JUMP_DURATION
		if t >= 1.0:
			# Land
			_jumping = false
			_jump_cooldown_timer = JUMP_COOLDOWN
			anim_sprite.position.y = 0.0
			anim_sprite.scale = Vector2(1.0, 1.0)
		else:
			# Parabolic arc: peak at t=0.5
			var height := 4.0 * JUMP_HEIGHT * t * (1.0 - t)
			anim_sprite.position.y = -height
			# Slight squash-stretch
			var stretch := 1.0 + 0.15 * sin(t * PI)
			anim_sprite.scale = Vector2(1.0 / stretch, stretch)


func is_jumping() -> bool:
	return _jumping


# ── Buffs ───────────────────────────────────────────────────────────────

func _tick_buffs(delta: float) -> void:
	if buff_speed_timer > 0.0:
		buff_speed_timer -= delta
		if buff_speed_timer <= 0.0:
			buff_speed_timer = 0.0
			buff_changed.emit("speed", false, 0.0)
	if buff_damage_timer > 0.0:
		buff_damage_timer -= delta
		if buff_damage_timer <= 0.0:
			buff_damage_timer = 0.0
			buff_changed.emit("damage", false, 0.0)
	if buff_shield_timer > 0.0:
		buff_shield_timer -= delta
		if buff_shield_timer <= 0.0:
			buff_shield_timer = 0.0
			invincible = false
			buff_changed.emit("shield", false, 0.0)


func apply_buff(buff_name: String, duration: float) -> void:
	match buff_name:
		"speed":
			buff_speed_timer = duration
			buff_changed.emit("speed", true, duration)
		"damage":
			buff_damage_timer = duration
			buff_changed.emit("damage", true, duration)
		"shield":
			buff_shield_timer = duration
			invincible = true
			buff_changed.emit("shield", true, duration)
	_powerup_bounce()


# Asterix-style double bounce on powerup consumption
var _bounce_tween: Tween = null

func _powerup_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	anim_sprite.scale = Vector2(1.0, 1.0)
	_bounce_tween = create_tween()
	# First bounce: scale up to 1.5x then back
	_bounce_tween.tween_property(anim_sprite, "scale", Vector2(1.5, 1.5), 0.1)
	_bounce_tween.tween_property(anim_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	# Second bounce: scale up to 1.5x then back
	_bounce_tween.tween_property(anim_sprite, "scale", Vector2(1.5, 1.5), 0.1)
	_bounce_tween.tween_property(anim_sprite, "scale", Vector2(1.0, 1.0), 0.1)


func has_damage_buff() -> bool:
	return buff_damage_timer > 0.0


# ── Hazard effects ───────────────────────────────────────────────────────

func _process_hazard_damage(delta: float) -> void:
	var dps := 0.0
	match _current_tile_type:
		3: dps = POISON_DPS   # Tile.POISON
		4: dps = ACID_DPS     # Tile.ACID
		5: dps = LAVA_DPS     # Tile.LAVA
	if dps <= 0.0:
		_hazard_dmg_timer = 0.0
		return
	_hazard_dmg_timer += delta
	if _hazard_dmg_timer >= HAZARD_DMG_INTERVAL:
		_hazard_dmg_timer -= HAZARD_DMG_INTERVAL
		var tick_damage: int = maxi(1, roundi(dps * HAZARD_DMG_INTERVAL))
		take_damage(tick_damage)


func _apply_hazard_tint() -> void:
	match _current_tile_type:
		2:  # ICE — frosty blue tint
			anim_sprite.modulate = Color(0.7, 0.85, 1.0, 1.0)
		3:  # POISON — sickly green
			anim_sprite.modulate = Color(0.6, 1.0, 0.5, 1.0)
		4:  # ACID — yellow-green flash
			anim_sprite.modulate = Color(0.8, 1.0, 0.3, 1.0)
		5:  # LAVA — red-orange heat
			anim_sprite.modulate = Color(1.0, 0.5, 0.3, 1.0)
		_:  # Normal — reset
			anim_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


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
	if _is_dead:
		return
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

	# Fire scroll buff: double damage
	if buff_damage_timer > 0.0:
		extra_damage += 2

	# Forward shot(s)
	var forward_count := 1
	var spread_angle := 0.0
	if mods["spread"] > 0:
		forward_count = [3, 5, 7][mods["spread"] - 1]
		spread_angle = [0.35, 0.5, 0.7][mods["spread"] - 1]

	_fire_fan(base_dir, forward_count, spread_angle, bullet_type, extra_damage, pierce_count, homing_str)

	# Play shoot sound based on current bullet type
	SoundManager.play_shoot(bullet_type)

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
		_powerup_bounce()

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

func heal(amount: int = 1) -> void:
	if _is_dead:
		return
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health)
	# Brief green flash
	anim_sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)
	var tw := create_tween()
	tw.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	_powerup_bounce()


func take_damage(amount: int = 1) -> void:
	if invincible or _is_dead:
		return
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		_is_dead = true
		shoot_timer.stop()
		# Play death animation, stay visible for game over screen
		anim_sprite.play("death")
		died.emit()
		return
	# Play hit sound and animation briefly, then resume normal
	SoundManager.play_player_hit()
	anim_sprite.play("hit")
	invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	invincible = false
	# Force back to idle so animation never stays stuck on finished "hit"
	if not _is_dead and anim_sprite.animation == "hit":
		anim_sprite.play("idle")
