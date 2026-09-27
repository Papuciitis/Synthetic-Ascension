#!/usr/bin/env python3
"""Three-quarter wall kit (2026-09-27 world look pass).

The old walls were a flat top-down stone band per connection mask (thick
cartoon outline, rounded ends) plus a separate 22 px brick strip hung under
exposed caps ("Phase 3 shallow depth"). Read together they looked like
stacked paper. This bakes each connection mask as ONE three-quarter piece in
the reference's language: a lit stone top lifted by the wall height, a dark
stone face below every south-facing edge, a thin near-black outline, and
contact shade at the foot. Gameplay does not move: the collision line is
still the 24 px band through the cell centre; the piece only draws taller.

Geometry, in world px (one cell = 64, centre (32, 32) of its cell):
  top    = the wall footprint (THICK wide, centred on the cell) lifted by HEIGHT
  face   = below each exposed south edge of the top, HEIGHT tall
  canvas = the cell plus HEIGHT above it: 64 x (64 + HEIGHT)
Output is SCALE texels per world px, so draw at 1 / SCALE and centre the
sprite HEIGHT / 2 above the cell centre.

Sources: the brick band inside the old top-down art (it tiles along its
length), so the kit keeps the existing palette until real kit art arrives.
Hand-made strips in assets/world/walls/source/ (wall_top_strip.png,
wall_face_strip.png; docs/art/2026-09-27-world-look-art.md W1/W2) replace
it automatically; re-run and re-import, nothing else changes.

Run:  python3 tools/design/build_wall_kit.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/world/walls"
OUT = ROOT / "assets/world/walls/kit"

SCALE = 4
CELL = 64
THICK = 32
HEIGHT = 28

N, E, S, W = 1, 2, 4, 8

W_PX = CELL * SCALE
H_PX = (CELL + HEIGHT) * SCALE
LIFT = HEIGHT * SCALE
T0 = (CELL - THICK) // 2 * SCALE  # top rect start inside the cell
T1 = T0 + THICK * SCALE

OUTLINE = np.array([22.0, 16.0, 13.0])
OUTLINE_PX = 5


def load_band(name: str, axis: str) -> np.ndarray:
    img = np.asarray(Image.open(SRC / name).convert("RGB"), dtype=np.float64)
    # The band sits at 352..673 with a ~14 px outline; keep the bricks only.
    if axis == "h":
        return img[370:655, :, :]
    return img[:, 370:655, :]


CAP_H = load_band("wall_stone_straight_h.png", "h")  # (rows, 1024)
CAP_V = load_band("wall_stone_straight_v.png", "v")  # (1024, cols)
FACE = None

# Hand-made strips (docs/art/2026-09-27-world-look-art.md, W1/W2) replace the
# old band when present: W1 is the top (its rotation serves the vertical
# arms), W2 the face.
TOP_STRIP = SRC / "source/wall_top_strip.png"
FACE_STRIP = SRC / "source/wall_face_strip.png"
if TOP_STRIP.exists():
    top = Image.open(TOP_STRIP).convert("RGB")
    top = top.resize((1024, max(64, round(1024 * top.height / top.width))), Image.LANCZOS)
    CAP_H = np.asarray(top, dtype=np.float64)
    CAP_V = np.rot90(CAP_H, k=-1).copy()
if FACE_STRIP.exists():
    face = Image.open(FACE_STRIP).convert("RGB")
    face = face.resize((1024, max(32, round(1024 * face.height / face.width))), Image.LANCZOS)
    FACE = np.asarray(face, dtype=np.float64)


def sample_face(xs: np.ndarray, ys: np.ndarray, y0: int, y1: int) -> np.ndarray:
    u = (xs * (1024 // W_PX)) % FACE.shape[1]
    v = ((ys - y0) / max(1, (y1 - y0)) * (FACE.shape[0] - 1)).astype(int)
    return FACE[np.clip(v, 0, FACE.shape[0] - 1), u]


def sample_h(xs: np.ndarray, ys: np.ndarray, y0: int, y1: int) -> np.ndarray:
    """Horizontal band: u follows world x (1024 source px per cell), v spans
    the rect's height across the band."""
    u = (xs * (1024 // W_PX)) % CAP_H.shape[1]
    v = ((ys - y0) / max(1, (y1 - y0)) * (CAP_H.shape[0] - 1)).astype(int)
    return CAP_H[np.clip(v, 0, CAP_H.shape[0] - 1), u]


def sample_v(xs: np.ndarray, ys: np.ndarray, x0: int, x1: int) -> np.ndarray:
    """Vertical band: v follows world y (lifted cell space), u spans width."""
    v = (ys * (1024 // W_PX)) % CAP_V.shape[0]
    u = ((xs - x0) / max(1, (x1 - x0)) * (CAP_V.shape[1] - 1)).astype(int)
    return CAP_V[v, np.clip(u, 0, CAP_V.shape[1] - 1)]


def rects_for(mask: int):
    """Top rects in LIFTED cell space (y 0..256 is the cell), tagged h/v."""
    rects = [("h", T0, T0, T1, T1)]  # centre square: (kind, x0, y0, x1, y1)
    if mask & N:
        rects.append(("v", T0, 0, T1, T0))
    if mask & S:
        rects.append(("v", T0, T1, T1, W_PX))
    if mask & E:
        rects.append(("h", T1, T0, W_PX, T1))
    if mask & W:
        rects.append(("h", 0, T0, T0, T1))
    return rects


def faces_for(mask: int):
    """Face rects in canvas space: under each exposed south top edge."""
    faces = []
    if not mask & S:
        faces.append((T0, T1, T1, T1 + LIFT))
    if mask & E:
        faces.append((T1, T1, W_PX, T1 + LIFT))
    if mask & W:
        faces.append((0, T1, T0, T1 + LIFT))
    return faces


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r:
                continue
            shifted = np.zeros_like(mask)
            ys = slice(max(0, dy), mask.shape[0] + min(0, dy))
            yd = slice(max(0, -dy), mask.shape[0] + min(0, -dy))
            xs = slice(max(0, dx), mask.shape[1] + min(0, dx))
            xd = slice(max(0, -dx), mask.shape[1] + min(0, -dx))
            shifted[ys, xs] = mask[yd, xd]
            out |= shifted
    return out


def build(mask: int, window: bool = False) -> Image.Image:
    rgb = np.zeros((H_PX, W_PX, 3))
    solid = np.zeros((H_PX, W_PX), dtype=bool)
    yy, xx = np.mgrid[0:H_PX, 0:W_PX]

    # Faces first: the top overlaps their upper lip.
    for (x0, y0, x1, y1) in faces_for(mask):
        region = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        t = (yy[region] - y0) / (y1 - y0)
        if FACE is not None:
            # Painted in shade already; only the gradient toward the foot.
            col = sample_face(xx[region], yy[region], y0, y1)
            shade = 0.95 - 0.2 * t
        else:
            col = sample_h(xx[region], yy[region], y0, y1)
            shade = 0.5 - 0.16 * t
        col = col * shade[:, None]
        # Desaturate a touch: the face is in shadow.
        grey = col.mean(axis=1, keepdims=True)
        col = col * 0.8 + grey * 0.2
        # Contact shade at the foot.
        foot = (y1 - yy[region]) < 7
        col[foot] *= 0.72
        rgb[region] = col
        solid |= region

    top = np.zeros((H_PX, W_PX), dtype=bool)
    for (kind, x0, y0, x1, y1) in rects_for(mask):
        region = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        if kind == "h":
            col = sample_h(xx[region], yy[region], T0, T1)
        else:
            col = sample_v(xx[region], yy[region], T0, T1)
        rgb[region] = col * 1.04
        top |= region
    solid |= top

    # Lit front lip of the top, a hard dark line where top meets face. A top
    # that continues south into the next cell has no lip at the canvas edge.
    continued = top.copy()
    if mask & S:
        continued[T1:, T0:T1] = True
    below = np.zeros_like(continued)
    below[:-6] = continued[6:]
    below[-6:] = continued[-6:]
    lip = top & ~below
    rgb[lip] = np.minimum(rgb[lip] * 1.22, 255)
    seam = (~top) & np.roll(top, 2, axis=0) & solid
    rgb[seam] *= 0.55

    if window:
        # A barred opening through the middle of the straight piece.
        horizontal = bool(mask & (E | W))
        if horizontal:
            gap = (xx >= 72) & (xx < 184)
        else:
            gap = (yy >= 72) & (yy < 184)
        slot = gap & top
        if horizontal:
            slot &= (yy >= T0 + 16) & (yy < T1 - 16)
        else:
            slot &= (xx >= T0 + 16) & (xx < T1 - 16)
        rgb[slot] = np.array([26.0, 22.0, 24.0])
        bars = slot & (((xx if horizontal else yy) // 8) % 4 == 0)
        rgb[bars] = np.array([92.0, 88.0, 84.0])
        if horizontal:
            opening = gap & (yy >= T1 + 10) & (yy < T1 + LIFT - 18)
            rgb[opening & solid] = np.array([20.0, 17.0, 18.0])

    # Outline around the whole piece, except where it continues into the
    # next cell (the canvas edge, and under a south arm: the neighbour's top).
    virtual = solid.copy()
    if mask & S:
        virtual[T1:, T0:T1] = True
    ring = dilate(virtual, OUTLINE_PX) & ~virtual
    alpha = np.zeros((H_PX, W_PX))
    alpha[solid] = 255
    rgb[ring] = OUTLINE
    alpha[ring] = 235

    out = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def build_fill(corner: str) -> Image.Image:
    """The top of one open quadrant corner (THICK/2 square), drawn where two
    arms and the diagonal neighbour are all wall, so a solid block of wall
    cells reads as one slab instead of a grid of crosses."""
    side = T0
    x0 = T1 if "e" in corner else 0
    y0 = T1 if "s" in corner else 0
    yy, xx = np.mgrid[y0:y0 + side, x0:x0 + side]
    # Same band rows as the arms beside it: v runs over the top's thickness.
    rows = (yy - y0) + T0 + (side // 2 if y0 == 0 else 0)
    col = sample_h(xx.ravel(), rows.ravel(), T0, T1).reshape(side, side, 3) * 1.04
    alpha = np.full((side, side, 1), 255.0)
    return Image.fromarray(np.dstack([np.clip(col, 0, 255), alpha]).astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for mask in range(16):
        build(mask).save(OUT / f"wall34_{mask:02d}.png")
    for corner in ("ne", "se", "sw", "nw"):
        build_fill(corner).save(OUT / f"wall34_fill_{corner}.png")
    build(E | W, window=True).save(OUT / "wall34_window_h.png")
    build(N | S, window=True).save(OUT / "wall34_window_v.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
