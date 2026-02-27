extends CharacterBody2D
# Skeleton rogue — fast, fragile, zigzags toward the player.
# 1 HP, high speed, erratic movement makes it hard to hit.

signal killed(score_value: int)

const SPEED := 110.0
const MAX_HEALTH := 1
const SCORE_VALUE := 5
const DAMAGE_COOLDOWN := 0.6
const ZIGZAG_INTERVAL := 0.4
const ZIGZAG_STRENGTH := 60.0

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var zigzag_offset := 0.0
var zigzag_timer := 0.0
var _is_dying := false

# Sprite sheet textures
var _idle_tex: Texture2D = preload("res://art/sprites/skeleton_rogue/Idle.png")
var _run_tex: Texture2D = preload("res://art/sprites/skeleton_rogue/Run.png")
var _death_tex: Texture2D = preload("res://art/sprites/skeleton_rogue/Death.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run")
	anim_sprite.animation_finished.connect(_on_animation_finished)


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
			"fps": 12.0,
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


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if player == null or not is_instance_valid(player):
		return

	# Zigzag perpendicular to the chase direction
	zigzag_timer += delta
	if zigzag_timer >= ZIGZAG_INTERVAL:
		zigzag_timer = 0.0
		zigzag_offset = randf_range(-ZIGZAG_STRENGTH, ZIGZAG_STRENGTH)

	var dir := (player.global_position - global_position).normalized()
	var perp := Vector2(-dir.y, dir.x)
	velocity = (dir * SPEED) + (perp * zigzag_offset)
	move_and_slide()

	# Flip sprite based on horizontal movement direction
	anim_sprite.flip_h = dir.x < 0

	# Stay on run animation while alive (rats are always running)
	if anim_sprite.animation != "run":
		anim_sprite.play("run")


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	Stats.record_damage_dealt(amount, "Rat")
	anim_sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		_die()


# Play death animation, emit score, disable interactions
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
		body.take_damage(1)
		Stats.record_damage_taken(1)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
