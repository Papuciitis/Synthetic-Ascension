#!/usr/bin/env python3
"""Author the Ranged V5 runtime VFX textures procedurally (Phase 2).

The approved Precision direction (user reference, 2026-09-25) is geometric:
near-white cores, pale warm gold glow, small muted violet accents, needles,
elongated diamonds, radial needle bursts. These are exact shapes, so they are
authored here as math instead of sourced or generated art — license-free,
reproducible, and matching the palette by construction. Barrage keeps a
hotter white-blue/amber tracer identity and Ordnance keeps round/spiky/
falling silhouettes so the three disciplines never read alike.

Run:  python3 tools/design/build_ranged_vfx.py
Writes assets/textures/vfx/ranged/*.png (transparent, premultiplied-free).
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets/textures/vfx/ranged"

# The palette, sampled from the accepted direction.
WHITE = (255, 248, 231)
GOLD = (245, 197, 107)
DEEP_GOLD = (216, 158, 68)
VIOLET = (155, 127, 184)
TRACER_HOT = (255, 244, 214)
TRACER_AMBER = (255, 196, 120)
ORDNANCE_ORANGE = (255, 150, 64)
MINE_RED = (255, 96, 64)
HEAT_ORANGE = (255, 120, 40)


def _canvas(w: int, h: int) -> np.ndarray:
    return np.zeros((h, w, 4), dtype=np.float64)


# Files the USER authored (Batch 1 of 2026-09-26 and Batch A of 2026-09-27,
# see docs/art/asset-manifest.md). The procedural versions below are kept as
# history and fallbacks, but running this script must never overwrite the
# art. Pass force=True to a single _save call if you really mean it.
USER_ART = {
    "needle_bullet.png", "tracer_bullet.png", "barrage_dart.png",
    "grenade_body.png", "mine_body.png", "pressure_ring.png",
    "heat_ring_broken.png", "spin_glow.png", "impact_burst.png",
    "judgment_mark.png", "beam_core.png", "beam_cap.png",
}


def _save(name: str, rgba: np.ndarray, force: bool = False) -> None:
    if name in USER_ART and not force and (OUT / name).exists():
        print("skip", name, "(user art; pass force=True to overwrite)")
        return
    rgba = np.clip(rgba, 0.0, 255.0).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT / name)
    print("wrote", name)


def _add(canvas: np.ndarray, color, alpha: np.ndarray) -> None:
    """Additive-ish compose: colour weighted by alpha, alpha maxed."""
    for i in range(3):
        canvas[..., i] = np.maximum(canvas[..., i], color[i] * alpha)
    canvas[..., 3] = np.maximum(canvas[..., 3], alpha * 255.0)


def _grid(w: int, h: int):
    y, x = np.mgrid[0:h, 0:w]
    return x.astype(np.float64), y.astype(np.float64)


def _soft(dist: np.ndarray, inner, outer) -> np.ndarray:
    span = np.maximum(np.asarray(outer, dtype=np.float64) - inner, 1e-6)
    return np.clip(1.0 - (dist - inner) / span, 0.0, 1.0)


def needle_bullet() -> None:
    """Precision native round: a 64x16 needle, white core, gold sheath."""
    w, h = 64, 16
    c = _canvas(w, h)
    x, y = _grid(w, h)
    cy = (h - 1) / 2.0
    # Sheath: lens shape, widest at 40% length, tapering to a point at the tip.
    t = x / (w - 1)
    half_width = 5.5 * np.sin(np.pi * np.clip(t, 0, 1) ** 0.8)
    dist = np.abs(y - cy)
    _add(c, DEEP_GOLD, _soft(dist, half_width * 0.4, half_width) * 0.85)
    _add(c, GOLD, _soft(dist, half_width * 0.25, half_width * 0.7) * 0.95)
    # Core: thin white line, brightest near the tip.
    core = _soft(dist, 0.0, 1.6) * (0.55 + 0.45 * t)
    _add(c, WHITE, core)
    _save("needle_bullet.png", c)


def tracer_bullet() -> None:
    """Barrage native round: a hot, shorter tracer with an amber tail."""
    w, h = 48, 12
    c = _canvas(w, h)
    x, y = _grid(w, h)
    cy = (h - 1) / 2.0
    t = x / (w - 1)
    half_width = 4.0 * np.clip(t * 1.6, 0.15, 1.0)
    dist = np.abs(y - cy)
    _add(c, TRACER_AMBER, _soft(dist, half_width * 0.3, half_width) * (0.25 + 0.7 * t))
    _add(c, TRACER_HOT, _soft(dist, 0.0, 1.8) * (0.2 + 0.8 * t ** 1.5))
    _save("tracer_bullet.png", c)


def diamond_mote() -> None:
    """The elongated rhombus pip from the reference; trails and markers."""
    s = 32
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    manhattan = np.abs(x - cx) / 1.55 + np.abs(y - cy) * 1.55
    _add(c, GOLD, _soft(manhattan, 4.0, 11.0) * 0.9)
    _add(c, WHITE, _soft(manhattan, 0.0, 4.5))
    _add(c, VIOLET, _soft(manhattan, 9.0, 13.0) * 0.25)
    _save("diamond_mote.png", c)


def beam_core() -> None:
    """Horizontally tileable beam middle: white core, gold falloff."""
    w, h = 64, 32
    c = _canvas(w, h)
    _, y = _grid(w, h)
    cy = (h - 1) / 2.0
    dist = np.abs(y - cy)
    _add(c, DEEP_GOLD, _soft(dist, 4.0, 13.0) * 0.55)
    _add(c, GOLD, _soft(dist, 2.0, 8.0) * 0.85)
    _add(c, WHITE, _soft(dist, 0.0, 2.6))
    _save("beam_core.png", c)


def beam_cap() -> None:
    """Beam end: the needle-burst impact from the reference, 96x96."""
    s = 96
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    # Twelve needle spikes of alternating length.
    spikes = np.zeros_like(r)
    for k in range(12):
        a = k * math.pi / 6.0
        length = 44.0 if k % 2 == 0 else 30.0
        d_ang = np.abs(np.angle(np.exp(1j * (ang - a))))
        width = np.clip(0.16 - r / length * 0.14, 0.004, 0.2)
        spike = _soft(d_ang, 0.0, width) * _soft(r, length * 0.15, length)
        spikes = np.maximum(spikes, spike)
    _add(c, GOLD, spikes * 0.95)
    _add(c, WHITE, spikes * _soft(r, 0.0, 20.0))
    # Bright core and a small violet ring accent.
    _add(c, WHITE, _soft(r, 0.0, 7.0))
    _add(c, GOLD, _soft(r, 4.0, 14.0) * 0.8)
    _add(c, VIOLET, _soft(np.abs(r - 17.0), 0.0, 3.0) * 0.35)
    _save("beam_cap.png", c)


def impact_burst() -> None:
    """Smaller 64x64 hit burst for ordinary impacts."""
    s = 64
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    spikes = np.zeros_like(r)
    for k in range(8):
        a = k * math.pi / 4.0 + 0.12
        length = 28.0 if k % 2 == 0 else 19.0
        d_ang = np.abs(np.angle(np.exp(1j * (ang - a))))
        width = np.clip(0.2 - r / length * 0.17, 0.006, 0.22)
        spikes = np.maximum(spikes, _soft(d_ang, 0.0, width) * _soft(r, length * 0.1, length))
    _add(c, GOLD, spikes)
    _add(c, WHITE, _soft(r, 0.0, 5.0))
    _save("impact_burst.png", c)


def grenade_body() -> None:
    """Ordnance grenade: a round dark-metal ball with a hot rim glint."""
    s = 24
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    r = np.hypot(x - cx, y - cy)
    body = _soft(r, 6.5, 8.5)
    for i in range(3):
        c[..., i] = np.maximum(c[..., i], (58, 52, 48)[i] * body)
    c[..., 3] = np.maximum(c[..., 3], body * 255.0)
    # Warm glint top-left and an orange fuse dot.
    glint = _soft(np.hypot(x - cx + 2.5, y - cy + 2.5), 0.0, 3.4) * body
    _add(c, TRACER_HOT, glint * 0.8)
    fuse = _soft(np.hypot(x - cx - 4.5, y - cy + 5.5), 0.0, 2.0)
    _add(c, ORDNANCE_ORANGE, fuse)
    _save("grenade_body.png", c)


def mine_body() -> None:
    """Genuine Mine: a spiked disc, unmistakably stationary and armed."""
    s = 28
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    disc = _soft(r, 6.0, 8.0)
    for i in range(3):
        c[..., i] = np.maximum(c[..., i], (72, 60, 50)[i] * disc)
    c[..., 3] = np.maximum(c[..., 3], disc * 255.0)
    spikes = np.zeros_like(r)
    for k in range(8):
        a = k * math.pi / 4.0
        d_ang = np.abs(np.angle(np.exp(1j * (ang - a))))
        spikes = np.maximum(spikes, _soft(d_ang, 0.0, 0.16) * _soft(r, 6.0, 12.5))
    _add(c, DEEP_GOLD, spikes * 0.8)
    _add(c, MINE_RED, _soft(r, 0.0, 2.6))
    _save("mine_body.png", c)


def shell_marker() -> None:
    """The falling-Shell telegraph: a hollow diamond reticle, reads as
    'incoming from above' against grenades and Mines."""
    s = 48
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    manhattan = np.abs(x - cx) + np.abs(y - cy)
    ring = _soft(np.abs(manhattan - 15.0), 0.0, 2.6)
    _add(c, ORDNANCE_ORANGE, ring * 0.95)
    inner = _soft(np.abs(manhattan - 6.0), 0.0, 1.8)
    _add(c, TRACER_HOT, inner * 0.8)
    _save("shell_marker.png", c)


def aura_ring() -> None:
    """Hot Core's radiant aura edge: soft, hot, honest about its radius."""
    s = 128
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    r = np.hypot(x - cx, y - cy)
    edge = 58.0
    ring = _soft(np.abs(r - edge), 0.0, 5.0)
    _add(c, HEAT_ORANGE, ring * 0.85)
    fill = _soft(r, 0.0, edge) * 0.10
    _add(c, HEAT_ORANGE, fill)
    _save("aura_ring.png", c)


def spin_glow() -> None:
    """Spin Up muzzle glow: a compact radial flare tinted per stage in code."""
    s = 48
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    r = np.hypot(x - cx, y - cy)
    _add(c, (255, 255, 255), _soft(r, 0.0, 6.0))
    _add(c, (255, 255, 255), _soft(r, 4.0, 20.0) * 0.35)
    _save("spin_glow.png", c)


def _over(canvas: np.ndarray, color, alpha: np.ndarray) -> None:
    """Standard straight-alpha OVER compose (paint back to front). Used where
    a dark layer must sit UNDER a bright one; _add's per-channel max cannot
    express that."""
    a_src = np.clip(alpha, 0.0, 1.0)[..., None]
    a_dst = canvas[..., 3:4] / 255.0
    a_out = a_src + a_dst * (1.0 - a_src)
    col_src = np.asarray(color, dtype=np.float64)[None, None, :]
    col_out = (col_src * a_src + canvas[..., :3] * a_dst * (1.0 - a_src)) / np.maximum(a_out, 1e-6)
    canvas[..., :3] = col_out
    canvas[..., 3] = a_out[..., 0] * 255.0


def bullet_shared() -> None:
    """The batched pool's shared body — the native weapon and every enemy
    shot. Travel is +x (head on the right). A warm-white bolt: rounded head,
    gold sheath, amber tail thinning and fading out to the left, wrapped in
    a soft near-black halo so it keeps contrast on pale ground under the
    runtime's normal blending (the pool draws MIX, not additive). The
    instance colour lands as a 45% tint at runtime, so the body stays
    near-neutral and enemy hues survive."""
    w, h = 64, 16
    c = _canvas(w, h)
    x, y = _grid(w, h)
    cy = (h - 1) / 2.0
    head_x = w - 9.0
    dx = x - head_x
    dist_y = np.abs(y - cy)
    t = np.clip(x / head_x, 0.0, 1.0)  # 0 at the tail, 1 at the head centre
    ahead = dx > 0.0
    radius = 4.6
    r_head = np.sqrt(dx ** 2 + dist_y ** 2)
    body_half = radius * (0.32 + 0.68 * t ** 1.3)
    # Distance outside the silhouette: radial past the head centre (so the
    # halo wraps the cap instead of streaking off the canvas), vertical
    # along the body.
    edge = np.where(ahead, r_head - radius, dist_y - body_half)
    # The tail thins and fades to nothing by the left edge; nothing may be
    # cut flat by the canvas.
    fade = np.clip(x / 9.0, 0.0, 1.0)
    energy = np.where(ahead, 1.0, 0.12 + 0.88 * t ** 1.6) * fade
    halo = _soft(edge, 0.0, 2.5) * 0.66 * np.where(ahead, 1.0, 0.2 + 0.8 * t) * fade
    _over(c, (16, 12, 20), halo)
    _over(c, DEEP_GOLD, _soft(edge, -1.2, 0.5) * energy * 0.95)
    _over(c, GOLD, _soft(edge, -2.4, -0.7) * energy)
    # Core: warm white, hottest at the head, a thin line down the tail.
    core_edge = np.where(ahead, r_head - radius * 0.55, dist_y - 1.9 * (0.3 + 0.7 * t))
    core = _soft(core_edge, -0.6, 0.9) * np.where(ahead, 1.0, 0.3 + 0.7 * t ** 1.3) * fade
    _over(c, WHITE, core)
    _save("bullet_shared.png", c)



def barrage_dart() -> None:
    """Barrage's identity is dart / aperture / broken ring ("JSON lasīšana"
    table): an angular dart head with a short broken-ring exhaust, for the
    engine-simulated fragments."""
    s = 32
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    # Dart head: a chevron pointing +x (rotation happens in-engine via color
    # modulate only, so the dart reads directionless-sharp at this size).
    head = _soft(np.abs(dy) * 2.2 + np.abs(dx - 4.0), 0.0, 7.0) * (dx > -2)
    _add(c, TRACER_HOT, head)
    _add(c, TRACER_AMBER, _soft(np.abs(dy) * 1.6 + np.abs(dx - 2.0), 2.0, 9.0) * 0.8)
    # Broken-ring exhaust behind the head: two arc stubs.
    r = np.hypot(dx + 6.0, dy)
    ang = np.arctan2(dy, dx + 6.0)
    ring = _soft(np.abs(r - 7.0), 0.0, 1.8)
    gaps = (np.abs(np.angle(np.exp(1j * (ang - math.pi)))) < 0.9) | (np.abs(ang) < 0.7)
    _add(c, TRACER_AMBER, ring * np.where(gaps, 0.0, 0.75))
    _save("barrage_dart.png", c)


def heat_ring_broken() -> None:
    """The Hot Core aura as a BROKEN ring: overheating, breaking down —
    not a clean magic circle. Ring at 58/64 of half-size like aura_ring."""
    s = 128
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    edge = 58.0
    ring = _soft(np.abs(r - edge), 0.0, 4.5)
    # Six segments with ragged gaps; a faint inner shimmer ring.
    seg = np.mod(ang + math.pi, math.pi / 3.0)
    gap = seg < 0.22
    _add(c, HEAT_ORANGE, ring * np.where(gap, 0.0, 0.9))
    _add(c, TRACER_HOT, _soft(np.abs(r - edge), 0.0, 1.5) * np.where(gap, 0.0, 0.5))
    inner = _soft(np.abs(r - edge * 0.75), 0.0, 2.0)
    inner_gap = np.mod(ang, math.pi / 2.0) < 0.35
    _add(c, HEAT_ORANGE, inner * np.where(inner_gap, 0.0, 0.30))
    _add(c, HEAT_ORANGE, _soft(r, 0.0, edge) * 0.08)
    _save("heat_ring_broken.png", c)


def pressure_ring() -> None:
    """Ordnance's Shell telegraph as a PRESSURE ring (shell / charge /
    pressure ring): concentric double ring with gauge ticks, reading as
    'contained force about to land', replacing the hollow diamond."""
    s = 64
    c = _canvas(s, s)
    x, y = _grid(s, s)
    cx = cy = (s - 1) / 2.0
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    outer = _soft(np.abs(r - 27.0), 0.0, 2.2)
    _add(c, ORDNANCE_ORANGE, outer * 0.95)
    inner = _soft(np.abs(r - 19.0), 0.0, 1.6)
    _add(c, TRACER_AMBER, inner * 0.7)
    # Twelve gauge ticks crossing the outer ring.
    for k in range(12):
        a = k * math.pi / 6.0
        d_ang = np.abs(np.angle(np.exp(1j * (ang - a))))
        tick = _soft(d_ang, 0.0, 0.05) * _soft(np.abs(r - 27.0), 0.0, 5.5)
        _add(c, TRACER_HOT, tick * 0.85)
    # Core charge dot.
    _add(c, ORDNANCE_ORANGE, _soft(r, 0.0, 3.5) * 0.9)
    _save("pressure_ring.png", c)


if __name__ == "__main__":
    bullet_shared()
    barrage_dart()
    heat_ring_broken()
    pressure_ring()
    needle_bullet()
    tracer_bullet()
    diamond_mote()
    beam_core()
    beam_cap()
    impact_burst()
    grenade_body()
    mine_body()
    shell_marker()
    aura_ring()
    spin_glow()
    print("done ->", OUT)
