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

K.STYLES.update({
    "kerb": {"thick": 26, "lift": 8, "coping": 0},
    "ruin": {"thick": 40, "lift": 14, "coping": 5},
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


def broken_coping(piece, top: np.ndarray, inner: np.ndarray, seed: int, gaps: int) -> list:
    """Break the coping and the face's upper course over short stretches of
    the arms: the band drops onto rubble there. Returns the gap centres."""
    rng = np.random.default_rng(seed)
    centres = []
    arms = _arms(piece.mask)
    for k in range(gaps):
        axis, lo, hi, _ = arms[k % len(arms)]
        # Only a front (south) coping and its face crumble: the break reads
        # at the edge the camera sees, not as holes through the band.
        if axis != "x" or hi - lo < 18.0 or piece.mask & S:
            continue
        at = rng.uniform(lo + 7.0, hi - 7.0)
        half = rng.uniform(5.0, 8.5)
        jag = _smooth_noise(seed + k * 17, (piece.h, piece.w), world(1.2))
        if axis == "x":
            along = piece.xx / RS
        else:
            along = piece.yy / RS - K.HEADROOM + piece.lift
        region = np.abs(along - at) + jag * 1.6 < half
        broken = region & (piece.rgba[:, :, 3] > 0)
        # Coping and upper course gone: the top drops to the rubble fill,
        # the face loses its upper rows (jagged), leaving a low stump.
        south_rim = top & ~inner & (piece.yy > piece.lifted(piece.t1 - piece.coping - 1.0))
        rim_part = broken & south_rim
        piece.rgba[rim_part, :3] = np.clip(RUIN_GROUND[piece.yy[rim_part] % 256, piece.xx[rim_part] % 256], 0, 255)
        face_part = broken & ~top
        if face_part.any():
            ys = piece.yy[face_part]
            cut = ys < (ys.min() + world(piece.lift * 0.55)) + jag[face_part] * world(1.5)
            idx = np.where(face_part)
            piece.rgba[idx[0][cut], idx[1][cut], 3] = 0.0
        centres.append((axis, at))
    return centres


def build_ruin(mask: int, variant: int = 0) -> Image.Image:
    piece = K.Piece("ruin", mask)
    for x0, x1, plan_y in piece.face_rects():
        K.stone_face(piece, x0, x1, plan_y, shade=0.86)
    top = K.build_top(piece, True)
    inner = _inner(piece)
    # Dry, weedy soil, never the clipped bed's dark loam.
    _soil(piece, inner, RUIN_GROUND, 1.0, 31 + mask)
    rgb = piece.rgba[:, :, :3]
    piece.rgba[:, :, :3] = np.where(top[:, :, None] & ~inner[:, :, None], _cool(rgb, 0.25) * 0.92, rgb)
    chipped_arris(piece, top & ~inner, 307 + mask * 11 + variant)
    gaps = 1 if (mask in (E | W, N | S) and variant == 0) else (2 if mask in (E | W, N | S) else 1)
    centres = broken_coping(piece, top, inner, 401 + mask * 19 + variant * 5, gaps)
    rng = np.random.default_rng(503 + mask * 23 + variant)
    c = CELL / 2.0
    front = piece.t1 - 3.0
    for k, (axis, at) in enumerate(centres):
        if axis == "x":
            chip(piece, k + variant, at, front + 2.0, rng.uniform(18.0, 22.0), flip=bool(k % 2))
        else:
            chip(piece, k + variant, c, at + 4.0, rng.uniform(15.0, 18.0), flip=bool(k % 2))
    # Weeds: one or two unclipped tufts, low, never a hedge.
    if mask == (N | S):
        tufts = [(c + rng.uniform(-5.0, 5.0), 28.0 + 10.0 * variant), (c + rng.uniform(-5.0, 5.0), 52.0)]
    elif mask & N and not mask & S:
        tufts = [(c, 24.0)]
    elif mask == (E | W):
        tufts = [(14.0 + 6.0 * variant + rng.uniform(-3.0, 3.0), front), (44.0 + rng.uniform(-4.0, 4.0), front)]
    else:
        tufts = [(c + rng.uniform(-12.0, 12.0), front)]
    for k, (cx, base) in enumerate(tufts):
        height = rng.uniform(15.0, 20.0)
        if mask & N:
            height = min(height, (piece.lifted(base) - piece.lifted(0.0)) / RS)
        weed(piece, k + mask, cx, base, height, flip=bool((mask + k) % 2), dry=True)
    # Ends and corners without a break still show the neglect: a fallen chip.
    if not centres and mask not in (E | W, N | S):
        chip(piece, mask + variant, c + rng.uniform(-8.0, 8.0), front + 2.0, rng.uniform(14.0, 17.0), flip=bool(mask % 2))
    K.contact_shadow(piece)
    return K.reduce(piece)


def build_moss(mask: int, variant: int = 0) -> Image.Image:
    piece = K.Piece("moss", mask)
    for x0, x1, plan_y in piece.face_rects():
        K.stone_face(piece, x0, x1, plan_y, shade=0.84)
    faces = piece.rgba[:, :, 3] > 0
    top = K.build_top(piece, True)
    inner = _inner(piece)
    _soil(piece, inner, MOSS_SOIL, 0.88, 41 + mask)
    rim = top & ~inner
    # Moss over the coping in soft patches, heavier toward the shaded edges.
    blot = _smooth_noise(601 + mask * 3 + variant, (piece.h, piece.w), world(1.2))
    # Moss creeps from the wet soil over the coping's inner lip, with a few
    # sparse cushions elsewhere: a damp edge, not a stained slab.
    near_soil = np.zeros_like(inner)
    grown = Image.fromarray((inner * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * world(1.6) + 1))
    near_soil = (np.asarray(grown) > 0) & ~inner
    cover = np.where(near_soil, 0.55 + 0.15 * np.clip(blot, -1.0, 1.0), np.clip(blot - 1.2, 0.0, 0.5))
    moss = np.clip(MOSS * 0.92, 0, 255)
    mixed = piece.rgba[:, :, :3] * (1.0 - cover[:, :, None]) + moss[None, None, :] * cover[:, :, None]
    piece.rgba[rim, :3] = mixed[rim] * 0.96
    # Water stain: the face darkens and greens toward its wet foot.
    face_only = faces & ~top
    rows = piece.yy[face_only]
    if rows.size:
        t = ((rows - rows.min()) / max(1, rows.max() - rows.min()))[:, None]
        base = piece.rgba[face_only, :3]
        wet = base * (0.90 - 0.22 * t) * (1.0 - 0.25 * t) + moss[None, :] * 0.25 * t
        piece.rgba[face_only, :3] = wet
    rng = np.random.default_rng(709 + mask * 29 + variant)
    c = CELL / 2.0
    front = piece.t1 - 4.0
    if mask & N and not mask & S:
        tufts = [(c, 24.0)]
    elif mask == (N | S):
        tufts = [(c + rng.uniform(-4.0, 4.0), 26.0 + 8.0 * variant), (c + rng.uniform(-4.0, 4.0), 54.0)]
    elif mask == (E | W):
        tufts = [(16.0 + rng.uniform(-3.0, 3.0), front), (46.0 + 4.0 * variant + rng.uniform(-3.0, 3.0), front)]
    else:
        tufts = [(c + rng.uniform(-12.0, 12.0), front)]
    for k, (cx, base) in enumerate(tufts):
        height = rng.uniform(16.0, 22.0)
        if mask & N:
            height = min(height, (piece.lifted(base) - piece.lifted(0.0)) / RS)
        weed(piece, k + mask + 1, cx, base, height, flip=bool((mask + k + variant) % 2))
    if mask == (E | W) or (bin(mask).count("1") <= 1 and variant == 0):
        K.ivy(piece, 6.0 if variant == 0 else 28.0, piece.t1, bool(variant))
    K.contact_shadow(piece)
    return K.reduce(piece)


def build_fill(style: str) -> Image.Image:
    cfg = K.STYLES[style]
    side = (CELL - cfg["thick"]) / 2.0 + cfg["coping"]
    px = world(side)
    if style == "kerb":
        rgb = _cool(K.LIME[:px, :px] * KERB_VALUE, KERB_GREY)
    elif style == "moss":
        rgb = MOSS_SOIL[:px, :px] * 0.88
    else:
        rgb = RUIN_GROUND[:px, :px]
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
    builders = {"kerb": build_kerb, "ruin": build_ruin, "moss": build_moss}
    for style, build in builders.items():
        for mask in range(16):
            build(mask).save(OUT / f"{style}34_{mask:02d}.png")
        build(E | W, 1).save(OUT / f"{style}34_h_b.png")
        build(N | S, 1).save(OUT / f"{style}34_v_b.png")
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


if __name__ == "__main__":
    main()
