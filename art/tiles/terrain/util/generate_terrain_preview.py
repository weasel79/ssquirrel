"""Generate a static 16x8 terrain preview image (terrain_preview.png).

Layout:
  - sea of water tiles (background)
  - small sand island (4x2) in the left-centre
  - large sand island (9x6) on the right with a 4x3 inner lake

Run from the project root:
  python generate_terrain_preview.py
"""

from PIL import Image
import os, random

TILE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "wfc")
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "terrain_preview.png")
TILE_SIZE = 32
COLS, ROWS = 16, 8

# ── Tile loader with cache ────────────────────────────────────────────────────
_cache: dict = {}

def tile(name: str) -> Image.Image:
    if name not in _cache:
        _cache[name] = Image.open(os.path.join(TILE_DIR, name + ".png")).convert("RGB")
    return _cache[name]


# ── Map grid ──────────────────────────────────────────────────────────────────
# Seed ensures reproducible water fill variation across the sea
rng = random.Random(7)
W = ["water_fill_0", "water_fill_1", "water_fill_2"]
grid = [[rng.choice(W) for _ in range(COLS)] for _ in range(ROWS)]

# ── Small sand island: cols 1-4, rows 4-5 (4 wide × 2 tall) ─────────────────
grid[4][1] = "sand_outer_tl"
grid[4][2] = "sand_edge_top"
grid[4][3] = "sand_edge_top"
grid[4][4] = "sand_outer_tr"
grid[5][1] = "sand_outer_bl"
grid[5][2] = "sand_edge_bottom"
grid[5][3] = "sand_edge_bottom"
grid[5][4] = "sand_outer_br"

# ── Big sand island: cols 5-13, rows 1-6 (9 wide × 6 tall) ──────────────────
# Top edge
grid[1][5]  = "sand_outer_tl"
for c in range(6, 13): grid[1][c] = "sand_edge_top"
grid[1][13] = "sand_outer_tr"

# Left / right edges
for r in range(2, 6):
    grid[r][5]  = "sand_edge_left"
    grid[r][13] = "sand_edge_right"

# Bottom edge
grid[6][5]  = "sand_outer_bl"
for c in range(6, 13): grid[6][c] = "sand_edge_bottom"
grid[6][13] = "sand_outer_br"

# Interior sand fills — cycle through 3 variants for texture variety
SF = ["sand_fill_0", "sand_fill_1", "sand_fill_2"]
for r in range(2, 6):
    for c in range(6, 13):
        grid[r][c] = SF[(r + c) % len(SF)]

# ── Inner lake: cols 7-10, rows 2-4 (4 wide × 3 tall) ───────────────────────
# Top row — water_edge_top (frame 351) shows sand-above / water-below cleanly
grid[2][7]  = "water_outer_tl"   # corner, approx = water_fill
grid[2][8]  = "water_edge_top"   # sand above, water below
grid[2][9]  = "water_edge_top"
grid[2][10] = "water_outer_tr"   # corner, approx = water_fill

# Middle row — water fill interior
grid[3][7]  = "water_edge_left"  # waterfall-style left edge
grid[3][8]  = "water_fill_0"
grid[3][9]  = "water_fill_1"
grid[3][10] = "water_edge_right" # waterfall-style right edge

# Bottom row — approx fills (no clean sand-below tile exists)
grid[4][7]  = "water_outer_bl"   # corner, approx = water_fill
grid[4][8]  = "water_edge_bottom"# approx = water_fill
grid[4][9]  = "water_edge_bottom"
grid[4][10] = "water_outer_br"   # corner, approx = water_fill

# ── Render ────────────────────────────────────────────────────────────────────
img = Image.new("RGB", (COLS * TILE_SIZE, ROWS * TILE_SIZE))
for r in range(ROWS):
    for c in range(COLS):
        img.paste(tile(grid[r][c]), (c * TILE_SIZE, r * TILE_SIZE))

img.save(OUT_PATH)
print(f"Saved {OUT_PATH}  ({COLS * TILE_SIZE}x{ROWS * TILE_SIZE} px)")
