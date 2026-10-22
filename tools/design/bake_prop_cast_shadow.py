#!/usr/bin/env python3
"""Bake assets/world/props/prop_cast_shadow.png: the soft footprint cast that
ChunkBlockRenderer stretches under every small half-cover prop.

A 128x64 capsule, alpha only (white RGB): darkest at the base end (x = 0),
fading by 45% toward the tip, feathered from 55% of the radius outward. The
shared sun-shade material multiplies the ground by its alpha.
Run: python3 tools/design/bake_prop_cast_shadow.py
"""
from pathlib import Path
from PIL import Image

W, H = 128, 64
R = H / 2.0


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


image = Image.new("RGBA", (W, H))
pixels = image.load()
for y in range(H):
    for x in range(W):
        px, py = x + 0.5, y + 0.5 - R
        spine = min(max(px, R), W - R)
        d = ((px - spine) ** 2 + py ** 2) ** 0.5 / R
        edge = 1.0 - smoothstep(0.55, 1.0, d)
        along = 1.0 - 0.45 * smoothstep(0.0, 1.0, px / W)
        pixels[x, y] = (255, 255, 255, round(255 * edge * along))
out = Path(__file__).resolve().parents[2] / "assets/world/props/prop_cast_shadow.png"
image.save(out)
print(out)
