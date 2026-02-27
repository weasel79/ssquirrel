extends CharacterBody2D
# Nazi rat — fast, fragile, zigzags toward the player.
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

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
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


func take_damage(amount: int = 1) -> void:
	health -= amount
	Stats.record_damage_dealt(amount, "Rat")
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
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
