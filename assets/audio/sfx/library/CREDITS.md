# Quiet Alcove book sounds

Six original recordings from **RPG Audio** by **Kenney Vleugels (Kenney.nl)**.

- Primary source and license declaration: https://kenney.nl/assets/rpg-audio
- Downloaded archive: https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip
- License: **Creative Commons Zero (CC0) 1.0 Universal** — https://creativecommons.org/publicdomain/zero/1.0/
- Original archive license text is included as `LICENSE-Kenney.txt`, with trailing blank-line whitespace normalized.
- Retrieved and source license checked on **2026-10-14**.

The bundled license permits personal and commercial use. Attribution is optional;
credit to Kenney is preserved here for provenance.

| Project file | Original archive file | Duration | Intended cue |
| --- | --- | ---: | --- |
| `book_open.ogg` | `Audio/bookOpen.ogg` | 0.154 s | Open a library book |
| `book_close.ogg` | `Audio/bookClose.ogg` | 0.231 s | Close a library book |
| `page_turn_1.ogg` | `Audio/bookFlip1.ogg` | 0.769 s | Longer page rustle |
| `page_turn_2.ogg` | `Audio/bookFlip2.ogg` | 0.430 s | Medium page rustle |
| `page_turn_3.ogg` | `Audio/bookFlip3.ogg` | 0.231 s | Quick page flick |
| `bookmark.ogg` | `Audio/handleSmallLeather.ogg` | 0.338 s | Soft cover/ribbon handling acknowledgment |

## Processing and playback

Audio is copied byte-for-byte from the source archive; only filenames changed.
There is no synthesis, retiming, denoising, gain baking, resampling, or added reverb.
All files are stereo Ogg Vorbis at 48 kHz and are intended as one-shots.

Measured decoded levels below are an objective starting point for a quiet mix.
The suggested playback gains bring the whole-file RMS to about -38 to -40 dBFS,
below the existing UI click's approximately -34 dBFS at its manifest gain.
Whole-file RMS is not a perceptual loudness measurement; adjust in the final game mix.

| File | Source peak | Source RMS | Suggested playback gain |
| --- | ---: | ---: | ---: |
| `book_open.ogg` | -11.54 dBFS | -33.65 dBFS | -5 dB |
| `book_close.ogg` | +0.86 dBFS | -18.74 dBFS | -19 dB |
| `page_turn_1.ogg` | +0.47 dBFS | -29.79 dBFS | -8 dB |
| `page_turn_2.ogg` | -8.27 dBFS | -37.01 dBFS | -1 dB |
| `page_turn_3.ogg` | -4.56 dBFS | -32.13 dBFS | -6 dB |
| `bookmark.ogg` | -11.62 dBFS | -35.73 dBFS | -4 dB |

Vorbis decoding can reconstruct sample peaks above 0 dBFS; the conservative gains
leave at least 7.5 dB of sample peak headroom for every selected cue. The last 5 ms
RMS ranges from -46 to -83 dBFS before playback gain, supporting quiet endings.
Use little or no pitch jitter so the set retains its natural handling character.
