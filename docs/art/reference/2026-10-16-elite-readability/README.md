# Secondary elite tells, combat text and illustrated badges

The user approved this pass after the crowded-fight review, with a final
request that each name in a mixed-modifier announcement retain its own
original tell colour. The secondary Vampiric tell is an outward red collar
with a stronger opacity floor and a dark separation edge. Splitting has wider lime branches
and a dark underlay. Dominant sheen colours and enemy combat statistics are
unchanged.

Floating named messages use the HUD's Cinzel caption font; damage figures
use its Cinzel figure font. Top-centre guidance uses the same caption face.
Five generated, coloured modifier badges appear beside elite announcements
and the matching queued teaching alert. Semantic modifier IDs select the
badges directly; words are not parsed and font symbols do not substitute for
artwork. The API can carry badges on future named effects without adding
new status application messages in this pass. Mixed announcements now use
each modifier's canonical tell colour for its own name, with neutral ivory
separators; badges keep their authored colours. Ordinary callouts retain
their caller-supplied colour. No words are parsed to infer a modifier.

## Actual game pixels

The original clip and before/after images below are the approved preview
before the final per-name colour correction. They are preserved as reviewed;
the final rendered colour regression and verification record cover that
small follow-up separately.

- `modifier-name-colours.png`: final rendered double/triple announcement
  glyphs in steel/red and cyan/lime/yellow, using the real text renderer and
  generated badges. Transparent 640 × 480 test viewport; original 15px
  Cinzel glyphs, with no image painting or mockup text added.
- `elite-readability-crowd.mp4`: silent live production combat at native
  1280 × 720. The opening shows the illustrated Armoured teaching alert,
  single modifiers and multiple-modifier announcement rows. The middle
  shows the stronger red collar and green seams through the crowded fight.
- `elite-readability-opening.png`, `elite-readability-midfight.png`, and
  `elite-readability-ending.png`: full-colour stills from that recording.
- `elite-readability-before.png` and `elite-readability-after.png`: a
  controlled six-actor comparison at the same native game scale. The before
  was recorded before product edits in this pass; both captures use the
  same fixture and actor positions, including two- and three-modifier cases.
- `elite-readability-before-after-2x.png`: the first three staged cases
  cropped from those screenshots and enlarged exactly 2× with nearest
  neighbour sampling. These are captured game pixels, not a painted mockup.

Both fixtures render the production 1920 × 1080 game canvas into a
1280 × 720 window: one world pixel becomes two thirds of an image pixel at
camera zoom 1.0. The staged fixture uses actual Brute EnemyActors, the real
batched renderer at z=10, actual modifier marks and real promotion popups.
Actor movement/combat alone is frozen there so tell differences are easy
to inspect. Both staged runs captured 72 frames and wrote no saves.

## Live encounter and timing

The live recording reuses `tools/dev/EliteCrowdFightPreview.tscn` without
changing its committed setup. Seed 1610202607 starts 48 enemies, including
10 elites: five single modifiers, Armoured + Vampiric, Shielded + Fast,
Vampiric + Fast, a forced Armoured + Splitting + Fast stress case, and one
plain gold elite. The triple exceeds the normal two-modifier collapse roll.

Real production terrain, HUD, enemy AI, navigation, player attacks,
projectiles, hits and deaths remain live. Ambient population and encounter
beats are disabled. Scripted movement and aiming, held ranged attack and
player god mode make the scenario controlled. This is a readability review,
not a difficulty or performance benchmark; seeded recordings are not
claimed to have identical frame-by-frame combat outcomes.

The clean run captured 151 frames over 10.016667 simulation seconds and
20.423689 wall seconds: 46 attacks, 56 landed hits including four on elites,
21 enemy deaths, no elite deaths, and up to nine managed projectiles.
There were zero profile save writes, capture failures, runtime errors or
warnings. `crowd-capture-info.json` records each sampled frame's elapsed
time, surviving elites, modifiers, positions, health and event counts.

The MP4 retains the measured wall-clock sample intervals with a variable
frame rate. It has not been accelerated to the requested 15 fps. Raw Images
are collected before PNG export, so PNG encoding does not stall recorded
combat. `encoding-info.json` records final encoding details. The delivered
MP4 was fully decoded without errors, and its decoded middle frame was
exported and inspected separately.

## Readability assessment

The red collar remains visible on the steel Brute without relying on a red
body sheen. Lime branches extend beyond the armour silhouette and remain
identifiable in a tight group. The painted badge colours let the player
read mixed modifiers beside their matching Cinzel labels; the top teaching
alert uses the same illustrated vocabulary. Heavy overlap still limits
how much of every body can be seen at once, so the live clip and native
stills are retained alongside the enlarged comparison.

Reproduce with Godot 4.7.1, without a simultaneous human playtest:

```text
--path . --audio-driver Dummy --rendering-method gl_compatibility res://tools/dev/EliteReadabilityPreview.tscn -- --out=<absolute-staged-output>
--path . --audio-driver Dummy --rendering-method gl_compatibility res://tools/dev/EliteCrowdFightPreview.tscn -- --out=<absolute-live-output>
```

The new staged fixture also supports `--reduced-motion`, `--still-only`,
and `--interactive`. Raw frame sequences stay under `.godot/` rather than
being imported as game resources. The user requested committing and pushing
this pass together with the per-name colour correction, without another
visual approval step.
