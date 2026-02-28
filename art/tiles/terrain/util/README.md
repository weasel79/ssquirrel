# Terrain Utility Tools

Scripts and tools for generating and editing terrain tiles for the SSQuirrel project.
All scripts are run from the **project root** (`ssquirel/`).

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
python build_mapgen.py
```
This re-embeds all tileset PNGs as base64 and rewrites `terrain_mapgen.html`.

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

Extracts individual autotile sets from `terrain_atlas.gif` (1012 frames, 32×32 px each)
and saves them as 96×192 px PNG tilesets to `art/tiles/terrain/`.

Each tileset is a 3×6 grid of 32×32 tiles (see `terraintileset.md` for the layout).
Frame offsets per tileset are defined in `terrain_atlas.txt`.

**Usage**
```
python extract_terrain_tiles.py
```

---

## generate_terrain_preview.py

Generates `terrain_preview.png` — a small test map rendered from the extracted tile PNGs.
Used to visually verify tile extractions and inner corner logic.

**Usage**
```
python generate_terrain_preview.py
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
