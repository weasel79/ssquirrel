extends Area2D
# Projectile — flies toward enemies, supports stacking mods.
# Spawner sets: direction, bullet_type, extra_damage, pierce_count, homing_strength.

const LIFETIME := 2.5

var BULLET_STATS := {
	"normal":  { "speed": 300.0, "damage": 1 },
	"spread":  { "speed": 280.0, "damage": 1 },
	"rapid":   { "speed": 350.0, "damage": 1 },
	"pierce":  { "speed": 250.0, "damage": 1 },
	"bigshot": { "speed": 200.0, "damage": 2 },
	"homing":  { "speed": 260.0, "damage": 1 },
}

var BULLET_TEXTURES := {
	"normal":  preload("res://art/bullet.png"),
	"spread":  preload("res://art/bullet_spread.png"),
	"rapid":   preload("res://art/bullet_rapid.png"),
	"pierce":  preload("res://art/bullet_pierce.png"),
	"bigshot": preload("res://art/bullet_big.png"),
	"homing":  preload("res://art/bullet_homing.png"),
}

# Set by spawner before adding to tree
var direction := Vector2.RIGHT
var bullet_type := "normal"
var extra_damage := 0       # from bigshot stacking
var pierce_count := 0       # 0 = no pierce, -1 = infinite, N = N enemies
var homing_strength := 0.0  # 0 = straight, >0 = turn rate in rad/s

var speed := 300.0
var damage := 1
var _pierces_remaining := 0

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Apply base stats from bullet type
	var stats: Dictionary = BULLET_STATS.get(bullet_type, BULLET_STATS["normal"])
	speed = stats["speed"]
	damage = stats["damage"] + extra_damage
	_pierces_remaining = pierce_count

	# Set texture
	if bullet_type in BULLET_TEXTURES:
		sprite.texture = BULLET_TEXTURES[bullet_type]

	# Rotate to face direction
	rotation = direction.angle()

	# Auto-despawn
	lifetime_timer.wait_time = LIFETIME
	lifetime_timer.one_shot = true
	lifetime_timer.start()
	lifetime_timer.timeout.connect(queue_free)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Homing: steer toward nearest enemy
	if homing_strength > 0.0:
		var target := _find_nearest_enemy()
		if target != null:
			var desired := (target.global_position - global_position).normalized()
			var angle_diff := direction.angle_to(desired)
			var max_turn := homing_strength * delta
			angle_diff = clampf(angle_diff, -max_turn, max_turn)
			direction = direction.rotated(angle_diff)
			rotation = direction.angle()

	position += direction * speed * delta


func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


# Damage enemy — handle pierce counting
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)

		# Pierce logic: -1 = infinite, 0 = no pierce, >0 = count down
		if _pierces_remaining == 0:
			queue_free()
		elif _pierces_remaining > 0:
			_pierces_remaining -= 1
