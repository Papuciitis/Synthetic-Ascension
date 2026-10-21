#!/usr/bin/env python3
"""Low plaza-edge kits and the plaza prop atlas (2026-10-21 plaza pass).

Plaza perimeter rings stay physical WALL cells (the 24 px collision band
through the cell centre, ChunkBlockPhysics), but they are drawn as
knee-high dressed limestone instead of the 92 px wall kit:

  planter34_*     a stone planter box with clipped box shrubs and lavender
                  (ordinary squares: entry, landmark, reward and shrine
                  plazas)
  balustrade34_*  a plain low parapet with corner piers and no planting
                  (gates and every arena court: ward courts, checkpoints,
                  miniboss and boss courts, where nothing may hide a tell)

Same contract as tools/design/build_wall_kit.py: one piece per connection
mask (N=1, E=2, S=4, W=8) on a canvas of the cell plus 28 px above it
(64 x 92 world px), so ChunkBlockRenderer draws both through the wall kit
path. A piece's top is its plan footprint lifted by its height, and a stone
face hangs under every south-exposed edge. Planting may rise above the lifted
top, but never above the lifted cell edge where a north arm continues: pieces
overlap the cell above in arbitrary instance order, so nothing a neighbour
draws there may be covered or cover it.

Sources: assets/world/plazas_v1/planter_wall.png (dressed face, shrubs,
lavender, ivy); the coping is a calm procedural limestone in the face's
palette, so long runs read as one quiet edge rather than a striped band.
Output at SCALE texels per world px (2: the edge is drawn small), rendered
at RS and reduced for clean edges.

The same run packs the plaza / street props into one small atlas
(plaza_props.png): one texture, so the props registered for actor cover add
a single small layer to WorldCover's shared alpha array.

Run:  python3 tools/design/build_plaza_kit.py
"""

from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/world/plazas_v1"
DRESSING = ROOT / "assets/world/dressing_v2"
DISTRICTS = ROOT / "assets/world/districts_v2"
OUT = ROOT / "assets/world/plazas_v1/kit"

SCALE = 2          # output texels per world px
RS = 4             # render texels per world px (reduced to SCALE at the end)
CELL = 64
HEADROOM = 28      # canvas rows above the cell (the wall kit's KIT_HEIGHT)
PAD = 24           # world px of virtual margin around a canvas for erosion
N, E, S, W = 1, 2, 4, 8

STYLES = {
    # band thickness and lift (face height), world px
    "planter": {"thick": 40, "lift": 16, "coping": 5},
    "balustrade": {"thick": 28, "lift": 17, "coping": 0},
}
# Limestone of the source face's lit rim, a little cooler and greyer so the
# edge stays below the actors in contrast.
LIMESTONE = np.array([184.0, 176.0, 158.0])
SOIL = np.array([74.0, 57.0, 41.0])
# The parapet's top is a broad pale band: hold it under the planters' coping.
BALUSTRADE_VALUE = 0.72


def world(v: float) -> int:
    return int(round(v * RS))


# ---------------------------------------------------------------- sources ---

PLANTER = np.asarray(Image.open(SRC / "planter_wall.png").convert("RGBA"), dtype=np.float64)


def _tile_strip(region: np.ndarray, width: int, blend: int) -> np.ndarray:
    """Resample a strip to `width` texels and cross-fade its ends so it wraps."""
    img = Image.fromarray(region.astype(np.uint8), "RGBA")
    h = region.shape[0]
    img = img.resize((width + blend, h), Image.LANCZOS)
    arr = np.asarray(img, dtype=np.float64)
    out = arr[:, :width].copy()
    t = np.linspace(0.0, 1.0, blend)[None, :, None]
    out[:, :blend] = arr[:, width:width + blend] * (1.0 - t) + arr[:, :blend] * t
    return out


# Clean dressed stone of the source face (rim, upper course, plinth course):
# x 250..500, y 90..166, one cell wide so every piece samples the same wrap.
FACE_STRIP = _tile_strip(PLANTER[90:166, 250:500], CELL * RS, 24)


def _limestone_field(seed: int, size: int) -> np.ndarray:
    """A calm limestone surface that tiles every `size` texels (one cell), so
    copings and kerbs continue across cells: low-frequency mottling plus a
    fine grain, as sums of whole-period waves."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size] / float(size)
    out = np.zeros((size, size))
    for freq, amp, count in ((1, 5.0, 3), (3, 3.0, 5), (9, 2.0, 8), (27, 1.6, 10)):
        for _ in range(count):
            fx, fy = rng.integers(-freq, freq + 1, size=2)
            if fx == 0 and fy == 0:
                fx = freq
            phase = rng.uniform(0.0, 2.0 * np.pi)
            out += np.sin(2.0 * np.pi * (fx * xx + fy * yy) + phase) * amp / np.sqrt(count)
    grain = rng.normal(0.0, 2.2, size=(size, size))
    return LIMESTONE[None, None, :] + (out + grain)[:, :, None]


LIME = _limestone_field(11, CELL * RS)

# Clumps of the source's alternating box / lavender row (x0, x1).
CLUMP_X = {
    "box1": (6, 104), "lav1": (100, 192), "box2": (188, 292),
    "lav2": (284, 358), "box3": (352, 448), "lav3": (430, 512),
}


def clump(name: str) -> np.ndarray:
    x0, x1 = CLUMP_X[name]
    part = PLANTER[0:92, x0:x1].copy()
    w = part.shape[1]
    feather = 10
    ramp = np.ones(w)
    ramp[:feather] = np.linspace(0.0, 1.0, feather)
    ramp[-feather:] = np.linspace(1.0, 0.0, feather)
    part[:, :, 3] *= ramp[None, :]
    fade = np.ones(part.shape[0])
    fade[-5:] = np.linspace(1.0, 0.3, 5)
    part[:, :, 3] *= fade[:, None]
    rows = np.where(part[:, :, 3].max(axis=1) > 8)[0]
    return part[rows[0]:] if len(rows) else part


def ivy_sprig() -> np.ndarray:
    """The trailing ivy over the source's face, keyed off the stone."""
    part = PLANTER[86:191, 44:236].copy()
    rgb = part[:, :, :3]
    green = (rgb[:, :, 1] > rgb[:, :, 0] * 1.04) & (rgb[:, :, 1] > rgb[:, :, 2] * 1.12)
    alpha = np.where(green, part[:, :, 3], 0.0)
    img = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    a = img.split()[3].filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    img.putalpha(a.filter(ImageFilter.GaussianBlur(0.6)))
    return np.asarray(img, dtype=np.float64)


CLUMPS = {name: clump(name) for name in CLUMP_X}
IVY = ivy_sprig()


# -------------------------------------------------------------- compositing -

def over(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    """Alpha-composite src (RGBA float) onto dst at integer texel (x, y)."""
    h, w = src.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(dst.shape[1], x + w), min(dst.shape[0], y + h)
    if x0 >= x1 or y0 >= y1:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    sa = s[:, :, 3:4] / 255.0
    da = d[:, :, 3:4] / 255.0
    out_a = sa + da * (1.0 - sa)
    rgb = np.where(out_a > 0, (s[:, :, :3] * sa + d[:, :, :3] * da * (1.0 - sa)) / np.maximum(out_a, 1e-6), 0.0)
    d[:, :, :3] = rgb
    d[:, :, 3:4] = out_a * 255.0


def scaled(src: np.ndarray, factor: float, flip: bool = False) -> np.ndarray:
    img = Image.fromarray(np.clip(src, 0, 255).astype(np.uint8), "RGBA")
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    size = (max(1, round(img.width * factor)), max(1, round(img.height * factor)))
    return np.asarray(img.resize(size, Image.LANCZOS), dtype=np.float64)


def erode(mask: np.ndarray, r: int) -> np.ndarray:
    """Square (Chebyshev) erosion by r texels, separable; outside counts as empty."""
    if r <= 0:
        return mask.copy()
    out = mask.copy()
    for axis in (0, 1):
        src = out
        acc = src.copy()
        for k in range(1, r + 1):
            for sign in (-1, 1):
                shifted = np.zeros_like(src)
                if axis == 0:
                    if sign < 0:
                        shifted[:-k] = src[k:]
                    else:
                        shifted[k:] = src[:-k]
                else:
                    if sign < 0:
                        shifted[:, :-k] = src[:, k:]
                    else:
                        shifted[:, k:] = src[:, :-k]
                acc &= shifted
        out = acc
    return out


class Piece:
    """One kit piece in render texels: canvas 64 x 92 world px."""

    def __init__(self, style: str, mask: int):
        self.style = style
        self.mask = mask
        cfg = STYLES[style]
        self.thick = cfg["thick"]
        self.lift = cfg["lift"]
        self.coping = cfg["coping"]
        self.t0 = (CELL - self.thick) / 2.0
        self.t1 = self.t0 + self.thick
        self.w = CELL * RS
        self.h = (CELL + HEADROOM) * RS
        self.rgba = np.zeros((self.h, self.w, 4))
        self.yy, self.xx = np.mgrid[0:self.h, 0:self.w]

    def lifted(self, plan_y: float, extra: float = 0.0) -> int:
        """Canvas texel row of a plan y lifted by the piece height."""
        return world(plan_y - self.lift - extra + HEADROOM)

    def ground(self, plan_y: float) -> int:
        return world(plan_y + HEADROOM)

    def plan_rects(self, extend: float = 0.0):
        """Top footprint rects (x0, y0, x1, y1) in plan world px; `extend`
        pushes open arm ends past the cell edge (the continuing neighbour)."""
        t0, t1, m = self.t0, self.t1, self.mask
        rects = [(t0, t0, t1, t1)]
        if m & N:
            rects.append((t0, -extend, t1, t0))
        if m & S:
            rects.append((t0, t1, t1, CELL + extend))
        if m & E:
            rects.append((t1, t0, CELL + extend, t1))
        if m & W:
            rects.append((-extend, t0, t0, t1))
        return rects

    def top_mask(self, extend: float = 0.0, pad: int = 0) -> np.ndarray:
        """Lifted top region in canvas texels, optionally on a padded grid."""
        h, w = self.h + 2 * pad, self.w + 2 * pad
        yy, xx = np.mgrid[0:h, 0:w]
        out = np.zeros((h, w), dtype=bool)
        for x0, y0, x1, y1 in self.plan_rects(extend):
            out |= (xx >= world(x0) + pad) & (xx < world(x1) + pad) & (yy >= self.lifted(y0) + pad) & (yy < self.lifted(y1) + pad)
        return out

    def face_rects(self):
        """South faces (x0, x1, plan_y) under each exposed south edge."""
        t0, t1, m = self.t0, self.t1, self.mask
        faces = []
        if not m & S:
            faces.append((t0, t1, t1))
        if m & E:
            faces.append((t1, CELL, t1))
        if m & W:
            faces.append((0.0, t0, t1))
        return faces


def stone_face(piece: Piece, x0: float, x1: float, plan_y: float, shade: float = 1.0) -> None:
    """The dressed face under a south edge: rim, course, plinth, contact shade."""
    top, bottom = piece.lifted(plan_y), piece.ground(plan_y)
    c0, c1 = world(x0), world(x1)
    if c1 <= c0 or bottom <= top:
        return
    rows = np.arange(top, bottom)
    v = ((rows - top) / max(1, bottom - top - 1) * (FACE_STRIP.shape[0] - 1)).astype(int)
    u = np.arange(c0, c1) % FACE_STRIP.shape[1]
    block = FACE_STRIP[v][:, u].copy()
    # Pull the painted face toward the coping's cool limestone.
    grey = block[:, :, :3].mean(axis=2, keepdims=True)
    block[:, :, :3] = block[:, :, :3] * 0.78 + grey * 0.22
    t = ((rows - top) / max(1, bottom - top))[:, None, None]
    block[:, :, :3] *= shade * (0.90 - 0.12 * t)
    foot = (bottom - rows) < world(2.0)
    block[foot, :, :3] *= 0.78
    block[:, :, 3] = 255.0
    piece.rgba[top:bottom, c0:c1] = block


def _run_lengths(mask: np.ndarray, axis: int, reverse: bool) -> np.ndarray:
    """Texels from each mask texel to the mask's edge along one direction."""
    m = np.flip(mask, axis=axis) if reverse else mask
    out = np.zeros(m.shape)
    n = m.shape[axis]
    prev = np.zeros(m.shape[1 - axis])
    for i in range(n):
        line = m[i] if axis == 0 else m[:, i]
        cur = np.where(line, prev + 1.0, 0.0)
        if axis == 0:
            out[i] = cur
        else:
            out[:, i] = cur
        prev = cur
    return np.flip(out, axis=axis) if reverse else out


def build_top(piece: Piece, soil: bool) -> np.ndarray:
    pad = world(PAD)
    top = piece.top_mask()
    virtual_p = piece.top_mask(extend=PAD, pad=pad)
    crop = (slice(pad, pad + piece.h), slice(pad, pad + piece.w))
    virtual = virtual_p[crop]
    if soil:
        inner_p = erode(virtual_p, world(piece.coping))
        inner = inner_p[crop] & top
        lip = inner & ~erode(inner_p, world(1.5))[crop]
    else:
        inner = np.zeros_like(top)
        lip = inner
    rim = top & ~inner
    lime = LIME[piece.yy % LIME.shape[0], piece.xx % LIME.shape[1]].copy()
    # Rounded coping lit from the upper right: brighter toward north / east
    # edges, a touch darker toward south / west, so the band has a profile.
    band = float(world(piece.thick))
    d_n = _run_lengths(virtual_p, 0, False)[crop]
    d_s = _run_lengths(virtual_p, 0, True)[crop]
    d_e = _run_lengths(virtual_p, 1, True)[crop]
    d_w = _run_lengths(virtual_p, 1, False)[crop]
    across_h = np.clip(d_n / np.maximum(d_n + d_s, 1.0), 0.0, 1.0)
    across_v = np.clip(d_e / np.maximum(d_e + d_w, 1.0), 0.0, 1.0)
    horizontal_part = (d_n + d_s) <= band + 2
    across = np.where(horizontal_part, across_h, across_v)
    light = 1.06 - 0.16 * across
    lime *= light[:, :, None]
    if not soil:
        # Dressed coping stones: a fine joint every half cell along the run.
        plan_y = piece.yy / RS - HEADROOM + piece.lift
        along = np.where(horizontal_part, piece.xx / RS, plan_y)
        joint = np.abs(((along + 16.0) % 32.0) - 16.0) < 0.55
        lime[joint & top] *= 0.80
    piece.rgba[top, :3] = np.clip(lime[top], 0, 255)
    piece.rgba[top, 3] = 255.0
    if soil:
        rng = np.random.default_rng(piece.mask * 31 + 7)
        noise = rng.normal(0.0, 9.0, size=(piece.h, piece.w))
        img = Image.fromarray(np.clip(noise + 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4))
        n = (np.asarray(img, dtype=np.float64) - 128.0)[:, :, None]
        earth = np.clip(SOIL[None, None, :] + n, 0, 255)
        piece.rgba[inner, :3] = earth[inner]
        piece.rgba[lip, :3] *= 0.72
    # Lit north lip; a pale arris on the south lip above each face.
    above = np.zeros_like(virtual)
    above[world(1.2):] = virtual[:-world(1.2)]
    lit = rim & ~above
    piece.rgba[lit, :3] = np.minimum(piece.rgba[lit, :3] * 1.08 + 8, 255)
    below = np.zeros_like(virtual)
    below[:-world(1.0)] = virtual[world(1.0):]
    lip_s = rim & ~below
    piece.rgba[lip_s, :3] = np.minimum(piece.rgba[lip_s, :3] * 1.12 + 4, 255)
    return top


def plant(piece: Piece, name: str, cx: float, base_plan_y: float, height: float, flip: bool = False) -> None:
    src = CLUMPS[name]
    factor = world(height) / src.shape[0]
    img = scaled(src, factor, flip)
    # Keep every leaf inside the cell's columns: the canvas is exactly one
    # cell wide and a neighbour cannot continue a clipped plant.
    half = img.shape[1] / 2.0
    left = int(round(np.clip(world(cx) - half, 0, piece.w - img.shape[1])))
    y = piece.lifted(base_plan_y) - img.shape[0]
    over(piece.rgba, img, left, y)


def ivy(piece: Piece, x0: float, plan_y: float, flip: bool) -> None:
    img = scaled(IVY, world(piece.lift + 8.0) / IVY.shape[0], flip)
    img = img[:, :min(img.shape[1], piece.w - world(x0))]
    over(piece.rgba, img, world(x0), piece.lifted(plan_y) - world(3.0))


def pier(piece: Piece, cx: float, cy: float, half: float, raise_px: float) -> None:
    """A square stone post centred on (cx, cy) plan, `raise_px` above the top."""
    x0, x1 = world(cx - half), world(cx + half)
    cap0 = piece.lifted(cy - half, raise_px)
    cap1 = piece.lifted(cy + half, raise_px)
    base = piece.ground(cy + half)
    rows = np.arange(cap1, base)
    if rows.size:
        v = ((rows - cap1) / max(1, base - cap1 - 1) * (FACE_STRIP.shape[0] - 1)).astype(int)
        u = np.arange(x0, x1) % FACE_STRIP.shape[1]
        block = FACE_STRIP[v][:, u].copy()
        grey = block[:, :, :3].mean(axis=2, keepdims=True)
        block[:, :, :3] = (block[:, :, :3] * 0.78 + grey * 0.22) * 0.84
        block[(base - rows) < world(2.0), :, :3] *= 0.78
        block[:, :, 3] = 255.0
        piece.rgba[cap1:base, x0:x1] = block
    cap = (piece.xx >= x0) & (piece.xx < x1) & (piece.yy >= cap0) & (piece.yy < cap1)
    lime = LIME[piece.yy % LIME.shape[0], piece.xx % LIME.shape[1]].copy()
    # A shallow pyramid cap lit from the upper right.
    u = (piece.xx - x0) / max(1, x1 - x0)
    v = (piece.yy - cap0) / max(1, cap1 - cap0)
    lit = np.where(u > v, 1.10, 0.94) * np.where(u + v > 1.0, 1.0, 1.04)
    lime *= lit[:, :, None]
    piece.rgba[cap, :3] = np.minimum(lime[cap] * (BALUSTRADE_VALUE + 0.06) + 4, 255)
    piece.rgba[cap, 3] = 255.0
    lip = cap & (piece.yy < cap0 + world(1.2))
    piece.rgba[lip, :3] = np.minimum(piece.rgba[lip, :3] * 1.08 + 10, 255)
    south = cap & (piece.yy >= cap1 - world(1.0))
    piece.rgba[south, :3] = np.minimum(piece.rgba[south, :3] * 1.12 + 6, 255)


def contact_shadow(piece: Piece) -> None:
    """A soft dark fringe where the faces meet the ground (no outline)."""
    alpha = piece.rgba[:, :, 3] > 200
    for step, strength in ((1, 92.0), (2, 64.0), (3, 36.0)):
        shifted = np.zeros_like(alpha)
        shifted[world(step * 0.6):] = alpha[:-world(step * 0.6)]
        ring = shifted & (piece.rgba[:, :, 3] < 1)
        piece.rgba[ring, :3] = 24.0
        piece.rgba[ring, 3] = strength


def reduce(piece: Piece) -> Image.Image:
    arr = np.clip(piece.rgba, 0, 255)
    a = arr[:, :, 3:4] / 255.0
    pm = np.dstack([arr[:, :, :3] * a, arr[:, :, 3:4]])
    pm_img = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA")
    size = (CELL * SCALE, (CELL + HEADROOM) * SCALE)
    small = np.asarray(pm_img.resize(size, Image.LANCZOS), dtype=np.float64)
    sa = small[:, :, 3:4] / 255.0
    rgb = np.where(sa > 0, small[:, :, :3] / np.maximum(sa, 1e-6), 0.0)
    return Image.fromarray(np.clip(np.dstack([rgb, small[:, :, 3:4]]), 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------- the pieces --

def build_planter(mask: int, variant: int = 0) -> Image.Image:
    piece = Piece("planter", mask)
    for x0, x1, plan_y in piece.face_rects():
        stone_face(piece, x0, x1, plan_y)
    build_top(piece, True)
    c = CELL / 2.0
    front = piece.t1 - 4.0
    plants = []
    if mask == (E | W):
        names = ("box1", "lav1") if variant == 0 else ("lav2", "box2")
        plants = [(names[0], 16.0, front, 37.0), (names[1], 48.0, front, 39.0)]
    elif mask == (N | S):
        # A continuous hedge up the run: three overlapping clumps per cell.
        names = ("lav1", "box1", "lav3") if variant == 0 else ("box3", "lav2", "box2")
        plants = [(names[0], c, 24.0, 30.0), (names[1], c, 44.0, 32.0), (names[2], c, 64.0, 32.0)]
    elif bin(mask).count("1") <= 1:
        plants = [("box3", c, front, 38.0)]
        if mask & N:
            plants.append(("lav1", c, 22.0, 26.0))
    else:
        base = front if not mask & S else 50.0
        arms = bin(mask).count("1")
        plants = [("box2" if arms == 2 else "lav3", c, base, 40.0)]
        if mask & N:
            plants.append(("lav2", c, 22.0, 26.0))
        if arms >= 3:
            # Junctions of a double ring sit inside one deep bed: fill it.
            if mask & E:
                plants.append(("box1", 52.0, base - 6.0, 30.0))
            if mask & W:
                plants.append(("lav1", 12.0, base - 6.0, 30.0))
            if mask & S:
                plants.append(("box3", c, 62.0, 30.0))
    for name, cx, base, height in sorted(plants, key=lambda p: p[2]):
        if mask & N:
            # Rising no higher than the lifted cell edge (canvas row of plan 0).
            height = min(height, (piece.lifted(base) - piece.lifted(0.0)) / RS)
        plant(piece, name, cx, base, height, flip=(variant == 1))
    if mask == (E | W) and variant == 1:
        ivy(piece, 4.0, piece.t1, False)
    contact_shadow(piece)
    return reduce(piece)


def build_balustrade(mask: int, pier_here: bool = False) -> Image.Image:
    piece = Piece("balustrade", mask)
    for x0, x1, plan_y in piece.face_rects():
        stone_face(piece, x0, x1, plan_y, shade=0.88)
    top = build_top(piece, False)
    # A long parapet must sit below the actors in value: weathered, not white.
    piece.rgba[top, :3] *= BALUSTRADE_VALUE
    arms = bin(mask).count("1")
    # Piers close a run's free end (and the rhythm piece); L-turns of the
    # stepped diagonals and the T / cross cells of a double ring only turn or
    # widen the parapet, so a staircase stays a rail and a thick ring a slab.
    if pier_here or arms <= 1:
        pier(piece, CELL / 2.0, CELL / 2.0, piece.thick / 2.0 + 2.0, 4.0)
        cap = piece.rgba[:, :, 3] > 0
        piece.rgba[cap & ~top, :3] *= 1.0
    contact_shadow(piece)
    return reduce(piece)


def build_fill(style: str) -> Image.Image:
    """The top of one open quadrant where two arms and the diagonal cell are
    all edge cells. A planter fill also covers the coping of the two arms
    beside the quadrant, so a block of edge cells reads as one bed."""
    cfg = STYLES[style]
    side = (CELL - cfg["thick"]) / 2.0 + cfg["coping"]
    px = world(side)
    if style == "planter":
        rng = np.random.default_rng(5)
        rgb = np.clip(SOIL[None, None, :] + rng.normal(0.0, 6.0, size=(px, px, 1)), 0, 255)
    else:
        rgb = LIME[:px, :px] * BALUSTRADE_VALUE * 0.98
    arr = np.dstack([rgb, np.full((px, px, 1), 255.0)])
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((round(side * SCALE), round(side * SCALE)), Image.LANCZOS)


def build_stone_tile() -> Image.Image:
    """One cell of the coping limestone (tiles in both axes) for kerbs drawn
    as polygons around planting beds."""
    img = Image.fromarray(np.clip(LIME, 0, 255).astype(np.uint8), "RGB")
    return img.resize((CELL * SCALE, CELL * SCALE), Image.LANCZOS)


# ------------------------------------------------------------ prop atlas ---

# name: (source, world width drawn). Texels: PROP_TEXELS per world px.
PROP_TEXELS = 1.5
PROPS = {
    "lamp_post": (DRESSING / "lamp_post.png", 25.0),
    "tree_planter": (DRESSING / "tree_planter.png", 96.0),
    "olive_planter": (SRC / "olive_planter.png", 84.0),
    "notice_board": (SRC / "notice_board.png", 58.0),
    "plaza_fountain": (SRC / "plaza_fountain.png", 128.0),
    "well_stone": (DRESSING / "well_stone.png", 112.0),
    "wall_fountain": (DISTRICTS / "wall_fountain.png", 104.0),
    "market_stall": (SRC / "market_awning_stall.png", 132.0),
    "bench_stone": (DRESSING / "bench_stone.png", 104.0),
    "drain_grate": (SRC / "drain_grate.png", 38.0),
    "pots_cluster": (DRESSING / "pots_cluster.png", 56.0),
    "cypress": (DRESSING / "cypress_tree.png", 36.0),
    "box_shrub": ("clump:box2", 30.0),
    "lavender": ("clump:lav1", 28.0),
}
ATLAS_SIZE = (1024, 384)
ATLAS_PAD = 8


def build_atlas():
    images = {}
    for name, (path, width) in PROPS.items():
        if str(path).startswith("clump:"):
            img = Image.fromarray(np.clip(CLUMPS[str(path)[6:]], 0, 255).astype(np.uint8), "RGBA")
        else:
            img = Image.open(path).convert("RGBA")
        img = img.crop(img.getbbox())
        w = round(width * PROP_TEXELS)
        h = round(img.height * w / img.width)
        images[name] = img.resize((w, h), Image.LANCZOS)
    order = sorted(images, key=lambda n: (-images[n].height, n))
    atlas = Image.new("RGBA", ATLAS_SIZE, (0, 0, 0, 0))
    regions = {}
    x, y, shelf = ATLAS_PAD, ATLAS_PAD, 0
    for name in order:
        img = images[name]
        if x + img.width + ATLAS_PAD > ATLAS_SIZE[0]:
            x, y, shelf = ATLAS_PAD, y + shelf + ATLAS_PAD, 0
        if y + img.height + ATLAS_PAD > ATLAS_SIZE[1]:
            raise SystemExit("plaza prop atlas overflow at " + name)
        atlas.alpha_composite(img, (x, y))
        regions[name] = [x, y, img.width, img.height]
        x += img.width + ATLAS_PAD
        shelf = max(shelf, img.height)
    return atlas, regions


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for mask in range(16):
        build_planter(mask).save(OUT / f"planter34_{mask:02d}.png")
        build_balustrade(mask).save(OUT / f"balustrade34_{mask:02d}.png")
    build_planter(E | W, 1).save(OUT / "planter34_h_b.png")
    build_planter(N | S, 1).save(OUT / "planter34_v_b.png")
    build_balustrade(E | W, True).save(OUT / "balustrade34_pier_h.png")
    build_balustrade(N | S, True).save(OUT / "balustrade34_pier_v.png")
    build_fill("planter").save(OUT / "planter34_fill.png")
    build_fill("balustrade").save(OUT / "balustrade34_fill.png")
    build_stone_tile().save(OUT / "plaza_stone.png")
    # Bed fills: the game's own cared lawn and earth, one repeat each at one
    # texel per world px, so beds load nothing large while streaming.
    lawn = Image.open(ROOT / "assets/world/ground/city_care/v1/cared_lawn.png").convert("RGB")
    lawn.resize((320, 320), Image.LANCZOS).save(OUT / "plaza_lawn.png")
    soil = Image.open(ROOT / "assets/world/ground/ground_dirt_01.png").convert("RGB")
    soil.resize((384, 384), Image.LANCZOS).save(OUT / "plaza_soil.png")
    atlas, regions = build_atlas()
    atlas.save(OUT / "plaza_props.png")
    (OUT / "plaza_props.json").write_text(json.dumps({"texels_per_world_px": PROP_TEXELS, "regions": regions}, indent=1, sort_keys=True) + "\n")
    print("wrote", OUT)
    for name in sorted(regions):
        print(f'\t&"{name}": Rect2({", ".join(str(v) for v in regions[name])}),')


if __name__ == "__main__":
    main()
