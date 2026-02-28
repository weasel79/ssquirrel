extends Node2D
# WorldGenerator — endless scrolling noise-based terrain with autotiling
# and procedural hazard zones (ice, poison, acid, lava, toxic gas).
# Three noise layers: terrain shape, hazard placement, hazard type.
# One composited ImageTexture per chunk (1 draw call) + gas overlay sprite.
# Chunks generate one per frame to avoid stuttering.

const TILE_SIZE := 16
const CHUNK_TILES := 20        # 20×20 tiles = 320×320 px per chunk
const CHUNK_PX := CHUNK_TILES * TILE_SIZE
const GENERATE_RADIUS := 2    # chunks around player to keep
const MAX_CHUNKS_PER_FRAME := 2
const WALL_THRESHOLD := 0.28  # terrain noise > this = wall
const HAZARD_THRESHOLD := 0.22  # hazard noise > this = hazard zone
const SAFE_RADIUS := 5        # tiles around spawn always safe grass

# Tile type constants for gameplay queries
enum Tile { GRASS = 0, WALL = 1, ICE = 2, POISON = 3, ACID = 4, LAVA = 5 }

# Tile images for compositing
var _tile_images: Dictionary = {}

# Noise generators
var _noise: FastNoiseLite         # terrain shape (wall vs open)
var _hazard_noise: FastNoiseLite  # where hazards appear
var _biome_noise: FastNoiseLite   # what type of hazard

# Chunk tracking
var _chunks: Dictionary = {}           # Vector2i -> Node2D
var _chunk_types: Dictionary = {}      # Vector2i -> PackedByteArray (tile types)
var _pending_chunks: Array[Vector2i] = []
var _player: Node2D = null

# Safe zone
var _spawn_tile := Vector2i.ZERO

# Fill tile variant arrays
var _grass_fills: Array[String] = []
var _ice_fills: Array[String] = []
var _poison_fills: Array[String] = []
var _acid_fills: Array[String] = []
var _lava_fills: Array[String] = []
var _gas_fills: Array[String] = []


func _ready() -> void:
	_setup_noise()
	_load_tile_images()
	_create_gas_shader()


func init_world(player: Node2D) -> void:
	_player = player
	_spawn_tile = Vector2i(
		floori(player.global_position.x / TILE_SIZE),
		floori(player.global_position.y / TILE_SIZE))
	var pc := _world_to_chunk(player.global_position)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var ck := Vector2i(pc.x + dx, pc.y + dy)
			if ck not in _chunks:
				_build_chunk(ck)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_queue_nearby_chunks()
	_generate_pending()
	_cleanup_far_chunks()


# ── Public API: query tile type at world position ────────────────────────

func get_tile_type(world_pos: Vector2) -> int:
	var wx: int = floori(world_pos.x / TILE_SIZE)
	var wy: int = floori(world_pos.y / TILE_SIZE)
	var ck := Vector2i(floori(float(wx) / CHUNK_TILES), floori(float(wy) / CHUNK_TILES))
	if ck not in _chunk_types:
		return Tile.GRASS
	var local_x: int = wx - ck.x * CHUNK_TILES
	var local_y: int = wy - ck.y * CHUNK_TILES
	if local_x < 0 or local_x >= CHUNK_TILES or local_y < 0 or local_y >= CHUNK_TILES:
		return Tile.GRASS
	return _chunk_types[ck][local_y * CHUNK_TILES + local_x]


# ── Noise setup ───────────────────────────────────────────────────────────

func _setup_noise() -> void:
	var base_seed := randi()

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.06
	_noise.seed = base_seed
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5

	# Hazard placement — different frequency for larger blobs
	_hazard_noise = FastNoiseLite.new()
	_hazard_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hazard_noise.frequency = 0.04
	_hazard_noise.seed = base_seed + 1337
	_hazard_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hazard_noise.fractal_octaves = 2
	_hazard_noise.fractal_lacunarity = 2.0
	_hazard_noise.fractal_gain = 0.5

	# Biome type — very low frequency so hazard zones are coherent
	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.012
	_biome_noise.seed = base_seed + 42069
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


# ── Tile image loading ────────────────────────────────────────────────────

func _load_tile_images() -> void:
	var base := "res://art/tiles/wfc/"
	var names := [
		# Grass autotile
		"grass_fill_0", "grass_fill_1", "grass_fill_2",
		"grass_fill_3", "grass_fill_4", "grass_fill_5",
		"grass_edge_top", "grass_edge_bottom",
		"grass_edge_left", "grass_edge_right",
		"grass_outer_tl", "grass_outer_tr",
		"grass_outer_bl", "grass_outer_br",
		"grass_inner_tl", "grass_inner_tr",
		"grass_inner_bl", "grass_inner_br",
		"dark_fill",
		# Walls
		"wall_top_r1_c1", "wall_top_r1_c2", "wall_top_r1_c3",
		"wall_body_r5_c1", "wall_body_r5_c2", "wall_body_r5_c3",
		# Hazard fills
		"ice_fill_0", "ice_fill_1", "ice_fill_2", "ice_fill_3",
		"poison_fill_0", "poison_fill_1", "poison_fill_2",
		"acid_fill_0", "acid_fill_1", "acid_fill_2",
		"lava_fill_0", "lava_fill_1", "lava_fill_2",
		"gas_fill_0", "gas_fill_1", "gas_fill_2",
	]
	for n: String in names:
		var path: String = base + n + ".png"
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			var img: Image = tex.get_image()
			if img.get_format() != Image.FORMAT_RGB8:
				img.convert(Image.FORMAT_RGB8)
			_tile_images[n] = img

	_grass_fills = ["grass_fill_0", "grass_fill_1", "grass_fill_2",
		"grass_fill_3", "grass_fill_4", "grass_fill_5"]
	_ice_fills = ["ice_fill_0", "ice_fill_1", "ice_fill_2", "ice_fill_3"]
	_poison_fills = ["poison_fill_0", "poison_fill_1", "poison_fill_2"]
	_acid_fills = ["acid_fill_0", "acid_fill_1", "acid_fill_2"]
	_lava_fills = ["lava_fill_0", "lava_fill_1", "lava_fill_2"]
	_gas_fills = ["gas_fill_0", "gas_fill_1", "gas_fill_2"]


# ── Terrain sampling ──────────────────────────────────────────────────────

func _is_wall(wx: int, wy: int) -> bool:
	if _in_safe_zone(wx, wy):
		return false
	return _noise.get_noise_2d(float(wx), float(wy)) > WALL_THRESHOLD


func _in_safe_zone(wx: int, wy: int) -> bool:
	return absi(wx - _spawn_tile.x) <= SAFE_RADIUS and absi(wy - _spawn_tile.y) <= SAFE_RADIUS


# Determine hazard type for a non-wall tile. Returns Tile enum value.
func _get_hazard_type(wx: int, wy: int) -> int:
	if _in_safe_zone(wx, wy):
		return Tile.GRASS
	var h: float = _hazard_noise.get_noise_2d(float(wx), float(wy))
	if h < HAZARD_THRESHOLD:
		return Tile.GRASS
	# Use biome noise to pick hazard type in coherent zones
	var b: float = _biome_noise.get_noise_2d(float(wx), float(wy))
	if b < -0.25:
		return Tile.ICE
	elif b < 0.0:
		return Tile.POISON
	elif b < 0.25:
		return Tile.ACID
	else:
		return Tile.LAVA


# Pick autotile or hazard tile name for compositing
func _pick_tile(is_w: bool, w_up: bool, w_right: bool, w_down: bool,
		w_left: bool, hazard: int, rng: RandomNumberGenerator) -> String:
	if is_w:
		if rng.randf() < 0.5:
			return "wall_top_r1_c%d" % (rng.randi_range(1, 3))
		else:
			return "wall_body_r5_c%d" % (rng.randi_range(1, 3))

	# Non-wall tile with hazard — use hazard fill for interior tiles
	var up := w_up
	var rt := w_right
	var dn := w_down
	var lt := w_left
	var has_wall_neighbor: bool = up or rt or dn or lt

	# Hazard fills replace grass fills for interior (no wall neighbor) tiles
	if not has_wall_neighbor and hazard != Tile.GRASS:
		match hazard:
			Tile.ICE:
				return _ice_fills[rng.randi() % _ice_fills.size()]
			Tile.POISON:
				return _poison_fills[rng.randi() % _poison_fills.size()]
			Tile.ACID:
				return _acid_fills[rng.randi() % _acid_fills.size()]
			Tile.LAVA:
				return _lava_fills[rng.randi() % _lava_fills.size()]

	# Standard grass autotile logic
	if not has_wall_neighbor:
		return _grass_fills[rng.randi() % _grass_fills.size()]

	# Single edges
	if up and not rt and not dn and not lt:
		return "grass_edge_bottom"
	if not up and not rt and dn and not lt:
		return "grass_edge_top"
	if not up and not rt and not dn and lt:
		return "grass_edge_right"
	if not up and rt and not dn and not lt:
		return "grass_edge_left"

	# Outer corners
	if up and lt and not dn and not rt:
		return "grass_outer_br"
	if up and rt and not dn and not lt:
		return "grass_outer_bl"
	if dn and lt and not up and not rt:
		return "grass_outer_tr"
	if dn and rt and not up and not lt:
		return "grass_outer_tl"

	# Three or four wall neighbors
	var wall_count := int(up) + int(rt) + int(dn) + int(lt)
	if wall_count >= 3:
		return "dark_fill"

	# Opposite walls (corridor)
	return _grass_fills[rng.randi() % _grass_fills.size()]


# ── Chunk management ──────────────────────────────────────────────────────

func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK_PX), floori(pos.y / CHUNK_PX))


func _queue_nearby_chunks() -> void:
	var pc := _world_to_chunk(_player.global_position)
	for dy in range(-GENERATE_RADIUS, GENERATE_RADIUS + 1):
		for dx in range(-GENERATE_RADIUS, GENERATE_RADIUS + 1):
			var ck := Vector2i(pc.x + dx, pc.y + dy)
			if ck not in _chunks and ck not in _pending_chunks:
				_pending_chunks.append(ck)


func _generate_pending() -> void:
	var built := 0
	while not _pending_chunks.is_empty() and built < MAX_CHUNKS_PER_FRAME:
		var ck: Vector2i = _pending_chunks.pop_front()
		if ck not in _chunks:
			_build_chunk(ck)
			built += 1


func _cleanup_far_chunks() -> void:
	var pc := _world_to_chunk(_player.global_position)
	var to_remove: Array[Vector2i] = []
	for ck: Vector2i in _chunks:
		if maxi(absi(ck.x - pc.x), absi(ck.y - pc.y)) > GENERATE_RADIUS + 1:
			to_remove.append(ck)
	for ck in to_remove:
		(_chunks[ck] as Node2D).queue_free()
		_chunks.erase(ck)
		_chunk_types.erase(ck)


# ── Chunk building ────────────────────────────────────────────────────────

func _build_chunk(ck: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)

	var ox: int = ck.x * CHUNK_TILES
	var oy: int = ck.y * CHUNK_TILES

	# Sample wall/grass for each cell + 1-tile border for neighbor lookups
	var padded := CHUNK_TILES + 2
	var solid := PackedByteArray()
	solid.resize(padded * padded)
	for py in range(padded):
		for px in range(padded):
			var wx: int = ox + px - 1
			var wy: int = oy + py - 1
			solid[py * padded + px] = 1 if _is_wall(wx, wy) else 0

	# Sample hazard types for this chunk's tiles
	var tile_types := PackedByteArray()
	tile_types.resize(CHUNK_TILES * CHUNK_TILES)

	# Build composite image
	var chunk_img := Image.create(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGB8)
	chunk_img.fill(Color(0.12, 0.08, 0.06))

	# Gas overlay image (RGBA, transparent base)
	var has_gas := false
	var gas_img := Image.create(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8)
	gas_img.fill(Color(0, 0, 0, 0))

	var chunk_node := Node2D.new()
	chunk_node.name = "Chunk_%d_%d" % [ck.x, ck.y]
	chunk_node.position = Vector2(ck.x * CHUNK_PX, ck.y * CHUNK_PX)

	var shared_rect := RectangleShape2D.new()
	shared_rect.size = Vector2(TILE_SIZE, TILE_SIZE)

	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var px_p: int = tx + 1
			var py_p: int = ty + 1
			var is_w: bool = solid[py_p * padded + px_p] == 1
			var w_up: bool = solid[(py_p - 1) * padded + px_p] == 1
			var w_dn: bool = solid[(py_p + 1) * padded + px_p] == 1
			var w_lt: bool = solid[py_p * padded + (px_p - 1)] == 1
			var w_rt: bool = solid[py_p * padded + (px_p + 1)] == 1

			var wx: int = ox + tx
			var wy: int = oy + ty

			# Determine tile type
			var hazard: int = Tile.GRASS
			if is_w:
				hazard = Tile.WALL
			else:
				hazard = _get_hazard_type(wx, wy)
			tile_types[ty * CHUNK_TILES + tx] = hazard

			var tile_name: String = _pick_tile(is_w, w_up, w_rt, w_dn, w_lt, hazard, rng)

			# Blit tile into chunk image
			if tile_name in _tile_images:
				var src: Image = _tile_images[tile_name]
				chunk_img.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
					Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))

			# Paint gas/glow overlay for hazard tiles
			if hazard == Tile.POISON or hazard == Tile.ACID or hazard == Tile.LAVA:
				var overlay_color: Color
				match hazard:
					Tile.POISON: overlay_color = Color(0.2, 0.6, 0.15, 0.35)
					Tile.ACID:   overlay_color = Color(0.5, 0.7, 0.1, 0.25)
					Tile.LAVA:   overlay_color = Color(0.9, 0.3, 0.05, 0.2)
				gas_img.fill_rect(
					Rect2i(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE),
					overlay_color)
				has_gas = true

			# Wall collision
			if is_w:
				var body := StaticBody2D.new()
				body.position = Vector2(
					tx * TILE_SIZE + TILE_SIZE * 0.5,
					ty * TILE_SIZE + TILE_SIZE * 0.5)
				body.collision_layer = 32
				body.collision_mask = 0
				var shape := CollisionShape2D.new()
				shape.shape = shared_rect
				body.add_child(shape)
				chunk_node.add_child(body)

	# Terrain sprite
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(chunk_img)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chunk_node.add_child(spr)

	# Gas/glow overlay sprite with animated shader
	if has_gas:
		var gas_spr := Sprite2D.new()
		gas_spr.texture = ImageTexture.create_from_image(gas_img)
		gas_spr.centered = false
		gas_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gas_spr.z_index = 1
		# Apply pulsing shader
		var mat := ShaderMaterial.new()
		mat.shader = _gas_shader
		gas_spr.material = mat
		chunk_node.add_child(gas_spr)

	add_child(chunk_node)
	_chunks[ck] = chunk_node
	_chunk_types[ck] = tile_types


# ── Gas overlay shader (created once, shared) ────────────────────────────

var _gas_shader: Shader = null

func _create_gas_shader() -> void:
	_gas_shader = Shader.new()
	_gas_shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		COLOR = tex;
		return;
	}
	// Pulsing opacity with two overlapping sine waves
	float pulse = sin(TIME * 1.5 + UV.x * 8.0) * 0.3
	            + sin(TIME * 2.3 + UV.y * 6.0) * 0.2;
	// Drift the UV slightly for swirling motion
	float drift_x = sin(TIME * 0.7 + UV.y * 4.0) * 0.02;
	float drift_y = cos(TIME * 0.9 + UV.x * 5.0) * 0.02;
	vec4 drifted = texture(TEXTURE, UV + vec2(drift_x, drift_y));
	drifted.a *= (0.7 + pulse);
	drifted.a = clamp(drifted.a, 0.0, 0.6);
	COLOR = drifted;
}
"""
