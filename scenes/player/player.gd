extends CharacterBody2D
# Player character — top-down movement with stacking weapon mods.
# Each mod can be leveled 1→2→3 by collecting the same pickup again.
# All active mods apply simultaneously when shooting.
# Mario sprite sheet (20-col × 38-row, 16×16 tiles) with directional anims,
# hammer-beat melee, and cape mode.

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
const ICE_FRICTION := 0.92
const POISON_DPS := 0.8
const ACID_DPS := 1.5
const LAVA_DPS := 2.5
const HAZARD_DMG_INTERVAL := 0.4

# Jump constants
const JUMP_DURATION := 0.4
const JUMP_HEIGHT := 20.0
const JUMP_COOLDOWN := 0.0

# Sprite sheet constants
const SPRITE_SCALE := 4.0
const SHEET_COLS  := 20
const SHEET_TILE  := 16

# Melee trigger range (world px at scale 1 — compare to distance_to)
const MELEE_RANGE := 32.0

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
var _ice_velocity := Vector2.ZERO
var _hazard_dmg_timer := 0.0
var _current_tile_type := 0

# Orbit system state
var orbit_bullets: Array[Node2D] = []
var orbit_angle := 0.0

# Temporary buffs
var buff_speed_timer := 0.0
var buff_damage_timer := 0.0
var buff_shield_timer := 0.0

# Jump state
var _jumping := false
var _jump_timer := 0.0
var _jump_cooldown_timer := 0.0

# Animation direction tracking
var _facing: String = "right"    # "left" | "right" | "up" | "down"
var _h_facing: String = "right"  # last horizontal — drives walk/jump/hammer/cape

# Cape and hammer state
var _cape_active: bool = false
var _hammer_playing: bool = false

# Sprite sheet texture (loaded once)
var _sheet: Texture2D = preload("res://art/sprites/player/mario/mario_reconstructed_sheet.png")

@onready var shoot_timer: Timer = $ShootTimer
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")
var orbit_scene: PackedScene = preload("res://scenes/projectile/orbit_bullet.tscn")


func _ready() -> void:
	anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	_recalculate_fire_rate()
	_build_animations()
	anim_sprite.play("idle_right")


# ── Sprite sheet helpers ─────────────────────────────────────────────────

# Return an AtlasTexture for frame N (0-based, row-major, 20 cols, 16×16).
func _frame_atlas(n: int) -> AtlasTexture:
	var col := n % SHEET_COLS
	var row := n / SHEET_COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = Rect2(col * SHEET_TILE, row * SHEET_TILE, SHEET_TILE, SHEET_TILE)
	return atlas


# Add one animation to a SpriteFrames resource from a list of sheet frame numbers.
func _add_anim(sf: SpriteFrames, anim_name: String,
		frame_nums: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for fn: int in frame_nums:
		sf.add_frame(anim_name, _frame_atlas(fn))


func _build_animations() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	# Idle (4 directions)
	_add_anim(sf, "idle_left",  [22],          3.0, true)
	_add_anim(sf, "idle_right", [23],          3.0, true)
	_add_anim(sf, "idle_front", [24],          3.0, true)
	_add_anim(sf, "idle_rear",  [25],          3.0, true)

	# Walk
	_add_anim(sf, "walk_left",  [18, 19, 28],  8.0, true)
	_add_anim(sf, "walk_right", [26, 27, 29],  8.0, true)

	# Jump
	_add_anim(sf, "jump_left",  [46],          6.0, false)
	_add_anim(sf, "jump_right", [47],          6.0, false)

	# Hammer beat (non-looping, plays once per trigger)
	# Left:  victory → hurt → swing sequence
	# Right: same + 1 per frame
	_add_anim(sf, "hammer_left",
		[34, 35, 8, 9, 68, 70, 74, 60, 74, 70, 68, 72, 76, 72],
		14.0, false)
	_add_anim(sf, "hammer_right",
		[35, 36, 9, 10, 69, 71, 75, 61, 75, 71, 69, 73, 77, 73],
		14.0, false)

	# Cape — walk / idle
	_add_anim(sf, "cape_walk_left",  [111, 112, 113], 8.0, true)
	_add_anim(sf, "cape_walk_right", [116, 117, 118], 8.0, true)
	_add_anim(sf, "cape_idle_left",  [114],            3.0, true)
	_add_anim(sf, "cape_idle_right", [115],            3.0, true)

	# Cape — jump (going up) and fly (gliding down past peak)
	_add_anim(sf, "cape_jump_left",  [120, 121, 122, 123, 124], 12.0, false)
	_add_anim(sf, "cape_jump_right", [125, 126, 127, 128, 129], 12.0, false)
	_add_anim(sf, "cape_fly_left",   [141, 142],                 8.0, true)
	_add_anim(sf, "cape_fly_right",  [147, 148],                 8.0, true)

	# Hit / death
	_add_anim(sf, "hit",   [8, 9],   10.0, false)
	_add_anim(sf, "death", [8, 9],    4.0, false)

	anim_sprite.sprite_frames = sf


# ── Physics ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Query tile type under player
	var world_gen := get_parent().get_node_or_null("WorldGenerator")
	if world_gen and world_gen.has_method("get_tile_type"):
		_current_tile_type = world_gen.get_tile_type(global_position)
	else:
		_current_tile_type = 0

	# Movement
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var move_speed := SPEED
	if buff_speed_timer > 0.0:
		move_speed *= 1.5

	_on_ice = (_current_tile_type == 2)
	if _on_ice:
		var desired_vel := input_dir.normalized() * move_speed
		_ice_velocity = _ice_velocity * ICE_FRICTION + desired_vel * (1.0 - ICE_FRICTION)
		velocity = _ice_velocity
	else:
		if _current_tile_type == 3:
			move_speed *= 0.7
		velocity = input_dir.normalized() * move_speed
		_ice_velocity = velocity

	move_and_slide()

	# Update facing direction
	if absf(input_dir.x) > 0.1:
		_h_facing = "left" if input_dir.x < 0 else "right"
		_facing = _h_facing
	elif absf(input_dir.y) > 0.1:
		_facing = "up" if input_dir.y < 0 else "down"

	# Cape toggle
	if Input.is_action_just_pressed("cape_toggle"):
		_cape_active = not _cape_active

	# Hazard effects
	_process_hazard_damage(delta)
	if not _jumping:
		_apply_hazard_tint()
	if invincible:
		anim_sprite.modulate.a = 0.4 if fmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0 else 1.0

	# Animation
	_update_animation(input_dir)

	# Orbit bullets
	if mods["orbit"] > 0:
		orbit_angle += delta * 3.0
		_update_orbit_bullets()

	_tick_buffs(delta)
	_process_jump(delta)


# ── Animation state machine ──────────────────────────────────────────────

func _update_animation(input_dir: Vector2) -> void:
	var cur: String = anim_sprite.animation

	# Death is terminal
	if cur == "death":
		return

	# Hit plays once, then exits
	if cur == "hit" and anim_sprite.is_playing():
		return

	# Hammer beat: let it finish, then clear
	if _hammer_playing:
		if anim_sprite.is_playing() and cur in ["hammer_left", "hammer_right"]:
			return
		_hammer_playing = false

	# Trigger hammer if enemy is in melee range
	if not _hammer_playing:
		var nearest := _find_nearest_enemy()
		if nearest != null and \
				global_position.distance_to(nearest.global_position) <= MELEE_RANGE:
			var ha := "hammer_left" if _h_facing == "left" else "hammer_right"
			if cur != ha:
				anim_sprite.play(ha)
			_hammer_playing = true
			return

	# Determine desired animation
	var desired: String

	if _jumping:
		if _cape_active:
			# Cape fly kicks in past jump peak
			if _jump_timer >= JUMP_DURATION * 0.5:
				desired = "cape_fly_left"  if _h_facing == "left" else "cape_fly_right"
			else:
				desired = "cape_jump_left" if _h_facing == "left" else "cape_jump_right"
		else:
			desired = "jump_left" if _h_facing == "left" else "jump_right"

	elif input_dir.length() > 0.1:
		if _cape_active:
			desired = "cape_walk_left" if _h_facing == "left" else "cape_walk_right"
		else:
			desired = "walk_left" if _h_facing == "left" else "walk_right"

	else:
		# Idle: use full 4-direction facing
		if _cape_active:
			desired = "cape_idle_left" if _h_facing == "left" else "cape_idle_right"
		else:
			match _facing:
				"left":  desired = "idle_left"
				"right": desired = "idle_right"
				"up":    desired = "idle_rear"
				"down":  desired = "idle_front"
				_:       desired = "idle_right"

	if anim_sprite.animation != desired or not anim_sprite.is_playing():
		anim_sprite.play(desired)


# ── Jump ─────────────────────────────────────────────────────────────────

func _process_jump(delta: float) -> void:
	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump") and not _jumping and _jump_cooldown_timer <= 0.0:
		_jumping = true
		_jump_timer = 0.0
		SoundManager.play_jump()

	if _jumping:
		_jump_timer += delta
		var t := _jump_timer / JUMP_DURATION
		if t >= 1.0:
			_jumping = false
			_jump_cooldown_timer = JUMP_COOLDOWN
			anim_sprite.position.y = 0.0
			anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		else:
			var height := 4.0 * JUMP_HEIGHT * t * (1.0 - t)
			anim_sprite.position.y = -height
			var stretch := 1.0 + 0.15 * sin(t * PI)
			anim_sprite.scale = Vector2(SPRITE_SCALE / stretch, SPRITE_SCALE * stretch)


func is_jumping() -> bool:
	return _jumping


# ── Buffs ─────────────────────────────────────────────────────────────────

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


var _bounce_tween: Tween = null

func _powerup_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(anim_sprite, "scale",
		Vector2(SPRITE_SCALE * 1.5, SPRITE_SCALE * 1.5), 0.1)
	_bounce_tween.tween_property(anim_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.1)
	_bounce_tween.tween_property(anim_sprite, "scale",
		Vector2(SPRITE_SCALE * 1.5, SPRITE_SCALE * 1.5), 0.1)
	_bounce_tween.tween_property(anim_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.1)


func has_damage_buff() -> bool:
	return buff_damage_timer > 0.0


# ── Hazard effects ────────────────────────────────────────────────────────

func _process_hazard_damage(delta: float) -> void:
	var dps := 0.0
	match _current_tile_type:
		3: dps = POISON_DPS
		4: dps = ACID_DPS
		5: dps = LAVA_DPS
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
		2:  anim_sprite.modulate = Color(0.7, 0.85, 1.0, 1.0)
		3:  anim_sprite.modulate = Color(0.6, 1.0, 0.5, 1.0)
		4:  anim_sprite.modulate = Color(0.8, 1.0, 0.3, 1.0)
		5:  anim_sprite.modulate = Color(1.0, 0.5, 0.3, 1.0)
		_:  anim_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ── Targeting ─────────────────────────────────────────────────────────────

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


# ── Shooting ──────────────────────────────────────────────────────────────

func _on_shoot_timer_timeout() -> void:
	if _is_dead:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return

	var base_dir := (target.global_position - global_position).normalized()

	var extra_damage := 0
	var pierce_count := 0
	var homing_str := 0.0
	var bullet_type := "normal"

	if mods["bigshot"] > 0:
		extra_damage = mods["bigshot"]
		bullet_type = "bigshot"
	if mods["pierce"] > 0:
		pierce_count = [2, 5, -1][mods["pierce"] - 1]
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

	if buff_damage_timer > 0.0:
		extra_damage += 2

	var forward_count := 1
	var spread_angle := 0.0
	if mods["spread"] > 0:
		forward_count = [3, 5, 7][mods["spread"] - 1]
		spread_angle  = [0.35, 0.5, 0.7][mods["spread"] - 1]

	_fire_fan(base_dir, forward_count, spread_angle, bullet_type, extra_damage, pierce_count, homing_str)
	SoundManager.play_shoot(bullet_type)

	if mods["rear"] > 0:
		var rear_dir := -base_dir
		var rear_count: int = mods["rear"]
		var rear_spread := 0.0
		if rear_count > 1:
			rear_spread = 0.3
		_fire_fan(rear_dir, rear_count, rear_spread, bullet_type, extra_damage, pierce_count, homing_str)


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


# ── Orbit bullets ─────────────────────────────────────────────────────────

func _update_orbit_bullets() -> void:
	var desired_count: int = [2, 4, 6][clampi(mods["orbit"] - 1, 0, 2)]
	var orbit_radius := 40.0

	while orbit_bullets.size() < desired_count:
		var ob: Node2D = orbit_scene.instantiate()
		get_tree().current_scene.add_child(ob)
		orbit_bullets.append(ob)

	while orbit_bullets.size() > desired_count:
		var ob: Node2D = orbit_bullets.pop_back()
		if is_instance_valid(ob):
			ob.queue_free()

	var clean: Array[Node2D] = []
	for ob: Node2D in orbit_bullets:
		if is_instance_valid(ob):
			clean.append(ob)
	orbit_bullets = clean

	for idx in range(orbit_bullets.size()):
		var angle := orbit_angle + (TAU / orbit_bullets.size()) * idx
		var ob: Node2D = orbit_bullets[idx]
		ob.global_position = global_position + Vector2.from_angle(angle) * orbit_radius


# ── Mod management ────────────────────────────────────────────────────────

func add_mod(mod_name: String) -> void:
	if mod_name in mods and mods[mod_name] < MAX_MOD_LEVEL:
		mods[mod_name] += 1
		_recalculate_fire_rate()
		mods_changed.emit(mods)
		_powerup_bounce()
		if mod_name == "orbit":
			_update_orbit_bullets()


func _recalculate_fire_rate() -> void:
	var interval := BASE_SHOOT_INTERVAL
	if mods["rapid"] > 0:
		var multiplier: float = [0.65, 0.45, 0.30][mods["rapid"] - 1]
		interval *= multiplier
	if mods["bigshot"] > 0:
		interval *= 1.15
	shoot_timer.wait_time = interval


# ── Damage ────────────────────────────────────────────────────────────────

func heal(amount: int = 1) -> void:
	if _is_dead:
		return
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health)
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
		anim_sprite.play("death")
		died.emit()
		return
	SoundManager.play_player_hit()
	anim_sprite.play("hit")
	invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	invincible = false
	if not _is_dead and anim_sprite.animation == "hit":
		anim_sprite.play("idle_" + _facing if _facing in ["left","right"] else "idle_right")
