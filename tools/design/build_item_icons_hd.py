#!/usr/bin/env python3
"""HD item icons: every item icon rebuilt from its full-resolution original.

The 40 item icons under assets/textures/items/{conduit,curses,gravemarch,
lattice,offhand,rings}/ are the user's painted art (2026-09-26), but they
were installed at 32x32 and so looked soft in the 44-84 px slots of the
Exchange, Gear & Stash, the HUD bar and the tooltip. The 1254 px masters
were kept. This script rebuilds each icon from its master at 128x128, under
the same file name and path, so every .tres binding and every import uid
stays as it was.

Two steps:

  python3 tools/design/build_item_icons_hd.py --match [--sheet out.png]
      Finds each icon's master among the untracked images in the repo root
      ("ChatGPT Image ...png", beka_face.png, banner_icon.png). Each
      candidate and each installed icon is reduced to the same small
      signature (trimmed to its alpha box, padded square, premultiplied
      downscale to 16x16), and the closest master wins. A match must be
      unique and clearly ahead of the runner-up. The masters are copied
      unchanged to incoming/items/<icon file name>, and the match is
      recorded in incoming/items/sources.json. --sheet writes a contact
      sheet (master | installed icon) to check the mapping by eye.

  python3 tools/design/build_item_icons_hd.py [--sheet out.png] [--only name]
      Bakes the icons from incoming/items/. For each master: alpha below
      3/255 (an invisible haze the generator leaves around the object) is
      cleared, the image is trimmed to its alpha box, padded to a square
      with a CONTENT/SIZE margin and downscaled with premultiplied alpha in
      floating point (Lanczos). The outer BORDER pixels are forced to zero
      alpha so filtering never smears an edge. Icons without a master are
      left as they are and listed. --sheet writes a before/after sheet.

Each icon's .import should have mipmaps/generate=true: the project's canvas
filter is Linear Mipmap, so a 128 px icon drawn at 48 px samples a
pre-filtered level instead of skipping texels. After a bake, re-import:
  flock <lock> <godot> --headless --path . --import

Requires Pillow and numpy.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ITEMS = ROOT / "assets/textures/items"
FAMILIES = ("conduit", "curses", "gravemarch", "lattice", "offhand", "rings")
INCOMING = ROOT / "incoming/items"
SOURCES_JSON = INCOMING / "sources.json"

SIZE = 128          # output edge in pixels
CONTENT = 118       # the longer side of the trimmed art, in output pixels
BORDER = 2          # outer ring forced to zero alpha
HAZE = 3.0 / 255.0  # master alpha below this is cleared before trimming

SIG = 16            # matching signature edge
SIG_TRIM = 0.25     # alpha threshold for the signature's trim
MATCH_MARGIN = 2.0  # the runner-up must be at least this many times farther


# --------------------------------------------------------------- helpers

def load_rgba(path: Path) -> np.ndarray:
    """An image as float32 RGBA in [0, 1], straight alpha."""
    with Image.open(path) as im:
        return np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0


def alpha_box(alpha: np.ndarray, threshold: float):
    ys, xs = np.nonzero(alpha > threshold)
    if xs.size == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def resize_premultiplied(rgba: np.ndarray, width: int, height: int,
                         resample=Image.LANCZOS) -> np.ndarray:
    """Premultiplied, floating-point resize, so transparent pixels never
    bleed their (meaningless) colour into the edge. Returns straight alpha."""
    alpha = rgba[..., 3]
    planes = [rgba[..., 0] * alpha, rgba[..., 1] * alpha, rgba[..., 2] * alpha, alpha]
    out = np.empty((height, width, 4), dtype=np.float32)
    for i, plane in enumerate(planes):
        img = Image.fromarray(np.ascontiguousarray(plane), mode="F")
        out[..., i] = np.asarray(img.resize((width, height), resample), dtype=np.float32)
    out = np.clip(out, 0.0, 1.0)
    a = out[..., 3]
    safe = np.where(a > 1e-6, a, 1.0)
    for i in range(3):
        out[..., i] = np.where(a > 1e-6, np.clip(out[..., i] / safe, 0.0, 1.0), 0.0)
    return out


def pad_square(rgba: np.ndarray, side: int) -> np.ndarray:
    h, w = rgba.shape[:2]
    out = np.zeros((side, side, 4), dtype=np.float32)
    ox = (side - w) // 2
    oy = (side - h) // 2
    out[oy:oy + h, ox:ox + w] = rgba
    return out


def to_image(rgba: np.ndarray) -> Image.Image:
    return Image.fromarray(np.round(np.clip(rgba, 0.0, 1.0) * 255.0).astype(np.uint8), "RGBA")


def installed_icons():
    """Every installed item icon, keyed by file name (names are unique)."""
    icons = {}
    for family in FAMILIES:
        for path in sorted((ITEMS / family).glob("*.png")):
            if path.name in icons:
                sys.exit(f"duplicate icon file name {path.name}")
            icons[path.name] = path
    return icons


# --------------------------------------------------------------- matching

def signature(rgba: np.ndarray) -> np.ndarray:
    box = alpha_box(rgba[..., 3], SIG_TRIM)
    x0, y0, x1, y1 = box
    crop = rgba[y0:y1, x0:x1]
    sq = pad_square(crop, max(crop.shape[0], crop.shape[1]))
    sig = resize_premultiplied(sq, SIG, SIG)
    sig[..., :3] *= sig[..., 3:4]
    return sig


def candidate_masters():
    """Untracked full-resolution art in the repo root with real alpha."""
    out = []
    for path in sorted(ROOT.glob("*.png")):
        with Image.open(path) as im:
            if im.mode not in ("RGBA", "LA", "P") or min(im.size) < 256:
                continue
        out.append(path)
    return out


def match(sheet: Path | None) -> int:
    icons = installed_icons()
    sigs = {}
    for path in candidate_masters():
        rgba = load_rgba(path)
        if rgba[..., 3].min() > 0.99 or alpha_box(rgba[..., 3], SIG_TRIM) is None:
            continue
        sigs[path] = signature(rgba)
    print(f"{len(sigs)} candidate masters with alpha")

    result = {}
    failures = []
    for name, path in icons.items():
        sig = signature(load_rgba(path))
        ranked = sorted((float(np.mean((sig - s) ** 2)), p) for p, s in sigs.items())
        best, runner = ranked[0], ranked[1]
        ratio = runner[0] / max(best[0], 1e-9)
        result[name] = {"source": best[1].name, "distance": round(best[0], 6),
                        "runner_up": runner[1].name, "runner_up_ratio": round(ratio, 2)}
        flag = "" if ratio >= MATCH_MARGIN else "   <-- AMBIGUOUS"
        print(f"{name:42s} <- {best[1].name:44s} d={best[0]:.5f} x{ratio:.1f}{flag}")
        if ratio < MATCH_MARGIN:
            failures.append(name)

    used = {}
    for name, info in result.items():
        used.setdefault(info["source"], []).append(name)
    for source, names in used.items():
        if len(names) > 1:
            failures.extend(names)
            print(f"master {source} claimed by {names}")
    if failures:
        print("no files copied: resolve the ambiguous matches above by hand")
        return 1

    INCOMING.mkdir(parents=True, exist_ok=True)
    for name, info in result.items():
        shutil.copyfile(ROOT / info["source"], INCOMING / name)
    SOURCES_JSON.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"copied {len(result)} masters to {INCOMING.relative_to(ROOT)}/")
    if sheet is not None:
        _match_sheet(result, icons, sheet)
    return 0


def _match_sheet(result: dict, icons: dict, sheet: Path) -> None:
    cell = 132
    cols = 4
    names = sorted(result)
    rows = (len(names) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * cell * 2, rows * (cell + 16)), (46, 42, 40))
    draw = ImageDraw.Draw(canvas)
    for i, name in enumerate(names):
        x = (i % cols) * cell * 2
        y = (i // cols) * (cell + 16)
        with Image.open(INCOMING / name) as master:
            thumb = master.convert("RGBA")
            thumb.thumbnail((cell - 4, cell - 4), Image.LANCZOS)
        canvas.paste(thumb, (x + 2, y + 2), thumb)
        with Image.open(icons[name]) as icon:
            big = icon.convert("RGBA").resize((cell - 4, cell - 4), Image.NEAREST)
        canvas.paste(big, (x + cell + 2, y + 2), big)
        draw.text((x + 4, y + cell), f"{name[:-4]}  <- {result[name]['source'][-22:]}", fill=(240, 220, 150))
    sheet.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(sheet)
    print(f"match sheet -> {sheet}")


# --------------------------------------------------------------- baking

def bake_one(master: Path) -> Image.Image:
    rgba = load_rgba(master)
    rgba[..., 3] = np.where(rgba[..., 3] < HAZE, 0.0, rgba[..., 3])
    box = alpha_box(rgba[..., 3], 0.0)
    if box is None:
        raise ValueError(f"{master.name} is fully transparent")
    x0, y0, x1, y1 = box
    crop = rgba[y0:y1, x0:x1]
    longest = max(crop.shape[0], crop.shape[1])
    side = int(np.ceil(longest * SIZE / CONTENT))
    out = resize_premultiplied(pad_square(crop, side), SIZE, SIZE)
    out[..., 3] = np.where(out[..., 3] < 0.5 / 255.0, 0.0, out[..., 3])
    out[:BORDER, :, 3] = 0.0
    out[-BORDER:, :, 3] = 0.0
    out[:, :BORDER, 3] = 0.0
    out[:, -BORDER:, 3] = 0.0
    out[..., :3] = np.where(out[..., 3:4] > 0.0, out[..., :3], 0.0)
    return to_image(out)


def bake(sheet: Path | None, only: str) -> int:
    icons = installed_icons()
    if not INCOMING.is_dir():
        sys.exit(f"{INCOMING} is missing: run with --match first")
    before = {}
    baked = []
    for name, path in icons.items():
        if only and name != only and Path(name).stem != only:
            continue
        master = INCOMING / name
        if not master.is_file():
            continue
        with Image.open(path) as old:
            before[name] = old.convert("RGBA")
        bake_one(master).save(path, optimize=True)
        baked.append(name)
        print(f"baked {path.relative_to(ROOT)}  {SIZE}x{SIZE}")
    missing = [n for n in icons if not (INCOMING / n).is_file()]
    print(f"{len(baked)} icons baked")
    if missing:
        print("left as they are (no master): " + ", ".join(missing))
    if sheet is not None and baked:
        _bake_sheet(baked, icons, before, sheet)
    return 0


def _bake_sheet(names: list, icons: dict, before: dict, sheet: Path) -> None:
    """Before (32 px, bilinear to 64) | after at 64 and 48 | after at 128,
    on the dark panel colour the UI uses."""
    bg = (14, 12, 11)
    cell_w = 64 + 48 + 128 + 64 + 40
    cell_h = 128 + 18
    cols = 3
    rows = (len(names) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * cell_w, rows * cell_h), bg)
    draw = ImageDraw.Draw(canvas)
    for i, name in enumerate(sorted(names)):
        x = (i % cols) * cell_w + 6
        y = (i // cols) * cell_h + 4
        old = before[name].resize((64, 64), Image.BILINEAR)
        canvas.paste(old, (x, y + 32), old)
        with Image.open(icons[name]) as new_icon:
            new = new_icon.convert("RGBA")
        n64 = new.resize((64, 64), Image.BOX)
        n48 = new.resize((48, 48), Image.BOX)
        canvas.paste(n64, (x + 72, y + 32), n64)
        canvas.paste(n48, (x + 144, y + 40), n48)
        canvas.paste(new, (x + 200, y), new)
        draw.text((x, y + 130), name[:-4], fill=(220, 200, 150))
    sheet.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(sheet)
    print(f"bake sheet -> {sheet}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--match", action="store_true", help="find and copy the masters")
    parser.add_argument("--sheet", type=Path, default=None, help="write a contact sheet PNG here")
    parser.add_argument("--only", default="", help="bake one icon (file name or stem)")
    args = parser.parse_args()
    if args.match:
        return match(args.sheet)
    return bake(args.sheet, args.only)


if __name__ == "__main__":
    sys.exit(main())
