# Boss sounds

## Current attack mapping — 16 October 2026

The initial Sci-fi Sounds selection was replaced after the user's listening
feedback. The weighted warning/impact and compact mine are edited recordings;
the air swish and electrical crackle retain their V2 source audio unchanged.
These are the implemented choices, with conservative starting mix gains.
The assistant has not auditioned them; final in-game mix approval remains
with the user.

| Effect and exact trigger | SFX ID | Recording | Duration | Gain |
| --- | --- | --- | ---: | ---: |
| Bulldozer accepts a slam/shockwave, or its S5 committed rush | `boss_warning` | [Weighted brace](candidates_v3/warning_weighted_brace.wav) | 0.480 s | -8 dB |
| Arcanist fan; S5 blink or mine planting anticipation | `boss_cast_warning` | [Air swish](candidates_v2/cast_air_swish.wav) | 0.197 s | -15 dB |
| Bulldozer slam, ground-shock release or charge-end impact | `boss_slam_impact` | [Weighted thud](candidates_v3/slam_weighted_thud.wav) | 0.720 s | -8 dB |
| Accepted focused/split volley releases its complete bolt batch | `boss_fan_release` | [Electric crackle](candidates_v2/beam_electric_crackle.wav), pitch 1.1 | 0.606 s playback | -12 dB |
| Committed rush/breach actually begins moving | `boss_rush_release` | [Weighted thud](candidates_v3/slam_weighted_thud.wav), pitch 0.95 | 0.758 s playback | -11 dB |
| Beam moves from anticipation into its active sweep | `boss_beam_release` | [Electric crackle](candidates_v2/beam_electric_crackle.wav) | 0.666 s | -10 dB |
| Pylon releases a projectile at its muzzle | `boss_pylon_shot` | [Air swish](candidates_v2/cast_air_swish.wav) | 0.197 s | -18 dB |
| Mine detonates at its planted position | `boss_mine_burst` | [Compact blast](candidates_v3/mine_compact_blast.wav) | 0.660 s | -10 dB |
| Canonical boss death, once per actual defeated body | `boss_defeat` | [Weighted thud](candidates_v3/slam_weighted_thud.wav), tank pitch 0.78 / mage pitch 1.0 | 0.923 / 0.720 s playback | -6 dB |

All nine definitions use the SFX bus, zero pitch jitter and one-shot playback.
Boss one-shots now have eight reserved positional voices, still controlled by
the user's SFX setting. Ordinary weapon/death saturation cannot steal them;
within the boss pool a pylon shot cannot displace a major warning or phase cue.
Recordings retain their delivered durations; the S5 teaching kit requests them
at its accepted anticipation and actual release boundaries. Physical impacts
and mine detonations retain the existing 120 ms per-ID limit; pylon releases
retain 150 ms. The physical impact recording is shared by slam, shock and the
charge endpoint. The longer V2 ground-crumble candidate is not registered.
These attack changes do not replace the separate multikill event sound.

**Beam attribution:** “Ice and Electricity Magic by Iwan 'qubodup' Gabovitch.”
[Author's source page](https://opengameart.org/content/ice-electricity-magic),
[creator](https://opengameart.org/users/qubodup),
**[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)**.
`qubodupElectricityDamage01.flac` was converted to PCM16 WAV without other
audio edits. Original source and attribution notes are preserved in
`candidates_v2/LICENSE-qubodup-ice-electricity.txt`. Preserve this credit,
source and license link wherever the recording is distributed.

`tools/package_release.ps1` automatically copies the root
`THIRD_PARTY_NOTICES.txt` beside the release executable/PCK and includes it
in `SHA256SUMS.txt`. Every existing export preset also includes that notice
and the individual audio credits/license text in the packed project data.
Manually assembled releases must retain the readable root notice beside
their executable and data package.

The other current recordings are CC0. Their exact sources, processing,
licenses and hashes are in [V2 credits](candidates_v2/CREDITS.md),
[V3 credits](candidates_v3/CREDITS.md), the adjacent `sources.json` files,
and `candidates_v3/recipe.json`. The rejected V2 metal/mining pings are not
part of any active definition.

## Original selection — superseded

Five recordings by **Kenney**, from the official [Sci-fi Sounds 1.0](https://kenney.nl/assets/sci-fi-sounds) pack, retrieved 16 October 2026. The official page and original archive license explicitly declare **CC0**. The original license is preserved byte-for-byte in `LICENSE-Kenney-sci-fi-sounds.txt`. Attribution is optional; provenance is retained here.

- [Official archive](https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip)
- [CC0 1.0 dedication](https://creativecommons.org/publicdomain/zero/1.0/)
- `sources.json` records archive, original license, original recording and delivered WAV SHA-256 hashes, plus decoder and numerical checks.

### Preserved original files

| Delivered file | Original archive member | Duration | Decoded WAV peak / RMS, dBFS | Manifest gain / candidate starting gain |
| --- | --- | ---: | ---: | ---: |
| `warning_metal.wav` | `Audio/impactMetal_000.ogg` | 0.635 s | -0.94 / -22.07 | -13 dB |
| `arcane_charge.wav` | `Audio/forceField_000.ogg` | 0.954 s | -0.89 / -11.53 | -15 dB |
| `beam_release.wav` | `Audio/laserLarge_000.ogg` | 0.677 s | -0.94 / -17.18 | -13 dB |
| `pylon_shot.wav` | `Audio/laserSmall_000.ogg` | 0.239 s | -5.65 / -21.62 | -13 dB |
| `mine_burst.wav` | `Audio/explosionCrunch_000.ogg` | 0.777 s | -0.96 / -13.76 | -17 dB |

All files are PCM 16-bit WAV, with source sample rate, channels and decoded frame count preserved. Conversion used PySoundFile 0.13.1 / libsndfile 1.2.2, installed only in a temporary analysis directory. No gain, trims, filters, resampling, synthesis or added layers were applied. WAV follows the existing action-cue workaround for Godot 4.7.1 importing some Ogg files. Engine imports and loaded-resource checks are handled separately during integration.

These five original recordings are no longer registered as boss attack
cues. The table's former gains are historical; the current mapping above
is the source of truth. Original files remain unchanged for provenance.

All five recordings remain **unlistened by the assistant**, originally chosen
from source names and technical envelope checks. The user rejected the
initial selection as too electronic/8-bit. Numerical RMS is not perceived
loudness. `arcane_charge.wav` remains unregistered.

`arcane_charge.wav` lasts 0.954 seconds, longer than the current fan's 0.22-second warning. Do not lengthen an attack merely to fit this recording; use it for a longer charge/emitter cue, fade it through an owner-controlled voice, or choose another cue after listening. `beam_release.wav` is a one-shot, not a tested seamless loop.

The project-generated `enemies/multikill_thump.wav` and `enemies/elite_down.wav`
retain their separate combat-event roles; their recipes are in
`tools/design/build_sfx_procedural.py`. Boss physical impacts now request the
dedicated weighted-thud definition instead of the procedural multikill sound.
