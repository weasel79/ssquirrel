extends Control
# Title screen — shows "SSquirrel" with animated Mario sprite for 2 seconds,
# then transitions to the main game scene.

const SHEET_COLS := 20
const SHEET_TILE := 16
const SPRITE_SCALE := 4.0

var _sheet: Texture2D = preload("res://art/sprites/player/mario/mario_reconstructed_sheet.png")

@onready var anim_sprite: AnimatedSprite2D = $CenterContainer/VBoxContainer/SpriteContainer/AnimSprite


func _ready() -> void:
	anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_build_animations()
	anim_sprite.play("run")
	SoundManager.play_its_me()

	# Wait 2 seconds then go to main scene
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _frame_atlas(n: int) -> AtlasTexture:
	var col := n % SHEET_COLS
	var row := n / SHEET_COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = Rect2(col * SHEET_TILE, row * SHEET_TILE, SHEET_TILE, SHEET_TILE)
	return atlas


func _build_animations() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	# Idle: right-facing idle frame
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 4.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", _frame_atlas(23))

	# Run: walk-right cycle
	sf.add_animation("run")
	sf.set_animation_speed("run", 12.0)
	sf.set_animation_loop("run", true)
	for fn in [26, 27, 29, 26, 27, 29, 23, 23]:
		sf.add_frame("run", _frame_atlas(fn))

	anim_sprite.sprite_frames = sf
