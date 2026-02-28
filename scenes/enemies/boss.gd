extends CharacterBody2D
# Boss — Link sprite at 4x scale, spawns when player has 2+ weapons at level 3.
# 4x visual scale, 10x mole HP, charges the player with increasing aggression.
# Periodically does a fast dash-charge. Shakes screen on contact.

signal killed(score_value: int)
signal health_changed(current: int, maximum: int)

const SPEED := 50.0
const DASH_SPEED := 200.0
const MAX_HEALTH := 1000
const SCORE_VALUE := 200
const DAMAGE_COOLDOWN := 0.8
const CONTACT_DAMAGE := 3
const DASH_INTERVAL := 4.0      # seconds between dash charges
const DASH_DURATION := 0.6      # how long a dash lasts
const SPRITE_SCALE := 4.0

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var _is_dying := false

# Dash state
var _dash_timer := 0.0
var _is_dashing := false
var _dash_dir := Vector2.ZERO
var _dash_time_left := 0.0
var _damage_tween: Tween = null

# Sprite sheet textures (Link from piskel)
var _idle_tex: Texture2D = preload("res://art/sprites/boss/Idle.png")
var _run_tex: Texture2D = preload("res://art/sprites/boss/Run.png")
var _death_tex: Texture2D = preload("res://art/sprites/boss/Death.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run")
	anim_sprite.animation_finished.connect(_on_animation_finished)
	# 4x visual scale
	anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)


func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"idle": {
			"texture": _idle_tex,
			"frame_size": Vector2i(32, 32),
			"frame_count": 3,
			"fps": 4.0,
			"loop": true,
		},
		"run": {
			"texture": _run_tex,
			"frame_size": Vector2i(32, 32),
			"frame_count": 6,
			"fps": 8.0,
			"loop": true,
		},
		"death": {
			"texture": _death_tex,
			"frame_size": Vector2i(32, 32),
			"frame_count": 6,
			"fps": 6.0,
			"loop": false,
		},
	})
	anim_sprite.sprite_frames = sf


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if player == null or not is_instance_valid(player):
		return

	var dir := (player.global_position - global_position).normalized()

	# Dash charge logic
	_dash_timer += delta
	if _is_dashing:
		_dash_time_left -= delta
		velocity = _dash_dir * DASH_SPEED
		# Red tint during dash
		anim_sprite.modulate = Color(1.0, 0.4, 0.3, 1.0)
		if _dash_time_left <= 0.0:
			_is_dashing = false
			anim_sprite.modulate = Color.WHITE
	elif _dash_timer >= DASH_INTERVAL:
		# Start a dash toward the player
		_dash_timer = 0.0
		_is_dashing = true
		_dash_dir = dir
		_dash_time_left = DASH_DURATION
	else:
		velocity = dir * SPEED

	move_and_slide()

	anim_sprite.flip_h = dir.x < 0

	if velocity.length() > 5.0:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	health_changed.emit(health, MAX_HEALTH)
	Stats.record_damage_dealt(amount, "Boss")
	# Kill previous damage tween to prevent flicker from competing tweens
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	anim_sprite.modulate = Color.RED
	var rest_color := Color(1.0, 0.4, 0.3, 1.0) if _is_dashing else Color.WHITE
	_damage_tween = create_tween()
	_damage_tween.tween_property(anim_sprite, "modulate", rest_color, 0.15)
	var punch_scale := Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 1.1)
	var normal_scale := Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_damage_tween.parallel().tween_property(anim_sprite, "scale", punch_scale, 0.05)
	_damage_tween.tween_property(anim_sprite, "scale", normal_scale, 0.1)
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
	if anim_sprite.animation == "death":
		queue_free()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dying:
		return
	if body.is_in_group("player") and body.has_method("take_damage") and can_deal_damage:
		body.take_damage(CONTACT_DAMAGE)
		Stats.record_damage_taken(CONTACT_DAMAGE)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
