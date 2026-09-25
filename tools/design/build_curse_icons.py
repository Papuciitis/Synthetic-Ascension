#!/usr/bin/env python3
"""Icons for the eight curse relics (Phase 4 existing-item texture audit).

Every curse .tres shipped without an icon, so curses rendered blank in the
inventory bar, shop grid, tooltip and ground loot. These are authored
32x32 pixel icons in one shared language: a bold dark silhouette, an ember
or bone accent, and a common murky-violet rim so a curse reads as a curse
at a glance. Provisional-quality by design; the manifest records them as
authored placeholders open to a later art pass.

Run:  python3 tools/design/build_curse_icons.py
Writes assets/textures/items/curses/curse_*.png
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/items/curses"

RIM = (96, 70, 118, 255)        # the shared murky-violet curse rim
DARK = (38, 34, 42, 255)
MID = (70, 62, 76, 255)
BONE = (214, 202, 178, 255)
EMBER = (222, 120, 64, 255)
ASH = (128, 122, 118, 255)
GOLD = (198, 162, 92, 255)
VOID = (18, 14, 24, 255)


def _c(size=32):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def _px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def _rect(img, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            _px(img, x, y, c)


def _ring(img):
    """The shared cursed rim: a broken circle."""
    import math
    cx = cy = 15.5
    for i in range(64):
        a = i / 64.0 * 6.28318
        if 0.5 < a < 1.1 or 3.6 < a < 4.2:
            continue  # broken segments
        _px(img, round(cx + 14.2 * math.cos(a)), round(cy + 14.2 * math.sin(a)), RIM)


def slow_heart():
    img = _c()
    _ring(img)
    # A heavy heart.
    for y, (x0, x1) in enumerate([(9, 14), (8, 15), (8, 15), (8, 15), (9, 14), (10, 13), (11, 12)]):
        _rect(img, x0, 10 + y, x1, 10 + y, DARK)
        _rect(img, x0 + 9, 10 + y, x1 + 9 if y else x1 + 9, 10 + y, DARK)
    _rect(img, 8, 12, 24, 16, DARK)
    for y in range(17, 24):
        _rect(img, 8 + (y - 16), y, 24 - (y - 16), y, DARK)
    _rect(img, 10, 12, 11, 13, MID)
    # The slow drip.
    _px(img, 16, 25, EMBER)
    _px(img, 16, 27, EMBER)
    return img


def sour_providence():
    img = _c()
    _ring(img)
    # A wilted clover: three drooping leaves on a bent stem.
    _rect(img, 15, 18, 16, 25, MID)
    _px(img, 17, 24, MID)
    for cx, cy in [(11, 13), (20, 12), (15, 8)]:
        _rect(img, cx - 2, cy - 1, cx + 2, cy + 1, DARK)
        _rect(img, cx - 1, cy - 2, cx + 1, cy + 2, DARK)
        _px(img, cx, cy, (60, 72, 48, 255))
    _px(img, 21, 15, (60, 72, 48, 255))  # a leaf falling off
    return img


def tithe_bones():
    img = _c()
    _ring(img)
    # Crossed bones under a levied coin.
    for t in range(-7, 8):
        _px(img, 16 + t, 18 + t // 2 + 2, BONE)
        _px(img, 16 + t, 20 - t // 2 + 2, BONE)
    for cx, cy in [(8, 16), (24, 16), (8, 26), (24, 26)]:
        _rect(img, cx - 1, cy - 1, cx + 1, cy + 1, BONE)
    _rect(img, 13, 7, 19, 13, GOLD)
    _rect(img, 14, 8, 18, 12, (160, 128, 66, 255))
    _px(img, 16, 10, GOLD)
    return img


def jinxed_coin():
    img = _c()
    _ring(img)
    # A cracked coin.
    import math
    for a in range(80):
        ang = a / 80.0 * 6.28318
        for r in range(0, 9):
            _px(img, round(16 + r * math.cos(ang)), round(16 + r * math.sin(ang)), GOLD if r > 6 else (150, 120, 64, 255))
    for x, y in [(16, 8), (15, 11), (16, 14), (17, 17), (15, 20), (16, 23)]:
        _px(img, x, y, VOID)
        _px(img, x + 1, y + 1, VOID)
    return img


def ashen_ballast():
    img = _c()
    _ring(img)
    # A strapped stone weight.
    _rect(img, 10, 10, 22, 24, ASH)
    _rect(img, 11, 11, 21, 13, (150, 144, 138, 255))
    _rect(img, 15, 6, 17, 10, MID)   # the hook
    _rect(img, 10, 16, 22, 17, DARK)  # strap
    _px(img, 12, 20, DARK)
    _px(img, 19, 21, DARK)
    return img


def hollow_reliquary():
    img = _c()
    _ring(img)
    # A reliquary box with nothing inside.
    _rect(img, 8, 11, 24, 25, MID)
    _rect(img, 8, 11, 24, 13, GOLD)
    _rect(img, 10, 15, 22, 23, VOID)
    _px(img, 15, 18, RIM)
    _px(img, 17, 20, RIM)
    return img


def leadfoot_vigil():
    img = _c()
    _ring(img)
    # A heavy greave/boot.
    _rect(img, 12, 7, 18, 20, DARK)
    _rect(img, 12, 20, 24, 25, DARK)
    _rect(img, 13, 8, 15, 18, MID)
    _rect(img, 12, 23, 24, 25, ASH)
    _px(img, 22, 21, EMBER)
    return img


def starving_crown():
    img = _c()
    _ring(img)
    # A thin jagged crown over a hollow.
    _rect(img, 8, 18, 24, 21, GOLD)
    for i, x in enumerate(range(8, 25, 4)):
        _rect(img, x, 12 - (i % 2) * 2, x + 1, 18, GOLD)
    _rect(img, 12, 23, 20, 24, VOID)
    _px(img, 16, 15, RIM)
    return img


ICONS = {
    "curse_slow_heart": slow_heart,
    "curse_sour_providence": sour_providence,
    "curse_tithe_bones": tithe_bones,
    "curse_jinxed_coin": jinxed_coin,
    "curse_ashen_ballast": ashen_ballast,
    "curse_hollow_reliquary": hollow_reliquary,
    "curse_leadfoot_vigil": leadfoot_vigil,
    "curse_starving_crown": starving_crown,
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in ICONS.items():
        build().save(OUT / f"{name}.png")
        print("wrote", name)
