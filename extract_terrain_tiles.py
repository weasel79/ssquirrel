"""Extract terrain tiles from terrain_atlas.gif (project root) into art/tiles/wfc/.

Each frame is 32x32 px. Tiles are saved at native 32x32.
NOTE: world_generator.gd uses TILE_SIZE=16; update that constant to 32
      (or resize tiles to 16x16 by changing RESIZE = True below).

Run from the project root:
  python extract_terrain_tiles.py
"""

from PIL import Image, ImageSequence
import json, os

GIF_PATH = os.path.join(os.path.dirname(__file__), "terrain_atlas.gif")
OUT_DIR  = os.path.join(os.path.dirname(__file__), "art", "tiles", "wfc")

# Set True to downscale to 16x16 (matches current TILE_SIZE=16 in world_generator.gd)
RESIZE = False
OUT_SIZE = 16 if RESIZE else 32

# ── Final frame-index mapping ────────────────────────────────────────────────
# Convention: bg_edge indicates which side has void/background.
# e.g. edge_top  = material at bottom, void above  → placed at N-edge of terrain
#      outer_tl  = material in bottom-right only    → placed at top-left convex corner
#      inner_tl  = material fills tile minus small top-left notch (approx = fill)
#
# Source frame indices verified visually from terrain_atlas.gif (1012 frames, 32x32).

TILES = {
    # ── SAND (yellow-gold organic blobs) ─────────────────────────────────────
    "sand_fill_0":    381,   # textured yellow sand
    "sand_fill_1":    916,   # uniform fine sand
    "sand_fill_2":    917,   # fine sand variant
    "sand_edge_top":  349,   # sand at bottom, void above
    "sand_edge_bottom": 413, # sand at top, void below
    "sand_edge_left": 380,   # sand on right, void left
    "sand_edge_right": 382,  # sand on left, void right
    "sand_outer_tl":  348,   # sand in bottom-right quadrant
    "sand_outer_tr":  350,   # sand in bottom-left quadrant
    "sand_outer_bl":  412,   # sand in top-right quadrant
    "sand_outer_br":  414,   # sand in top-left quadrant
    "sand_inner_tl":  381,   # ≈fill (inner corners not distinct in this set)
    "sand_inner_tr":  381,
    "sand_inner_bl":  381,
    "sand_inner_br":  381,

    # ── WATER (deep blue) ────────────────────────────────────────────────────
    "water_fill_0":   294,   # solid blue water
    "water_fill_1":   295,   # blue water variant
    "water_fill_2":   452,   # clean solid blue water (322 had grass island)
    # No clean edge/corner water tiles found in this tileset (only mixed sand+water)
    "water_edge_top":    351, # water+sand border (sand above water)
    "water_edge_bottom": 294, # ≈fill (no distinct tile found)
    "water_edge_left":   401, # water on right, void left (waterfall edge)
    "water_edge_right":  403, # water on left, void right
    "water_outer_tl":    294,
    "water_outer_tr":    294,
    "water_outer_bl":    294,
    "water_outer_br":    294,
    "water_inner_tl":    294,
    "water_inner_tr":    294,
    "water_inner_bl":    294,
    "water_inner_br":    294,

    # ── EARTH (warm tan-brown, top-down organic) ─────────────────────────────
    "earth_fill_0":    703,  # tan-brown earth
    "earth_fill_1":    704,  # variant
    "earth_fill_2":    705,  # variant
    "earth_fill_3":    706,  # darker variant
    "earth_edge_top":  265,  # earth at bottom, void above
    "earth_edge_bottom": 725, # earth at top, void below
    "earth_edge_left": 296,  # earth on right, void left
    "earth_edge_right": 298, # earth on left, void right
    "earth_outer_tl":  264,  # earth in bottom-right
    "earth_outer_tr":  84,   # earth in bottom-left (267 had lava/orange)
    "earth_outer_bl":  37,   # earth in top-right
    "earth_outer_br":  852,  # earth in top-left
    "earth_inner_tl":  703,  # ≈fill
    "earth_inner_tr":  703,
    "earth_inner_bl":  703,
    "earth_inner_br":  703,

    # ── STONE (grey stone bricks, dungeon floor) ─────────────────────────────
    "stone_fill_0":    870,  # large stone bricks
    "stone_fill_1":    871,  # variant
    "stone_fill_2":    872,  # variant
    "stone_fill_3":    216,  # grey stone blocks (different style)
    "stone_fill_4":    217,  # variant
    "stone_edge_top":  215,  # stone at bottom, void above
    "stone_edge_bottom": 870, # ≈fill (493 had plant decoration; no clean tile found)
    "stone_edge_left": 276,  # stone on right, void left
    "stone_edge_right": 278, # stone on left, void right
    "stone_outer_tl":  249,  # stone in bottom-right
    "stone_outer_tr":  252,  # stone in bottom-left
    "stone_outer_bl":  870,  # ≈fill (no distinct tile found)
    "stone_outer_br":  881,  # dark stone in top-left (726 was a rock sprite)
    "stone_inner_tl":  870,  # ≈fill
    "stone_inner_tr":  870,
    "stone_inner_bl":  870,
    "stone_inner_br":  870,
}

# ── Metadata ─────────────────────────────────────────────────────────────────
def build_meta():
    meta = {"tile_size": OUT_SIZE, "source_gif_frame_size": 32, "tiles": {}}
    for name, frame_idx in TILES.items():
        parts = name.split("_")
        # material = everything before last 1-2 parts
        # position = last 1-2 parts
        if parts[-1] in ("0", "1", "2", "3", "4", "5"):
            mat = "_".join(parts[:-2])
            pos = parts[-2] + "_" + parts[-1]
        else:
            mat = "_".join(parts[:-2]) if len(parts) > 2 else parts[0]
            pos = "_".join(parts[-2:]) if len(parts) > 2 else parts[-1]
        # simpler: material is first word, position is rest
        mat = parts[0]
        pos = "_".join(parts[1:])
        meta["tiles"][name] = {
            "material":  mat,
            "position":  pos,
            "source_frame": frame_idx,
            "file": name + ".png",
            "approximate": name.replace(mat+"_","")
                            in ("inner_tl","inner_tr","inner_bl","inner_br")
                            or (mat == "water" and "edge" in pos and frame_idx in (294,295))
        }
    return meta


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    print(f"Loading {GIF_PATH} …")
    img = Image.open(GIF_PATH)
    frames = [f.copy().convert("RGBA") for f in ImageSequence.Iterator(img)]
    print(f"  {len(frames)} frames loaded")

    saved = 0
    for name, frame_idx in TILES.items():
        if frame_idx >= len(frames):
            print(f"  SKIP {name}: frame {frame_idx} out of range")
            continue
        tile = frames[frame_idx]
        if RESIZE:
            tile = tile.resize((OUT_SIZE, OUT_SIZE), Image.NEAREST)
        out_path = os.path.join(OUT_DIR, name + ".png")
        # Convert to RGB (no alpha) to match existing wfc tiles (FORMAT_RGB8)
        bg = Image.new("RGB", tile.size, (30, 20, 15))
        bg.paste(tile, mask=tile.split()[3] if tile.mode == "RGBA" else None)
        bg.save(out_path)
        saved += 1

    print(f"  Saved {saved} tiles to {OUT_DIR}")

    # Write metadata JSON
    meta = build_meta()
    meta_path = os.path.join(OUT_DIR, "terrain_meta.json")
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)
    print(f"  Wrote {meta_path}")

    print("\nDone.")
    print("NOTE: world_generator.gd uses TILE_SIZE=16 but these tiles are 32x32.")
    print("      Either set RESIZE=True above and re-run, or change TILE_SIZE to 32.")


if __name__ == "__main__":
    main()
