# Boss sound audition candidates, second pass

Prepared 16 October 2026 after the first Sci-fi Sounds selection was rejected
as too electronic/8-bit. This source batch is preserved unchanged. The
**air swish** now supplies the Arcanist fan warning and pylon shot; the
**electric crackle** supplies beam release. The heavy-metal and mining
recordings were rejected as pings and are not integrated. The mine's body
was carried into the shorter edited V3 blast; this two-second V2 version
and the ground-crumble candidate remain unregistered. See the
[current mapping](../CREDITS.md) for exact gains and triggers. Attack
durations are unchanged. These files remain unlistened by the assistant;
technical checks do not establish artistic fit or final mix approval.

| Candidate | Proposed use | Duration | Peak / RMS, dBFS | Source basis |
| --- | --- | ---: | ---: | --- |
| `warning_heavy_metal.wav` | Bulldozer commitment or bracing cue | 0.359 s | -1.09 / -23.62 | Kenney Impact Sounds, heavy metal impact 001; the pack is tagged as foley |
| `slam_mining_impact.wav` | Slam contact | 0.830 s | -0.91 / -19.76 | Kenney Impact Sounds, mining impact 004 |
| `shock_ground_crumble.wav` | Ground-shock material/crackle tail | 1.886 s | -0.01 / -14.63 | qubodup's earth spell, made by reversing and speeding a boiling-water recording |
| `cast_air_swish.wav` | Short caster release, pylon shot or swing accent | 0.197 s | -0.10 / -15.28 | artisticdude's Swishes Sound Pack; the author describes recording swung objects |
| `beam_electric_crackle.wav` | Beam release or pylon energy bolt | 0.666 s | -0.01 / -18.01 | qubodup's electricity spell collection; one-shot, not a tested channel loop |
| `mine_chunky_blast.wav` | Mine detonation or heavy impact option | 2.000 s | -1.87 / -16.59 | First two seconds of Joth's Chunky Explosion, with a 200 ms end fade |

The table records the original audition roles. Ground crumble has a
rising envelope, so compare it as material movement rather than assuming it
will sell the instant of a slam. The air swish fits inside the current
0.22-second fan anticipation if used there. Every file reaches -40 dBFS within
32 ms; these numerical onsets do not establish perceptual timing. None calls
for lengthening an attack. Preview files retain source level; active manifest
gains are documented in the parent mapping. Simultaneous mine detonations
keep a global per-ID request limit.

## Sources and licenses

- **Kenney — Impact Sounds 1.0**: [official page](https://kenney.nl/assets/impact-sounds),
  [official archive](https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip).
  CC0 1.0. Original archive license preserved byte-for-byte in
  `LICENSE-Kenney-impact-sounds.txt`. This is a different pack from the
  rejected Sci-fi Sounds selection.
- **Iwan “qubodup” Gabovitch — Earth Element Magic Spell**:
  [author's submission](https://opengameart.org/content/earth-element-magic-spell),
  [lossless original](https://opengameart.org/sites/default/files/Earth%20Element%20Magic%20Spell_0.flac).
  CC0 1.0. Only full-recording format conversion was applied.
- **artisticdude — Swishes Sound Pack**:
  [author's submission](https://opengameart.org/content/swishes-sound-pack),
  [original archive](https://opengameart.org/sites/default/files/swishes.zip).
  CC0 1.0. Delivered `swishes/swish-9.wav` as PCM16 WAV without changing
  duration, pitch, level or channel count.
- **Iwan “qubodup” Gabovitch — Ice & Electricity Magic**:
  [author's submission](https://opengameart.org/content/ice-electricity-magic),
  [original archive](https://opengameart.org/sites/default/files/qubodupIceAndElectricitySpells.7z),
  [creator](https://opengameart.org/users/qubodup).
  **[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)**. Credit:
  “Ice and Electricity Magic by Iwan 'qubodup' Gabovitch.”
  `qubodupElectricityDamage01.flac` was converted to PCM16 WAV with no other
  changes. Original attribution/source notes are preserved byte-for-byte in
  `LICENSE-qubodup-ice-electricity.txt`. Retain this credit and license link
  wherever this candidate is shipped.
- **Joth — Chunky Explosion**:
  [author's submission](https://opengameart.org/content/chunky-explosion),
  [original MP3](https://opengameart.org/sites/default/files/Chunky%20Explosion.mp3).
  CC0 1.0. The source was cut to its first 2.000 seconds and
  faded linearly to zero over the final 0.200 seconds, then saved as PCM16 WAV.

[CC0 1.0 dedication](https://creativecommons.org/publicdomain/zero/1.0/).
No registration, paid pack or account access was used. Original archives and
unused recordings remain outside the repository.

## Technical checks

`sources.json` records exact source URLs, archive/member hashes, delivered
hashes, source and delivered durations, sample rates, channel counts, peaks,
RMS and onset thresholds. Decoding/conversion used PySoundFile 0.13.1 with
libsndfile 1.2.2. No synthesis, resampling, EQ, pitch changes or added layers
were applied; only the blast received the explicitly documented trim/fade.

All six delivered recordings have zero decoded samples at or beyond the
signed 16-bit full-scale threshold. This is a numerical clipping screen,
not a listening verdict or proof against distortion already in a source.
Two alternative explosion/Tesla sources were rejected because decoded
samples reached full scale; a slower spell was rejected because its onset
missed an immediate release. These rejected recordings are not copied here.
