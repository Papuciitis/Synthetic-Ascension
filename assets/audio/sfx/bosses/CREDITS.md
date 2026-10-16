# Boss sounds

Five recordings by **Kenney**, from the official [Sci-fi Sounds 1.0](https://kenney.nl/assets/sci-fi-sounds) pack, retrieved 16 October 2026. The official page and original archive license explicitly declare **CC0**. The original license is preserved byte-for-byte in `LICENSE-Kenney-sci-fi-sounds.txt`. Attribution is optional; provenance is retained here.

- [Official archive](https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip)
- [CC0 1.0 dedication](https://creativecommons.org/publicdomain/zero/1.0/)
- `sources.json` records archive, original license, original recording and delivered WAV SHA-256 hashes, plus decoder and numerical checks.

## Delivered files

| Delivered file | Original archive member | Duration | Decoded WAV peak / RMS, dBFS | Manifest gain / candidate starting gain |
| --- | --- | ---: | ---: | ---: |
| `warning_metal.wav` | `Audio/impactMetal_000.ogg` | 0.635 s | -0.94 / -22.07 | -13 dB |
| `arcane_charge.wav` | `Audio/forceField_000.ogg` | 0.954 s | -0.89 / -11.53 | -15 dB |
| `beam_release.wav` | `Audio/laserLarge_000.ogg` | 0.677 s | -0.94 / -17.18 | -13 dB |
| `pylon_shot.wav` | `Audio/laserSmall_000.ogg` | 0.239 s | -5.65 / -21.62 | -13 dB |
| `mine_burst.wav` | `Audio/explosionCrunch_000.ogg` | 0.777 s | -0.96 / -13.76 | -17 dB |

All files are PCM 16-bit WAV, with source sample rate, channels and decoded frame count preserved. Conversion used PySoundFile 0.13.1 / libsndfile 1.2.2, installed only in a temporary analysis directory. No gain, trims, filters, resampling, synthesis or added layers were applied. WAV follows the existing action-cue workaround for Godot 4.7.1 importing some Ogg files. Engine imports and loaded-resource checks are handled separately during integration.

Four recordings are registered as one-shot SFX IDs: `boss_warning` (`warning_metal.wav`, -13 dB), `boss_beam_release` (`beam_release.wav`, -13 dB), `boss_pylon_shot` (`pylon_shot.wav`, -13 dB), and `boss_mine_burst` (`mine_burst.wav`, -17 dB). Each uses the SFX bus and zero pitch jitter. Attack-boundary playback is integrated separately in the boss actors and hazards.

All five recordings remain **unlistened**, chosen from source names and technical envelope checks. Human listening and in-game mix checks are still needed; numerical RMS is not perceived loudness. `arcane_charge.wav` is an unregistered candidate, and its -15 dB value is only a starting suggestion.

`arcane_charge.wav` lasts 0.954 seconds, longer than the current fan's 0.22-second warning. Do not lengthen an attack merely to fit this recording; use it for a longer charge/emitter cue, fade it through an owner-controlled voice, or choose another cue after listening. `beam_release.wav` is a one-shot, not a tested seamless loop.

The existing project-generated `enemies/multikill_thump.wav` and `enemies/elite_down.wav` are available for physical impact and defeat/release respectively; their recipes are in `tools/design/build_sfx_procedural.py`. No duplicate copies were added here. Avoid one detonation cue per mine or one voice per projectile in a volley: play at the pattern level or apply a global per-ID cooldown.
