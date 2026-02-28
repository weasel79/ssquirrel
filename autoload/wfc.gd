extends Node
# WFC (Wave Function Collapse) — simple tile constraint solver.
# Generates 2D grids of tile indices where neighboring tiles must match
# on their shared edges. Each tile has 4 edge sockets (TRBL).
# Socket strings must match: tile_a.right == tile_b.left, etc.
#
# Usage:
#   wfc.define_tile("grass", tex, "GGG", "GGG", "GGG", "GGG", 10.0)
#   wfc.define_tile("wall_top", tex, "WWW", "WGW", "WBW", "WGW", 2.0)
#   var grid = wfc.generate(20, 15)  # returns 2D array of tile names

# Tile definition: edge sockets + texture + weight
class TileDef:
	var name: String
	var texture: Texture2D
	var sockets: Array[String]  # [top, right, bottom, left]
	var weight: float
	var collision: bool  # true = wall/solid, blocks movement

var _tiles: Dictionary = {}  # name -> TileDef
var _tile_names: Array[String] = []


func define_tile(tile_name: String, tex: Texture2D,
		top: String, right: String, bottom: String, left: String,
		weight: float = 1.0, has_collision: bool = false) -> void:
	var td := TileDef.new()
	td.name = tile_name
	td.texture = tex
	td.sockets = [top, right, bottom, left]
	td.weight = weight
	td.collision = has_collision
	_tiles[tile_name] = td
	if tile_name not in _tile_names:
		_tile_names.append(tile_name)


func get_tile(tile_name: String) -> TileDef:
	return _tiles.get(tile_name)


func get_all_tile_names() -> Array[String]:
	return _tile_names


# Generate a grid[rows][cols] of tile name strings using WFC
func generate(cols: int, rows: int, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Each cell holds an array of possible tile names
	var grid: Array = []
	for r in range(rows):
		var row: Array = []
		for c in range(cols):
			row.append(_tile_names.duplicate())
		grid.append(row)

	# Collapse loop
	var max_iterations := cols * rows * 3
	for _iter in range(max_iterations):
		# Find cell with lowest entropy (fewest options > 1)
		var min_entropy := 9999
		var min_cells: Array = []
		for r in range(rows):
			for c in range(cols):
				var count: int = grid[r][c].size()
				if count <= 1:
					continue
				if count < min_entropy:
					min_entropy = count
					min_cells = [[r, c]]
				elif count == min_entropy:
					min_cells.append([r, c])

		if min_cells.is_empty():
			break  # All collapsed

		# Pick random cell among lowest entropy
		var pick: Array = min_cells[rng.randi() % min_cells.size()]
		var pr: int = pick[0]
		var pc: int = pick[1]

		# Collapse: pick one tile weighted by tile weight
		var options: Array = grid[pr][pc]
		var chosen := _weighted_pick(options, rng)
		grid[pr][pc] = [chosen]

		# Propagate constraints
		_propagate(grid, cols, rows)

	# Convert to single tile names (pick first if multiple remain)
	var result: Array = []
	for r in range(rows):
		var row: Array = []
		for c in range(cols):
			var opts: Array = grid[r][c]
			if opts.is_empty():
				row.append(_tile_names[0])  # fallback
			else:
				row.append(opts[0])
		result.append(row)
	return result


# Propagate constraints until stable
func _propagate(grid: Array, cols: int, rows: int) -> void:
	var changed := true
	var safety := 0
	while changed and safety < cols * rows * 4:
		changed = false
		safety += 1
		for r in range(rows):
			for c in range(cols):
				if grid[r][c].size() <= 1:
					continue
				var before: int = grid[r][c].size()
				grid[r][c] = _constrain_cell(grid, c, r, cols, rows)
				if grid[r][c].size() < before:
					changed = true


# Filter options for cell (c,r) based on already-collapsed neighbors
func _constrain_cell(grid: Array, c: int, r: int, cols: int, rows: int) -> Array:
	var options: Array = grid[r][c].duplicate()

	# Check each neighbor direction: [dr, dc, my_socket_idx, neighbor_socket_idx]
	var dirs := [[-1, 0, 0, 2], [0, 1, 1, 3], [1, 0, 2, 0], [0, -1, 3, 1]]

	for dir_info: Array in dirs:
		var nr: int = r + (dir_info[0] as int)
		var nc: int = c + (dir_info[1] as int)
		var my_idx: int = dir_info[2] as int
		var nb_idx: int = dir_info[3] as int

		if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
			continue

		var neighbor_options: Array = grid[nr][nc]
		if neighbor_options.size() == 0:
			continue

		# Collect all valid sockets the neighbor can present on its facing edge
		var valid_neighbor_sockets: Array[String] = []
		for nb_name in neighbor_options:
			var nb_def: TileDef = _tiles[nb_name]
			var sock: String = nb_def.sockets[nb_idx]
			if sock not in valid_neighbor_sockets:
				valid_neighbor_sockets.append(sock)

		# Filter my options: my socket on this edge must match one of neighbor's
		var filtered: Array = []
		for my_name in options:
			var my_def: TileDef = _tiles[my_name]
			var my_sock: String = my_def.sockets[my_idx]
			if my_sock in valid_neighbor_sockets:
				filtered.append(my_name)
		options = filtered

	if options.is_empty():
		# Contradiction — keep first tile as fallback
		return [_tile_names[0]]
	return options


# Weighted random pick from tile name list
func _weighted_pick(options: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for name in options:
		var td: TileDef = _tiles[name]
		total += td.weight
	var roll := rng.randf() * total
	var accum := 0.0
	for name in options:
		var td: TileDef = _tiles[name]
		accum += td.weight
		if roll <= accum:
			return name
	return options[options.size() - 1]
