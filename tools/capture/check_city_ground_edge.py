"""Check a native technical road-ownership capture for discontinuous shoulders.

The capture uses magenta for road and cyan for frontage. Read existing pixels;
never modify the screenshot. This catches Compatibility shader lattice jumps
that geometry-only tests cannot observe. It is not a general art-quality test.
"""
import argparse
import json
from pathlib import Path

from PIL import Image


def inspect(path: Path) -> dict:
    image = Image.open(path).convert("RGB")
    width, height = image.size
    pixels = image.load()
    edge = []
    for x in range(round(width * 0.27), round(width * 0.855)):
        rows = []
        for y in range(height):
            red, green, blue = pixels[x, y]
            if red > 38 and blue > 38 and green < min(red, blue) * 0.45:
                rows.append(y)
        if rows:
            edge.append((x, rows[-1]))
    jumps = [(abs(b[1] - a[1]), b[0]) for a, b in zip(edge, edge[1:]) if b[0] == a[0] + 1]
    peak, at_x = max(jumps, default=(height, -1))
    limit = max(3, round(width / 960 * 3))
    enough_samples = len(edge) > width * 0.50
    return {"image": str(path), "width": width, "height": height,
            "sampled_columns": len(edge), "largest_jump_px": peak,
            "largest_jump_at_x": at_x, "limit_px": limit,
            "passed": enough_samples and peak <= limit}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = [inspect(path) for path in args.images]
    encoded = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    raise SystemExit(0 if all(item["passed"] for item in result) else 1)


if __name__ == "__main__":
    main()
