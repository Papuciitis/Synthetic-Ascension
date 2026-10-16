# Boss sound listening drafts, third pass

Prepared 16 October 2026 from the user's listening feedback: the warning and
slam were heard as pings; the mine body was useful but its tail was too long
and perhaps too realistic. V2 source files remain unchanged. These three
edited recordings are now registered for physical warning, physical impact
and mine detonation. See the [current mapping](../CREDITS.md) for exact
triggers and starting mix gains. The assistant has not auditioned these
recordings; final in-game mix approval remains with the user.

| File | Intended audition | Length | Peak / RMS, dBFS |
| --- | --- | ---: | ---: |
| `warning_weighted_brace.wav` | A low physical commitment cue with a soft body and restrained material movement | 0.480 s | -5.00 / -20.04 |
| `slam_weighted_thud.wav` | A heavier impact with the mine source under the soft impact and a short crumble layer | 0.720 s | -3.00 / -20.13 |
| `mine_compact_blast.wav` | The accepted mine source, cut to a compact body with a controlled end | 0.660 s | -3.80 / -20.56 |

The rejected heavy-metal and mining recordings are absent from these mixes.
Low-pass filtering reduces bright ringing, and explicit fades stop the tails.
The mine also removes very low rumble and the sharpest high frequencies,
aiming for a compact game effect. That is the processing intent, not a
listening verdict. None changes an attack's timing.

## Sources

All three sources are **[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)**,
which permits editing and redistribution. Attribution is retained for
provenance:

- **Kenney, Impact Sounds 1.0** —
  [official page](https://kenney.nl/assets/impact-sounds),
  [original archive](https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip).
  Only `Audio/impactSoft_heavy_003.ogg` is used here. The archive's license is
  preserved byte-for-byte in `LICENSE-Kenney-impact-sounds.txt`.
- **Iwan “qubodup” Gabovitch, Earth Element Magic Spell** —
  [author's submission](https://opengameart.org/content/earth-element-magic-spell),
  [lossless original](https://opengameart.org/sites/default/files/Earth%20Element%20Magic%20Spell_0.flac).
  The author derived this material from a boiling-water recording.
- **Joth, Chunky Explosion** —
  [author's submission](https://opengameart.org/content/chunky-explosion),
  [original MP3](https://opengameart.org/sites/default/files/Chunky%20Explosion.mp3).
  This is the same source the user found promising in V2, excerpted directly
  from the original download so the previous two-second fade is not baked
  into a second edit.

## Reproducible processing and checks

`recipe.json` specifies every source excerpt, filter, relative layer level,
envelope, fade and output normalization. `sources.json` preserves the original
source/archive hashes and delivered WAV hashes. Processing uses source
recordings/effects, mono downmix, 44.1 kHz delivery, linear resampling,
windowed FIR filtering and envelope/layer editing. No new oscillator, pitch
shift, bitcrushing, retro tone, compressor or clipping effect was added.

Delivery is mono PCM16 WAV. All three drafts decode with the documented
frame counts and contain zero samples at the full-scale threshold. Peaks
retain at least 3 dB of numerical headroom. The measured -40 dBFS onsets are
within 0.4 ms. These numerical checks do not establish perceived weight,
distortion, realism or suitability in the game. The active manifest points
to these unchanged delivered WAV files; selecting them does not alter any
attack duration or trigger frame.
