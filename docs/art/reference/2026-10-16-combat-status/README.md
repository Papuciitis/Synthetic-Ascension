# Combat status presentation — 2026-10-16

This folder holds the bounded visual review for the combat-status artwork and
canonical text colours. Both native capture scenes exited cleanly in the
coordinated serial engine slot. All three catalogue pages and the live fight
reported zero save writes and zero failures; the combined logs contain no
runtime errors or warnings.

Review `status-catalog-1.png`, `status-catalog-2.png` and
`status-catalog-3.png` for all 21 new badges. `combat-status-fight.mp4` is the
silent live recording: 145 native frames across 10 simulation seconds and
11.362081 seconds of measured video timing. Combat produced 47 native weapon
fires, 90 landed hits, 14 elite hits and 21 enemy deaths. No elite died during
this capture.

`StatusEffectsPreview.tscn` produces three staged native 1280 × 720 catalogue
pages from the production 1920 × 1080 canvas. Twenty floating examples and
mixed rows use the actual `BattleText` renderer, fonts and generated badges.
The Debt card instead exercises the actual tagged persistent-world-label draw
path in `AscensionRunner`, displaying the static staged sample
`DEBT 24  1.5s`. Its timer is not simulated. The catalogue shows all 21 added
semantic IDs; it does not exercise all 21 underlying build behaviours.

Floating samples use authored callout emphasis 1.35×. The persistent Debt
sample retains its production 15-world-pixel caption and 26-world-pixel badge,
without enlargement. The existing elite mixed row retains each name's original
modifier colour. These are presentation checks, not a gameplay-scale claim for
an enlarged inspection sheet.

`StatusEffectsFightPreview.tscn` extends the existing bounded
`EliteCrowdFightPreview.tscn` setup: the production Game scene, native camera,
terrain, player movement and attacks, enemy AI, projectiles and deaths remain
live. Its 48-enemy encounter includes ten elites and a deliberately forced
three-modifier case beyond the normal two-modifier collapse roll.

Common statuses are applied through real gameplay APIs at scripted times:
burn and bleed through `EnemyStatus`; stun through `EnemyCombat`; ward and
haste through the actual enemy buff methods with authored Chanter and Herald
values; healing lock through the player's existing lock method. This checks
status application and rendering, not natural item/build triggers. The player
uses god mode and scripted controller input. Ambient spawning and encounter
beats are disabled. Already-reviewed elite teaching tips are marked consumed
so the healing-lock illustrated teaching alert can appear within this short
capture. No player profile is selected and save writes are checked.

`status-fight-common-statuses.png` is the unmodified full native source frame
at **3.383333 simulation seconds**: BURNING and BLEEDING remain visible over a
live target, with STUNNED on the ARMOURED + VAMPIRIC elite.
`status-fight-healing-teach.png` is the unmodified frame at **6.466667 simulation
seconds**, showing the actual healing-lock teaching alert and purple badge,
the sealed HP bar and the stunned mixed elite. These are byte-for-byte copies
of existing recorded PNGs, with no new engine run or added labels.

The lock was applied at 1.616667 simulation seconds. Earlier ordinary narrative
tips delayed its queued teaching alert until 6.316667 seconds; the seal's
floating caption appears earlier. The first burn/bleed/stun messages at about
0.6 seconds overlap the narrative panel, so the later application was selected
for the representative still. WARDED and HASTE are visible around 1.083333
seconds in the recording. This queue/overlap limitation is preserved in the
capture rather than hidden by suppressing ordinary narrative feedback.

The real APIs accepted four burn applications, four bleed applications, three
stuns and three ward/haste applications. Recorded state confirms burn and
bleed coexisted, a mixed elite was stunned, the ward and speed multipliers
were active, and the actual illustrated healing teaching alert was visible.

Raw frame sequences stay in the ignored `.godot` capture directory. The final
silent MP4 uses measured wall-clock sample intervals and variable frame rate;
it is not sped up to the requested capture rate. Full final-video decoding and
a decoded-frame inspection passed. The native catalogue pages and opening,
midfight, decoded-midfight, ending and representative status frames were also
visually inspected. This is a readability review, not a balance or performance
benchmark.

`catalog-capture-info.json`, `fight-capture-info.json` and
`status-application-info.json` hold renderer/application observations;
`selected-native-frames.json` records the exact selected source indices,
simulation and wall-clock times. `encoding-info.json` records the silent H.264
VFR encoding and full decoding check. `preview-run-info.json` preserves both
exact commands and their separate APPDATA, LOCALAPPDATA and XDG profile roots,
with immediate restoration of the launcher's environment. Both windows started
offscreen. `preview-capture-verification.json` records final checks and artifact
hashes. Root-owned asset and regression-test records in this folder are separate
from this preview evidence.

JSON and log evidence retain their captured newline bytes through this folder's
Git attributes, so their recorded hashes survive checkout. Source and artwork
index hashes are recorded separately in `candidate-source-manifest.json`;
the shared player snapshot includes four concurrent weapon-factory hunks that
are excluded from this status commit.
