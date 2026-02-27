extends Area2D
# Orbit bullet — circles around the player as a shield.
# Position is controlled by the player script, not by velocity.
# Deals damage on contact with enemies (with a short per-enemy cooldown).

const DAMAGE := 1
const HIT_COOLDOWN := 0.5

var _hit_cooldowns := {}  # enemy instance_id -> true (while on cooldown)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	var eid := body.get_instance_id()
	if eid in _hit_cooldowns:
		return
	body.take_damage(DAMAGE)
	_hit_cooldowns[eid] = true
	# Remove cooldown after delay
	await get_tree().create_timer(HIT_COOLDOWN).timeout
	_hit_cooldowns.erase(eid)
