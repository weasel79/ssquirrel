# Terrain Utility Tools

Scripts and tools for generating and editing terrain tiles for the SSQuirrel project.
All scripts can be run from **any directory** — they use `__file__`-relative paths.

---

## terrain_mapgen.html

Interactive terrain map generator — open directly in any browser (no server needed).

**Features**
- Left panel: terrain groups with per-terrain **amount** and **size** faders
  - Amount fader: how much of the map this terrain covers (faders are free; generation normalises non-main terrains among themselves)
  - Size fader: one big blob (×1) → many scattered islands (scatter)
  - Radio button: marks one terrain as **main terrain** (fills the entire background with solid/alt tiles, no walls or corners)
- Singles density fader: scatters random plant/item tiles from `terrain_atlas_singles.png` on interior cells
- **Generate** / **🎲 Random**: generate a map with current settings or a random seed
- **Save .tmap** / **Load .tmap**: save and reload map layouts as JSON
- **Export PNG**: export the rendered map as a PNG image

**Rebuild** (required after editing `build_mapgen.py`):
```
python art/tiles/terrain/util/build_mapgen.py
```
This re-embeds all tileset PNGs as base64 and rewrites `terrain_mapgen.html` in the same folder.

---

## build_mapgen.py

Generates `terrain_mapgen.html`.

Reads all terrain tileset PNGs from `art/tiles/terrain/` and `terrain_atlas_singles.png`,
base64-encodes them, and writes a fully self-contained HTML file.

**Usage**
```
python build_mapgen.py
```

**Tileset list** (defined in `ALL` at the top of the script):
`grass`, `grass2`, `sand`, `water`, `gravel`, `dark`, `tile`,
`water_on_grass`, `sand_on_water`, `dirt_on_grass`,
`lava`, `abyss`, `abyss2`, `hole_t`, `toxic`,
`dirt_bright`, `dirt_dark`, `dirt3`,
`crop1`, `crop2`, `bush`, `corn`

Missing PNGs are silently skipped.

---

## extract_terrain_tiles.py

Extracts individual autotile sets from `terrain_atlas.gif` (in `art/tiles/terrain/`, 1012 frames, 32×32 px each)
and saves them as 96×192 px PNG tilesets to `art/tiles/terrain/`.

Each tileset is a 3×6 grid of 32×32 tiles (see `terraintileset.md` for the layout).
Frame offsets per tileset are defined in `terrain_atlas.txt`.

**Usage**
```
python art/tiles/terrain/util/extract_terrain_tiles.py
```

---

## generate_terrain_preview.py

Generates `terrain_preview.png` (saved to `art/tiles/terrain/`) — a small test map rendered from the extracted tile PNGs.
Used to visually verify tile extractions and inner corner logic.

**Usage**
```
python art/tiles/terrain/util/generate_terrain_preview.py
```

---

## terrain_atlas.txt

Plain-text mapping of tileset names to their start frame index in `terrain_atlas.gif`.
One entry per line: `<name> <start_frame>`.

Used by `extract_terrain_tiles.py`.

---

## terraintileset.md

Documentation of the terrain tileset PNG layout:
- 3 columns × 6 rows of 32×32 px tiles per PNG (96×192 px total)
- Tile slot names, positions, and meanings
- Corrected inner corner selection rule (void diagonal → opposite tile name)
- Atlas offset table

---

## tileset_editor.html *(project root)*

Standalone GIF tileset editor — open directly in any browser (no server needed).
Located at `ssquirel/tileset_editor.html`.

**Features**
- Load `terrain_atlas.gif` (or any GIF) and browse all frames as a grid
- Drag to reorder tiles; Shift+drag to swap two tiles
- Alt+drag rubber-band selection (add or remove mode based on first tile hit)
- Right-click to delete a tile; Ctrl+click to duplicate
- Ctrl+Z: undo (10 steps)
- Zoom slider: scale grid 1×–4×
- Save/Load: JSON with base64 PNGs (preserves arrangement without the source GIF)
- Refresh: re-decode source GIF keeping current arrangement

**Libraries (CDN)**
- omggif@1.0.10 — GIF decode
- SortableJS@1.15.2 — drag-and-drop
- gifenc@1.0.3 — GIF encode
