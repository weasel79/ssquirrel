# SSQuirrel — Project Notes for Claude

## Project Summary
- Godot 4 game: top-down adventure with squirrel character
- WFC (Wave Function Collapse) terrain generation via `autoload/wfc.gd`
- Terrain tiles loaded from `art/tiles/wfc/` as 32×32 RGB PNGs
- `scenes/world/world_generator.gd`: TILE_SIZE=16, CHUNK_TILES=20; generates chunk Images by blitting tiles
- Socket-based WFC in `autoload/wfc.gd`: define_tile(name, tex, top, right, bottom, left, weight, collision)

## Key Files
| File | Purpose |
|---|---|
| `extract_terrain_tiles.py` | Extracts tiles from `terrain_atlas.gif` → `art/tiles/wfc/` |
| `generate_terrain_preview.py` | Renders a 16×8 static map preview PNG |
| `tileset_editor.html` | Standalone HTML/JS GIF tileset editor (open in browser) |
| `terrain_atlas.gif` | Source tileset: 1012 frames × 32×32 px |
| `terrain_preview.png` | 16×8 map preview (water + 2 sand islands + inner lake) |
| `tile_verify_*.png` | Verification sheets for each material |
| `art/tiles/wfc/terrain_meta.json` | Tile metadata (material, position, source_frame, approximate) |

## Terrain Tile Convention
- Naming: `{material}_{position}.png`
- Materials: sand, water, earth, stone (+ existing: grass, ice, lava, acid, gas, poison)
- Positions: fill_0..N, edge_top/bottom/left/right, outer_tl/tr/bl/br, inner_tl/tr/bl/br
- `edge_top` = material at bottom, void above → placed at N-edge of terrain
- `outer_tl` = material in bottom-right quadrant → placed at top-left convex corner
- inner corners = approximate fills in this tileset (not distinct tiles)

## Known Tile Approximations (terrain_atlas.gif)
- `stone_edge_bottom`: no clean tile → uses fill (frame 870)
- `stone_outer_br`: no clean tile → uses dark stone corner (frame 881)
- `water_*_outer/inner`: all approximate = water_fill_0
- `water_edge_left/right`: waterfall-style (frames 401, 403), not flat terrain
- All inner corner tiles: approximate fills

## TILE_SIZE Mismatch
- Tiles extracted at **32×32** native GIF resolution
- `world_generator.gd` uses `TILE_SIZE = 16`
- Options: set `RESIZE = True` in extract_terrain_tiles.py and re-run, OR change TILE_SIZE to 32

## tileset_editor.html — Controls
- Drag: reorder tiles
- Shift+drag: swap two tiles (shiftHeld via keydown/keyup — NOT evt.originalEvent.shiftKey which is unreliable in SortableJS)
- Right-click: delete tile
- Ctrl+click: duplicate tile
- Ctrl+Z: undo (10 steps)
- Zoom slider: scale grid 1×–4×
- Save/Load: JSON with base64 PNGs
- Refresh: re-decode source GIF keeping current arrangement

## Libraries Used (tileset_editor.html, CDN)
- omggif@1.0.10 — GIF decode (`decodeAndBlitFrameRGBA`; call with `rgba.fill(0)` for independent frames)
- SortableJS@1.15.2 — drag-and-drop
- gifenc@1.0.3 — GIF encode (quantize + applyPalette, window.gifenc)

---

## Session — 2026-02-28 — Terrain tile extraction + tileset editor

### Summary
- Analyzed terrain_atlas.gif (1012 frames, 32×32) for autotile sets
- Extracted 63 tiles for sand/water/earth/stone to art/tiles/wfc/
- Fixed 4 bad tile mappings after visual verification
- Moved source GIF and verify sheets from Downloads to project root
- Created static terrain preview (16×8 tiles, two sand islands, inner lake)
- Built full-featured standalone HTML/JS tileset editor with undo, swap, save/load, zoom

### Fixed mappings
| Tile | Old frame | New frame | Reason |
|---|---|---|---|
| earth_outer_tr | 267 | 84 | 267 had lava/orange content |
| stone_edge_bottom | 493 | 870 (fill approx) | 493 had plant decoration |
| stone_outer_br | 726 | 881 | 726 was a rock sprite |
| water_fill_2 | 322 | 452 | 322 had a grass island |

### Issues
- New materials not yet integrated into world_generator.gd
- TILE_SIZE=16 vs 32px tile mismatch unresolved
- Water edge tiles are waterfall-style, not flat terrain borders

### To-do
- [ ] Integrate sand/earth/water/stone into world_generator.gd _pick_tile()
- [ ] Decide: resize tiles to 16px or change TILE_SIZE to 32
- [ ] Test tileset_editor.html with terrain_atlas.gif
- [ ] Consider finding/creating cleaner water edge tiles

---

## Session — 2026-02-28 (cont.2) — Terrain atlas corrections + rubber-band deselect

### Summary
- Corrected two terrain set start tiles after visual verification of extracted PNGs
- Enhanced rubber-band selection in tileset_editor.html to support both add and remove modes

### Tile corrections
| Set | Old start | New start |
|---|---|---|
| dirt_on_grass | 285 | 485 |
| sand | 283 | 288 |
- Updated terrain_atlas.txt for both entries
- Re-ran Pillow extraction for each: art/tiles/terrain/{dirt_on_grass,sand}.png

### tileset_editor.html — rubber-band mode toggle
- Alt+drag now decides add vs. remove based on the first tile under the cursor at mousedown
- If first tile is **selected** → rectangle **deselects** all overlapping tiles (`rbMode = 'remove'`)
- If first tile is **unselected** (or no tile) → rectangle **selects** all overlapping tiles (`rbMode = 'add'`)
- Uses `e.target.closest('.ti')` to detect first tile; `rbMode` variable set in capture-phase mousedown

### Issues
- New materials (sand/earth/water/stone) not yet integrated into world_generator.gd _pick_tile()
- TILE_SIZE=16 vs 32px tile mismatch unresolved
- gifenc Export GIF: `window.gifenc` undefined (unresolved)

### To-do
- [ ] Integrate sand/earth/water/stone into world_generator.gd _pick_tile()
- [ ] Decide: resize tiles to 16px or change TILE_SIZE to 32
- [ ] Fix gifenc CDN global (inspect UMD export name)

### Ideas
- Add "verify" button to tileset_editor.html: render a preview of selected tiles side-by-side
- Alt+click single tile: instant add/remove toggle without dragging

---

## Session — 2026-02-28 (cont.) — gifenc CDN bug discovered

### Summary
- Short session: completed previous cas, then hit export bug
- tileset_editor.html Export GIF button throws "gifenc library not loaded"
- Root cause: `window.gifenc` is undefined after CDN script loads
- gifenc@1.0.3 UMD bundle at `dist/gifenc.umd.js` may not expose `window.gifenc` as expected
- Investigation stopped — continuing next session

### Issue
- `window.gifenc` undefined at export time despite `<script src="...gifenc.umd.js">` loading
- Possible fix directions: check UMD export name, use `import` instead of global, or switch to alternative GIF encoder

### To-do
- [ ] Fix gifenc CDN global: inspect UMD bundle export, patch access (`gifenc` vs `window.gifenc`)
- [ ] Alternatively try gif.js or a different GIF encoder

---

## Session — 2026-02-28 (cont.3) — terrain_mapgen.html major feature pass

### Summary
Extended terrain map generator (`build_mapgen.py` → `art/tiles/terrain/util/terrain_mapgen.html`) with many features. All non-PNG files moved to `util/` subfolder.

### Features added
- **Singles fader**: scatters random plant/item tiles from `terrain_atlas_singles.png` on interior cells; density 0–100 → 0–40% probability per eligible cell
- **Main terrain** (radio button): selected terrain fills entire map as solid/alt background; no walls or corners ever used for it
- **Transparency fix**: render pass 1 draws main terrain on ALL cells (not just mainTerrain cells) — transparent wall/corner areas of other terrains correctly show grass/background beneath
- **Minimum 2-tile width erosion** (`erodeBlobs`): iteratively removes non-main cells that have 0 same-material backing in either H or V axis; map edges count as backing
- **Random seed button**: "🎲 Random" next to Generate, picks 0–9999999 seed and generates immediately
- **Size fader**: per-terrain sub-row; blob count via `numBlobs = round(totalTarget / blobSize)` where `blobSize = lerp(4, totalTarget, size/100)`
- **Free sliders**: removed auto-sum; generation normalises non-main pcts internally (`normPct = m.pct / rawSum * 100`)
- **renderSeed** (`seed ^ 0x3f7a2b1c`): stable re-render seed; density slider changes re-render consistently without regenerating layout

### File changes
- `build_mapgen.py`: output moved to `art/tiles/terrain/util/terrain_mapgen.html`
- `art/tiles/terrain/util/`: new subfolder; contains `terrain_mapgen.html`, `terraintileset.md`, `README.md`
- `art/tiles/terrain/util/README.md`: documents all scripts and the HTML tool

### Key technical findings
- Canvas transparency requires drawing background on *every* cell in pass 1, not just background-material cells
- erodeBlobs axis check: `hBacking = (x===0 || left===mat) + (x===W-1 || right===mat)`; remove if hBacking===0 OR vBacking===0
- `isInterior(x,y,g)`: all 4 cardinal neighbours same material — used by singles scatter to avoid walls/corners
- Free sliders + normalize-on-generate is cleaner than auto-scaling for multi-terrain setups

### To-do
- [ ] Integrate terrain map generator output into Godot world_generator.gd
- [ ] Resolve TILE_SIZE=16 vs 32px tile mismatch
- [ ] Fix gifenc Export GIF in tileset_editor.html
- [ ] Consider adding a "border padding" option (force N tiles of main terrain around map edge)

---

## Session — 2026-02-28 (cont.5) — Terrain tileset integration into world_generator.gd + web deploy

### Summary
Replaced old WFC tile system with new terrain tileset system in `world_generator.gd`.
Full 8-directional autotile, two-pass compositing, wall overlay rendering, debug panel.
Git committed + web export to GitHub Pages.

### Architecture (now current)
- `TILE_SIZE = 32` (was 16 — fixed)
- `CHUNK_TILES = 20`, `CHUNK_PX = 640`
- `MAIN_TERRAIN_POOL`: grass, grass2, sand, gravel, tile, dark, dirt_bright, dirt_dark, dirt3
- `REQUIRED_HAZARDS`: water, lava, toxic
- `WALL_OVERLAY_POOL`: abyss, abyss2, bush, hole_t, tile
- Per-level state: `_main_terrain`, `_wall_terrain`, `_active_terrains`, `_terrain_slots`, `_terrain_ranges`
- `_load_terrain_tileset(name)`: loads 96×192 PNG → 18 slot Images (solid, alt1-3, wall_top/bottom/left/right, corner_tl/tr/bl/br, inner_tl/tr/bl/br, small, small2)
- No WFC, no gas overlays, no old fill arrays

### Rendering pipeline
- **Pass 1**: fill ALL cells (including wall cells) with main terrain `solid` (opaque RGB8 base)
- **Pass 2 — wall cells**: blend main alt/solid fill → blend wall overlay autotile → add collision body
- **Pass 2 — main terrain cells**: blend solid/alt fill only (no edge/corner tiles)
- **Pass 2 — non-main terrain cells**: full 8-directional autotile (edge, corner, inner corner)

### Key technical findings
- `blend_rect` not `blit_rect`: blend_rect composites alpha; blit_rect copies raw pixels including alpha channel
- `chunk_img.convert(Image.FORMAT_RGB8)` before `ImageTexture.create_from_image()`: collapses RGBA8 → opaque RGB8, eliminates residual transparent pixels in the sprite
- Wall overlay pass: main terrain alt/solid drawn first (opaque ground), then wall overlay blended on top — transparent areas of overlay tiles show main terrain underneath, not void
- Debug CanvasLayer (layer 100): screen-space panel, right side, shows solid tile thumbnail + terrain name for all active terrains; main = `*`, wall = `(wall)`

### Git / web deploy
- Godot headless export: `Godot_v4.6.1-stable_win64.exe --headless --path <dir> --export-release "Web"`
- GitHub Pages at `https://weasel79.github.io/ssquirrel/` (master root, COOP/COEP via service worker)
- `.gitignore` updated: `*.exe`/`*.zip` excluded; web export files (`SSQuirrel.html/.pck/.js/.wasm` etc.) explicitly included
- 52 MB `.pck` accepted by GitHub (under 100 MB hard limit)

### Issues
- Wall autotile visual correctness not confirmed by user yet (inner corners may need tuning)

### To-do
- [ ] User test: verify wall/corner autotile looks correct in-game
- [ ] Consider hazard tile effects on player (water slow, lava/toxic damage)
- [ ] Consider player spawn forced to main terrain
- [ ] Fix gifenc Export GIF in tileset_editor.html (still unresolved)

### Ideas
- Different wall overlays per biome (e.g. ice biome gets snow/crystal overlays)
- Animated tiles (lava shimmer, water ripple) via AnimatedSprite2D or shader
- Minimap overlay using chunk tile_types array

---

## Session — 2026-02-28 (cont.6) — Player animation corrections + boss tuning + HUD keys

### Summary
Corrected all cape/walk animation frame assignments in player.gd, added new animations, updated animation state machine, tuned Donald boss difficulty, fixed HUD key list, and pushed web export to GitHub Pages.

### Frame changes (player.gd `_build_animations()`)
| Animation | Was | Now |
|---|---|---|
| `cape_idle_left` | `[114]` | `[111,112,113,114]` 4-frame |
| `cape_idle_right` | `[115]` | `[115,116,117,118]` 4-frame |
| `cape_walk_left` | `[111,112,113]` | `[120,121,122,123,124]` |
| `cape_walk_right` | `[116,117,118]` | `[125,126,127,128,129]` |
| `cape_jump_left` | `[120–124]` | `[132,133,134,135]` |
| `cape_jump_right` | `[125–129]` | `[136,137,138,139]` |

### New animations added
- `walk_up` — [158,159,160]; plays when moving straight up without cape
- `cape_walk_up` — [143,146]; cape + moving up
- `cape_walk_down` — [144,145]; cape + moving down
- `cape_toxic_left/right` — [154,156] / [155,157]; looping hazard effect
- `cheer` — [170,171,172,173,174]; non-looping, call `player.play_cheer()`

### Animation state machine update
- `absf(input_dir.x) <= 0.1` check before horizontal walk → triggers `walk_up` or `cape_walk_up/down`

### Other changes
- Donald boss: `MAX_HEALTH` 1500→2250 (+50%), `FINGER_INTERVAL` 8.0→6.4s (25% more frequent)
- HUD `_refresh_stats_panel()`: fixed "SPACE = Dodge" → "SPACE = Jump"; added "C = Cape toggle"
- Web export + git commit + push to `weasel79/ssquirrel` master

### To-do
- [ ] Test new cape animations in-game (correct frames confirmed by user, not visually tested yet)
- [ ] Trigger `play_cheer()` from main.gd on boss defeat
- [ ] cape_toxic animation: hook up to actual toxic tile detection

---

## Session — 2026-02-28 (cont.4) — Terrain file reorganisation

### Summary
Moved all terrain-related files out of project root into `art/tiles/terrain/` subdirectories.
Updated all scripts to use `__file__`-relative paths. Updated README. Git committed + pushed.

### File moves
| File | Old | New |
|---|---|---|
| `terrain_atlas.gif` / `.png` / `_z.png` | project root | `art/tiles/terrain/` |
| `terrain_preview.png` / `.import` | project root | `art/tiles/terrain/` |
| `build_mapgen.py` | project root | `art/tiles/terrain/util/` |
| `extract_terrain_tiles.py` | project root | `art/tiles/terrain/util/` |
| `generate_terrain_preview.py` | project root | `art/tiles/terrain/util/` |
| `terrain_atlas.txt` | project root | `art/tiles/terrain/util/` |

### Path update pattern (all scripts now use)
```python
_HERE = os.path.dirname(os.path.abspath(__file__))
# terrain/ (parent of util/):  os.path.join(_HERE, '..')
# art/tiles/wfc/:               os.path.join(_HERE, '..', '..', 'wfc')
```

### Usage (updated)
- Extract tiles: `python art/tiles/terrain/util/extract_terrain_tiles.py`
- Generate preview: `python art/tiles/terrain/util/generate_terrain_preview.py`
- Rebuild map generator: `python art/tiles/terrain/util/build_mapgen.py`

### To-do
- [ ] Integrate terrain map generator output into Godot world_generator.gd
- [ ] Resolve TILE_SIZE=16 vs 32px tile mismatch
- [ ] Fix gifenc Export GIF in tileset_editor.html
