#!/usr/bin/env python3
"""Contact sheets and stills for reviewing a take or the finished trailer.

usage: review_take.py <ffmpeg> <video> <out dir> <first frame> <last frame> <step> [tile width] [columns]

Writes sheet-<first>-<last>.png: every <step>-th frame, scaled to the tile
width and labelled with its frame number and time, so a whole take can be
read at a glance; the tile width doubles as the small-screen check.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    ff, video, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    first, last, step = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
    tile_w = int(sys.argv[7]) if len(sys.argv) > 7 else 480
    columns = int(sys.argv[8]) if len(sys.argv) > 8 else 4
    out.mkdir(parents=True, exist_ok=True)
    frames = list(range(first, last + 1, step))
    with tempfile.TemporaryDirectory() as tmp:
        select = "+".join(f"eq(n\\,{n})" for n in frames)
        subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-i", video, "-vf",
                        f"select='{select}',scale={tile_w}:-2", "-vsync", "0", f"{tmp}/f%05d.png"], check=True)
        tiles = sorted(Path(tmp).glob("f*.png"))
        if not tiles:
            sys.exit("no frames extracted")
        w, h = Image.open(tiles[0]).size
        rows = (len(tiles) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * w, rows * (h + 18)), (20, 20, 20))
        draw = ImageDraw.Draw(sheet)
        for i, (n, tile) in enumerate(zip(frames, tiles)):
            x, y = (i % columns) * w, (i // columns) * (h + 18)
            sheet.paste(Image.open(tile), (x, y + 18))
            draw.text((x + 4, y + 3), f"#{n}  {n / 60:.2f}s", fill=(255, 220, 120))
        path = out / f"sheet-{first}-{last}.png"
        sheet.save(path)
        print(path, f"{len(tiles)} tiles {w}x{h}")


if __name__ == "__main__":
    main()
