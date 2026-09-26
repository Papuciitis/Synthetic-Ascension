#!/usr/bin/env python3
"""Icons for item batch 2 (Phase 4): Missing Pālis, Plot Armor, Second
Breakfast. Same 32x32 authored pixel language as the rest of the catalog.

Run:  python3 tools/design/build_item_icons.py
Writes assets/textures/items/{rings,offhand}/*.png
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

MAGENTA = (236, 64, 222, 255)
BLACK = (24, 20, 26, 255)
STEEL = (148, 152, 164, 255)
STEEL_D = (96, 100, 114, 255)
GOLDSTAR = (244, 208, 108, 255)
PLATE = (226, 222, 210, 255)
PLATE_D = (188, 182, 168, 255)
YOLK = (240, 186, 70, 255)
WHITE = (246, 244, 238, 255)
BACON = (178, 92, 74, 255)


def _c(size=32):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def _px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def _rect(img, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            _px(img, x, y, c)


def missing_palis():
    """The missing texture itself: a magenta-black checker tile, one corner
    peeling away in a wave."""
    img = _c()
    import math
    for y in range(5, 27):
        # The wave: rows shear sideways more toward the top-right peel.
        shear = int(round(2.2 * math.sin((y - 5) * 0.55) * max(0.0, (27 - y) / 22.0)))
        for x in range(5, 27):
            checker = ((x // 5) + (y // 5)) % 2 == 0
            _px(img, x + shear, y, MAGENTA if checker else BLACK)
    # Peeled corner: a lifted triangle with a pale underside.
    for i in range(6):
        _rect(img, 26 - i, 5 + i, 26, 5 + i, (0, 0, 0, 0))
        _px(img, 26 - i, 5 + i, (210, 205, 200, 255))
    _px(img, 25, 6, (230, 226, 220, 255))
    return img


def plot_armor():
    """A chestplate too shiny to die in, with the protagonist star."""
    img = _c()
    # Torso plate.
    _rect(img, 9, 7, 22, 10, STEEL)
    _rect(img, 8, 11, 23, 20, STEEL)
    _rect(img, 10, 21, 21, 25, STEEL_D)
    # Neck opening + shoulder cuts.
    _rect(img, 14, 7, 17, 9, (0, 0, 0, 0))
    _px(img, 8, 7, (0, 0, 0, 0))
    _px(img, 23, 7, (0, 0, 0, 0))
    # Center ridge and shine.
    _rect(img, 15, 10, 16, 24, STEEL_D)
    _rect(img, 10, 9, 11, 18, (188, 194, 206, 255))
    # The star.
    _px(img, 16, 14, GOLDSTAR)
    _px(img, 15, 15, GOLDSTAR)
    _px(img, 16, 15, GOLDSTAR)
    _px(img, 17, 15, GOLDSTAR)
    _px(img, 16, 16, GOLDSTAR)
    _px(img, 14, 14, GOLDSTAR)
    _px(img, 18, 14, GOLDSTAR)
    return img


def second_breakfast():
    """A plate that was not done with you: two fried eggs and bacon."""
    img = _c()
    import math
    # Plate.
    cx = cy = 16.0
    for y in range(32):
        for x in range(32):
            r = math.hypot(x - cx, y - cy)
            if r <= 13.5:
                _px(img, x, y, PLATE)
            if 12.0 <= r <= 13.5:
                _px(img, x, y, PLATE_D)
    # Two eggs.
    for ex, ey in [(11, 13), (20, 17)]:
        for y in range(-4, 5):
            for x in range(-4, 5):
                if math.hypot(x, y) <= 4.2:
                    _px(img, ex + x, ey + y, WHITE)
        for y in range(-1, 2):
            for x in range(-1, 2):
                _px(img, ex + x, ey + y, YOLK)
    # Bacon strip along the rim.
    for t in range(9):
        _px(img, 9 + t, 22 + (t % 2), BACON)
        _px(img, 9 + t, 23 + (t % 2), BACON)
    return img


SCAR = (166, 128, 120, 255)
GAUZE = (216, 210, 198, 255)
CREST_GOLD = (222, 184, 96, 255)
CREST_BLUE = (86, 108, 162, 255)


def trauma():
    """A shield that learned: cracked, gauze-bound, and harder for it."""
    img = _c()
    # Shield silhouette.
    _rect(img, 9, 6, 22, 12, STEEL)
    _rect(img, 10, 13, 21, 18, STEEL)
    _rect(img, 12, 19, 19, 22, STEEL_D)
    _rect(img, 14, 23, 17, 25, STEEL_D)
    # The remembered wound: a scar seam down one side.
    for x, y in [(13, 7), (14, 9), (13, 11), (14, 13), (15, 15), (14, 17), (15, 19)]:
        _px(img, x, y, SCAR)
    # Gauze wrap across the middle.
    _rect(img, 9, 14, 22, 15, GAUZE)
    _px(img, 11, 16, GAUZE)
    _px(img, 20, 13, GAUZE)
    return img


def dignity():
    """An upright little standard: a crest on a staff, held high."""
    img = _c()
    # Staff.
    _rect(img, 15, 6, 16, 26, (110, 88, 62, 255))
    # Banner crest.
    _rect(img, 17, 7, 26, 14, CREST_BLUE)
    for y in range(15, 18):
        _rect(img, 17, y, 26 - (y - 14) * 3, y, CREST_BLUE)
    _rect(img, 18, 8, 20, 10, CREST_GOLD)
    _px(img, 22, 11, CREST_GOLD)
    # Base footing: it stands, it does not kneel.
    _rect(img, 12, 26, 19, 27, STEEL_D)
    return img


if __name__ == "__main__":
    rings = ROOT / "assets/textures/items/rings"
    offhand = ROOT / "assets/textures/items/offhand"
    rings.mkdir(parents=True, exist_ok=True)
    offhand.mkdir(parents=True, exist_ok=True)
    missing_palis().save(rings / "missing_palis.png")
    plot_armor().save(offhand / "plot_armor.png")
    second_breakfast().save(rings / "second_breakfast.png")
    trauma().save(offhand / "trauma.png")
    dignity().save(rings / "dignity.png")
    print("wrote missing_palis, plot_armor, second_breakfast, trauma, dignity")
