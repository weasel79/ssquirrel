extends CharacterBody2D
# Orc shaman — slow, tough chaser. When killed, spawns 3 shaman babies.
# 5 HP, runs toward the player, emits `killed` with score value.

signal killed(score_value: int)

const SPEED      := 40.0
const MAX_HEALTH := 5
const SCORE_VALUE := 40
const DAMAGE_COOLDOWN := 1.0

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var _is_dying := false

var _run_tex:   Texture2D = preload("res://art/sprites/orc_shaman/Run.png")
var _death_tex: Texture2D = preload("res://art/sprites/orc_shaman/Death.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run")
	anim_sprite.animation_finished.connect(_on_animation_finished)


func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"run": {
			"texture":    _run_tex,
			"frame_size": Vector2i(64, 64),
			"frame_count": 6,
			"fps": 8.0,
			"loop": true,
		},
		"death": {
			"texture":    _death_tex,
			"frame_size": Vector2i(64, 64),
			"frame_count": 7,
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
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * SPEED
	move_and_slide()
	anim_sprite.flip_h = dir.x < 0


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	Stats.record_damage_dealt(amount, "OrcShaman")
	anim_sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
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
		body.take_damage(1)
		Stats.record_damage_taken(1)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
