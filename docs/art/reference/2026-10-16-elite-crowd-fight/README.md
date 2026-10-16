# Elites in live crowded combat

`elite-crowd-fight.mp4` is a silent capture of the production Game scene,
including its real terrain, HUD, player input, enemy AI, navigation,
projectiles, hits, deaths and batched rendering. The original 1920×1080
viewport and camera zoom 1.0 are rendered into a 1280×720 window. The video
retains measured wall-clock sample timing; it has not been accelerated to
the requested capture rate. Full-colour opening, midfight and ending PNGs
are also retained.

The seeded test starts with 48 enemies, including 10 elites: each of the
five single modifiers; Armoured + Vampiric, Shielded + Fast and Vampiric +
Fast; Armoured + Splitting + Fast; and a plain gold elite. The triple is a
deliberately forced stress case beyond the normal two-modifier collapse
roll. Ambient spawning and encounter beats are disabled so the population
is controlled. Scripted controller movement/aim and held ranged attack
drive real production combat; god mode protects the player. Enemy stats
are unchanged. This checks readability, not difficulty or performance.

Clean run: 150 recorded frames, 10.0 simulation seconds / 15.603452 wall
seconds, 46 attacks, 55 landed hits including 11 against elites, 17 deaths
including two elites, up to 10 managed projectiles. No save writes or
runtime errors occurred. `capture-info.json` contains per-frame positions,
health, modifier sets, event counts and timestamps; `encoding-info.json`
records video encoding and full decode verification.

## Readability assessment

The cyan protection boundaries, yellow wind ribbons and coloured body
edges remain easy to identify through the crowd. Green seams and the
Armoured + Vampiric red ring remain visible in motion but become subtler
during tight body overlaps and impact flashes. Distinguishing the presence
of an elite is stronger than reading every secondary modifier at once.
The approved art is retained; further tuning should use this capture and
a human playtest rather than the isolated enlarged cards alone.

## Verified fixes in this follow-up

- Existing elite tells respond immediately to live Reduced Motion changes.
  Pulses/trails stop, all static marks remain, the dominant body tint is
  restored, and animation resumes when motion is enabled again. Released
  marks disconnect so replacement modifiers cannot inherit an old tint.
- Elite death bursts have their own allowance of two per frame beside
  the existing ten ordinary puffs. Fodder deaths from the same area attack
  cannot suppress the elite burst; kill accounting and audio count every
  death as before.
- Objective loop emitters are centred on their owner. Wardstone and Exit
  Rite hums follow translated, rotated, scaled and moving owners instead
  of applying the owner's position twice. Audio was checked with the Dummy
  driver; the video itself is silent.

`verification.json` records seven focused suites/audits and their source
hashes. The user approved the crowded fight preview and three fixes on
2026-10-16 and requested a separate commit and push. The first two visual
passes remain separate committed/pushed changes.

Reproduce with Godot 4.7.1 (never during a human playtest):

```text
--path . --audio-driver Dummy --rendering-method gl_compatibility res://tools/dev/EliteCrowdFightPreview.tscn -- --out=<absolute-output-folder>
```

Optional flags: `--visible`, `--seconds=10`, `--fps=15`, `--reduced-motion`.
Raw frames are exported after combat, avoiding PNG compression during the
recording. The first bootstrap attempt exposed an invalid `current_scene`
parent and is excluded: the final harness attaches Game directly beneath
the SceneTree root, and only the clean rerun is packaged here.
