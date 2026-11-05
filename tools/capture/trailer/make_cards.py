#!/usr/bin/env python3
"""Title card and pending-take placeholder cards for the first trailer.

usage: make_cards.py <project root> <out dir> [placeholder-id "line 1" "line 2" ...]

Renders 1920x1080 RGB PNGs with the game's own fonts (Cinzel Decorative for
the title, Marcellus SC / IBM Plex Sans Condensed for small type) in the
palette of the menu logo: parchment letters with ember accents on a dark
vignette. Placeholders are deliberately loud (diagonal stripes, PLACEHOLDER
banner) so a pending pickup can never pass for a finished shot.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
PARCHMENT = (238, 226, 203)
EMBER = (226, 138, 58)
INK = (12, 9, 7)


def font(root: Path, rel: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(root / rel), size)


def vignette() -> Image.Image:
    # Warm centre falling to black, matching the boot splash.
    base = Image.new("RGB", (W, H), INK)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.18, H * 0.12, W * 0.82, H * 0.88), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    warm = Image.new("RGB", (W, H), (46, 30, 18))
    return Image.composite(warm, base, glow)


def centred(draw: ImageDraw.ImageDraw, y: float, text: str, face, fill, spacing: int = 0) -> tuple:
    width = draw.textlength(text, font=face) + spacing * (len(text) - 1)
    x = (W - width) / 2
    for ch in text:
        draw.text((x, y), ch, font=face, fill=fill, anchor="ls")
        x += draw.textlength(ch, font=face) + spacing
    return (W - width) / 2, (W + width) / 2


def title(root: Path) -> Image.Image:
    card = vignette()
    face = font(root, "assets/fonts/cinzel_decorative/CinzelDecorative-Bold.ttf", 128)
    small = font(root, "assets/fonts/marcellus_sc/MarcellusSC-Regular.ttf", 44)
    # Soft ember bloom behind the letters, then the letters themselves.
    bloom = Image.new("RGB", (W, H), (0, 0, 0))
    centred(ImageDraw.Draw(bloom), 600, "ASCENSION", face, EMBER, 10)
    centred(ImageDraw.Draw(bloom), 452, "SYNTHETIC", small.font_variant(size=76), EMBER, 26)
    bloom = bloom.filter(ImageFilter.GaussianBlur(18))
    card = Image.blend(card, Image.composite(bloom, card, bloom.convert("L")), 0.55)
    draw = ImageDraw.Draw(card)
    centred(draw, 452, "SYNTHETIC", small.font_variant(size=76), PARCHMENT, 26)
    left, right = centred(draw, 600, "ASCENSION", face, PARCHMENT, 10)
    # Ornament rules, as on the logo: thin ember lines with a centre star.
    for y in (486, 650):
        draw.line((left + 40, y, W / 2 - 60, y), fill=EMBER, width=3)
        draw.line((W / 2 + 60, y, right - 40, y), fill=EMBER, width=3)
        cx = W / 2
        draw.polygon([(cx, y - 14), (cx + 7, y), (cx, y + 14), (cx - 7, y)], fill=EMBER)
    return card


def placeholder(root: Path, ident: str, lines: list) -> Image.Image:
    card = Image.new("RGB", (W, H), (28, 24, 22))
    draw = ImageDraw.Draw(card)
    for x in range(-H, W, 90):
        draw.line((x, H, x + H, 0), fill=(52, 44, 38), width=26)
    head = font(root, "assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-SemiBold.ttf", 96)
    body = font(root, "assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Regular.ttf", 50)
    draw.rectangle((0, 330, W, 470), fill=(196, 40, 40))
    draw.text((W / 2, 400), f"PLACEHOLDER {ident}", font=head, fill=(255, 255, 255), anchor="mm")
    for i, line in enumerate(lines):
        draw.text((W / 2, 560 + i * 70), line, font=body, fill=(240, 232, 220), anchor="mm")
    return card


def main() -> None:
    root, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    title(root).save(out / "title.png")
    if len(sys.argv) > 3:
        placeholder(root, sys.argv[3], sys.argv[4:]).save(out / f"placeholder-{sys.argv[3]}.png")
    print("cards ->", out)


if __name__ == "__main__":
    main()
