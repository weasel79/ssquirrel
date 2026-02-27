extends Node
# SpriteHelper — runtime SpriteFrames builder from horizontal strip sheets.
# Autoloaded as "SpriteHelper". Creates AtlasTexture frames from PNG sheets
# without needing the Godot editor's SpriteFrames import pipeline.


# Build a SpriteFrames resource from a dictionary of animation definitions.
# anim_defs format:
#   { "anim_name": { "texture": Texture2D, "frame_size": Vector2i,
#                    "frame_count": int, "fps": float, "loop": bool } }
# Returns a ready-to-use SpriteFrames resource.
func build_sprite_frames(anim_defs: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	# Remove the default "default" animation that SpriteFrames ships with
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	for anim_name: String in anim_defs:
		var def: Dictionary = anim_defs[anim_name]
		var tex: Texture2D = def["texture"]
		var frame_size: Vector2i = def["frame_size"]
		var frame_count: int = def["frame_count"]
		var fps: float = def.get("fps", 8.0)
		var loop: bool = def.get("loop", true)

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)

		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(
				i * frame_size.x, 0,
				frame_size.x, frame_size.y
			)
			sf.add_frame(anim_name, atlas)

	return sf
