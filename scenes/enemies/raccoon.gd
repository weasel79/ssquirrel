extends CharacterBody2D
# Orc shaman — ranged attacker, keeps distance and throws acorns.
# 3 HP, maintains preferred range, fires acorns at the player.

signal killed(score_value: int)

const SPEED := 45.0
const MAX_HEALTH := 3
const SCORE_VALUE := 20
const DAMAGE_COOLDOWN := 1.0
const PREFERRED_RANGE := 150.0
const SHOOT_RANGE := 200.0

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var _is_dying := false

var acorn_scene: PackedScene = preload("res://scenes/projectile/acorn.tscn")

# Sprite sheet textures
var _idle_tex: Texture2D = preload("res://art/sprites/orc_shaman/Idle.png")
var _run_tex: Texture2D = preload("res://art/sprites/orc_shaman/Run.png")
var _death_tex: Texture2D = preload("res://art/sprites/orc_shaman/Death.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite
@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run")
	anim_sprite.animation_finished.connect(_on_animation_finished)
	shoot_timer.timeout.connect(_on_shoot_timer)


# Build SpriteFrames from horizontal strip sheets at runtime
func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"idle": {
			"texture": _idle_tex,
			"frame_size": Vector2i(32, 32),
			"frame_count": 4,
			"fps": 6.0,
			"loop": true,
		},
		"run": {
			"texture": _run_tex,
			"frame_size": Vector2i(64, 64),
			"frame_count": 6,
			"fps": 10.0,
			"loop": true,
		},
		"death": {
			"texture": _death_tex,
			"frame_size": Vector2i(64, 64),
			"frame_count": 6,
			"fps": 10.0,
			"loop": false,
		},
	})
	anim_sprite.sprite_frames = sf


func _physics_process(_delta: float) -> void:
	if _is_dying:
		return
	if player == null or not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	# Move toward preferred range — advance if too far, retreat if too close
	if dist > PREFERRED_RANGE + 20.0:
		velocity = dir * SPEED
	elif dist < PREFERRED_RANGE - 20.0:
		velocity = -dir * SPEED * 0.7
	else:
		# Strafe sideways at preferred range
		var perp := Vector2(-dir.y, dir.x)
		velocity = perp * SPEED * 0.5

	move_and_slide()

	# Flip sprite based on horizontal direction to player
	anim_sprite.flip_h = dir.x < 0

	# Switch between idle and run animations
	if velocity.length() > 5.0:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")


# Fire an acorn projectile toward the player
func _on_shoot_timer() -> void:
	if _is_dying:
		return
	if player == null or not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > SHOOT_RANGE:
		return
	var dir := (player.global_position - global_position).normalized()
	var acorn: Node2D = acorn_scene.instantiate()
	acorn.global_position = global_position
	acorn.direction = dir
	get_tree().current_scene.add_child(acorn)


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	Stats.record_damage_dealt(amount, "Raccoon")
	anim_sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		_die()


# Play death animation, emit score, disable interactions
func _die() -> void:
	_is_dying = true
	remove_from_group("enemies")
	killed.emit(SCORE_VALUE)
	set_physics_process(false)
	shoot_timer.stop()
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
		body.take_damage(1)
		Stats.record_damage_taken(1)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
