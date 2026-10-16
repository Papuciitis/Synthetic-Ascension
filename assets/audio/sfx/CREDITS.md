SFX Credits / Licenses
=====================

This project includes a small curated subset of sounds taken from the packs you provided.

CC0 (no attribution required, kept here for reference)
-----------------------------------------------------
- "Beeps" pack (beeps.zip) — OpenGameArt — CC0
- "UI Sounds" (ui_sounds.zip) — OpenGameArt — CC0
- "50 CC0 Sci-Fi SFX" (sci-fi-sfx.zip) — OpenGameArt — CC0
- "Impacts/Gun/sfx" (impacts.zip) — OpenGameArt — listed as free; treated as CC0 in your source list
- "100 CC0 metal and wood SFX" (100-CC0-wood-metal-SFX.zip) — OpenGameArt — CC0
- "Thwack Sounds" (thwack-1.0.zip) — OpenGameArt — CC0
- "Superpowers asset packs sound effects" (superpowers-asset-packs-soundeffects.zip) — OpenGameArt / Sparklin Labs — CC0

If you decide to use the optional CC-BY packs later (Electric Sound Library, Mechanical Pack),
keep their attribution text in this file and include required attributions in your release notes.

Player movement and injury cues (2026-10-16)
------------------------------------------

- `actions/dash.wav` — Kenney RPG Audio, `Audio/cloth2.ogg`, CC0 1.0.
- `actions/hurt.wav` — Kenney Impact Sounds, `Audio/impactSoft_medium_000.ogg`, CC0 1.0.
- Exact source URLs, archive/file hashes, original license texts and unchanged
  PCM conversion details are in `actions/CREDITS.md` and `actions/sources.json`.

Boss attack cues (2026-10-16)
---------------------------

- **Ice and Electricity Magic by Iwan 'qubodup' Gabovitch** supplies the
  boss beam-release recording, `bosses/candidates_v2/beam_electric_crackle.wav`.
  [Author's source page](https://opengameart.org/content/ice-electricity-magic),
  [creator](https://opengameart.org/users/qubodup),
  **[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)**.
  The original `qubodupElectricityDamage01.flac` was converted to PCM16 WAV;
  duration, level, pitch and channels are unchanged. Preserve this attribution
  and license link in distributions containing the recording. Original source
  notes are in `bosses/candidates_v2/LICENSE-qubodup-ice-electricity.txt`.
- The release packager automatically ships root `THIRD_PARTY_NOTICES.txt`
  beside the executable/PCK and covers it in `SHA256SUMS.txt`. Export
  presets also include the root notice and individual audio credits/license
  files in packed data. Manually assembled releases must retain the same
  readable notice beside the game.
- The warning, physical impact and mine are edited CC0 recordings from
  Kenney's Impact Sounds, qubodup's Earth Element Magic Spell and Joth's
  Chunky Explosion. The caster and pylon use artisticdude's CC0 Swishes pack.
- [Current effect-to-recording mapping](bosses/CREDITS.md), exact sources,
  processing recipes, hashes and individual license records are under
  `bosses/`. The previous Sci-fi Sounds selection is retained for provenance
  and is no longer registered as these attack cues.
