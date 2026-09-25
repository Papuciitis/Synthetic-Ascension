#!/usr/bin/env python3
"""Provisional Beka sprites (Phase 4, memorial companion).

Colouring is the user's direct description (decision D-3): a black and white
female cat, tuxedo pattern — white nose/muzzle, white neck and chest, white
"boots" on all four paws, black elsewhere; drawn small, soft and calm. This
is a text-described likeness, labelled provisional in the asset manifest
until a photo reference is supplied.

Writes:
  assets/textures/items/offhand/beka_icon.png   (32x32, cat on a blanket)
  assets/textures/companions/beka_sit.png       (22x20)
  assets/textures/companions/beka_sleep.png     (22x14)
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

BLACK = (34, 32, 36, 255)
BLACK_HI = (58, 54, 60, 255)
WHITE = (240, 238, 232, 255)
PINK = (222, 140, 150, 255)
EYE = (120, 200, 120, 255)
BLANKET = (140, 100, 80, 255)
BLANKET_HI = (170, 128, 100, 255)


def _px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def _rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            _px(img, x, y, c)


def sitting(width=22, height=20) -> Image.Image:
    """A small sitting tuxedo cat, three-quarter view, tail curled."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    # Body: rounded black blob.
    _rect(img, 6, 8, 15, 17, BLACK)
    _rect(img, 5, 10, 5, 16, BLACK)
    _rect(img, 16, 10, 16, 16, BLACK)
    # Chest / neck white bib.
    _rect(img, 9, 10, 12, 15, WHITE)
    _rect(img, 10, 9, 11, 9, WHITE)
    # Head.
    _rect(img, 7, 2, 14, 8, BLACK)
    _px(img, 6, 3, BLACK)
    _px(img, 15, 3, BLACK)
    # Ears.
    _px(img, 7, 1, BLACK)
    _px(img, 8, 0, BLACK)
    _px(img, 13, 0, BLACK)
    _px(img, 14, 1, BLACK)
    _px(img, 8, 1, PINK)
    _px(img, 13, 1, PINK)
    # White muzzle and nose.
    _rect(img, 9, 5, 12, 7, WHITE)
    _px(img, 10, 5, PINK)
    _px(img, 11, 5, PINK)
    # Eyes.
    _px(img, 8, 4, EYE)
    _px(img, 13, 4, EYE)
    # Front legs with white boots.
    _rect(img, 8, 16, 9, 18, BLACK)
    _rect(img, 12, 16, 13, 18, BLACK)
    _rect(img, 8, 18, 9, 19, WHITE)
    _rect(img, 12, 18, 13, 19, WHITE)
    # Tail curled around the right side.
    _px(img, 17, 14, BLACK)
    _px(img, 18, 15, BLACK)
    _px(img, 18, 16, BLACK)
    _px(img, 17, 17, BLACK)
    _px(img, 16, 18, BLACK)
    _px(img, 15, 18, BLACK_HI)
    # Back highlight.
    _px(img, 14, 9, BLACK_HI)
    _px(img, 15, 10, BLACK_HI)
    return img


def sleeping(width=22, height=14) -> Image.Image:
    """Curled up asleep: a black crescent, white chest sliver, tucked nose."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    _rect(img, 4, 4, 17, 11, BLACK)
    _rect(img, 3, 6, 3, 10, BLACK)
    _rect(img, 18, 6, 18, 10, BLACK)
    _rect(img, 5, 11, 16, 12, BLACK)
    # Chest sliver.
    _rect(img, 8, 8, 11, 11, WHITE)
    # Head tucked at the left, muzzle white.
    _rect(img, 4, 5, 8, 8, BLACK)
    _rect(img, 4, 7, 6, 8, WHITE)
    _px(img, 4, 7, PINK)
    # Closed eye.
    _px(img, 6, 6, BLACK_HI)
    # Ear tips.
    _px(img, 5, 3, BLACK)
    _px(img, 7, 3, BLACK)
    # Tail wrapped over the front, white tip.
    _rect(img, 12, 12, 17, 13, BLACK)
    _px(img, 11, 13, WHITE)
    # White boot peeking.
    _px(img, 14, 11, WHITE)
    _px(img, 15, 11, WHITE)
    # Back highlight.
    _rect(img, 10, 4, 14, 4, BLACK_HI)
    return img


def icon() -> Image.Image:
    """32x32 inventory icon: Beka resting on a folded blanket."""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    # Folded blanket: two soft layers.
    _rect(img, 3, 22, 28, 27, BLANKET)
    _rect(img, 5, 20, 26, 21, BLANKET_HI)
    _rect(img, 3, 22, 28, 22, BLANKET_HI)
    # The sleeping cat, centred on the blanket.
    cat = sleeping()
    img.alpha_composite(cat.resize((22, 14), Image.NEAREST), (5, 7))
    return img


if __name__ == "__main__":
    companions = ROOT / "assets/textures/companions"
    offhand = ROOT / "assets/textures/items/offhand"
    companions.mkdir(parents=True, exist_ok=True)
    offhand.mkdir(parents=True, exist_ok=True)
    sitting().save(companions / "beka_sit.png")
    sleeping().save(companions / "beka_sleep.png")
    icon().save(offhand / "beka_icon.png")
    print("wrote beka_sit.png, beka_sleep.png, beka_icon.png")
