# First-city development prototype — 2026-10-16

## Human direction

Each earned increase is one choice among alternatives, and choices accumulate across attempts. The pool includes health, armor, carrying space, augment training, Haste, movement speed, Luck, Power, native weapon reach and native attack size. The human then clarified that meta development also means conditional rules: choosing a perk now enables additional choices after reaching a later milestone. It does not mean automatically receiving every available improvement.

## Concrete first-city test

One Research point comes from each first profile completion of city Rites 1–10. Repeating a Rite, dying, accepting PeeP, ordinary reconstruction and spending Followers do not grant Research. Ten different first clears therefore provide ten individual allocations. This is a bounded city experiment, not the final godhood tree or a cap for later regions. Legacy profiles receive points for actual clears after this feature, not inferred historical rewards.

Every purchase prepares the next attempt. The active attempt uses a separately saved snapshot, retained through Continue and reconstruction. Later run-earned levels and special forms remain temporary. Bag growth is seeded only on a fresh attempt and does not truncate loaded temporary space or items.

| Individual choice | Per purchased rank | First-city cap |
|---|---|---|
| Health | +5 maximum HP |3 |
| Armor | +1 |3 |
| Carrying space | +1 bag slot |3 |
| Augment training | One owned, selected augment starts at Lv2 |1 |
| Haste | +0.02 native Haste |3 |
| Movement speed | +2 world pixels/second |3 |
| Luck | +0.02 native Luck, using existing outcome scaling |3 |
| Power | +0.02 native Power |3 |
| Attack reach | +5% native melee reach / ranged travel |3 |
| Attack size | +5% native melee arc / projectile width / magic burst radius |3 |
| Binding Echo | At completed S5 in a future attempt, take two sequential normal Binding rewards instead of one |1 |

Each rank costs one Research. The pool deliberately has more ranks than the city budget; a ten-point allocation cannot buy everything. Training's selected target is changeable for the next attempt. Reach and size descriptions name their actual consumers; they do not claim a universal multiplier for all augments.

Binding Echo changes the build reward rule. It must be snapshotted before the attempt starts, requires reaching and completing S5, and has a saved once-per-attempt marker and remaining-reward queue. Both rewards use the normal Binding choice flow; the resulting temporary growth resets at true defeat. A duplicate settlement callback or reload must not generate another choice.

## Pacing comparison contract

Keep the completed-S8 Revelation and S9 mutation thresholds. Compare baseline, training only, a defensive ten-choice allocation and an offensive ten-choice allocation with the same seed, native gear, race/style and actual augment effect. Fixed absolute late rank separates lasting stat effects from a one-level starting head start; equal earned levels measures the head start as well. Capture native projectile geometry separately so attack-size bonuses are not falsely attributed to Tesla.

These stationary mechanics measurements cannot establish human city pacing, encounter time, enjoyment or late-city performance under a live crowd. The October 11 capture is historical evidence of early saturation, not a current-build benchmark. Human comparison remains required: fresh versus stocked Stash, prompt exit versus staying, time to desired powers, and purchases still worth wanting in S7–10.

## Verification

All final suites below completed with exit 0 and zero failed checks. The migration suite intentionally exercises a future-version save and emits its expected warning. Commands, process records, source identities and both initial failures and final successes are in [verification.json](evidence/2026-10-16-city-development/verification.json).

| Suite | Passed | Failed | Diagnostics |
|---|---:|---:|---|
| AugmentBindingTest | 64 | 0 | None |
| CityDevelopmentTest | 351 | 0 | None |
| CityDevelopmentBindingUiTest | 25 | 0 | None |
| CityFarmingExperimentsTest | 51 | 0 | None |
| AscensionRuntimeSafetyTest | 21 | 0 | None |
| CityDevelopmentUiTest | 86 | 0 | None |
| CityDevelopmentPacingProbe | 159 | 0 | None |
| ScriptParseAuditTest | 530 | 0 | None |
| CityContinuationTest | 92 | 0 | None |
| SegmentCompletionPersistenceTest | 38 | 0 | None |
| AttemptResetTest | 18 | 0 | None |
| SaveMigrationMatrixTest | 34 | 0 | Expected newer-save warning |
| AscensionCityPacingTest | 624 | 0 | None |
| PauseMenuFlowTest | 38 | 0 | None |
| ReliquaryCoreTest | 87 | 0 | None |

The shared headless project import completed with exit 0 and no diagnostics. The gameplay parse audit covers 530 scripts; all 530 source hashes were rechecked unchanged after the run. Independent scoped review has no open P1/P2 findings. It caught and resolved the claimed-S5 recovery stall and an early Binding pause that affected developer entry.

The native UI fixture exercises keyboard/controller navigation, the real augment selector, individual purchases, caps, save/reload and cancel ownership. The Game fixture covers two actual Binding screens, world/input pause through the gap, stale callbacks, between-choice reload and the production developer route. Final native captures show 12 layouts with zero capture/bounds failures, and the final renderer process exits 0 with no diagnostics. See the [capture manifest](../art/reference/2026-10-16-city-development/capture-info.json).

Initial clean behavioral REDs were observed: missing backend API (0/1, exit 1), missing actual menu entry (0/1, exit 1), and missing independent comparison metadata (44/7, exit 1). The first source runs also exposed ordinary Binding cadence and claimed-S5 recovery failures, then the actual Game queue/pause failure. Those logs are retained. An older Library fixture omitted the eight newly added optional lore pages; the lore chat corrected its expected catalogue count and the full Reliquary suite then passed 87/0. That fixture change belongs to the lore commit.

Earlier UI/probe fixture failures are distinguished from gameplay defects in verification.json. An unrecorded diagnostic process exit and an invalid standalone Game parse invocation are excluded. The first preview exposed late minimum-size growth and was repaired with a deferred layout fit; superseded misleading small-content labels were removed. A later preview had three GLES cache-directory creation errors at [Godot shader_gles3.cpp:802](https://github.com/godotengine/godot/blob/a13da4feb/drivers/gles3/shader_gles3.cpp#L788-L804). The log cannot establish the underlying OS cause. A fresh short process-local APPDATA/LOCALAPPDATA recapture resolved them without project-setting changes; the earlier log is retained separately.


Existing Stash wealth, repeated-item acquisition and reward feedback are separate balance axes. The new Research rules prevent death from paying Research; they do not establish that every possible economy farming strategy is solved. The independent overtime/Gospel variants remain available for matched city tests.

## Controlled mechanics results

The final probe passed 159 checks with zero failures and exit 0. It uses 40 stationary immortal enemies, seed 81919 and 10 simulated seconds per row. Native Conduit Lens gear stays fixed within each four-way comparison (R1 at start, R12 late). Raw output is [pacing.json](evidence/2026-10-16-city-development/pacing.json).

| Matched phase | Effective baseline | Trained only | Defensive ten choices | Offensive ten choices |
|---|---:|---:|---:|---:|
| Starting rank (1 versus trained 2), R1 gear |57.45 |84.96 |84.96 |93.31 |
| Fixed absolute Lv.12, R12 gear |1558.98 |1558.98 |1558.98 |1699.75 |
| Eleven earned levels (12 versus trained 13), R12 gear |1558.98 |1671.49 |1671.49 |1822.42 |

Values are actual Tesla damage per simulated second in this fixture. The training-only opening increase is about 48%; after eleven earned levels it is about 7.2%. At equal absolute late level its output matches baseline. Tesla's authored passive Haste also grows with rank (+0.02 early; +0.01 between Lv.12 and 13), so training is not a pure payload multiplier. Native projectile size is measured independently: the offensive allocation has collision radius 6.9 versus 6.0, with travel range unchanged.

The defensive allocation uses HP ×3, armor ×3, bag ×3, training ×1: +15 HP, +3 armor and +3 slots against the matched trained character. The offensive allocation uses Power ×3, Haste ×3, size ×3, training ×1: +0.06 Power, +0.06 Haste and 15% native attack size. These are two specific allocations of ten individual choices, not automatic packages, a maximum of every available option, or a recommended best build. Binding Echo is covered by the reward-flow regressions rather than assigned an invented DPS number.

This supports a visible early head start without a separate training-only late-level multiplier. It does not establish that S7–10 feel right, that every build is balanced, or that crowded city performance is adequate. The full city human comparison remains owed.
