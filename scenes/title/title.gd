extends Control
# Title screen — shows "SSquirrel" with animated Mario sprite for 2 seconds,
# then transitions to the main game scene.

var _tex := {
	"idle":  preload("res://art/sprites/player/mario_idle.png"),
	"run":   preload("res://art/sprites/player/mario_run.png"),
}

@onready var anim_sprite: AnimatedSprite2D = $CenterContainer/VBoxContainer/SpriteContainer/AnimSprite


func _ready() -> void:
	_build_animations()
	anim_sprite.play("run")
	SoundManager.play_its_me()

	# Wait 2 seconds then go to main scene
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _build_animations() -> void:
	var sf := SpriteHelper.build_sprite_frames({
		"idle": {
			"texture": _tex["idle"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 2,
			"fps": 4.0,
			"loop": true,
		},
		"run": {
			"texture": _tex["run"],
			"frame_size": Vector2i(64, 64),
			"frame_count": 8,
			"fps": 12.0,
			"loop": true,
		},
	})
	anim_sprite.sprite_frames = sf
