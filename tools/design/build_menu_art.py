#!/usr/bin/env python3
"""Build the front-end menu art (main menu, Archives) from incoming/menu/.

Sources, all in incoming/menu/:

- reference_main_menu_mockup.png  the user's main-menu mock-up (2026-10-02).
- reference_design_sheet.png      the user's design sheet: clean painting,
                                  title PNG, menu highlight PNG, font.
- threshold_plate.png             the mock-up painting with its painted UI
                                  removed and the dark forest extended left to
                                  16:9. Made once with LaMa (see below); this
                                  script never regenerates it.
- vigil_plate.png                 the design sheet painting, extended left to
                                  16:9 the same way.

How the two plates were made (one-off, torch + simple-lama-inpainting in a
scratch venv; not needed to run this script):

  threshold: mock-up art (x 0..1157) -> LaMa with threshold_ui_mask_pass1.png
  (title, menu, footer), then again with threshold_ui_mask_pass2.png (thin
  ornament lines it left) -> rows 110..1000 -> outpainted 160 px on the left
  (two LaMa strips) and 265 px on the bookshelf side (three strips), so the
  forest and the castle silhouettes stay behind the menu as in the mock-up and
  the floor candle keeps its ledge; each strip textured with a 45 % mirrored
  copy of its neighbourhood and clamped to lum 36 so no glare blobs survive.
  Mock-up pixel (mx, my) lands on plate ((160 + mx) * 2048/1582,
  (my - 110) * 1152/890); ArcaneBackdrop.PROFILES uses that mapping.
  vigil: design sheet painting (x 16..1044, y 72..858) -> rows 60..760 ->
  outpainted 216 px on the left in two strips.

Outputs, in assets/ui/menu/:

- threshold_backdrop.jpg, vigil_backdrop.jpg   2048 x 1152 plates.
- threshold_masks.png, vigil_masks.png         1024 x 576, R = open air the
  drifting cloud overlay may cover, G = valley mist band, B = cloud the shader
  may gently warp (kept clear of the castles so they never smear).
- title_logo.png, menu_highlight.png            cut from the design sheet by
  colour-to-alpha against its flat background; the highlight's enclosed dark
  rails and star stay opaque.
- flare_star.png                                a soft four-point star for
  the selection flare and the title twinkles.
- title_reveal.png                              when each title pixel is drawn
  (16-bit time in R/G, class in B) for the title's draw-on (title_sheen.gdshader).

Upscaling: with --esrgan=<realesrgan-ncnn-vulkan binary> the plates are 4x
upscaled by Real-ESRGAN (realesrgan-x4plus) and blended 65/35 with a Lanczos
resize, which keeps the brush texture the GAN smooths away. Without it the
plates are Lanczos only (softer). The committed plates used Real-ESRGAN.

Run: python3 tools/design/build_menu_art.py [--esrgan=/path/to/realesrgan-ncnn-vulkan] [--plate=threshold|vigil]
     python3 tools/design/build_menu_art.py --small   (cut-outs, icons, noise only;
     leaves the committed plates alone)
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "incoming" / "menu"
OUT = ROOT / "assets" / "ui" / "menu"
PLATE_SIZE = (2048, 1152)
MASK_SIZE = (1024, 576)
SHEET_BG = np.array([12.0, 14.0, 17.0])

## plate name -> (air y limit, mist band y0, y1, warp keep-out boxes in UV)
MASK_SPECS = {
    "threshold": (0.66, 0.40, 0.84, [(0.48, 0.0, 0.80, 0.52)]),
    "vigil": (0.62, 0.42, 0.88, [(0.76, 0.0, 1.0, 0.58), (0.38, 0.22, 0.76, 0.52)]),
}


def _esrgan(binary: str, src: Path) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        dst = Path(tmp) / "x4.png"
        subprocess.run(
            [binary, "-i", str(src), "-o", str(dst), "-n", "realesrgan-x4plus"],
            cwd=str(Path(binary).parent), check=True, capture_output=True,
        )
        return Image.open(dst).convert("RGB")


def build_plate(name: str, esrgan: str) -> Image.Image:
    src_path = SRC / f"{name}_plate.png"
    src = Image.open(src_path).convert("RGB")
    lanczos = np.asarray(src.resize(PLATE_SIZE, Image.LANCZOS)).astype(float)
    if esrgan:
        gan = np.asarray(_esrgan(esrgan, src_path).resize(PLATE_SIZE, Image.LANCZOS)).astype(float)
        plate = 0.65 * gan + 0.35 * lanczos
    else:
        plate = lanczos
    image = Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8))
    image.save(OUT / f"{name}_backdrop.jpg", quality=94, subsampling=0)
    return image


def _blur(mask: np.ndarray, sigma: float) -> np.ndarray:
    image = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(sigma))).astype(float) / 255


def build_masks(name: str, plate: Image.Image) -> None:
    air_y1, mist_y0, mist_y1, keepouts = MASK_SPECS[name]
    a = np.asarray(plate).astype(float)
    h, w, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    yy = (np.arange(h)[:, None] / h) * np.ones((1, w))
    xx = (np.arange(w)[None, :] / w) * np.ones((h, 1))
    open_px = ndi.binary_opening((lum > 42) & (b >= r - 6), iterations=2)
    air = _blur(open_px.astype(float), 28)
    air = np.clip((air - 0.25) / 0.5, 0, 1) * np.clip((air_y1 - yy) / 0.12, 0, 1)
    band = np.clip((yy - mist_y0) / 0.08, 0, 1) * np.clip((mist_y1 - yy) / 0.08, 0, 1)
    mist = np.clip((_blur(open_px.astype(float), 22) - 0.2) / 0.5, 0, 1) * band
    cloud = (lum > 52) & (b >= r - 4) & (lum < 230)
    beam = ndi.binary_dilation((b > 170) & (b > r + 45), iterations=14)
    dark = ndi.binary_dilation(lum < 44, iterations=8)
    warp = cloud & ~beam & ~dark & (yy < air_y1)
    for x0, y0, x1, y1 in keepouts:
        warp &= ~((xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1))
    warp = _blur(ndi.binary_erosion(ndi.binary_opening(warp, iterations=3), iterations=5).astype(float), 9)
    channels = np.dstack([air, mist, warp]) * 255
    Image.fromarray(channels.astype(np.uint8), "RGB").resize(MASK_SIZE, Image.LANCZOS).save(OUT / f"{name}_masks.png")


def _colour_to_alpha(sheet: np.ndarray, box: tuple, fill_holes: bool) -> Image.Image:
    x0, y0, x1, y1 = box
    c = sheet[y0:y1, x0:x1]
    alpha = np.clip(np.maximum(c - SHEET_BG, 0).max(axis=2) / (255 - SHEET_BG.min()), 0, 1)
    alpha = np.clip((alpha - 0.025) / 0.975, 0, 1)
    if fill_holes:
        core = alpha > 0.35
        holes = ndi.binary_fill_holes(ndi.binary_closing(core, iterations=2)) & ~core
        alpha = np.where(holes, 1.0, alpha)
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = np.where(alpha[..., None] < 1e-3, 0, (c - (1 - safe) * SHEET_BG) / safe)
    image = Image.fromarray(np.dstack([np.clip(colour, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    bbox = image.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    pad = 6
    return image.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                       min(image.width, bbox[2] + pad), min(image.height, bbox[3] + pad)))


def build_cutouts() -> None:
    sheet = np.asarray(Image.open(SRC / "reference_design_sheet.png").convert("RGB")).astype(float)
    # Boxes start below the sheet's own captions ("TITLE PNG ...").
    _colour_to_alpha(sheet, (1062, 84, 1676, 460), False).save(OUT / "title_logo.png")
    _colour_to_alpha(sheet, (1062, 545, 1676, 660), True).save(OUT / "menu_highlight.png")


## When each part of the title is drawn, as fractions of the whole draw-on.
## The ring and rules engrave first, then the words line by line, the stars
## last. Each window is (start, end); a letter takes LETTER_TIME of its line.
REVEAL_RING = (0.0, 0.26)
REVEAL_RULES = (0.08, 0.30)
REVEAL_LINES = [(0.20, 0.36), (0.32, 0.64), (0.60, 0.70), (0.66, 0.90)]  # THE, ASCENSION, OF, SYN'TEK
REVEAL_LINE_SPLITS = [100.0, 196.0, 226.0]  # centroid y (title px) between the lines
REVEAL_STARS = (0.90, 0.97)
REVEAL_BLADE = (0.84, 0.93)  # the sword through the O, falling top to bottom
LETTER_TIME = 0.085
HALO_LAG = 0.035


def build_reveal_map() -> None:
    """title_reveal.png: for every title pixel, when the draw-on reaches it.

    R/G hold the time as 16 bits (0..1), B the class (255 letters, 128 gold
    ornament, 0 halo) so the shader can colour the pen tip. Letters are traced
    along their strokes: geodesic distance inside the glyph from its top-left,
    so each one is drawn like a pen stroke rather than wiped.
    """
    from skimage.graph import MCP_Geometric

    im = np.asarray(Image.open(OUT / "title_logo.png").convert("RGBA")).astype(float) / 255.0
    a = im[..., 3]
    rgb = im[..., :3]
    mx = rgb.max(2)
    mn = rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    h, w = a.shape

    # Letters (cream, including the blade) with their rust spots folded in.
    cream = (a > 0.5) & (sat < 0.42) & (lum > 0.55)
    letters = ndi.binary_closing(cream, iterations=2)
    letters = ndi.binary_fill_holes(letters) & (a > 0.3)
    # Gold is bright and saturated; the letters' dark edges are not gold, they
    # are halo and follow their letter.
    gold = (a > 0.2) & ~letters & (lum > 0.3) & (sat > 0.3)
    # A letter's anti-aliased rim, where cream meets the orange glow, reads as
    # gold; it belongs to the letter (left unassigned here, it follows the
    # letter as halo) or the outlines would appear before the words.
    letter_dist = ndi.distance_transform_edt(~letters)
    gold &= letter_dist > 3.0
    times = np.full((h, w), -1.0)

    # The ring: least-squares circle through the gold, then by angle from the
    # top, both sides at once, meeting at the bottom.
    gy, gx = np.nonzero(gold)
    A = np.c_[2 * gx, 2 * gy, np.ones_like(gx)]
    sol = np.linalg.lstsq(A, gx ** 2 + gy ** 2, rcond=None)[0]
    cx, cy = sol[0], sol[1]
    radius = np.sqrt(sol[2] + cx * cx + cy * cy)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    dist = np.hypot(xx - cx, yy - cy)
    angle = np.abs(np.arctan2(xx - cx, -(yy - cy))) / np.pi  # 0 at the top, 1 at the bottom
    gold_lab, gold_n = ndi.label(gold)
    stars = np.zeros_like(gold)
    for i, sl in enumerate(ndi.find_objects(gold_lab)):
        comp = gold_lab[sl] == i + 1
        bh, bw = comp.shape
        if comp.sum() >= 120 and bh >= 30 and bw <= 60:  # the four-point stars
            stars[sl] |= comp
    ring = gold & ~stars & (np.abs(dist - radius) < 11.0)
    rules = gold & ~stars & ~ring
    times[ring] = REVEAL_RING[0] + (REVEAL_RING[1] - REVEAL_RING[0]) * angle[ring]
    if rules.any():
        spread = np.abs(xx - cx)
        times[rules] = REVEAL_RULES[0] + (REVEAL_RULES[1] - REVEAL_RULES[0]) * spread[rules] / max(spread[rules].max(), 1.0)
    times[stars] = REVEAL_STARS[0] + (REVEAL_STARS[1] - REVEAL_STARS[0]) * np.clip((yy[stars] - yy[stars].min()) / max(np.ptp(yy[stars]), 1.0), 0, 1)

    # The blade through the O touches the words above and below it, so it is
    # cut out first and drawn on its own, falling, after the words.
    upper = letters[: int(REVEAL_LINE_SPLITS[0]) - 10]
    blade_x = int(np.argmax(upper.sum(axis=0)))
    blade = letters & (np.abs(xx - blade_x) <= 6.0) & (yy < REVEAL_LINE_SPLITS[2] + 14.0)
    if blade.any():
        by = yy[blade]
        times[blade] = REVEAL_BLADE[0] + (REVEAL_BLADE[1] - REVEAL_BLADE[0]) * (by - by.min()) / max(np.ptp(by), 1.0)
    words = letters & ~blade

    # The words, line by line, each letter in reading order.
    lab, n = ndi.label(words)
    comps = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        mask = lab == i + 1
        if mask.sum() < 12:
            continue
        ys, xs = np.nonzero(mask)
        cyc = ys.mean()
        line = int(np.searchsorted(REVEAL_LINE_SPLITS, cyc))
        comps.append((line, xs.min(), i + 1, mask, ys, xs))
    for line in range(len(REVEAL_LINES)):
        members = sorted([c for c in comps if c[0] == line], key=lambda c: c[1])
        if not members:
            continue
        start, end = REVEAL_LINES[line]
        span = max(end - start - LETTER_TIME, 0.0)
        for k, (_, _, _, mask, ys, xs) in enumerate(members):
            t0 = start + (span * k / max(len(members) - 1, 1))
            seed = int(np.argmin(xs + ys * 0.6))  # top-left: where a pen starts
            cost = np.where(mask, 1.0, np.inf)
            mcp = MCP_Geometric(cost)
            geo, _ = mcp.find_costs([(ys[seed], xs[seed])])
            g = geo[mask]
            g = g / max(g[np.isfinite(g)].max(), 1.0)
            times[mask] = t0 + LETTER_TIME * np.clip(g, 0.0, 1.0)

    # The halo follows the nearest ink, a moment late; a letter's own dark
    # outline and glow follow that letter, never a ring or rule beside it.
    assigned = times >= 0.0
    halo = (a > 0.004) & ~assigned
    _, (iy, ix) = ndi.distance_transform_edt(~assigned, return_indices=True)
    times_any = times[iy, ix]
    _, (ly, lx) = ndi.distance_transform_edt(~letters, return_indices=True)
    times_letter = times[ly, lx]
    near_letter = letter_dist <= 12.0
    source = np.where(near_letter, times_letter, times_any)
    times[halo] = np.minimum(source[halo] + HALO_LAG, 1.0)
    times[times < 0.0] = 1.0

    t16 = np.round(np.clip(times, 0.0, 1.0) * 65535).astype(np.uint32)
    cls = np.where(letters, 255, np.where(gold, 128, 0)).astype(np.uint8)
    out = np.dstack([(t16 >> 8).astype(np.uint8), (t16 & 255).astype(np.uint8), cls])
    Image.fromarray(out, "RGB").save(OUT / "title_reveal.png")


def build_flare() -> None:
    n = 128
    y, x = np.mgrid[0:n, 0:n].astype(float)
    u = (x - n / 2 + 0.5) / (n / 2)
    v = (y - n / 2 + 0.5) / (n / 2)
    rays = np.exp(-np.abs(u) * 26) * np.exp(-np.abs(v) * 2.6) + np.exp(-np.abs(v) * 26) * np.exp(-np.abs(u) * 2.6)
    du, dv = (u + v) * 0.7071, (u - v) * 0.7071
    diag = np.exp(-np.abs(du) * 40) * np.exp(-np.abs(dv) * 6) + np.exp(-np.abs(dv) * 40) * np.exp(-np.abs(du) * 6)
    glow = np.exp(-(u * u + v * v) * 9)
    alpha = np.clip(rays + diag * 0.35 + glow * 0.55, 0, 1)
    alpha *= np.clip(1.0 - np.sqrt(u * u + v * v), 0, 1) ** 0.5
    rgba = np.dstack([np.full_like(alpha, 255), np.full_like(alpha, 255), np.full_like(alpha, 255), alpha * 255])
    Image.fromarray(rgba.astype(np.uint8), "RGBA").save(OUT / "flare_star.png")


def build_noise() -> None:
    """Tileable fbm, three decorrelated channels, for clouds, mist and ragged
    wipe edges. Wrap-mode blurs of white noise tile seamlessly."""
    rng = np.random.default_rng(20261002)
    n = 256
    channels = []
    for _ in range(3):
        acc = np.zeros((n, n))
        amp, total = 1.0, 0.0
        for sigma in (24.0, 12.0, 6.0, 3.0, 1.5):
            layer = ndi.gaussian_filter(rng.standard_normal((n, n)), sigma, mode="wrap")
            layer /= layer.std() + 1e-9
            acc += layer * amp
            total += amp
            amp *= 0.55
        acc /= total
        channels.append(np.clip(acc * 0.28 + 0.5, 0, 1))
    Image.fromarray((np.dstack(channels) * 255).astype(np.uint8), "RGB").save(OUT / "cloud_noise.png")


def _diamond(size: int, outline: float, filled: bool, inner_dot: bool) -> Image.Image:
    """A gold diamond icon, drawn analytically at 4x and downsampled."""
    s = size * 4
    y, x = np.mgrid[0:s, 0:s].astype(float)
    c = (s - 1) / 2
    d = (np.abs(x - c) + np.abs(y - c)) / c  # 1.0 on the diamond edge
    edge = 1.0 / c * 4
    ring = np.clip(1 - np.abs(d - (1 - outline)) / outline, 0, 1)
    ring = np.where(d <= 1.0, ring, 0)
    alpha = ring
    if filled:
        alpha = np.maximum(alpha, (d < 1 - outline * 2.2).astype(float))
    if inner_dot:
        alpha = np.maximum(alpha, (d < 0.28).astype(float))
    alpha = np.clip(alpha, 0, 1)
    gold = np.array([226.0, 176.0, 104.0])
    rgba = np.dstack([np.broadcast_to(gold[i], alpha.shape) for i in range(3)] + [alpha * 255])
    image = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    return image.resize((size, size), Image.LANCZOS)


def build_icons() -> None:
    _diamond(22, 0.16, False, False).save(OUT / "icon_check_off.png")
    _diamond(22, 0.16, True, False).save(OUT / "icon_check_on.png")
    _diamond(20, 0.2, True, False).save(OUT / "icon_grabber.png")
    _diamond(24, 0.14, False, True).save(OUT / "icon_grabber_hl.png")
    # A small downward chevron for option buttons.
    s = 64
    y, x = np.mgrid[0:s, 0:s].astype(float)
    v = s * 0.66 - np.abs(x - s / 2) * 0.62
    alpha = np.clip(1 - np.abs(y - v) / 3.4, 0, 1) * (np.abs(x - s / 2) < s * 0.36)
    rgba = np.dstack([np.full_like(alpha, 226), np.full_like(alpha, 176), np.full_like(alpha, 104), alpha * 255])
    Image.fromarray(rgba.astype(np.uint8), "RGBA").resize((16, 16), Image.LANCZOS).save(OUT / "icon_chevron.png")


def main() -> None:
    esrgan = ""
    only_small = False
    only_plate = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--esrgan="):
            esrgan = arg.split("=", 1)[1]
        elif arg == "--small":
            only_small = True
        elif arg.startswith("--plate="):
            only_plate = arg.split("=", 1)[1]
    OUT.mkdir(parents=True, exist_ok=True)
    if not only_small:
        for name in MASK_SPECS:
            if only_plate and name != only_plate:
                continue
            plate = build_plate(name, esrgan)
            build_masks(name, plate)
            print(f"{name}: backdrop + masks")
    build_cutouts()
    build_reveal_map()
    build_flare()
    build_noise()
    build_icons()
    print("title_logo, menu_highlight, flare_star, cloud_noise, icons")


if __name__ == "__main__":
    main()
