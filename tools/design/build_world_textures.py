#!/usr/bin/env python3
"""Shallow-depth world textures (Phase 3): the south wall face.

The existing wall art is a top-down 1024 px stone cap per connection mask.
This authors the matching vertical stone face drawn under a cap wherever no
wall continues south, in the caps' own palette (sampled mean ~(109,93,79)).
1024x352 at the renderer's 0.0625 scale = 64x22 world pixels.

Run:  python3 tools/design/build_world_textures.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/world/walls/wall_stone_face.png"

W, H = 1024, 352
BASE = np.array([96.0, 81.0, 68.0])
DARK = np.array([64.0, 53.0, 44.0])
LIGHT = np.array([124.0, 106.0, 89.0])
MORTAR = np.array([52.0, 44.0, 38.0])


def build() -> None:
    rng = np.random.default_rng(20260926)
    img = np.zeros((H, W, 4), dtype=np.float64)
    y = np.linspace(0.0, 1.0, H)[:, None]
    # Base vertical gradient: darker toward the ground.
    for i in range(3):
        img[..., i] = BASE[i] * (1.0 - 0.28 * y[..., 0])[:, None]
    img[..., 3] = 255.0

    # Stone courses: three rows of offset blocks with mortar lines.
    courses = 3
    course_h = H // courses
    block_w = 172
    for row in range(courses):
        y0 = row * course_h
        y1 = min(H, y0 + course_h)
        offset = (row % 2) * (block_w // 2)
        # Horizontal mortar line at the course top.
        img[y0:y0 + 8, :, :3] = MORTAR
        x = -offset
        while x < W:
            x1 = min(W, x + block_w)
            if x >= 0:
                # Per-block tint variation.
                tint = rng.uniform(-10.0, 10.0)
                img[y0 + 8:y1, max(0, x):x1, :3] += tint
                # Top bevel highlight and bottom shade inside the block.
                img[y0 + 8:y0 + 16, max(0, x):x1, :3] = LIGHT + tint
                img[y1 - 8:y1, max(0, x):x1, :3] = DARK + tint * 0.5
            # Vertical mortar joint.
            img[y0 + 8:y1, max(0, x1 - 6):x1, :3] = MORTAR
            x += block_w

    # Gentle noise so the face is not flat.
    noise = rng.normal(0.0, 4.0, (H // 4, W // 4, 1))
    noise = np.kron(noise, np.ones((4, 4, 1)))
    img[..., :3] += noise[:H, :W]

    # Ground-contact shade.
    img[-24:, :, :3] *= 0.82

    out = np.clip(img, 0, 255).astype(np.uint8)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
