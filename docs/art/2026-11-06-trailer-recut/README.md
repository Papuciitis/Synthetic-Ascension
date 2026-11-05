# The Ascension of Syn’Tek — 44-second recut

[Watch the exact recut](trailer-recut.mp4). This is the review draft delivered
after the 5 November cut. The next shoot and edit are described in the
[Claude capture brief](CLAUDE_CAPTURE_BRIEF.md).

The draft runs **44.10 seconds** at 1920×1080, 30 fps, with H.264 video and
48 kHz stereo AAC. SHA-256 is
`7a2966d527dab81b7c7fa3e93ef54c5a2fa0274e27db428cf9885b1c60fd76f2`.
All 1,323 frames decoded. The menu and ordinary gameplay tracks were verified
against `main_menu.mp3` and `in_game.mp3`. This draft uses a music-only mix.

The reveal animates the shipped logo and its timing map over the menu art.
It is a render from those assets. Hub, Beka, and Augment are stills from the
game. Combat combines the [first cut](../2026-11-05-first-trailer/README.md)
with earlier staged guard, S5 melee and ranged elite captures. The exact
sources and offsets are in [edit.json](edit.json). The Ascension dais is in
the Hub shot. The Tree interface needs its own moving take.

The published MP4 plays independently of the editing inputs. To rebuild the
recipe, supply the exact flattened first-cut MP4 that was used as input. Its
SHA-256 is `4b895178a1bce03efb88cf986ade9052fda0971959e06fcc4e70a24818e22ae3`.
The opening and closing plates are included in [inputs](inputs/). Use
Python 3.11+, FFmpeg with `libx264`, and a fresh output directory.

```sh
python3 docs/art/2026-11-06-trailer-recut/render_recut.py \
  "$(command -v ffmpeg)" docs/art/2026-11-06-trailer-recut/edit.json \
  build/trailer-recut-rebuild/recut.mp4 --cut-one /path/to/first-cut.mp4
```

Add `--check` to validate the input paths, first-cut hash and runtime without
rendering. Encoder versions can change the rebuilt file bytes.
