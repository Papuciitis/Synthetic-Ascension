# Player movement and injury foley

Two recordings by **Kenney**, retrieved from the official pack downloads on
**16 October 2026**. Both pack pages declare **Creative Commons Zero
(CC0 1.0 Universal)**. The included original license texts are preserved as
`LICENSE-Kenney-rpg-audio.txt` and `LICENSE-Kenney-impact-sounds.txt`, with
line endings and trailing whitespace normalized. Attribution is optional;
the creator and exact sources remain recorded here.

| Local WAV | Original archive filename | Official pack / license declaration | Cue |
| --- | --- | --- | --- |
| `dash.wav` | `Audio/cloth2.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio), 1.0 | Restrained cloth movement when an accepted dash starts |
| `hurt.wav` | `Audio/impactSoft_medium_000.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds), 1.0 | Short soft impact when the player actually loses HP |

- [CC0 1.0 legal dedication](https://creativecommons.org/publicdomain/zero/1.0/)
- [Official RPG Audio archive](https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip)
- [Official Impact Sounds archive](https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip)
- Archive, original recording, original license and delivered WAV SHA-256
  hashes are recorded per file in `sources.json`.

## Conversion and mix

Recordings were decoded silently with the already installed FFmpeg
4.4.1-Jellyfin to **16-bit stereo PCM WAV**, preserving sample rate and all
decoded frames. Command: `ffmpeg -i ORIGINAL.ogg -c:a pcm_s16le LOCAL.wav`.
No cuts, gain baking, resampling, filtering, synthesis or added layers were
applied. WAV follows the interface recordings' workaround for a reproducible
Godot 4.7.1 crash importing some Ogg files.

| File | Length | Sample rate | Source decoded peak / RMS | Manifest gain | Peak / RMS at that gain |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dash.wav` | 0.436 s | 48 kHz | -7.94 / -28.93 dBFS | -10 dB | -17.94 / -38.93 dBFS |
| `hurt.wav` | 0.132 s | 44.1 kHz | -0.96 / -14.82 dBFS | -18 dB | -18.96 / -32.82 dBFS |

Whole-recording RMS is an objective starting point, not perceptual loudness.
No audible preview was played during this overnight pass; final balance
against weapons, music and the heartbeat needs a human listen.

Dash playback is positional at departure, once per accepted dash event.
Injury is non-positional and throttled to one cue per 220 ms. Only positive
actual HP loss qualifies; absorbed, evaded and invulnerable hits and
intentional HP payments do not. Both cues use the existing **SFX** bus and
its Sound Effects volume/mute settings.
