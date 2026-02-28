extends Area2D
# Power-up pickup — spawns randomly on the map with various effects.
# Types: life_pot, scroll_fire, scroll_ice, scroll_thunder,
#        gem_red, gem_green, gem_purple, nut
# Bobs up and down, color-pulses per type, despawns after 12 seconds.

signal collected(powerup_type: String)

const LIFETIME := 12.0
const BOB_SPEED := 2.5
const BOB_AMOUNT := 4.0

# Set by spawner before adding to tree
var powerup_type: String = "life_pot"
var _start_y := 0.0
var _time := 0.0

var textures := {
	"life_pot":       preload("res://art/items/life_pot.png"),
	"scroll_fire":    preload("res://art/items/scroll_fire.png"),
	"scroll_ice":     preload("res://art/items/scroll_ice.png"),
	"scroll_thunder": preload("res://art/items/scroll_thunder.png"),
	"gem_red":        preload("res://art/items/gem_red.png"),
	"gem_green":      preload("res://art/items/gem_green.png"),
	"gem_purple":     preload("res://art/items/gem_purple.png"),
	"nut":            preload("res://art/items/nut.png"),
}

# Pulse color per type (base tint for glow effect)
var pulse_colors := {
	"life_pot":       Color(1.0, 0.4, 0.4),
	"scroll_fire":    Color(1.0, 0.5, 0.2),
	"scroll_ice":     Color(0.4, 0.7, 1.0),
	"scroll_thunder": Color(1.0, 1.0, 0.3),
	"gem_red":        Color(1.0, 0.3, 0.3),
	"gem_green":      Color(0.3, 1.0, 0.4),
	"gem_purple":     Color(0.7, 0.3, 1.0),
	"nut":            Color(0.9, 0.75, 0.5),
}

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_start_y = position.y
	if powerup_type in textures:
		sprite.texture = textures[powerup_type]
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

	# Color pulse glow based on type
	var base_col: Color = pulse_colors.get(powerup_type, Color.WHITE)
	var pulse := 0.7 + 0.3 * sin(_time * 4.0)
	sprite.modulate = base_col.lerp(Color.WHITE, pulse)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(powerup_type)
		queue_free()


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
