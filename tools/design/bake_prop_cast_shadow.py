#!/usr/bin/env python3
"""Bake assets/world/props/prop_cast_shadow.png: the soft footprint cast that
ChunkBlockRenderer stretches under every small half-cover prop.

A 128x64 tapered capsule, alpha only (white RGB). Its base end (x = 0) is the
prop's footprint, half the texture tall; it narrows to 60% toward the tip, as a
prop's top casts narrower than its base. The core is solid; only the outer 28%
of the half-width feathers (the penumbra) and the far quarter fades by up to
25%. The shared sun-shade material multiplies the ground by its alpha.
Run: python3 tools/design/bake_prop_cast_shadow.py
"""
from pathlib import Path
from PIL import Image

W, H = 128, 64
R = H / 2.0
TIP = 0.6


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def half_width(x):
    return R * (1.0 + (TIP - 1.0) * min(1.0, max(0.0, x / W)))


image = Image.new("RGBA", (W, H))
pixels = image.load()
tip_r = half_width(W)
for y in range(H):
    for x in range(W):
        px, py = x + 0.5, y + 0.5 - R
        # Rounded ends: a half-disc of the local half-width at either end.
        if px < R:
            cap = (R - px) / R
        elif px > W - tip_r:
            cap = (px - (W - tip_r)) / tip_r
        else:
            cap = 0.0
        reach = half_width(px) * max(0.0, 1.0 - cap * cap) ** 0.5
        d = abs(py) / reach if reach > 0.0 else 2.0
        edge = 1.0 - smoothstep(0.72, 1.0, d)
        along = 1.0 - 0.25 * smoothstep(0.75, 1.0, px / W)
        pixels[x, y] = (255, 255, 255, round(255 * edge * along))
out = Path(__file__).resolve().parents[2] / "assets/world/props/prop_cast_shadow.png"
image.save(out)
print(out)
