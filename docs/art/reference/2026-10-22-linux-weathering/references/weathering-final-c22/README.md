# Weathering final candidate (stage 4, Claude)

Branch `claude/c22-weathering` @ `ecb568f2c32acb8c0fcb8c8cfd53b89ab0f4736f`, base d14d71c3, 8 commits; no file overlap with production 29337639 and `git merge-tree` is clean.

## Commits

- `ecb568f2` art: raise weathering into the brief's readable range
- `d81cce4d` fix: draw facade stains in the wall field's own transform domain
- `8a9114f9` fix: sample wall damp and roof lichen with gradients outside their bands
- `3b90f4c0` chore: record the stain wall shader's resource uid
- `67759db9` fix: keep weathering on real sources and inside the single facade fade
- `d44fad9d` art: adopt the lead's restrained per-theme atmosphere values
- `c8d82d5d` feat: weather walls and roofs from their physical causes
- `8c0e58f7` art: rasterise the lead's weathering masks for the runtime

## Runtime sha256 at the candidate

- `scenes/world/buildings/weathering/CityWeathering.gd` b5691e78901b5691…
- `scenes/world/buildings/weathering/facade_stain.gdshader` ae5ae629bf71aee4…
- `scenes/world/buildings/weathering/facade_damp.gdshaderinc` 4d09af2c97b99f8e…
- `scenes/world/buildings/weathering/facade_plinth.gdshader` ed17bf1bbd8fb8f7…
- `scenes/world/buildings/facade_wall.gdshader` 235b8b69eee14b61…
- `scenes/world/buildings/roof.gdshader` b387b31e555022c2…
- `scenes/world/buildings/CityFacadeComposer.gd` fec134c3ebcd7ab8…
- `core/systems/world/atmosphere/WorldAtmosphere.gd` d58c23cdb68aed1b…
- `core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd` 3d39d1f3636544fa…
- `project.godot` 46713b6ec35b5e2b…
- `assets/world/weathering/v1/wall_base_damp.png` f3f33d5c201cee47…
- `assets/world/weathering/v1/runoff_streaks.png` 179617d64d5143f7…
- `assets/world/weathering/v1/roof_lichen.png` 0f8a5ad9d6f5d0ea…

## Checks (all through guarded_engine, 70 C start)

| Check | Candidate | RED |
|---|---|---|
| CityWeatheringTest (headless) | 32203/0 at ecb568f2; 25907/0 at d81cce4d | 25095/812 with the 3b90 stain files: exactly the new identity/decode checks |
| CityWeatheringSeamRenderTest (native GL, UHD 620) | 145/0 (`/var/tmp/sa-c22/seam/green3`) | 61/84 (`/var/tmp/sa-c22/seam/red`, `failures.txt`): 56 ownership failures (alpha off by 48-64 steps on stain edges at partial fade), 28 zero-strength RGB |

The seam fixture renders twin transparent SubViewports with snap on: the real `_wall_field` reference against cut plus `draw_run`. Fractional sills sit at bottom-116.53875 and .75. It covers fades .5/.25/1, zooms 1/.75/1.25/2 with a fractional camera, dry and canal damp, and warm and pale walls. Alpha may differ by at most 1 step, and RGB at strength 0 by at most 2 steps.

Its first two GREEN runs exposed a real pre-existing bug. Every wall had a faint damp line at 64 px above the foot: implicit derivatives inside the damp band's per-pixel early return, plus the repeating mask wrapping in v. 8a9114f9 fixes both, and applies the same derivative fix to roof lichen.

## Native surveys (CitySegmentSurvey, seed 16102026, route 1 + kit 2 points)

The brief's four contexts are in `/var/tmp/sa-c22/compare/<ctx>/{before,after}`. Each directory has `provenance.json`: command, commit, dirty inputs, scoped sha256, output sha256 and thermal.

- **before** = production d14d71c3 in /tmp/sa-wp2-evidence (S9A captured 02:56 with root's ACK; tracked status clean before and after).
- **after** = ecb568f2 values. All runs completed with 0 diagnostics, peak 73-84 C.
- `after-untuned` = 3b90-era values, kept for comparison. Its S7B attempt stopped at 94 C and is a gap.

Contexts: s2 (S2 household), s6a (industrial_cutthrough), s7b (canal_services), s9a (outer_wall).

At gameplay zoom the damp reads as a restrained darker band at the wall foot: low in S2, greener and stronger on the S7B canal walls. Sill runoff appears below only a share of silled windows. The masks and stains have no per-frame texture writes, no readback and no fullscreen pass. Only the seam fixture reads back.

## Not claimed

- No GPU timing: that is root's stage-4 cost queue.
- Soot is intent only: there is no operating vent owner yet.
- Lichen is checked by source and compile only (the surveys render roofs with 0 diagnostics). It was not judged per theme up close.
- Captures are 1280x720 survey frames, not the 960/1080 pair named in the brief.
