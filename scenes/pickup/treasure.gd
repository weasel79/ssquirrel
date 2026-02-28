extends Area2D
# Treasure pickup — spawned on enemy death (20% chance) or boss death (10 items).
# Displays a random gold icon, bobs in place, and is collected on player overlap.

signal collected

const LIFETIME   := 8.0
const BOB_SPEED  := 3.0
const BOB_AMOUNT := 3.0

var _start_y := 0.0
var _time    := 0.0

var _textures: Array[Texture2D] = [
	preload("res://art/items/treasure/1.png"),
	preload("res://art/items/treasure/2.png"),
	preload("res://art/items/treasure/3.png"),
	preload("res://art/items/treasure/4.png"),
	preload("res://art/items/treasure/5.png"),
	preload("res://art/items/treasure/6.png"),
	preload("res://art/items/treasure/7.png"),
	preload("res://art/items/treasure/8.png"),
	preload("res://art/items/treasure/9.png"),
	preload("res://art/items/treasure/10.png"),
]

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_start_y = position.y
	sprite.texture = _textures[randi() % _textures.size()]
	body_entered.connect(_on_body_entered)
	var timer := Timer.new()
	timer.wait_time = LIFETIME
	timer.one_shot = true
	add_child(timer)
	timer.start()
	timer.timeout.connect(_fade_out)


func _process(delta: float) -> void:
	_time += delta
	position.y = _start_y + sin(_time * BOB_SPEED) * BOB_AMOUNT


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
