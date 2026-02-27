"""Generate pixel art sprites for SSQuirrel game — 2x size, more detail."""
from PIL import Image

ART = "C:/Users/Horst/team dip Dropbox/jr blender/Godot/ssquirrel/ssquirel/art"

T = (0, 0, 0, 0)  # transparent


def rect(img, x0, y0, x1, y1, c):
    """Fill a rectangle from (x0,y0) to (x1,y1) inclusive."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img.putpixel((x, y), c)


def line_h(img, x0, x1, y, c):
    """Horizontal line from x0 to x1 inclusive."""
    for x in range(x0, x1 + 1):
        img.putpixel((x, y), c)


def line_v(img, x, y0, y1, c):
    """Vertical line from y0 to y1 inclusive."""
    for y in range(y0, y1 + 1):
        img.putpixel((x, y), c)


# ── Player: 32x32 top-down hero with green cap ──────────────────────────
def make_player():
    img = Image.new("RGBA", (32, 32), T)
    p = img.putpixel
    skin = (240, 200, 160, 255)
    cap = (50, 160, 50, 255)
    cap_dk = (30, 120, 30, 255)
    cap_lt = (70, 190, 70, 255)
    shirt = (60, 100, 180, 255)
    shirt_dk = (40, 70, 140, 255)
    belt = (100, 70, 40, 255)
    buckle = (220, 200, 60, 255)
    pants = (80, 80, 120, 255)
    boot = (60, 40, 30, 255)
    hair = (120, 80, 40, 255)
    eye = (20, 20, 40, 255)
    mouth = (200, 100, 100, 255)
    outline = (30, 30, 30, 255)

    # Cap
    rect(img, 10, 2, 21, 3, cap_dk)
    rect(img, 9, 4, 22, 5, cap)
    rect(img, 9, 6, 22, 7, cap_lt)
    rect(img, 7, 8, 24, 9, cap_dk)  # brim

    # Head
    rect(img, 10, 10, 21, 15, skin)
    # Eyes
    rect(img, 11, 12, 12, 13, eye)
    rect(img, 19, 12, 20, 13, eye)
    # Eye highlights
    p((11, 12), (200, 200, 240, 255))
    p((19, 12), (200, 200, 240, 255))
    # Mouth
    rect(img, 14, 14, 17, 14, mouth)
    # Hair sides
    rect(img, 8, 10, 9, 15, hair)
    rect(img, 22, 10, 23, 15, hair)

    # Shirt
    rect(img, 8, 16, 23, 17, shirt)
    rect(img, 6, 18, 25, 21, shirt)
    rect(img, 6, 18, 7, 21, skin)   # left hand
    rect(img, 24, 18, 25, 21, skin)  # right hand
    rect(img, 10, 20, 11, 21, shirt_dk)  # shirt fold
    rect(img, 20, 20, 21, 21, shirt_dk)

    # Belt
    rect(img, 10, 22, 21, 23, belt)
    rect(img, 14, 22, 17, 23, buckle)

    # Pants
    rect(img, 10, 24, 14, 27, pants)
    rect(img, 17, 24, 21, 27, pants)

    # Boots
    rect(img, 8, 28, 14, 29, boot)
    rect(img, 17, 28, 23, 29, boot)

    img.save(f"{ART}/player.png")
    print("  player.png (32x32)")


# ── Squirrel: 32x32 brown squirrel with stahlhelm, red armband ──────────
def make_squirrel():
    img = Image.new("RGBA", (32, 32), T)
    p = img.putpixel
    fur = (160, 100, 50, 255)
    fur_lt = (200, 140, 80, 255)
    fur_dk = (120, 70, 30, 255)
    belly = (220, 190, 150, 255)
    eye = (200, 30, 30, 255)  # angry red
    nose = (40, 30, 20, 255)
    armband = (200, 30, 30, 255)
    armband_dk = (160, 20, 20, 255)
    helmet = (80, 90, 80, 255)
    helmet_dk = (50, 60, 50, 255)
    tail = (180, 120, 60, 255)
    tail_dk = (140, 90, 40, 255)
    white = (255, 255, 255, 255)

    # Stahlhelm (rows 0-5)
    rect(img, 10, 0, 21, 1, helmet_dk)
    rect(img, 8, 2, 23, 3, helmet)
    rect(img, 8, 4, 23, 5, helmet)
    rect(img, 7, 6, 24, 7, helmet_dk)  # brim

    # Ears poking through helmet
    rect(img, 8, 1, 9, 2, fur_lt)
    rect(img, 22, 1, 23, 2, fur_lt)

    # Head
    rect(img, 8, 8, 23, 13, fur)
    # Angry red eyes with white dot
    rect(img, 10, 9, 12, 11, eye)
    rect(img, 19, 9, 21, 11, eye)
    p((10, 9), white); p((19, 9), white)
    # Angry eyebrows (\ /)
    line_h(img, 9, 12, 8, fur_dk)
    line_h(img, 19, 22, 8, fur_dk)
    # Nose
    rect(img, 14, 11, 17, 12, nose)
    # Cheeks
    rect(img, 9, 12, 10, 13, fur_lt)
    rect(img, 21, 12, 22, 13, fur_lt)
    # Sneer
    line_h(img, 13, 18, 13, fur_dk)
    p((12, 12), fur_dk); p((19, 12), fur_dk)  # sneer corners

    # Body
    rect(img, 8, 14, 23, 15, fur)
    rect(img, 6, 16, 25, 23, fur)
    # Belly
    rect(img, 12, 16, 19, 22, belly)
    # Red armband on left arm with white circle
    rect(img, 4, 16, 7, 19, armband)
    rect(img, 4, 20, 7, 21, armband_dk)
    rect(img, 5, 17, 6, 18, white)  # white circle on armband

    # Right arm
    rect(img, 24, 16, 27, 21, fur)

    # Legs
    rect(img, 10, 24, 14, 27, fur_dk)
    rect(img, 17, 24, 21, 27, fur_dk)

    # Feet (goose-step style — right foot forward)
    rect(img, 8, 28, 14, 29, fur_dk)
    rect(img, 17, 28, 23, 29, fur_dk)

    # Big fluffy tail (right side)
    rect(img, 26, 4, 29, 5, tail)
    rect(img, 26, 6, 31, 9, tail)
    rect(img, 27, 10, 31, 13, tail)
    rect(img, 26, 14, 30, 17, tail_dk)
    rect(img, 25, 16, 27, 18, tail_dk)

    img.save(f"{ART}/squirrel.png")
    print("  squirrel.png (32x32)")


# ── Rat: 32x32 fast grey rat with red beret ──────────────────────────────
def make_rat():
    img = Image.new("RGBA", (32, 32), T)
    fur = (140, 140, 150, 255)
    fur_lt = (170, 170, 180, 255)
    fur_dk = (100, 100, 110, 255)
    belly = (200, 195, 190, 255)
    eye = (200, 30, 30, 255)
    nose = (255, 150, 150, 255)
    beret = (180, 30, 30, 255)
    beret_dk = (140, 20, 20, 255)
    tail_c = (200, 170, 170, 255)
    ear = (200, 160, 160, 255)
    white = (255, 255, 255, 255)
    whisker = (80, 80, 80, 255)

    # Beret
    rect(img, 11, 1, 20, 2, beret_dk)
    rect(img, 9, 3, 22, 5, beret)
    rect(img, 15, 0, 16, 1, beret_dk)  # nub on top

    # Big round ears
    rect(img, 6, 3, 9, 7, ear)
    rect(img, 22, 3, 25, 7, ear)
    rect(img, 7, 4, 8, 6, fur_lt)
    rect(img, 23, 4, 24, 6, fur_lt)

    # Head (pointy snout)
    rect(img, 9, 6, 22, 13, fur)
    rect(img, 11, 14, 20, 15, fur)  # snout extends down
    # Eyes
    rect(img, 11, 8, 13, 10, eye)
    rect(img, 18, 8, 20, 10, eye)
    img.putpixel((11, 8), white); img.putpixel((18, 8), white)
    # Nose
    rect(img, 14, 13, 17, 14, nose)
    # Whiskers
    line_h(img, 5, 10, 12, whisker)
    line_h(img, 5, 10, 14, whisker)
    line_h(img, 21, 26, 12, whisker)
    line_h(img, 21, 26, 14, whisker)
    # Mean expression
    line_h(img, 10, 13, 7, fur_dk)  # angry brows
    line_h(img, 18, 21, 7, fur_dk)

    # Body (slim, fast-looking)
    rect(img, 10, 16, 21, 23, fur)
    rect(img, 13, 16, 18, 22, belly)

    # Arms
    rect(img, 7, 17, 9, 21, fur)
    rect(img, 22, 17, 24, 21, fur)

    # Legs
    rect(img, 10, 24, 14, 27, fur_dk)
    rect(img, 17, 24, 21, 27, fur_dk)
    rect(img, 9, 28, 14, 29, fur_dk)
    rect(img, 17, 28, 22, 29, fur_dk)

    # Long rat tail (curling down-left)
    line_h(img, 3, 7, 20, tail_c)
    line_v(img, 3, 20, 24, tail_c)
    line_h(img, 1, 3, 24, tail_c)

    img.save(f"{ART}/rat.png")
    print("  rat.png (32x32)")


# ── Mole: 32x32 tanky mole with tiny helmet, dark glasses ───────────────
def make_mole():
    img = Image.new("RGBA", (32, 32), T)
    fur = (80, 60, 50, 255)
    fur_lt = (110, 85, 70, 255)
    fur_dk = (50, 35, 25, 255)
    belly = (170, 150, 130, 255)
    glasses = (20, 20, 30, 255)
    glasses_rim = (60, 60, 70, 255)
    helmet = (80, 90, 80, 255)
    helmet_dk = (50, 60, 50, 255)
    nose = (220, 150, 150, 255)
    claw = (200, 180, 160, 255)
    mouth = (140, 60, 60, 255)

    # Tiny stahlhelm (sits on big head)
    rect(img, 11, 0, 20, 1, helmet_dk)
    rect(img, 10, 2, 21, 4, helmet)
    rect(img, 9, 5, 22, 5, helmet_dk)

    # Big round head
    rect(img, 7, 6, 24, 15, fur)
    rect(img, 6, 8, 7, 13, fur)
    rect(img, 24, 8, 25, 13, fur)
    # Dark glasses (this mole is almost blind)
    rect(img, 9, 8, 14, 11, glasses)
    rect(img, 17, 8, 22, 11, glasses)
    rect(img, 9, 8, 14, 8, glasses_rim)
    rect(img, 17, 8, 22, 8, glasses_rim)
    line_h(img, 14, 17, 9, glasses_rim)  # bridge
    # Big pink nose
    rect(img, 13, 12, 18, 14, nose)
    # Grim mouth
    line_h(img, 12, 19, 15, mouth)

    # Wide body (he's THICC)
    rect(img, 5, 16, 26, 25, fur)
    rect(img, 11, 16, 20, 24, belly)

    # Big clawed arms
    rect(img, 2, 17, 5, 23, fur_lt)
    rect(img, 26, 17, 29, 23, fur_lt)
    # Claws
    rect(img, 1, 24, 2, 25, claw)
    rect(img, 3, 24, 4, 25, claw)
    rect(img, 27, 24, 28, 25, claw)
    rect(img, 29, 24, 30, 25, claw)

    # Short stumpy legs
    rect(img, 9, 26, 14, 29, fur_dk)
    rect(img, 17, 26, 22, 29, fur_dk)
    rect(img, 8, 30, 14, 31, fur_dk)
    rect(img, 17, 30, 23, 31, fur_dk)

    img.save(f"{ART}/mole.png")
    print("  mole.png (32x32)")


# ── Raccoon: 32x32 ranged raccoon with officer cap ──────────────────────
def make_raccoon():
    img = Image.new("RGBA", (32, 32), T)
    fur = (120, 120, 120, 255)
    fur_lt = (160, 160, 160, 255)
    fur_dk = (80, 80, 80, 255)
    mask_c = (40, 40, 40, 255)
    belly = (200, 195, 185, 255)
    eye = (220, 200, 30, 255)  # menacing yellow
    nose = (30, 30, 30, 255)
    cap = (50, 60, 50, 255)
    cap_band = (200, 30, 30, 255)
    cap_badge = (220, 200, 60, 255)
    tail_stripe_lt = (160, 160, 160, 255)
    tail_stripe_dk = (40, 40, 40, 255)

    # Officer cap (peaked cap with red band)
    rect(img, 10, 0, 21, 1, cap)
    rect(img, 8, 2, 23, 4, cap)
    rect(img, 8, 5, 23, 5, cap_band)
    rect(img, 14, 3, 17, 4, cap_badge)  # badge
    rect(img, 6, 6, 25, 7, cap)  # peak/visor

    # Ears
    rect(img, 7, 2, 9, 5, fur_lt)
    rect(img, 22, 2, 24, 5, fur_lt)

    # Head
    rect(img, 8, 8, 23, 15, fur_lt)
    # Raccoon mask (dark around eyes)
    rect(img, 8, 9, 14, 12, mask_c)
    rect(img, 17, 9, 23, 12, mask_c)
    # Yellow menacing eyes
    rect(img, 10, 10, 12, 11, eye)
    rect(img, 19, 10, 21, 11, eye)
    img.putpixel((10, 10), (30, 30, 30, 255))  # pupils
    img.putpixel((19, 10), (30, 30, 30, 255))
    # White stripe between eyes
    line_v(img, 15, 8, 12, (230, 230, 230, 255))
    line_v(img, 16, 8, 12, (230, 230, 230, 255))
    # Nose
    rect(img, 14, 13, 17, 14, nose)
    # Smirk
    line_h(img, 13, 18, 15, fur_dk)

    # Body
    rect(img, 8, 16, 23, 25, fur)
    rect(img, 12, 16, 19, 24, belly)

    # Arms
    rect(img, 5, 17, 8, 23, fur)
    rect(img, 23, 17, 26, 23, fur)

    # Legs
    rect(img, 10, 26, 14, 29, fur_dk)
    rect(img, 17, 26, 21, 29, fur_dk)
    rect(img, 9, 30, 14, 31, fur_dk)
    rect(img, 17, 30, 22, 31, fur_dk)

    # Striped tail (going right)
    for i, y_off in enumerate(range(8, 24, 2)):
        c = tail_stripe_lt if i % 2 == 0 else tail_stripe_dk
        rect(img, 27, y_off, 31, y_off + 1, c)

    img.save(f"{ART}/raccoon.png")
    print("  raccoon.png (32x32)")


# ── Bullets: 8x8 for all types ──────────────────────────────────────────
def make_bullet():
    """Yellow energy ball — default weapon."""
    img = Image.new("RGBA", (8, 8), T)
    outer = (255, 220, 50, 255)
    inner = (255, 255, 200, 255)
    core = (255, 255, 255, 255)
    rect(img, 2, 0, 5, 0, outer)
    rect(img, 1, 1, 6, 1, outer)
    rect(img, 0, 2, 7, 5, outer)
    rect(img, 2, 2, 5, 5, inner)
    rect(img, 3, 3, 4, 4, core)
    rect(img, 1, 6, 6, 6, outer)
    rect(img, 2, 7, 5, 7, outer)
    img.save(f"{ART}/bullet.png")
    print("  bullet.png (8x8)")


def make_bullet_spread():
    """Green triple-shot bullet."""
    img = Image.new("RGBA", (8, 8), T)
    outer = (50, 220, 80, 255)
    inner = (150, 255, 170, 255)
    core = (220, 255, 220, 255)
    rect(img, 2, 0, 5, 0, outer)
    rect(img, 1, 1, 6, 1, outer)
    rect(img, 0, 2, 7, 5, outer)
    rect(img, 2, 2, 5, 5, inner)
    rect(img, 3, 3, 4, 4, core)
    rect(img, 1, 6, 6, 6, outer)
    rect(img, 2, 7, 5, 7, outer)
    img.save(f"{ART}/bullet_spread.png")
    print("  bullet_spread.png (8x8)")


def make_bullet_pierce():
    """Blue piercing bullet — elongated."""
    img = Image.new("RGBA", (8, 8), T)
    outer = (60, 120, 255, 255)
    inner = (150, 190, 255, 255)
    core = (220, 230, 255, 255)
    rect(img, 3, 0, 4, 0, outer)
    rect(img, 2, 1, 5, 1, outer)
    rect(img, 1, 2, 6, 5, outer)
    rect(img, 2, 2, 5, 5, inner)
    rect(img, 3, 2, 4, 5, core)
    rect(img, 2, 6, 5, 6, outer)
    rect(img, 3, 7, 4, 7, outer)
    img.save(f"{ART}/bullet_pierce.png")
    print("  bullet_pierce.png (8x8)")


def make_bullet_big():
    """Red/orange big shot — larger visual."""
    img = Image.new("RGBA", (12, 12), T)
    outer = (255, 100, 30, 255)
    inner = (255, 180, 80, 255)
    core = (255, 240, 200, 255)
    glow = (255, 60, 20, 200)
    rect(img, 3, 0, 8, 0, glow)
    rect(img, 2, 1, 9, 1, outer)
    rect(img, 1, 2, 10, 9, outer)
    rect(img, 3, 3, 8, 8, inner)
    rect(img, 4, 4, 7, 7, core)
    rect(img, 2, 10, 9, 10, outer)
    rect(img, 3, 11, 8, 11, glow)
    img.save(f"{ART}/bullet_big.png")
    print("  bullet_big.png (12x12)")


def make_bullet_rapid():
    """Small fast orange bullet."""
    img = Image.new("RGBA", (6, 6), T)
    outer = (255, 160, 30, 255)
    inner = (255, 220, 120, 255)
    rect(img, 1, 0, 4, 0, outer)
    rect(img, 0, 1, 5, 4, outer)
    rect(img, 1, 1, 4, 4, inner)
    rect(img, 2, 2, 3, 3, (255, 255, 200, 255))
    rect(img, 1, 5, 4, 5, outer)
    img.save(f"{ART}/bullet_rapid.png")
    print("  bullet_rapid.png (6x6)")


# ── Acorn: 8x8 enemy projectile ─────────────────────────────────────────
def make_acorn():
    img = Image.new("RGBA", (8, 8), T)
    cap = (100, 70, 30, 255)
    cap_dk = (70, 50, 20, 255)
    nut = (180, 130, 60, 255)
    nut_lt = (210, 170, 100, 255)
    rect(img, 2, 0, 5, 0, cap_dk)
    rect(img, 1, 1, 6, 1, cap)
    rect(img, 0, 2, 7, 3, cap)
    rect(img, 3, 2, 4, 2, cap_dk)  # stem
    rect(img, 0, 4, 7, 6, nut)
    rect(img, 2, 4, 5, 5, nut_lt)
    rect(img, 2, 7, 5, 7, nut)
    img.save(f"{ART}/acorn.png")
    print("  acorn.png (8x8)")


# ── Heart: 16x16 ────────────────────────────────────────────────────────
def make_heart():
    img = Image.new("RGBA", (16, 16), T)
    red = (220, 40, 40, 255)
    pink = (255, 120, 120, 255)
    dark = (160, 20, 20, 255)

    # Top bumps
    rect(img, 2, 1, 5, 2, red)
    rect(img, 9, 1, 12, 2, red)
    # Full width
    rect(img, 1, 3, 13, 4, red)
    rect(img, 0, 5, 14, 7, red)
    # Highlight
    rect(img, 2, 2, 4, 4, pink)
    # Narrow down
    rect(img, 1, 8, 13, 9, red)
    rect(img, 2, 10, 12, 11, red)
    rect(img, 3, 12, 11, 12, dark)
    rect(img, 4, 13, 10, 13, dark)
    rect(img, 5, 14, 9, 14, dark)
    rect(img, 6, 15, 8, 15, dark)

    img.save(f"{ART}/heart.png")
    print("  heart.png (16x16)")


# ── Upgrade pickups: 16x16 ──────────────────────────────────────────────
def make_upgrade_spread():
    """Green triple-arrow icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (40, 160, 60, 200)
    arrow = (200, 255, 200, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Three arrows pointing up
    for cx in [5, 8, 11]:
        line_v(img, cx, 5, 11, arrow)
        img.putpixel((cx - 1, 6), arrow)
        img.putpixel((cx + 1, 6), arrow)
        img.putpixel((cx, 4), arrow)
    img.save(f"{ART}/upgrade_spread.png")
    print("  upgrade_spread.png (16x16)")


def make_upgrade_rapid():
    """Orange lightning bolt icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (200, 130, 30, 200)
    bolt = (255, 255, 200, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Lightning bolt shape
    for x, y in [(9, 3), (8, 4), (7, 5), (6, 6), (7, 7), (8, 7),
                 (9, 7), (10, 7), (9, 8), (8, 9), (7, 10), (6, 11), (5, 12)]:
        img.putpixel((x, y), bolt)
        img.putpixel((x + 1, y), bolt)
    img.save(f"{ART}/upgrade_rapid.png")
    print("  upgrade_rapid.png (16x16)")


def make_upgrade_pierce():
    """Blue diamond/arrow icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (50, 100, 220, 200)
    icon = (180, 210, 255, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Arrow pointing right (pierce through)
    for dy in range(-2, 3):
        line_h(img, 4, 11, 8 + dy, icon)
    # Arrowhead
    img.putpixel((12, 6), icon); img.putpixel((12, 10), icon)
    img.putpixel((11, 5), icon); img.putpixel((11, 11), icon)
    img.save(f"{ART}/upgrade_pierce.png")
    print("  upgrade_pierce.png (16x16)")


def make_upgrade_bigshot():
    """Red/orange explosion icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (200, 60, 30, 200)
    icon = (255, 200, 100, 255)
    rect(img, 2, 2, 13, 13, bg)
    rect(img, 5, 4, 10, 11, icon)
    rect(img, 4, 5, 11, 10, icon)
    for cx, cy in [(8, 3), (8, 12), (3, 8), (12, 8)]:
        img.putpixel((cx, cy), icon)
    img.save(f"{ART}/upgrade_bigshot.png")
    print("  upgrade_bigshot.png (16x16)")


def make_upgrade_homing():
    """Magenta crosshair/target icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (180, 40, 180, 200)
    icon = (255, 180, 255, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Crosshair circle
    rect(img, 5, 3, 10, 3, icon); rect(img, 5, 12, 10, 12, icon)
    rect(img, 3, 5, 3, 10, icon); rect(img, 12, 5, 12, 10, icon)
    # Cross lines
    line_h(img, 5, 10, 8, icon)
    line_v(img, 8, 5, 10, icon)
    # Center dot
    rect(img, 7, 7, 8, 8, (255, 255, 255, 255))
    img.save(f"{ART}/upgrade_homing.png")
    print("  upgrade_homing.png (16x16)")


def make_upgrade_orbit():
    """Cyan rotating shield icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (30, 180, 200, 200)
    icon = (180, 255, 255, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Center player dot
    rect(img, 7, 7, 8, 8, (255, 255, 255, 255))
    # Orbiting dots at cardinal positions
    for cx, cy in [(8, 3), (12, 8), (8, 12), (3, 8)]:
        rect(img, cx-1, cy-1, cx, cy, icon)
    # Circular arc hints
    img.putpixel((5, 4), icon); img.putpixel((10, 4), icon)
    img.putpixel((5, 11), icon); img.putpixel((10, 11), icon)
    img.save(f"{ART}/upgrade_orbit.png")
    print("  upgrade_orbit.png (16x16)")


def make_upgrade_rear():
    """Yellow double-arrow (front+back) icon."""
    img = Image.new("RGBA", (16, 16), T)
    bg = (180, 180, 40, 200)
    icon = (255, 255, 180, 255)
    rect(img, 2, 2, 13, 13, bg)
    # Up arrow (front)
    line_v(img, 6, 4, 11, icon)
    img.putpixel((5, 5), icon); img.putpixel((4, 6), icon)
    img.putpixel((7, 5), icon); img.putpixel((8, 6), icon)
    # Down arrow (rear)
    line_v(img, 10, 4, 11, icon)
    img.putpixel((9, 10), icon); img.putpixel((8, 9), icon)
    img.putpixel((11, 10), icon); img.putpixel((12, 9), icon)
    img.save(f"{ART}/upgrade_rear.png")
    print("  upgrade_rear.png (16x16)")


def make_bullet_homing():
    """Magenta homing bullet."""
    img = Image.new("RGBA", (8, 8), T)
    outer = (200, 60, 200, 255)
    inner = (255, 150, 255, 255)
    core = (255, 220, 255, 255)
    rect(img, 2, 0, 5, 0, outer)
    rect(img, 1, 1, 6, 1, outer)
    rect(img, 0, 2, 7, 5, outer)
    rect(img, 2, 2, 5, 5, inner)
    rect(img, 3, 3, 4, 4, core)
    rect(img, 1, 6, 6, 6, outer)
    rect(img, 2, 7, 5, 7, outer)
    img.save(f"{ART}/bullet_homing.png")
    print("  bullet_homing.png (8x8)")


def make_bullet_orbit():
    """Cyan orbit bullet."""
    img = Image.new("RGBA", (8, 8), T)
    outer = (30, 200, 220, 255)
    inner = (120, 240, 255, 255)
    core = (220, 255, 255, 255)
    rect(img, 2, 0, 5, 0, outer)
    rect(img, 1, 1, 6, 1, outer)
    rect(img, 0, 2, 7, 5, outer)
    rect(img, 2, 2, 5, 5, inner)
    rect(img, 3, 3, 4, 4, core)
    rect(img, 1, 6, 6, 6, outer)
    rect(img, 2, 7, 5, 7, outer)
    img.save(f"{ART}/bullet_orbit.png")
    print("  bullet_orbit.png (8x8)")


if __name__ == "__main__":
    print("Generating sprites (2x size)...")
    make_player()
    make_squirrel()
    make_rat()
    make_mole()
    make_raccoon()
    make_bullet()
    make_bullet_spread()
    make_bullet_pierce()
    make_bullet_big()
    make_bullet_rapid()
    make_bullet_homing()
    make_bullet_orbit()
    make_acorn()
    make_heart()
    make_upgrade_spread()
    make_upgrade_rapid()
    make_upgrade_pierce()
    make_upgrade_bigshot()
    make_upgrade_homing()
    make_upgrade_orbit()
    make_upgrade_rear()
    print("Done! (21 sprites)")
