#!/usr/bin/env python3
"""Plaza edges and props by maintenance state (2026-10-21 plaza pass 2).

The lead's review of phase 1 found that the same tidy planter rims made
ruined, industrial and military squares read as one ornamental plaza family.
This adds the edge kits and props that let each district's squares show
their actual use and upkeep, processed from the existing kits only (no new
source generation):

  kerb34_*   working districts (industrial, rail): a low worn kerb with no
             planting, soot and oil stains, chipped arrises and dressed joints
  ruin34_*   ruined districts: the planter box neglected, its coping broken
             in places onto rubble, weeds instead of clipped planting
  moss34_*   damp districts (S7): the planter box with mossy coping, wet dark
             soil, unclipped weeds and ivy over a water-stained face

Same contract as build_plaza_kit.py (one piece per connection mask on the
wall kit's canvas, the cell plus 28 px above it, at 2 texels per world px),
so ChunkBlockRenderer draws them through the same kit path. Every break,
stain and weed stays inside the cell's interior columns: a straight run's
neighbour always continues an unbroken arm at the shared cell edge.

The non-cover props (stacked goods, rubble, weeds and a debris decal) go to
a second small atlas, plaza_props_worn.png. None of them is registered for
actor cover, so WorldCover's shared alpha array is not widened by it; the
cover-registered props stay in plaza_props.png, unchanged.

Sources (all existing, processed here; outputs are processed derivatives,
not untouched generation originals):
  assets/world/plazas_v1/planter_wall.png    face strip, ivy (via build_plaza_kit)
  assets/world/dressing_v2/rubble_pile.png   weeds, rubble fragments, prop
  assets/world/dressing_v2/crates_stack.png, sacks_pile.png, barrels_group.png,
                       scaffold_crates.png   stacked goods
  assets/world/ruins_v1/rubble_heap_large.png, floor_debris.png
  assets/world/ground/city_care/v1/damp_moss_soil.png   wet soil and moss
  assets/world/ground/ground_grass_dry_01.png           neglected bed fill

Run:  python3 tools/design/build_plaza_wear_kit.py
It writes only the files listed above (kerb34_*, ruin34_*, moss34_*,
plaza_props_worn.png/.json, plaza_moss_soil.png, plaza_weeds.png); the
phase-1 kit written by build_plaza_kit.py is not touched.
"""

from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_plaza_kit as K  # noqa: E402  (loads the shared sources once)

ROOT = K.ROOT
OUT = K.OUT
RS = K.RS
CELL = K.CELL
N, E, S, W = K.N, K.E, K.S, K.W
world = K.world

# Band thickness, lift (the run's height at a continuing cell edge) and
# coping per style; PlazaEdgeKit.STYLE_THICK / STYLE_LIFT / STYLE_COPING
# carry the same numbers for the quadrant fills.
K.STYLES.update({
    "kerb": {"thick": 26, "lift": 8, "coping": 0},
    "ruin": {"thick": 30, "lift": 6, "coping": 0},
    "moss": {"thick": 40, "lift": 16, "coping": 5},
})

DRESSING = ROOT / "assets/world/dressing_v2"
RUINS = ROOT / "assets/world/ruins_v1"
RUBBLE = np.asarray(Image.open(DRESSING / "rubble_pile.png").convert("RGBA"), dtype=np.float64)
MOSS_SOIL = np.asarray(Image.open(ROOT / "assets/world/ground/city_care/v1/damp_moss_soil.png").convert("RGB").resize((320, 320), Image.LANCZOS), dtype=np.float64)

# Working stone: the coping limestone darkened and pulled to a cool grey,
# so a long kerb stays below the actors and never reads as a pale band.
KERB_VALUE = 0.62
KERB_GREY = 0.45
def _ruin_ground() -> np.ndarray:
    """Dry packed earth half taken by weeds: the plaza soil with the dry
    grass ground over it in soft patches (one tiling cell)."""
    earth = np.asarray(Image.open(ROOT / "assets/world/ground/ground_dirt_01.png").convert("RGB").resize((256, 256), Image.LANCZOS), dtype=np.float64)
    grass = np.asarray(Image.open(ROOT / "assets/world/ground/ground_grass_dry_01.png").convert("RGB").resize((256, 256), Image.LANCZOS), dtype=np.float64)
    rng = np.random.default_rng(77)
    yy, xx = np.mgrid[0:256, 0:256] / 256.0
    field = np.zeros((256, 256))
    for freq in (2, 3, 5, 7):
        fx, fy = rng.integers(1, freq + 1, size=2)
        field += np.sin(2.0 * np.pi * (fx * xx + fy * yy) + rng.uniform(0, 6.3)) / freq
    # Mostly bare, dry earth; the weeds take the hollows only, and dry.
    cover = np.clip((field - 0.3) * 1.6, 0.0, 1.0)[:, :, None]
    dry = grass * np.array([1.04, 0.98, 0.76])[None, None, :] * 0.84
    return _cool(earth * 1.18 * (1.0 - cover) + dry * cover, 0.18)


# Moss and wet soil, from the damp care ground.
MOSS = MOSS_SOIL.reshape(-1, 3).mean(axis=0)


def _smooth_noise(seed: int, shape, blur: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    raw = rng.normal(0.0, 1.0, size=shape)
    img = Image.fromarray(np.clip(raw * 40 + 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    out = np.asarray(img, dtype=np.float64)
    out -= out.mean()
    return out / max(1e-6, out.std())


def _keyed(region: np.ndarray, green: bool) -> np.ndarray:
    """Keep only the weeds (green) or only the stones of a rubble crop."""
    part = region.copy()
    rgb = part[:, :, :3]
    is_green = (rgb[:, :, 1] > rgb[:, :, 0] * 1.04) & (rgb[:, :, 1] > rgb[:, :, 2] * 1.12)
    keep = is_green if green else ~is_green
    part[:, :, 3] = np.where(keep, part[:, :, 3], 0.0)
    img = Image.fromarray(np.clip(part, 0, 255).astype(np.uint8), "RGBA")
    a = img.split()[3].filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    img.putalpha(a.filter(ImageFilter.GaussianBlur(0.5)))
    out = np.asarray(img, dtype=np.float64)
    ys, xs = np.where(out[:, :, 3] > 8)
    if len(ys) == 0:
        return out
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# Weed tufts of the rubble pile (keyed off the stones) and small fragments.
WEEDS = [
    _keyed(RUBBLE[48:92, 40:100], True),
    _keyed(RUBBLE[40:96, 336:410], True),
    _keyed(RUBBLE[120:184, 272:368], True),
]
CHIPS = [
    _keyed(RUBBLE[56:104, 400:470], False),
    _keyed(RUBBLE[88:140, 440:505], False),
]


def _cool(rgb: np.ndarray, grey: float) -> np.ndarray:
    lum = rgb.mean(axis=-1, keepdims=True)
    return rgb * (1.0 - grey) + lum * grey


RUIN_GROUND = _ruin_ground()


def weed(piece, index: int, cx: float, base_plan_y: float, height: float, flip: bool = False, dry: bool = False) -> None:
    src = WEEDS[index % len(WEEDS)]
    img = K.scaled(src, world(height) / src.shape[0], flip)
    # Unclipped growth, a little duller than the clipped planting; a ruined
    # bed's weeds are dry, a damp bed's lush.
    img[:, :, :3] = _cool(img[:, :, :3], 0.12) * 0.92
    if dry:
        img[:, :, :3] *= np.array([1.06, 1.0, 0.74])[None, None, :]
    half = img.shape[1] / 2.0
    left = int(round(np.clip(world(cx) - half, 0, piece.w - img.shape[1])))
    K.over(piece.rgba, img, left, piece.lifted(base_plan_y) - img.shape[0] + world(2.0))


def chip(piece, index: int, cx: float, base_plan_y: float, width: float, flip: bool = False) -> None:
    src = CHIPS[index % len(CHIPS)]
    img = K.scaled(src, world(width) / src.shape[1], flip)
    img[:, :, :3] = _cool(img[:, :, :3], 0.30) * 0.90
    half = img.shape[1] / 2.0
    left = int(round(np.clip(world(cx) - half, 0, piece.w - img.shape[1])))
    K.over(piece.rgba, img, left, piece.lifted(base_plan_y) - img.shape[0] + world(3.0))


def _arms(mask: int):
    """Interior stretches (plan px) of each arm where breaks and weeds may go:
    (axis, lo, hi, across) with axis 'x' for E/W arms, 'y' for N/S arms."""
    c = CELL / 2.0
    out = []
    if mask & (E | W) == (E | W):
        out.append(("x", 8.0, 56.0, c))
    else:
        if mask & E:
            out.append(("x", c, 56.0, c))
        if mask & W:
            out.append(("x", 8.0, c, c))
    if mask & (N | S) == (N | S):
        out.append(("y", 8.0, 56.0, c))
    else:
        if mask & S:
            out.append(("y", c, 56.0, c))
        if mask & N:
            out.append(("y", 12.0, c, c))
    if not out:
        out.append(("x", 16.0, 48.0, c))
    return out


def stains(piece, top: np.ndarray, seed: int, strength: float) -> None:
    """Soot and oil: soft dark blotches over the top, a few sharper drips."""
    blot = _smooth_noise(seed, (piece.h, piece.w), world(3.0))
    dark = np.clip(blot - 1.3, 0.0, 1.0)
    piece.rgba[top, :3] *= (1.0 - strength * dark[top])[:, None]


def chipped_arris(piece, top: np.ndarray, seed: int) -> None:
    """Small shaded bites along the top's outer lips (worn arrises)."""
    rng = np.random.default_rng(seed)
    above = np.zeros_like(top)
    above[world(1.0):] = top[:-world(1.0)]
    below = np.zeros_like(top)
    below[:-world(1.0)] = top[world(1.0):]
    lip = top & (~above | ~below)
    ys, xs = np.where(lip)
    if len(ys) == 0:
        return
    for _ in range(4):
        i = rng.integers(0, len(ys))
        cy, cx = ys[i], xs[i]
        # Keep bites off the cell's outer columns (neighbours continue there).
        if cx < world(6) or cx > piece.w - world(6):
            continue
        r = world(rng.uniform(0.8, 1.6))
        bite = ((piece.yy - cy) ** 2 + ((piece.xx - cx) * 0.8) ** 2) <= r * r
        bite &= top
        piece.rgba[bite, :3] *= 0.86


def build_kerb(mask: int, variant: int = 0) -> Image.Image:
    piece = K.Piece("kerb", mask)
    for x0, x1, plan_y in piece.face_rects():
        K.stone_face(piece, x0, x1, plan_y, shade=0.78)
    faces = piece.rgba[:, :, 3] > 0
    top = K.build_top(piece, False)
    piece.rgba[top, :3] *= KERB_VALUE
    rgb = piece.rgba[:, :, :3]
    piece.rgba[:, :, :3] = np.where((top | faces)[:, :, None], _cool(rgb, KERB_GREY), rgb)
    stains(piece, top, 101 + mask * 7 + variant, 0.16)
    chipped_arris(piece, top, 211 + mask * 13 + variant)
    # Grime where the kerb meets the yard: the face darkens to its foot.
    face_only = faces & ~top
    rows = piece.yy[face_only]
    if rows.size:
        t = (rows - rows.min()) / max(1, rows.max() - rows.min())
        piece.rgba[face_only, :3] *= (0.94 - 0.16 * t)[:, None]
    K.contact_shadow(piece)
    return K.reduce(piece)


def _soil(piece, inner: np.ndarray, source: np.ndarray, gain: float, seed: int) -> None:
    tex = source[piece.yy % source.shape[0], piece.xx % source.shape[1]]
    shift = _smooth_noise(seed, (piece.h, piece.w), world(2.0))[:, :, None] * 6.0
    piece.rgba[inner, :3] = np.clip(tex[inner] * gain + shift[inner], 0, 255)


def _inner(piece) -> np.ndarray:
    """The soil top of a planter-geometry piece (inside its coping)."""
    pad = world(K.PAD)
    virtual_p = piece.top_mask(extend=K.PAD, pad=pad)
    crop = (slice(pad, pad + piece.h), slice(pad, pad + piece.w))
    return K.erode(virtual_p, world(piece.coping))[crop] & piece.top_mask()


# ------------------------------------------------------------ ruin edge ---
# A ruined square's ring is no planter at all: the stump of a tumbled wall.
# A low base course of loose dressed blocks (some gone, the rubble bed
# showing) with here and there a stone of the next course still on it, and
# fallen blocks, chips and dry weeds at its foot (concept plate 04). Cell
# edges are always block joints and every block on a cell edge where the run
# continues is base course at RUIN_EDGE_LIFT, so any variant meets any
# neighbour; all damage lives inside the cell.

RUIN_THICK = 30.0
RUIN_EDGE_LIFT = 6.0
RUIN_BOUND = 7.0
# Weathered stone: under the parapet's value, cool, never a pale band.
RUIN_VALUE = 0.70
RUIN_GREY = 0.28
RUIN_BASE = (0.0, 3.0, 4.0, 5.0, 6.0, 7.0)
RUIN_BASE_P = (0.16, 0.12, 0.18, 0.2, 0.2, 0.14)
assert K.STYLES["ruin"] == {"thick": RUIN_THICK, "lift": RUIN_EDGE_LIFT, "coping": 0}
# Per-cell variants (PlazaEdgeKit picks one per global cell by hash):
# straight runs carry most of a ring, so they get the most.
VARIANTS = {E | W: 4, N | S: 4}


def variant_count(mask: int) -> int:
    return VARIANTS.get(mask, 2)


def _row(v: float) -> int:
    return world(v + K.HEADROOM)


def _tileable(path: Path, size: int) -> np.ndarray:
    """A ground source resized to one cell (`size` texels) and cross-faded
    across its own wrap, so a piece's soil continues into its neighbour."""
    img = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
    a = np.asarray(img, dtype=np.float64)
    b = np.roll(a, (size // 2, size // 2), axis=(0, 1))
    ramp = np.abs(np.linspace(-1.0, 1.0, size))
    w = np.clip(np.maximum(ramp[:, None], ramp[None, :]) * 1.6 - 0.6, 0.0, 1.0)[:, :, None]
    return a * (1.0 - w) + b * w


RUIN_BED = _cool(_tileable(ROOT / "assets/world/ground/ground_dirt_01.png", CELL * RS) * 1.15, 0.30)
MOSS_SOIL_T = _tileable(ROOT / "assets/world/ground/city_care/v1/damp_moss_soil.png", CELL * RS)
MUD_T = _tileable(ROOT / "assets/world/ground/ground_mud_wet_01.png", CELL * RS)


def ruin_block(piece, x0: float, y0: float, x1: float, y1: float, h: float, tone: float, seed: int, floor_h: float = 0.0, split: tuple = ()) -> None:
    """One loose block: its top lifted by h, its south face down to the
    surface it stands on (the ground, or the base course at floor_h)."""
    c0, c1 = world(x0), world(x1)
    if c1 <= c0 or h <= floor_h:
        return
    r0, r1, ground = max(0, _row(y0 - h)), _row(y1 - h), _row(y1 - floor_h)
    cols = np.arange(c0, c1)
    if r1 > r0:
        rows = np.arange(r0, r1)
        lime = K.LIME[rows[:, None] % K.LIME.shape[0], cols[None, :] % K.LIME.shape[1]].copy()
        lime *= RUIN_VALUE * tone
        blot = _smooth_noise(seed, (r1 - r0, c1 - c0), world(1.4))
        lime *= (1.0 - 0.08 * np.clip(blot, 0.0, 2.0))[:, :, None]
        lip = (rows - r0) < world(0.8)
        lime[lip] = lime[lip] * 1.05 + 3.0
        lime[:, :world(0.5)] *= 0.78
        if split:
            # Two stones across the band: one joint along the run.
            axis, at = split
            if axis == "x":
                j = _row(at - h) - r0
                lime[max(0, j):max(0, j + world(0.5))] *= 0.74
            else:
                j = world(at) - c0
                lime[:, max(0, j):max(0, j + world(0.5))] *= 0.74
        piece.rgba[r0:r1, c0:c1, :3] = _cool(lime, RUIN_GREY)
        piece.rgba[r0:r1, c0:c1, 3] = 255.0
    if ground > r1:
        rows = np.arange(r1, ground)
        strip = K.FACE_STRIP
        v = np.clip(((rows - r1) / float(world(16.0)) * (strip.shape[0] - 1)).astype(int) + 6, 0, strip.shape[0] - 1)
        face = strip[v][:, cols % strip.shape[1], :3].copy()
        t = ((rows - r1) / max(1.0, float(ground - r1)))[:, None, None]
        face *= 0.72 * tone * (0.94 - 0.14 * t)
        if floor_h <= 0.0:
            face[(ground - rows) < world(1.2)] *= 0.78
        face[:, :world(0.5)] *= 0.76
        piece.rgba[r1:ground, c0:c1, :3] = _cool(face, RUIN_GREY + 0.06)
        piece.rgba[r1:ground, c0:c1, 3] = 255.0


def _partition(rng, a: float, b: float, bound_lo: bool, bound_hi: bool, lo: float = 10.0, hi: float = 19.0) -> list:
    """Blocks [(a0, a1, kind)] along one span; kind 'edge' on a continuing
    cell edge (fixed lift), else 'loose'."""
    out = []
    if bound_lo:
        out.append((a, a + RUIN_BOUND, "edge"))
        a += RUIN_BOUND
    tail = []
    if bound_hi:
        tail = [(b - RUIN_BOUND, b, "edge")]
        b -= RUIN_BOUND
    at = a
    while b - at > 0.01:
        length = rng.uniform(lo, hi)
        if b - (at + length) < 6.0:
            length = b - at
        out.append((at, at + length, "loose"))
        at += length
    return out + tail


def _ruin_layout(mask: int, rng, t0: float, t1: float) -> tuple:
    """(base, upper) blocks of a ruin piece as (x0, y0, x1, y1, h, axis);
    upper stones stand on a base block (their faces stop at its top)."""
    base, upper = [], []
    spans = []
    if mask & (E | W) or not mask & (N | S):
        spans.append(("x", 0.0 if mask & W else t0, CELL if mask & E else t1, bool(mask & W), bool(mask & E)))
        if mask & N:
            spans.append(("y", 0.0, t0, True, False))
        if mask & S:
            spans.append(("y", t1, CELL, False, True))
    else:
        spans.append(("y", 0.0 if mask & N else t0, CELL if mask & S else t1, bool(mask & N), bool(mask & S)))
    for axis, a, b, lo, hi in spans:
        parts = _partition(rng, a, b, lo, hi)
        loose = [k for k, p in enumerate(parts) if p[2] == "loose"]
        hs = list(rng.choice(RUIN_BASE, size=len(parts), p=RUIN_BASE_P))
        # A longer stretch always shows one lost block.
        if b - a >= 28.0 and len(loose) >= 2 and min(hs[k] for k in loose) > 0.0:
            hs[loose[int(rng.integers(0, len(loose)))]] = 0.0
        for k, (p0, p1, kind) in enumerate(parts):
            h = RUIN_EDGE_LIFT if kind == "edge" else float(hs[k])
            j0 = 0.0 if kind == "edge" else rng.uniform(0.0, 2.0)
            j1 = 0.0 if kind == "edge" else rng.uniform(0.0, 2.0)
            if axis == "x":
                rect = (p0, t0 + j0, p1, t1 - j1)
            else:
                rect = (t0 + j0, p0, t1 - j1, p1)
            split = ()
            if kind == "loose" and h > 0.0 and rng.random() < 0.5:
                split = (axis, t0 + (t1 - t0) * rng.uniform(0.4, 0.62))
            base.append(rect + (h, axis, split))
            # A stone of the next course left standing on some loose blocks.
            if kind != "loose" or h <= 0.0 or rng.random() > 0.45:
                continue
            top = h + rng.uniform(4.0, 9.0)
            length = (p1 - p0) * rng.uniform(0.55, 0.95)
            s0 = p0 + rng.uniform(0.0, (p1 - p0) - length)
            if axis == "x":
                back = rng.random() < 0.6
                y1 = (t0 + t1) * 0.5 + rng.uniform(-2.0, 3.0) if back else t1 - j1 - rng.uniform(0.0, 2.0)
                if mask & N:
                    top = min(top, t0 + RUIN_EDGE_LIFT)
                upper.append((s0, t0 + j0 + rng.uniform(0.0, 2.0), s0 + length, y1, top, axis, h))
            else:
                if mask & N:
                    top = min(top, s0 + RUIN_EDGE_LIFT)
                side = rng.random() < 0.5
                x0 = t0 + j0 + (0.0 if side else rng.uniform(4.0, 10.0))
                x1 = t1 - j1 - (rng.uniform(4.0, 10.0) if side else 0.0)
                upper.append((x0, s0, x1, s0 + length, top, axis, h))
    return base, upper


def _gap_chip(piece, k: int, cx: float, base_plan_y: float, width: float, flip: bool) -> None:
    src = CHIPS[k % len(CHIPS)]
    img = K.scaled(src, world(width) / src.shape[1], flip)
    img[:, :, :3] = _cool(img[:, :, :3], 0.34) * 0.84
    half = img.shape[1] / 2.0
    left = int(round(np.clip(world(cx) - half, world(3.0), piece.w - img.shape[1] - world(3.0))))
    K.over(piece.rgba, img, left, _row(base_plan_y) - img.shape[0] + world(2.0))


def _tuft(piece, k: int, cx: float, base_row: int, height: float, flip: bool, dry: bool, ceiling: int = 0) -> None:
    src = WEEDS[k % len(WEEDS)]
    height = min(height, (base_row - ceiling) / RS) if ceiling > 0 else height
    if height < 4.0:
        return
    img = K.scaled(src, world(height) / src.shape[0], flip)
    img[:, :, :3] = _cool(img[:, :, :3], 0.12) * 0.92
    if dry:
        img[:, :, :3] *= np.array([1.06, 1.0, 0.74])[None, None, :]
    half = img.shape[1] / 2.0
    left = int(round(np.clip(world(cx) - half, world(2.0), piece.w - img.shape[1] - world(2.0))))
    K.over(piece.rgba, img, left, base_row - img.shape[0] + world(1.5))


def build_ruin(mask: int, variant: int = 0) -> Image.Image:
    piece = K.Piece("ruin", mask)
    rng = np.random.default_rng(9001 + mask * 97 + variant * 7919)
    t0, t1 = piece.t0, piece.t1
    # The rubble bed under the band (seen through the gaps).
    for x0, y0, x1, y1 in piece.plan_rects():
        r0, r1, c0, c1 = _row(y0), _row(y1), world(x0), world(x1)
        rows, cols = np.arange(r0, r1), np.arange(c0, c1)
        piece.rgba[r0:r1, c0:c1, :3] = RUIN_BED[rows[:, None] % RUIN_BED.shape[0], cols[None, :] % RUIN_BED.shape[1]]
        piece.rgba[r0:r1, c0:c1, 3] = 255.0
    base, upper = _ruin_layout(mask, rng, t0, t1)
    # Painter's order: by south edge, base course first, then what stands on it.
    gaps = []
    for n, (x0, y0, x1, y1, h, axis, split) in enumerate(sorted(base, key=lambda b: (b[3], b[0]))):
        if h <= 0.0:
            gaps.append((x0, y0, x1, y1, axis))
            continue
        ruin_block(piece, x0, y0, x1, y1, h, rng.uniform(0.92, 1.05), 70 + mask * 13 + variant * 5 + n, 0.0, split)
    for n, (x0, y0, x1, y1, h, axis, floor_h) in enumerate(sorted(upper, key=lambda b: (b[3], b[0]))):
        ruin_block(piece, x0, y0, x1, y1, h, rng.uniform(0.94, 1.06), 300 + mask * 11 + variant * 7 + n, floor_h)
    ceiling = _row(-RUIN_EDGE_LIFT) if mask & N else 0
    # Rubble and a weed where blocks are gone.
    for k, (x0, y0, x1, y1, axis) in enumerate(gaps):
        if axis == "x":
            _gap_chip(piece, k + variant, (x0 + x1) * 0.5, t1 - 1.0, rng.uniform(9.0, 12.0), bool(k % 2))
            if rng.random() < 0.7:
                _tuft(piece, k + mask, (x0 + x1) * 0.5 + rng.uniform(-2.0, 2.0), _row(t1 - 4.0), rng.uniform(10.0, 15.0), bool((k + variant) % 2), True, ceiling)
        else:
            _gap_chip(piece, k + variant, CELL / 2.0, y1 - 1.0, rng.uniform(9.0, 12.0), bool(k % 2))
            if rng.random() < 0.5:
                _tuft(piece, k + mask + 1, CELL / 2.0 + rng.uniform(-4.0, 4.0), _row(y1 - 2.0), rng.uniform(9.0, 13.0), bool(k % 2), True, ceiling)
    # Fallen blocks and chips at the foot of the band (inside the cell).
    for f in range(int(rng.integers(1, 4))):
        w, d, h = rng.uniform(6.0, 10.0), rng.uniform(4.0, 6.5), rng.uniform(2.5, 4.0)
        west_zone = (3.0, t0 - 2.0 - w)
        east_zone = (t1 + 2.0, CELL - 3.0 - w)
        if mask & (E | W) or not mask & (N | S):
            south = rng.random() < 0.7
            if south and mask & S:
                south = False
            if not south and mask & N:
                continue
            if mask & (N | S):
                zone = west_zone if rng.random() < 0.5 else east_zone
                x = rng.uniform(*zone)
            else:
                x = rng.uniform(3.0, CELL - 3.0 - w)
            y = rng.uniform(t1 + 3.0, t1 + 9.0) if south else rng.uniform(5.0, t0 - 7.0)
        else:
            x = rng.uniform(*(east_zone if rng.random() < 0.6 else west_zone))
            y = rng.uniform(10.0, CELL - 12.0)
        ruin_block(piece, x, y, x + w, y + d, h, rng.uniform(0.88, 1.0), 500 + mask * 7 + f + variant * 3)
        if rng.random() < 0.6:
            _gap_chip(piece, f + mask, min(x + w + 3.0, CELL - 6.0), y + d + 1.0, rng.uniform(7.0, 10.0), bool(f % 2))
    # A dry tuft or two along the foot.
    for k in range(int(rng.integers(1, 3))):
        if mask & (E | W) or not mask & (N | S):
            cx = rng.uniform(8.0, CELL - 8.0)
            if mask & S and t0 - 4.0 < cx < t1 + 4.0:
                continue
            _tuft(piece, k + 2 * mask + variant, cx, _row(t1 + 1.5), rng.uniform(9.0, 14.0), bool(k % 2), True, ceiling)
        else:
            cx = t1 + 2.0 if rng.random() < 0.5 else t0 - 2.0
            _tuft(piece, k + mask + variant, cx, _row(rng.uniform(16.0, CELL - 6.0)), rng.uniform(9.0, 13.0), bool(k % 2), True, ceiling)
    if mask & S:
        # The south neighbour owns everything below its lifted north edge.
        piece.rgba[_row(CELL - RUIN_EDGE_LIFT):, world(t0):world(t1), 3] = 0.0
    K.contact_shadow(piece)
    return K.reduce(piece)


# ------------------------------------------------------------ damp edge ---
# A damp S7 square keeps its planter, neglected: the coping in separate
# stones under moss (some gone, the bed spilling through), wet dark soil
# with rank unclipped growth spilling over the front, ivy and water stains.

MOSS_DARK = np.array([62.0, 72.0, 44.0])
MOSS_LIGHT = np.array([104.0, 116.0, 66.0])


def _stone_ids(piece, rim: np.ndarray, rng) -> tuple:
    """Coping stones along the rim: per rim pixel, the stone it belongs to
    (cell edges are always joints) and whether it sits on a joint."""
    plan_x = piece.xx / RS
    plan_y = piece.yy / RS - K.HEADROOM + piece.lift
    vertical = (plan_x >= piece.t0) & (plan_x <= piece.t1) & ((plan_y < piece.t0) | (plan_y > piece.t1))
    along = np.where(vertical, plan_y, plan_x)
    side = np.where(vertical, plan_x > CELL / 2.0, plan_y > CELL / 2.0)
    cuts = [0.0]
    at = 0.0
    while True:
        at += rng.uniform(9.0, 15.0)
        if at > CELL - 6.0:
            break
        cuts.append(at)
    cuts.append(CELL)
    cuts = np.array(cuts)
    ids = np.searchsorted(cuts, along, side="right") * 4 + side.astype(int) * 2 + vertical.astype(int)
    near = np.min(np.abs(along[:, :, None] - cuts[None, None, :]), axis=2)
    joint = rim & (near < 0.45)
    return ids, joint


def build_moss(mask: int, variant: int = 0) -> Image.Image:
    piece = K.Piece("moss", mask)
    rng = np.random.default_rng(12011 + mask * 89 + variant * 6151)
    for x0, x1, plan_y in piece.face_rects():
        K.stone_face(piece, x0, x1, plan_y, shade=0.80)
    faces = piece.rgba[:, :, 3] > 0
    top = K.build_top(piece, True)
    inner = _inner(piece)
    rim = top & ~inner
    # Wet bed: moss soil with darker mud hollows.
    mud = _smooth_noise(41 + mask + variant * 3, (piece.h, piece.w), world(2.5))
    soil = MOSS_SOIL_T[piece.yy % MOSS_SOIL_T.shape[0], piece.xx % MOSS_SOIL_T.shape[1]] * 0.80
    wet = MUD_T[piece.yy % MUD_T.shape[0], piece.xx % MUD_T.shape[1]] * 0.70
    mix = np.clip((mud - 0.3) * 0.6, 0.0, 0.6)[:, :, None]
    piece.rgba[inner, :3] = (soil * (1.0 - mix) + wet * mix)[inner]
    # Coping: wet stone (no pale arris), stone by stone under moss.
    piece.rgba[rim, :3] = _cool(piece.rgba[rim, :3], 0.18) * 0.80
    ids, joint = _stone_ids(piece, rim, rng)
    blot = _smooth_noise(601 + mask * 3 + variant * 11, (piece.h, piece.w), world(1.0))
    edge_cells = (piece.xx < world(1.0)) | (piece.xx >= piece.w - world(1.0))
    moss_rgb = MOSS_DARK[None, None, :] * (1.0 - np.clip(blot * 0.4 + 0.5, 0, 1))[:, :, None] + MOSS_LIGHT[None, None, :] * np.clip(blot * 0.4 + 0.5, 0, 1)[:, :, None]
    for sid in np.unique(ids[rim]):
        stone = rim & (ids == sid)
        amount = rng.uniform(0.45, 0.95)
        gone = rng.random() < 0.22 and not stone[:, :world(2.0)].any() and not stone[:, -world(2.0):].any()
        if gone:
            # A lost coping stone: the bed spills through at soil level.
            piece.rgba[stone, :3] = (soil * 0.9)[stone] * 0.85 + moss_rgb[stone] * 0.15
            continue
        cover = np.clip(amount + 0.35 * blot, 0.0, 1.0)
        piece.rgba[stone, :3] = piece.rgba[stone, :3] * (1.0 - cover[stone, None]) + moss_rgb[stone] * cover[stone, None]
        piece.rgba[stone, :3] *= rng.uniform(0.92, 1.04)
    piece.rgba[joint, :3] *= 0.70
    # Water stain and moss creeping down the face.
    face_only = faces & ~top
    rows = piece.yy[face_only]
    if rows.size:
        t = ((rows - rows.min()) / max(1, rows.max() - rows.min()))[:, None]
        base = piece.rgba[face_only, :3]
        creep = np.clip(blot[face_only] - 0.4, 0.0, 1.0)[:, None] * (1.0 - t)
        stained = base * (0.90 - 0.24 * t) + MOSS_DARK[None, :] * 0.30 * t
        piece.rgba[face_only, :3] = stained * (1.0 - creep) + MOSS_DARK[None, :] * creep
    # Rank growth: tufts in the bed, some leaning over the front coping.
    c = CELL / 2.0
    ceiling = piece.lifted(0.0) if mask & N else 0
    spots = []
    if mask == (E | W):
        spots = [(rng.uniform(8.0, 26.0), piece.t1 - 3.0), (rng.uniform(36.0, 56.0), piece.t1 + 1.0)]
    elif mask == (N | S):
        spots = [(c + rng.uniform(-5.0, 5.0), rng.uniform(18.0, 34.0)), (c + rng.uniform(-5.0, 5.0), rng.uniform(44.0, 58.0))]
    else:
        spots = [(c + rng.uniform(-10.0, 10.0), piece.t1 - 2.0)]
    if rng.random() < 0.5:
        spots.append((c + rng.uniform(-14.0, 14.0), piece.t1 + 1.5))
    for k, (cx, base) in enumerate(spots):
        _tuft(piece, k + mask + variant, cx, piece.lifted(base), rng.uniform(14.0, 21.0), bool((mask + k + variant) % 2), False, ceiling)
    if rng.random() < 0.6 and piece.face_rects():
        x0, x1, plan_y = piece.face_rects()[int(rng.integers(0, len(piece.face_rects())))]
        K.ivy(piece, float(np.clip(rng.uniform(x0, max(x0, x1 - 20.0)), 2.0, CELL - 24.0)), plan_y, bool(variant % 2))
    K.contact_shadow(piece)
    return K.reduce(piece)


def build_fill(style: str) -> Image.Image:
    cfg = K.STYLES[style]
    side = (CELL - cfg["thick"]) / 2.0 + cfg["coping"]
    px = world(side)
    if style == "kerb":
        rgb = _cool(K.LIME[:px, :px] * KERB_VALUE, KERB_GREY)
    elif style == "moss":
        rgb = MOSS_SOIL_T[:px, :px] * 0.80
    else:
        # A ruined double ring's quadrant: a low mass of tumbled blocks at
        # the edge lift, dark joints between them.
        rng = np.random.default_rng(77)
        lime = K.LIME[:px, :px] * RUIN_VALUE
        yy, xx = np.mgrid[0:px, 0:px]
        cut_x, cut_y = rng.uniform(0.3, 0.7) * px, rng.uniform(0.3, 0.7) * px
        joint = (np.abs(xx - cut_x) < world(0.5)) | (np.abs(yy - cut_y) < world(0.5))
        lime[joint] *= 0.62
        rgb = _cool(lime, RUIN_GREY)
    arr = np.dstack([rgb, np.full((px, px, 1), 255.0)])
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((round(side * K.SCALE), round(side * K.SCALE)), Image.LANCZOS)


# ------------------------------------------------------------ worn atlas ---

PROP_TEXELS = 1.5
WORN_PROPS = {
    "crates_stack": (DRESSING / "crates_stack.png", 60.0),
    "sacks_pile": (DRESSING / "sacks_pile.png", 54.0),
    "barrels_group": (DRESSING / "barrels_group.png", 46.0),
    "scaffold_crates": (DRESSING / "scaffold_crates.png", 80.0),
    "handcart": (DRESSING / "handcart.png", 76.0),
    "rubble_pile": (DRESSING / "rubble_pile.png", 70.0),
    "rubble_heap": (RUINS / "rubble_heap_large.png", 84.0),
    "floor_debris": (RUINS / "floor_debris.png", 60.0),
    "weeds_a": ("weed:0", 26.0),
    "weeds_b": ("weed:1", 30.0),
    "weeds_c": ("weed:2", 30.0),
}
WORN_ATLAS_SIZE = (512, 192)


def build_worn_atlas():
    images = {}
    for name, (path, width) in WORN_PROPS.items():
        if str(path).startswith("weed:"):
            img = Image.fromarray(np.clip(WEEDS[int(str(path)[5:])], 0, 255).astype(np.uint8), "RGBA")
        else:
            img = Image.open(path).convert("RGBA")
        img = img.crop(img.getbbox())
        w = round(width * PROP_TEXELS)
        h = round(img.height * w / img.width)
        images[name] = img.resize((w, h), Image.LANCZOS)
    order = sorted(images, key=lambda n: (-images[n].height, n))
    atlas = Image.new("RGBA", WORN_ATLAS_SIZE, (0, 0, 0, 0))
    regions = {}
    x, y, shelf = K.ATLAS_PAD, K.ATLAS_PAD, 0
    for name in order:
        img = images[name]
        if x + img.width + K.ATLAS_PAD > WORN_ATLAS_SIZE[0]:
            x, y, shelf = K.ATLAS_PAD, y + shelf + K.ATLAS_PAD, 0
        if y + img.height + K.ATLAS_PAD > WORN_ATLAS_SIZE[1]:
            raise SystemExit("worn prop atlas overflow at " + name)
        atlas.alpha_composite(img, (x, y))
        regions[name] = [x, y, img.width, img.height]
        x += img.width + K.ATLAS_PAD
        shelf = max(shelf, img.height)
    return atlas, regions


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for mask in range(16):
        build_kerb(mask).save(OUT / f"kerb34_{mask:02d}.png")
    build_kerb(E | W, 1).save(OUT / "kerb34_h_b.png")
    build_kerb(N | S, 1).save(OUT / "kerb34_v_b.png")
    build_fill("kerb").save(OUT / "kerb34_fill.png")
    # Ruined and damp edges: hash-picked variants per mask (ruin34_MM_V).
    for style, build in (("ruin", build_ruin), ("moss", build_moss)):
        for mask in range(16):
            for v in range(variant_count(mask)):
                build(mask, v).save(OUT / f"{style}34_{mask:02d}_{v}.png")
        build_fill(style).save(OUT / f"{style}34_fill.png")
    # Bed fills (one repeat each at one texel per world px).
    Image.fromarray(np.clip(MOSS_SOIL, 0, 255).astype(np.uint8), "RGB").save(OUT / "plaza_moss_soil.png")
    Image.open(ROOT / "assets/world/ground/ground_grass_dry_01.png").convert("RGB").resize((320, 320), Image.LANCZOS).save(OUT / "plaza_weeds.png")
    atlas, regions = build_worn_atlas()
    atlas.save(OUT / "plaza_props_worn.png")
    (OUT / "plaza_props_worn.json").write_text(json.dumps({"texels_per_world_px": PROP_TEXELS, "regions": regions}, indent=1, sort_keys=True) + "\n")
    print("wrote", OUT)
    for name in sorted(regions):
        print(f'\t&"{name}": Rect2({", ".join(str(v) for v in regions[name])}),')
    print("variants:", {m: variant_count(m) for m in range(16)})


if __name__ == "__main__":
    main()
