extends Area2D
# Weapon upgrade pickup — dropped by enemies on death.
# Floats in place, bobs up and down, collected on player overlap.
# The `weapon_type` determines which upgrade the player gets.

signal collected(weapon_type: String)

const LIFETIME := 8.0
const BOB_SPEED := 3.0
const BOB_AMOUNT := 3.0

# Set by the spawner before adding to tree
var weapon_type: String = "spread"
var _start_y := 0.0
var _time := 0.0

# Texture map — set the right sprite based on weapon_type
var textures := {
	"spread": preload("res://art/upgrade_spread.png"),
	"rapid": preload("res://art/upgrade_rapid.png"),
	"pierce": preload("res://art/upgrade_pierce.png"),
	"bigshot": preload("res://art/upgrade_bigshot.png"),
	"homing": preload("res://art/upgrade_homing.png"),
	"orbit": preload("res://art/upgrade_orbit.png"),
	"rear": preload("res://art/upgrade_rear.png"),
}

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_start_y = position.y
	if weapon_type in textures:
		sprite.texture = textures[weapon_type]

	body_entered.connect(_on_body_entered)

	# Despawn after lifetime
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
		collected.emit(weapon_type)
		queue_free()


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
