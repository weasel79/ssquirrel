extends CharacterBody2D
# Fascist squirrel enemy — chases the player and deals contact damage.
# Dies after taking enough hits.  Emits `killed` with its score value.

signal killed(score_value: int)

const SPEED := 60.0
const MAX_HEALTH := 2
const SCORE_VALUE := 10
const DAMAGE_COOLDOWN := 0.8

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
	# Move toward the player
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * SPEED
	move_and_slide()


# Take damage from a projectile, flash red, die at 0 HP
func take_damage(amount: int = 1) -> void:
	health -= amount
	Stats.record_damage_dealt(amount, "Squirrel")
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		killed.emit(SCORE_VALUE)
		queue_free()


# Deal contact damage to the player
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage") and can_deal_damage:
		body.take_damage(1)
		Stats.record_damage_taken(1)
		can_deal_damage = false
		await get_tree().create_timer(DAMAGE_COOLDOWN).timeout
		can_deal_damage = true
