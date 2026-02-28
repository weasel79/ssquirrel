extends Node2D
# WorldGenerator — endless scrolling noise-based terrain with autotiling.
# Terrain tiles are 32×32 RGBA PNGs from art/tiles/terrain/; each PNG is a
# 3-col × 6-row sheet (96×192) covering solid, edge, corner, and alt-fill slots.
# On each level start one random "main terrain" is chosen; water/lava/toxic and
# 2–3 extra ground terrains are blended in as blobs using the existing noise layers.
# One composited ImageTexture per chunk (1 draw call) + animated hazard overlay.
#
# Compositing uses a two-pass approach matching terrain_mapgen.html:
#   Pass 1 — blit main terrain "solid" on every non-wall cell (opaque background).
#   Pass 2 — blend_rect each cell's autotile slot (alpha corner tiles show pass 1).

const TILE_SIZE   := 32               # native tile size — matches 32×32 PNGs
const CHUNK_TILES := 20               # 20×20 tiles per chunk
const CHUNK_PX    := CHUNK_TILES * TILE_SIZE   # 640 px per chunk
const GENERATE_RADIUS     := 2
const MAX_CHUNKS_PER_FRAME := 2
const WALL_THRESHOLD   := 0.28        # terrain noise > this = wall
const HAZARD_THRESHOLD := 0.22        # hazard noise > this = non-main terrain zone
const SAFE_RADIUS := 5                # tiles around spawn: always main terrain, never wall

# ── Terrain pools ─────────────────────────────────────────────────────────────

const MAIN_TERRAIN_POOL: Array[String] = [
	"grass", "grass2", "sand", "gravel", "tile",
	"dark", "dirt_bright", "dirt_dark", "dirt3"
]
# Always present, never main terrain. Deal damage when walked on.
const REQUIRED_HAZARDS: Array[String] = ["water", "lava", "toxic"]
# Randomly picked each level; overlaid on main terrain to render wall/mountain cells.
const WALL_OVERLAY_POOL: Array[String] = ["abyss", "abyss2", "bush", "hole_t", "tile"]

# Maps hazard terrain name → Tile enum int value for gameplay callers.
const HAZARD_TILE_TYPE: Dictionary = {
	"water": 3,   # Tile.POISON
	"lava":  5,   # Tile.LAVA
	"toxic": 3,   # Tile.POISON
}

# Tile type constants — unchanged to avoid breaking callers.
enum Tile { GRASS = 0, WALL = 1, ICE = 2, POISON = 3, ACID = 4, LAVA = 5 }

# ── Per-level state ───────────────────────────────────────────────────────────

var _main_terrain: String = "grass"
var _wall_terrain: String = "gravel"       # renders wall/mountain cells
var _active_terrains: Array[String] = []   # non-main terrains for this level
var _terrain_slots: Dictionary = {}        # terrain_name -> { slot_key -> Image }
var _terrain_ranges: Array = []            # [{name, lo, hi}] biome_noise → terrain

# ── Noise generators ─────────────────────────────────────────────────────────

var _noise: FastNoiseLite          # terrain shape (wall vs open)
var _hazard_noise: FastNoiseLite   # where non-main terrain blobs appear
var _biome_noise: FastNoiseLite    # which non-main terrain (coherent regions)

# ── Chunk tracking ────────────────────────────────────────────────────────────

var _chunks: Dictionary = {}             # Vector2i -> Node2D
var _chunk_types: Dictionary = {}        # Vector2i -> PackedByteArray (Tile enum)
var _pending_chunks: Array[Vector2i] = []
var _player: Node2D = null
var _spawn_tile := Vector2i.ZERO

var _debug_canvas: CanvasLayer = null


func _ready() -> void:
	_setup_noise()


func init_world(player: Node2D) -> void:
	_player = player
	_spawn_tile = Vector2i(
		floori(player.global_position.x / TILE_SIZE),
		floori(player.global_position.y / TILE_SIZE))

	# Choose terrains for this level before building any chunks.
	var setup_rng := RandomNumberGenerator.new()
	setup_rng.randomize()
	_setup_terrains(setup_rng)
	_create_terrain_debug_display()

	# Build the 3×3 chunks around the player immediately.
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


# ── Public API ────────────────────────────────────────────────────────────────

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


# ── Noise setup ───────────────────────────────────────────────────────────────

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

	_hazard_noise = FastNoiseLite.new()
	_hazard_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hazard_noise.frequency = 0.04
	_hazard_noise.seed = base_seed + 1337
	_hazard_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hazard_noise.fractal_octaves = 2
	_hazard_noise.fractal_lacunarity = 2.0
	_hazard_noise.fractal_gain = 0.5

	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.012
	_biome_noise.seed = base_seed + 42069
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


# ── Terrain setup (once per level) ───────────────────────────────────────────

func _setup_terrains(rng: RandomNumberGenerator) -> void:
	# Choose a random background (main) terrain.
	_main_terrain = MAIN_TERRAIN_POOL[rng.randi() % MAIN_TERRAIN_POOL.size()]

	# Build extra pool: all main-pool terrains that aren't the chosen main.
	var extra_pool: Array[String] = []
	for tname in MAIN_TERRAIN_POOL:
		if tname != _main_terrain:
			extra_pool.append(tname)
	extra_pool.shuffle()

	# Pick a wall overlay terrain (abyss/bush/hole_t/tile) — drawn on top of
	# main terrain to visually fill wall/mountain cells.
	_wall_terrain = WALL_OVERLAY_POOL[rng.randi() % WALL_OVERLAY_POOL.size()]

	# Pick 2–3 extra walkable ground terrains.
	var n_extra := rng.randi_range(2, 3)
	var extras := extra_pool.slice(0, n_extra)

	# Active terrains: required hazards + walkable extras.
	_active_terrains = REQUIRED_HAZARDS.duplicate()
	_active_terrains.append_array(extras)

	# Load tileset sheets for every terrain we'll use.
	_terrain_slots.clear()
	var all_needed: Array[String] = [_main_terrain, _wall_terrain]
	all_needed.append_array(_active_terrains)
	for tname in all_needed:
		_terrain_slots[tname] = _load_terrain_tileset(tname)

	# Divide biome_noise range [-1..1] evenly across active terrains so every
	# terrain is guaranteed a noise band and will appear on every map.
	_terrain_ranges.clear()
	var n := _active_terrains.size()
	for i in range(n):
		_terrain_ranges.append({
			"name": _active_terrains[i],
			"lo":   -1.0 + i * (2.0 / n),
			"hi":   -1.0 + (i + 1) * (2.0 / n),
		})


# Load a 96×192 tileset PNG and return a dict of 18 named 32×32 sub-images.
func _load_terrain_tileset(tname: String) -> Dictionary:
	var path := "res://art/tiles/terrain/" + tname + ".png"
	if not ResourceLoader.exists(path):
		return {}
	var img: Image = (load(path) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)   # keep alpha for transparent corner tiles
	var layout: Array[Array] = [
		["small",     "inner_tl",    "inner_tr"],
		["small2",    "inner_bl",    "inner_br"],
		["corner_tl", "wall_top",    "corner_tr"],
		["wall_left", "solid",       "wall_right"],
		["corner_bl", "wall_bottom", "corner_br"],
		["alt1",      "alt2",        "alt3"],
	]
	var slots: Dictionary = {}
	for row in range(6):
		for col in range(3):
			var sub: Image = img.get_region(Rect2i(col * 32, row * 32, 32, 32))
			slots[layout[row][col]] = sub
	return slots


# ── Terrain sampling ──────────────────────────────────────────────────────────

func _in_safe_zone(wx: int, wy: int) -> bool:
	return absi(wx - _spawn_tile.x) <= SAFE_RADIUS \
		and absi(wy - _spawn_tile.y) <= SAFE_RADIUS


# Raw terrain name for world position — no erosion, used to fill the padded grid.
# Returns "wall", _main_terrain, or an active terrain name.
func _get_terrain_raw(wx: int, wy: int) -> String:
	if _in_safe_zone(wx, wy):
		return _main_terrain
	if _noise.get_noise_2d(float(wx), float(wy)) > WALL_THRESHOLD:
		return "wall"
	var h: float = _hazard_noise.get_noise_2d(float(wx), float(wy))
	if h <= HAZARD_THRESHOLD:
		return _main_terrain
	var b: float = _biome_noise.get_noise_2d(float(wx), float(wy))
	for entry in _terrain_ranges:
		if b >= entry.lo and b < entry.hi:
			return entry.name
	return _active_terrains.back()


# ── Chunk management ──────────────────────────────────────────────────────────

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


# ── Chunk building ────────────────────────────────────────────────────────────

func _build_chunk(ck: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)

	var ox: int = ck.x * CHUNK_TILES
	var oy: int = ck.y * CHUNK_TILES
	var padded := CHUNK_TILES + 2   # 22×22 with 1-tile border for 8-dir neighbours

	# ── Stage 1: sample padded terrain grid ───────────────────────────────────
	var tgrid: Array = []
	tgrid.resize(padded * padded)
	for py in range(padded):
		for px in range(padded):
			tgrid[py * padded + px] = _get_terrain_raw(ox + px - 1, oy + py - 1)

	# ── Stage 2: one-pass erosion (minimum 2-tile blob width) ─────────────────
	# A non-main, non-wall cell with 0 same-material backing in H or V is
	# at most 1-tile wide in that axis — revert it to main terrain.
	for py in range(1, padded - 1):
		for px in range(1, padded - 1):
			var tmat: String = tgrid[py * padded + px]
			if tmat == _main_terrain or tmat == "wall":
				continue
			var h_back: int = int(tgrid[py * padded + (px - 1)] == tmat) \
				+ int(tgrid[py * padded + (px + 1)] == tmat)
			var v_back: int = int(tgrid[(py - 1) * padded + px] == tmat) \
				+ int(tgrid[(py + 1) * padded + px] == tmat)
			if h_back == 0 or v_back == 0:
				tgrid[py * padded + px] = _main_terrain

	# ── Stage 3: composite image + physics ────────────────────────────────────
	# RGBA8 so blend_rect can alpha-composite corner tiles correctly.
	var chunk_img := Image.create(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8)
	chunk_img.fill(Color(0.12, 0.08, 0.06, 1.0))   # dark background for walls

	var chunk_node := Node2D.new()
	chunk_node.name = "Chunk_%d_%d" % [ck.x, ck.y]
	chunk_node.position = Vector2(ck.x * CHUNK_PX, ck.y * CHUNK_PX)

	var shared_rect := RectangleShape2D.new()
	shared_rect.size = Vector2(TILE_SIZE, TILE_SIZE)

	var tile_types := PackedByteArray()
	tile_types.resize(CHUNK_TILES * CHUNK_TILES)

	# Pass 1: fill every non-wall cell with main terrain SOLID (opaque).
	# This ensures alpha-transparent corner tiles of other terrains composite
	# correctly onto the main terrain background, matching terrain_mapgen.html.
	var main_slots: Dictionary = _terrain_slots.get(_main_terrain, {})
	var main_solid: Image = main_slots.get("solid")
	# Fill every cell (including walls) with main terrain solid — wall overlay
	# and autotile blends will be applied on top in pass 2.
	if main_solid != null:
		for ty in range(CHUNK_TILES):
			for tx in range(CHUNK_TILES):
				chunk_img.blend_rect(main_solid, Rect2i(0, 0, 32, 32),
					Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))

	# Pass 2: autotile every cell (wall → collision only; other → blend_rect tile).
	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var py_p := ty + 1
			var px_p := tx + 1

			# This cell and its 8 neighbours from the eroded terrain grid.
			var tmat: String  = tgrid[py_p       * padded + px_p      ]
			var n_mat: String = tgrid[(py_p - 1) * padded + px_p      ]
			var s_mat: String = tgrid[(py_p + 1) * padded + px_p      ]
			var w_mat: String = tgrid[py_p       * padded + (px_p - 1)]
			var e_mat: String = tgrid[py_p       * padded + (px_p + 1)]
			var nw_mat: String = tgrid[(py_p - 1) * padded + (px_p - 1)]
			var ne_mat: String = tgrid[(py_p - 1) * padded + (px_p + 1)]
			var sw_mat: String = tgrid[(py_p + 1) * padded + (px_p - 1)]
			var se_mat: String = tgrid[(py_p + 1) * padded + (px_p + 1)]

			# Store gameplay tile type.
			var tile_type: int = Tile.GRASS
			if tmat == "wall":
				tile_type = Tile.WALL
			elif tmat in HAZARD_TILE_TYPE:
				tile_type = HAZARD_TILE_TYPE[tmat]
			tile_types[ty * CHUNK_TILES + tx] = tile_type

			if tmat == "wall":
				# Step 1: randomise main terrain alt fill on the solid base (pass 1).
				var wall_fill_key: String
				match rng.randi() % 6:
					0: wall_fill_key = "alt1"
					1: wall_fill_key = "alt2"
					2: wall_fill_key = "alt3"
					_: wall_fill_key = "solid"
				var wall_fill: Image = main_slots.get(wall_fill_key, main_solid)
				if wall_fill != null:
					chunk_img.blend_rect(wall_fill, Rect2i(0, 0, 32, 32),
						Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))

				# Step 2: autotile the wall overlay toward open (non-wall) neighbours.
				var wdN := n_mat  != "wall";  var wdE := e_mat  != "wall"
				var wdS := s_mat  != "wall";  var wdW := w_mat  != "wall"
				var wdNE := ne_mat != "wall"; var wdNW := nw_mat != "wall"
				var wdSE := se_mat != "wall"; var wdSW := sw_mat != "wall"
				var wdc := int(wdN) + int(wdE) + int(wdS) + int(wdW)
				var wkey: String
				if wdc == 0:
					if   wdSE: wkey = "inner_tl"
					elif wdSW: wkey = "inner_tr"
					elif wdNE: wkey = "inner_bl"
					elif wdNW: wkey = "inner_br"
					else:
						match rng.randi() % 6:
							0: wkey = "alt1"
							1: wkey = "alt2"
							2: wkey = "alt3"
							_: wkey = "solid"
				elif wdc == 1:
					if   wdN: wkey = "wall_top"
					elif wdS: wkey = "wall_bottom"
					elif wdW: wkey = "wall_left"
					else:     wkey = "wall_right"
				elif wdc == 2:
					if   wdN and wdW: wkey = "corner_tl"
					elif wdN and wdE: wkey = "corner_tr"
					elif wdS and wdW: wkey = "corner_bl"
					elif wdS and wdE: wkey = "corner_br"
					else:             wkey = "solid"
				elif wdc == 3:
					wkey = "small"
				else:
					wkey = "small2"
				var wslots: Dictionary = _terrain_slots.get(_wall_terrain, {})
				var wtile: Image = wslots.get(wkey, wslots.get("solid"))
				if wtile != null:
					chunk_img.blend_rect(wtile, Rect2i(0, 0, 32, 32),
						Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))

				# Add collision body.
				var body := StaticBody2D.new()
				body.position = Vector2(
					tx * TILE_SIZE + TILE_SIZE * 0.5,
					ty * TILE_SIZE + TILE_SIZE * 0.5)
				body.collision_layer = 32
				body.collision_mask  = 0
				var cshape := CollisionShape2D.new()
				cshape.shape = shared_rect
				body.add_child(cshape)
				chunk_node.add_child(body)
				continue

			if tmat == _main_terrain:
				# Main terrain: only fill variants — no edge or corner tiles.
				# Pass 1 already painted solid; here we randomise alt fills.
				var fill_key: String
				match rng.randi() % 6:
					0: fill_key = "alt1"
					1: fill_key = "alt2"
					2: fill_key = "alt3"
					_: fill_key = "solid"
				var fill_img: Image = main_slots.get(fill_key, main_solid)
				if fill_img != null:
					chunk_img.blend_rect(fill_img, Rect2i(0, 0, 32, 32),
						Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))
				continue

			# Non-main terrain: full 8-directional autotile (edges + corners).
			var tile_img: Image = _pick_terrain_tile(
				tmat, n_mat, e_mat, s_mat, w_mat,
				ne_mat, nw_mat, se_mat, sw_mat, rng)
			if tile_img != null:
				chunk_img.blend_rect(tile_img, Rect2i(0, 0, 32, 32),
					Vector2i(tx * TILE_SIZE, ty * TILE_SIZE))

	# Flatten to RGB8 — removes any residual alpha so the sprite is always opaque.
	chunk_img.convert(Image.FORMAT_RGB8)

	# Terrain sprite — one draw call covers the full chunk.
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(chunk_img)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chunk_node.add_child(spr)

	add_child(chunk_node)
	_chunks[ck]      = chunk_node
	_chunk_types[ck] = tile_types


# ── Autotile picker ───────────────────────────────────────────────────────────

# Return the 32×32 RGBA Image for the correct autotile slot of terrain `tmat`.
# A direction flag is true when that neighbour contains a DIFFERENT material
# (wall, void, or another terrain type), meaning an edge or corner is needed.
#
# Inner corner rule (terraintileset.md):
#   void at SE → inner_tl   void at SW → inner_tr
#   void at NE → inner_bl   void at NW → inner_br
func _pick_terrain_tile(
		tmat: String,
		n_mat: String, e_mat: String, s_mat: String, w_mat: String,
		ne_mat: String, nw_mat: String, se_mat: String, sw_mat: String,
		rng: RandomNumberGenerator) -> Image:

	var slots: Dictionary = _terrain_slots.get(tmat, {})
	if slots.is_empty():
		return null

	var dN  := n_mat  != tmat
	var dE  := e_mat  != tmat
	var dS  := s_mat  != tmat
	var dW  := w_mat  != tmat
	var dNE := ne_mat != tmat
	var dNW := nw_mat != tmat
	var dSE := se_mat != tmat
	var dSW := sw_mat != tmat

	var dc := int(dN) + int(dE) + int(dS) + int(dW)

	var key: String
	if dc == 0:
		# Interior — check diagonals for concave inner corners.
		if   dSE: key = "inner_tl"
		elif dSW: key = "inner_tr"
		elif dNE: key = "inner_bl"
		elif dNW: key = "inner_br"
		else:
			# Fully surrounded — randomise between solid and alt fills.
			match rng.randi() % 6:
				0: key = "alt1"
				1: key = "alt2"
				2: key = "alt3"
				_: key = "solid"
	elif dc == 1:
		# Single exposed edge.
		if   dN: key = "wall_top"
		elif dS: key = "wall_bottom"
		elif dW: key = "wall_left"
		else:    key = "wall_right"
	elif dc == 2:
		# Two neighbours different.
		if   dN and dW: key = "corner_tl"
		elif dN and dE: key = "corner_tr"
		elif dS and dW: key = "corner_bl"
		elif dS and dE: key = "corner_br"
		else:           key = "solid"   # opposite edges (corridor) → fill
	elif dc == 3:
		key = "small"
	else:
		key = "small2"   # 4 different neighbours

	return slots.get(key, slots.get("solid"))


# ── Debug terrain display ─────────────────────────────────────────────────────

# Shows a panel on the right side of the screen listing every active terrain
# with its solid tile image and name. Main terrain is marked with an asterisk.
# Rebuilt on each call (safe to call repeatedly from init_world).
func _create_terrain_debug_display() -> void:
	if _debug_canvas != null:
		_debug_canvas.queue_free()

	_debug_canvas = CanvasLayer.new()
	_debug_canvas.layer = 100   # always on top
	add_child(_debug_canvas)

	# Build the ordered display list: main, wall terrain, then actives.
	var all_display: Array[String] = [_main_terrain, _wall_terrain]
	all_display.append_array(_active_terrains)

	var vp_size: Vector2 = get_viewport_rect().size
	var item_h  := 36
	var panel_w := 164
	var panel_h := 8 + all_display.size() * item_h + 8
	var panel_x := vp_size.x - panel_w - 8.0
	var panel_y := 8.0

	# Semi-transparent background.
	var bg := ColorRect.new()
	bg.color    = Color(0.0, 0.0, 0.0, 0.6)
	bg.position = Vector2(panel_x, panel_y)
	bg.size     = Vector2(panel_w, panel_h)
	_debug_canvas.add_child(bg)

	for i in range(all_display.size()):
		var tname: String = all_display[i]
		var iy := panel_y + 8.0 + i * item_h
		var ix := panel_x + 6.0

		# 32×32 solid tile thumbnail.
		var slots: Dictionary = _terrain_slots.get(tname, {})
		var solid_img: Image  = slots.get("solid")
		if solid_img != null:
			var tspr := Sprite2D.new()
			tspr.texture        = ImageTexture.create_from_image(solid_img)
			tspr.centered       = false
			tspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tspr.position       = Vector2(ix, iy)
			_debug_canvas.add_child(tspr)

		# Terrain name label (role marker for main and wall terrains).
		var lbl := Label.new()
		var suffix := ""
		if tname == _main_terrain:  suffix = " *"
		elif tname == _wall_terrain: suffix = " (wall)"
		lbl.text = tname + suffix
		lbl.position = Vector2(ix + 36.0, iy + 8.0)
		lbl.add_theme_font_size_override("font_size", 11)
		_debug_canvas.add_child(lbl)
