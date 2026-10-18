#!/usr/bin/env python3
"""Build the boot splash and the app icon.

- assets/ui/boot/splash.png    1920x1080: the title logo over a faint candle
                               glow. Shown by the engine while the game loads
                               (application/boot_splash/image), in place of
                               Godot's logo.
- assets/ui/boot/app_icon.png  512x512: the logo's ringed four-point star,
                               redrawn here with shapes (it does not read the
                               logo, so a new logo needs a matching star). The
                               window, taskbar and exported .exe icon
                               (application/config/icon and the Windows
                               preset's application/icon).

The splash's border is pure black, the same as boot_splash/bg_color, the
letterbox bars and the main menu's opening curtain, so the splash fills any
window shape seamlessly and hands over to the menu without a step in tone.

Source of the splash: assets/ui/menu/title_logo.png (the main menu's title).

Run: python3 tools/design/build_boot_art.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "assets/ui/menu/title_logo.png"
OUT = ROOT / "assets/ui/boot"

BLACK = (0, 0, 0)
# The front end's ink (ArcaneMenuTheme): the icon's plate.
INK = (13, 13, 16)
GOLD = (246, 186, 104)
GOLD_LIGHT = (255, 228, 176)


def build_splash() -> Image.Image:
    w, h = 1920, 1080
    cx, cy = w // 2, h // 2
    glow = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(glow)
    for r in range(520, 0, -4):
        draw.ellipse((cx - r * 1.35, cy - r, cx + r * 1.35, cy + r), fill=int(120 * (1.0 - r / 520.0) ** 1.8))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    splash = Image.composite(Image.new("RGB", (w, h), (58, 38, 20)), Image.new("RGB", (w, h), BLACK), glow)
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.resize((round(logo.width * 1.2), round(logo.height * 1.2)), Image.LANCZOS)
    splash = splash.convert("RGBA")
    splash.alpha_composite(logo, (cx - logo.width // 2, cy - logo.height // 2))
    splash = splash.convert("RGB")
    for x in range(w):
        assert splash.getpixel((x, 0)) == BLACK and splash.getpixel((x, h - 1)) == BLACK
    for y in range(h):
        assert splash.getpixel((0, y)) == BLACK and splash.getpixel((w - 1, y)) == BLACK
    return splash


def _star(draw: ImageDraw.ImageDraw, center: tuple, long_r: float, short_r: float, inner_r: float, fill: tuple) -> None:
    x0, y0 = center
    points = []
    for k in range(8):
        angle = -math.pi / 2 + k * math.pi / 4
        if k % 2 == 0:
            radius = long_r if k in (0, 4) else short_r
        else:
            radius = inner_r
        points.append((x0 + radius * math.cos(angle), y0 + radius * math.sin(angle)))
    draw.polygon(points, fill=fill)


def build_icon() -> Image.Image:
    # Drawn at 2048 and reduced, for clean edges.
    n = 2048
    c = n / 2
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    pad = int(n * 0.04)
    plate = (pad, pad, n - pad, n - pad)
    draw.rounded_rectangle(plate, radius=int(n * 0.2), fill=INK + (255,))
    # A soft warm core behind the star, kept inside the plate.
    core = Image.new("L", (n, n), 0)
    core_draw = ImageDraw.Draw(core)
    for r in range(int(n * 0.42), 0, -6):
        core_draw.ellipse((c - r, c - r, c + r, c + r), fill=int(90 * (1.0 - r / (n * 0.42)) ** 2))
    core = core.filter(ImageFilter.GaussianBlur(n * 0.02))
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(plate, radius=int(n * 0.2), fill=255)
    core = Image.composite(core, Image.new("L", (n, n), 0), mask)
    icon.paste(Image.new("RGBA", (n, n), (70, 46, 24, 255)), (0, 0), core)
    ring_r = n * 0.33
    draw.ellipse((c - ring_r, c - ring_r, c + ring_r, c + ring_r), outline=GOLD + (255,), width=int(n * 0.028))
    # Small stars where the logo's ring carries them, top and bottom.
    for sy in (c - ring_r, c + ring_r):
        _star(draw, (c, sy), n * 0.075, n * 0.045, n * 0.014, GOLD_LIGHT + (255,))
    # The central star, a lighter core, and its hollow heart.
    _star(draw, (c, c), n * 0.27, n * 0.17, n * 0.045, GOLD + (255,))
    _star(draw, (c, c), n * 0.2, n * 0.12, n * 0.03, GOLD_LIGHT + (255,))
    _star(draw, (c, c), n * 0.07, n * 0.07, n * 0.02, INK + (255,))
    return icon.resize((512, 512), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_splash().save(OUT / "splash.png", optimize=True)
    build_icon().save(OUT / "app_icon.png", optimize=True)
    print(f"wrote {OUT / 'splash.png'} and {OUT / 'app_icon.png'}")


if __name__ == "__main__":
    main()
