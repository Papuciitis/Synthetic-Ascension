#!/usr/bin/env python3
"""Bake hub art from incoming/hub/<name>.png into assets/textures/hub/<name>.png.

Brief: docs/art/2026-09-27-hub-square-art.md. Every piece is baked at the
world size it is drawn at, so the game shows it 1:1:

- Buildings (batch B) share one detail scale in the generator's sheets (a
  door is ~200 source px), so they take one factor, SCALE, which puts a door
  at ~80 px beside the ~64 px player.
- Street dressing, the plaza and the icons are sized by the brief: TARGET
  gives each one's world height (or width, for the plaza).

Trims to the alpha box (ignoring faint haze) and zeroes the border alpha.
Strips that tile horizontally and frame sheets keep their full width, so
tiles still meet and frames stay on equal cells.

Run: python3 tools/design/bake_hub_art.py [name ...]   (default: all in incoming/hub)
"""
import sys
from pathlib import Path
from PIL import Image

SCALE = 0.4
## name -> ("h" | "w", world px): the baked height or width.
TARGET = {
    "hub_tree_autumn_a": ("h", 190),
    "hub_tree_autumn_b": ("h", 180),
    "hub_banner": ("h", 150),
    "hub_brazier_sheet": ("h", 90),
    "hub_stall_alcove": ("h", 140),
    "hub_stall_gear": ("h", 140),
    "hub_stall_green": ("h", 140),
    "hub_barrels": ("h", 70),
    "hub_sacks": ("h", 50),
    # HubWorld fits the plaza to (radius * 2 + 0.25) cells = 656 px.
    "hub_plaza": ("w", 656),
    "hub_icon_merchant": ("h", 48),
    "hub_icon_ascension": ("h", 48),
    "hub_icon_gear": ("h", 48),
    "hub_icon_alcove": ("h", 48),
    "hub_icon_exit": ("h", 48),
    # docs/art/2026-09-27-hub-npc-art.md: people at the player's ~77 px,
    # Beka at her in-game sizes (a sitting cat is ~34 px).
    "hub_npc_exchanger": ("h", 80),
    "hub_npc_quartermaster": ("h", 82),
    "hub_npc_chronicler": ("h", 78),
    "hub_npc_acolyte": ("h", 82),
    "hub_npc_smith": ("h", 82),
    "hub_crowd_pilgrim": ("h", 80),
    "hub_crowd_labourer": ("h", 80),
    "hub_crowd_washer": ("h", 76),
    "hub_crowd_elder": ("h", 74),
    "hub_crowd_courier": ("h", 76),
    "hub_crowd_clerk": ("h", 80),
    "hub_crowd_baker": ("h", 78),
    "hub_crowd_mender": ("h", 76),
    "hub_beka_walk": ("h", 28),
    "hub_beka_stand": ("h", 30),
    "hub_beka_content": ("h", 34),
    "hub_beka_groom": ("h", 34),
    "hub_beka_stretch": ("h", 26),
}
TILE_STRIPS = {"hub_roofs_back"}
FRAME_SHEETS = {
    "hub_brazier_sheet": 3,
    "hub_beka_walk": 6,
    **{f"hub_crowd_{n}": 3 for n in ("pilgrim", "labourer", "washer", "elder", "courier", "clerk", "baker", "mender")},
}
SRC = Path("incoming/hub")
DST = Path("assets/textures/hub")


def register_frames(im: Image.Image, frames: int) -> Image.Image:
    """Re-pack a hand-drawn frame strip onto equal cells.

    The generator does not space frames on exact equal cells (the brazier
    sheet's plinths sat 657 px apart on 724 px thirds), which makes the
    animation jitter. Find each frame as a run of non-empty columns, anchor
    it on its base (the bounding box of its lowest 40%, where the plinth is
    and the flame is not) and place every base at the centre of an equal
    cell, bottoms aligned.
    """
    solid = im.getchannel("A").point(lambda v: 255 if v else 0)
    w, h = im.size
    used = [solid.crop((x, 0, x + 1, h)).getbbox() is not None for x in range(w)]
    runs, start = [], None
    for x, on in enumerate(used + [False]):
        if on and start is None:
            start = x
        if not on and start is not None:
            runs.append((start, x))
            start = None
    if len(runs) != frames:
        print(f"  {frames} frames expected, found {len(runs)} column runs; keeping the sheet as drawn")
        return im
    anchors = []
    for x0, x1 in runs:
        box = solid.crop((x0, 0, x1, h)).getbbox()
        base_top = box[1] + int((box[3] - box[1]) * 0.6)
        base = solid.crop((x0, base_top, x1, box[3])).getbbox()
        anchors.append(x0 + (base[0] + base[2]) / 2.0)
    half = max(max(a - x0, x1 - a) for (x0, x1), a in zip(runs, anchors))
    cell = int(half * 2) + 8
    out = Image.new("RGBA", (cell * frames, h), (0, 0, 0, 0))
    for i, ((x0, x1), a) in enumerate(zip(runs, anchors)):
        piece = im.crop((x0, 0, x1, h))
        out.alpha_composite(piece, (int(round(i * cell + cell / 2.0 - (a - x0))), 0))
    return out


def bake(name: str) -> None:
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    alpha = im.getchannel("A").point(lambda v: 0 if v < 8 else v)
    im.putalpha(alpha)
    if name in FRAME_SHEETS:
        im = register_frames(im, FRAME_SHEETS[name])
        alpha = im.getchannel("A")
    box = alpha.getbbox()
    keep_width = name in TILE_STRIPS or name in FRAME_SHEETS
    im = im.crop((0, box[1], im.width, box[3]) if keep_width else box)
    if name in TARGET:
        axis, px = TARGET[name]
        factor = px / (im.height if axis == "h" else im.width)
    else:
        factor = SCALE
    w = max(1, round(im.width * factor))
    h = max(1, round(im.height * factor))
    frames = FRAME_SHEETS.get(name, 1)
    w -= w % frames
    out = im.resize((w, h), Image.LANCZOS)
    px = out.load()
    for x in range(w):
        px[x, 0] = px[x, 0][:3] + (0,)
        px[x, h - 1] = px[x, h - 1][:3] + (0,)
    if name not in TILE_STRIPS:
        # Every frame's side border too, so no frame bleeds into the next.
        for f in range(frames):
            for x in (f * w // frames, (f + 1) * w // frames - 1):
                for y in range(h):
                    px[x, y] = px[x, y][:3] + (0,)
    out.save(DST / f"{name}.png")
    print(f"{name}: {im.size} -> {out.size} ({w / 64:.2f} x {h / 64:.2f} cells)")


names = sys.argv[1:] or sorted(p.stem for p in SRC.glob("*.png"))
for n in names:
    bake(n)
