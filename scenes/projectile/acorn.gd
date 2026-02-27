extends Area2D
# Acorn — enemy projectile thrown by raccoons. Damages the player on hit.

const SPEED := 160.0
const DAMAGE := 1
const LIFETIME := 3.0

var direction := Vector2.RIGHT


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = LIFETIME
	timer.one_shot = true
	add_child(timer)
	timer.start()
	timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	# Spin for visual flair
	rotation += delta * 8.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		Stats.record_damage_taken(DAMAGE)
		queue_free()
