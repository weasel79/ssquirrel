extends CharacterBody2D
# Fascist mole — slow, tanky, takes lots of hits.
# 5 HP, slow movement, deals 2 damage on contact.

signal killed(score_value: int)

const SPEED := 35.0
const MAX_HEALTH := 5
const SCORE_VALUE := 25
const DAMAGE_COOLDOWN := 1.0
const CONTACT_DAMAGE := 2

var health: int = MAX_HEALTH
var player: Node2D = null
var can_deal_damage := true

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * SPEED
	move_and_slide()


func take_damage(amount: int = 1) -> void:
	health -= amount
	Stats.record_damage_dealt(amount, "Mole")
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	if health <= 0:
		killed.emit(SCORE_VALUE)
		queue_free()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage") and can_deal_damage:
		body.take_damage(CONTACT_DAMAGE)
		Stats.record_damage_taken(CONTACT_DAMAGE)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
