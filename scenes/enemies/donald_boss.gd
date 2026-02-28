extends CharacterBody2D
# DonaldBoss — 64×80 sprite sheet, 10 frames/row, 5 rows.
# Row 0: idle (1-10)  Row 1: walk (11-20)  Row 2: fight (21-30)
# Row 3: finger (31-40)  Row 4: hurt(41-43) pants(44-46) die(47-50)
#
# Phase 1 (HP > 35%): chases player, melee fight attack every 3s,
#   finger charge every 8s.
# Phase 2 (HP ≤ 35%): pants mode — 1.6× speed, faster attacks, plays
#   "pants" idle animation.
# Appears every boss wave alongside the existing Link boss.

signal killed(score_value: int)
signal health_changed(current: int, maximum: int)

const SPEED            := 60.0
const DASH_SPEED       := 220.0
const MAX_HEALTH       := 1500
const SCORE_VALUE      := 300
const DAMAGE_COOLDOWN  := 0.8
const CONTACT_DAMAGE   := 2
const FIGHT_DAMAGE     := 4      # extra damage during fight anim
const SPRITE_SCALE     := 2.0   # 64×80 → 128×160 display
const PANTS_THRESHOLD  := 0.35  # HP fraction that triggers pants mode

const FIGHT_INTERVAL  := 3.0   # seconds between fight attacks
const FINGER_INTERVAL := 8.0   # seconds between finger charges
const DASH_DURATION   := 0.5   # length of post-finger dash

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var _is_dying     := false
var _is_pants     := false

var _fight_timer  := 0.0
var _finger_timer := 3.5   # offset so first finger doesn't land immediately

var _is_attacking := false  # true while fight/finger anim plays
var _attack_name  := ""
var _is_dashing   := false
var _dash_dir     := Vector2.ZERO
var _dash_left    := 0.0

var _damage_tween: Tween = null

var _tex: Texture2D = preload("res://art/sprites/donald/donald.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run")
	anim_sprite.animation_finished.connect(_on_animation_finished)
	anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)


func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"idle": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 10, "fps": 8.0, "loop": true,
			"x_offset": 0, "y_offset": 0,
		},
		"run": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 10, "fps": 10.0, "loop": true,
			"x_offset": 0, "y_offset": 80,
		},
		"fight": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 10, "fps": 12.0, "loop": false,
			"x_offset": 0, "y_offset": 160,
		},
		"finger": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 10, "fps": 8.0, "loop": false,
			"x_offset": 0, "y_offset": 240,
		},
		"hurt": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 3, "fps": 10.0, "loop": false,
			"x_offset": 0, "y_offset": 320,
		},
		"pants": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 3, "fps": 4.0, "loop": true,
			"x_offset": 192, "y_offset": 320,
		},
		"death": {
			"texture": _tex, "frame_size": Vector2i(64, 80),
			"frame_count": 4, "fps": 6.0, "loop": false,
			"x_offset": 384, "y_offset": 320,
		},
	})
	anim_sprite.sprite_frames = sf


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if player == null or not is_instance_valid(player):
		return

	var dir := (player.global_position - global_position).normalized()
	var speed_mult := 1.6 if _is_pants else 1.0

	# Post-finger dash
	if _is_dashing:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED * speed_mult
		if _dash_left <= 0.0:
			_is_dashing = false
			_is_attacking = false
			anim_sprite.play("pants" if _is_pants else "run")
		move_and_slide()
		anim_sprite.flip_h = _dash_dir.x < 0
		return

	# Stand still while playing fight/finger anim
	if _is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		anim_sprite.flip_h = dir.x < 0
		return

	# Advance attack timers (faster in pants mode)
	var fight_int   := FIGHT_INTERVAL   / speed_mult
	var finger_int  := FINGER_INTERVAL  / speed_mult
	_fight_timer  += delta
	_finger_timer += delta

	# Finger special takes priority
	if _finger_timer >= finger_int:
		_finger_timer = 0.0
		_start_finger(dir)
		return
	elif _fight_timer >= fight_int:
		_fight_timer = 0.0
		_start_fight()
		return

	# Normal movement
	velocity = dir * SPEED * speed_mult
	move_and_slide()
	anim_sprite.flip_h = dir.x < 0

	var moving := velocity.length() > 5.0
	var cur := anim_sprite.animation
	if moving:
		if cur != "run":
			anim_sprite.play("run")
	else:
		var idle_anim := "pants" if _is_pants else "idle"
		if cur != idle_anim:
			anim_sprite.play(idle_anim)

	# Transition to pants mode
	if not _is_pants and float(health) / MAX_HEALTH <= PANTS_THRESHOLD:
		_enter_pants_mode()


func _start_fight() -> void:
	_is_attacking = true
	_attack_name = "fight"
	anim_sprite.play("fight")


func _start_finger(dir: Vector2) -> void:
	_is_attacking = true
	_attack_name = "finger"
	_dash_dir = dir
	anim_sprite.play("finger")


func _enter_pants_mode() -> void:
	_is_pants = true
	anim_sprite.play("pants")
	# Yellow flash to signal the transition
	anim_sprite.modulate = Color(1.0, 1.0, 0.2, 1.0)
	var tw := create_tween()
	tw.tween_property(anim_sprite, "modulate", Color.WHITE, 0.6)


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	health_changed.emit(health, MAX_HEALTH)
	Stats.record_damage_dealt(amount, "DonaldBoss")
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	anim_sprite.modulate = Color.RED
	_damage_tween = create_tween()
	_damage_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	var ps := Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 1.1)
	var ns := Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_damage_tween.parallel().tween_property(anim_sprite, "scale", ps, 0.05)
	_damage_tween.tween_property(anim_sprite, "scale", ns, 0.1)
	if health <= 0:
		_die()


func _die() -> void:
	_is_dying = true
	remove_from_group("enemies")
	killed.emit(SCORE_VALUE)
	set_physics_process(false)
	$HitBox.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	anim_sprite.play("death")


func _on_animation_finished() -> void:
	match anim_sprite.animation:
		"death":
			queue_free()
		"fight":
			_is_attacking = false
			anim_sprite.play("pants" if _is_pants else "run")
		"finger":
			# Wind up done — launch the dash
			_is_dashing = true
			_dash_left = DASH_DURATION
		"hurt":
			anim_sprite.play("pants" if _is_pants else "run")


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dying:
		return
	if body.is_in_group("player") and body.has_method("take_damage") and can_deal_damage:
		var dmg := FIGHT_DAMAGE if (_is_attacking and _attack_name == "fight") else CONTACT_DAMAGE
		body.take_damage(dmg)
		Stats.record_damage_taken(dmg)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
