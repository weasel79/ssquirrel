extends CharacterBody2D
# Raccoon officer — ranged attacker, keeps distance and throws acorns.
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

var acorn_scene: PackedScene = preload("res://scenes/projectile/acorn.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	shoot_timer.timeout.connect(_on_shoot_timer)


func _physics_process(_delta: float) -> void:
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


func _on_shoot_timer() -> void:
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
	health -= amount
	Stats.record_damage_dealt(amount, "Raccoon")
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		killed.emit(SCORE_VALUE)
		queue_free()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage") and can_deal_damage:
		body.take_damage(1)
		Stats.record_damage_taken(1)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
