extends CharacterBody2D
# Orc shaman baby — fast, 1-HP swarm unit spawned when a shaman dies (3 per kill).
# Uses directional sprites (Down / Side / Up) at native 1:1 scale.
# Picks the animation set matching the closest of the 4 cardinal directions.

signal killed(score_value: int)

const SPEED        := 80.0
const MAX_HEALTH   := 1
const SCORE_VALUE  := 5
const DAMAGE_COOLDOWN := 0.6

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true
var _is_dying := false
var _dir_facing: String = "side"   # "side" | "down" | "up"
var _flip_side: bool = false

# Directional sprite strips (all 64×64 frames, no upscaling)
var _idle_down_tex:  Texture2D = preload("res://art/sprites/orc_shaman_baby/Idle_Down.png")
var _idle_side_tex:  Texture2D = preload("res://art/sprites/orc_shaman_baby/Idle_Side.png")
var _idle_up_tex:    Texture2D = preload("res://art/sprites/orc_shaman_baby/Idle_Up.png")
var _run_down_tex:   Texture2D = preload("res://art/sprites/orc_shaman_baby/Run_Down.png")
var _run_side_tex:   Texture2D = preload("res://art/sprites/orc_shaman_baby/Run_Side.png")
var _run_up_tex:     Texture2D = preload("res://art/sprites/orc_shaman_baby/Run_Up.png")
var _death_down_tex: Texture2D = preload("res://art/sprites/orc_shaman_baby/Death_Down.png")
var _death_side_tex: Texture2D = preload("res://art/sprites/orc_shaman_baby/Death_Side.png")
var _death_up_tex:   Texture2D = preload("res://art/sprites/orc_shaman_baby/Death_Up.png")

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite


func _ready() -> void:
	add_to_group("enemies")
	# 1:1 pixel display — no scaling
	anim_sprite.scale = Vector2(1, 1)
	player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_sprite.play("run_side")
	anim_sprite.animation_finished.connect(_on_animation_finished)


func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"idle_down":  { "texture": _idle_down_tex,  "frame_size": Vector2i(64, 64), "frame_count": 4, "fps": 6.0,  "loop": true  },
		"idle_side":  { "texture": _idle_side_tex,  "frame_size": Vector2i(64, 64), "frame_count": 4, "fps": 6.0,  "loop": true  },
		"idle_up":    { "texture": _idle_up_tex,    "frame_size": Vector2i(64, 64), "frame_count": 4, "fps": 6.0,  "loop": true  },
		"run_down":   { "texture": _run_down_tex,   "frame_size": Vector2i(64, 64), "frame_count": 6, "fps": 10.0, "loop": true  },
		"run_side":   { "texture": _run_side_tex,   "frame_size": Vector2i(64, 64), "frame_count": 6, "fps": 10.0, "loop": true  },
		"run_up":     { "texture": _run_up_tex,     "frame_size": Vector2i(64, 64), "frame_count": 6, "fps": 10.0, "loop": true  },
		"death_down": { "texture": _death_down_tex, "frame_size": Vector2i(64, 64), "frame_count": 8, "fps": 10.0, "loop": false },
		"death_side": { "texture": _death_side_tex, "frame_size": Vector2i(64, 64), "frame_count": 8, "fps": 10.0, "loop": false },
		"death_up":   { "texture": _death_up_tex,   "frame_size": Vector2i(64, 64), "frame_count": 8, "fps": 10.0, "loop": false },
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

	# Determine facing from movement direction
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if ax >= ay:
		_dir_facing = "side"
		_flip_side = dir.x < 0
	elif dir.y > 0:
		_dir_facing = "down"
	else:
		_dir_facing = "up"
	anim_sprite.flip_h = _flip_side if _dir_facing == "side" else false

	var desired := "run_" + _dir_facing
	if anim_sprite.animation != desired:
		anim_sprite.play(desired)


func take_damage(amount: int = 1) -> void:
	if _is_dying:
		return
	health -= amount
	Stats.record_damage_dealt(amount, "OrcShamanBaby")
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
	anim_sprite.play("death_" + _dir_facing)


func _on_animation_finished() -> void:
	if anim_sprite.animation.begins_with("death"):
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
