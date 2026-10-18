# Boss delivery completion — 18 October 2026

Scope: finish the implementation left in the 17 October pull audit, excluding human playtesting. The current user also requested periodic commits/pushes, a loading spinner and replacement of the mixed meme boss portraits. The [existing design](../design/2026-10-16-boss-overhaul-proposal.md) and [delivery plan](../superpowers/plans/2026-10-18-finish-boss-delivery.md) govern the work; the later portrait request supersedes the proposal's default meme treatment.

## Rewards and Continue

S5 guarantees its configured 2–3 items at base rarity 3–4; S10 guarantees 5–7 at base rarity 7–9. Luck and quality rules still operate. A seed/segment/arena settlement saves the clear, complete Followers payout and immutable rolled items synchronously, retaining the original post-clear Resonance quality context. Repeated death callbacks cannot reroll or repay it.

Ground copies carry claim identities. Successful inventory insertion and claiming save together; a full bag leaves the reward pending. Pending rewards survive ground cleanup and recover near the player on Continue, Hub entry or a segment handoff. Terminal defeat takes precedence. Older clear-only saves remain cleared without retrospective item grants.

Completed primary objectives, exact Resonance and its buffer, elapsed time, completed secondary sources and earned Rite safeguards now persist with their segment. Partial primary objectives restart. Completed sources do not repay Resonance after Continue; restored wardstones retain their sanctuary. Stale builder epochs cannot overwrite a reset or a different segment. A mismatched progress snapshot cannot suppress a legacy clear's one-time Resonance restoration.

## Audio and presentation

Three original 16-second S10 score arrangements intensify with the three phases. A dedicated phase cue and defeat/release cue replace the reused entrance cue. Major warnings duck music by 7 dB; warning effects remain independent. Pause, disengage, defeat, reset and scene cleanup restore the correct route. [Provenance, recipes and hashes](../../assets/audio/music/s10/PROVENANCE.md) are saved with the assets.

The approved world forms now have feet-anchored anticipation, release and recovery acting, with static equipment heat/focus changes across phases. Reduced Motion preserves the original pose and the static phase identity. These transforms affect visual children, preserving attack clocks, target positions and collision shapes. This uses whole-form raster acting rather than newly drawn frame sheets.

The user's subsequent portrait correction replaces the meme blends with role/tier portraits derived from the four world forms. [Artwork and source records](../art/2026-10-18-boss-presentation-assets.md) include normal/small-window references. The representative boards isolate the body treatment; the separate [actual Game references](../art/reference/2026-10-18-boss-game/) include the court, production player, HUD and effects. Actual Game views are staged and frozen, not encounter recordings.

## Encounter corrections

- The S5 slam captures a longer warning for a sustained walk below 100 px/s. An 80 px/s player receives a 1.625-second warning instead of 1.3 seconds. A later speed change cannot move the committed release. S10's existing walk-out certification remains in charge of its commitments.
- Mine/blink routes beside walls use the turned production body and physical walls, while mine separation retains the full Hurtbox clearance. Unloaded ground is still refused. A finite inward mine arc can fit beside a wall when a full constellation cannot, with the same fuse, node count and warnings. A real capsule regression rejects a 50 px gap and accepts a 60 px gap.
- Encore waits for the original held Q to release. Its guard lasts 0.75 seconds, releases automatically and leaves the original recovery intact. Guard versus remote Detonate is captured; a later bunker cannot be consumed by a pending detonation repeat. Mirror/Gun Shield shots, release waves and bunker payloads retain cast scaling.
- Dominion repeats the original Compel choice without waiting for another key release. Its direct Q-created well, Throw, Crush, Grave and Pinball damage retain the originating scale. Both the original and Encore Aftershocks resolve with their own payload. Intervening Reaction casts cannot rewrite that choice. Existing Encore proc-power/area rules and independent resource-triggered passive rules remain.

The controlled Game fixtures now keep the production body registered with physics while manual movement is disabled. A third-seed wall fixture also searches from the actual boss home and validates the physically rested position, preserving its existing encounter-distance assertions. These changes correct test setup, without relaxing production encounter limits.

## Loading feedback

The existing shared transition card gains a gold loading cue and explicit Loading label, covering Start, Continue, Hub and segment transitions. Reduced Motion keeps a static mark. The cue does not claim a completion percentage. Scene construction still runs on the main thread, so the spinner can pause during a blocking build; the displayed loading card remains visible.

Four [rendered references](../art/reference/2026-10-18-loading-feedback/) cover a normal segment card, small Hub card, a 360×240 Reduced Motion card and an unnamed menu card. Native rendering recorded zero failures and zero save writes.

## Verification

All engine runs use process-local APPDATA/LOCALAPPDATA under the task's isolated evidence directory. No live player profile is selected. Native exit status is used where recorded; the supplied console launcher can itself return zero after a failing child, so assertion summaries and diagnostic scans are required as well.

| Area / suite | Passing checks | Failed |
| --- | ---: | ---: |
| Rewards / Continue / economy: eleven focused suites | 387 | 0 |
| Audio lifecycle / warning / menu / action / loop: seven suites | 236 | 0 |
| AscensionSharedRules / Bastion / Dominion | 55 / 62 / 50 | 0 |
| Wall placement / Arcanist teaching / main | 29 / 44 / 64 | 0 |
| Bulldozer teaching / main / walk-out oracle | 57 / 69 / 57 | 0 |
| S5 actual Game: two seeds, both roles, 35 case results | 158 | 0 |
| S5 actual Game: 80 px/s slam, three seeds, three pairs / six results | 33 | 0 |
| S10 actual Game: two seeds, both roles, 56 case results | 291 | 0 |
| S10 actual Game: third seed, both roles, 28 case results | 147 | 0 |
| LoadingScrim / FrontEndFlow / InterfaceThemeConsistency | 14 / 35 / 32 | 0 |
| Presentation / proportions / phase bar / main interruptions | 37 / 72 / 15 / 44 | 0 |
| Runner / runtime safety / attack identity / hazard geometry | 40 / 21 / 25 / 31 | 0 |
| Final ScriptParseAuditTest: eight gameplay roots | 535 | 0 |

The final S10 helper rerun passes the two original seeds and the added seed (16102026, 16102027, 18102026): all 84 requested case results finish, with native exits 0 and zero profile writes. Final portrait, loading and compatibility runs are clean. ScriptParseAuditTest ran last, after all source edits, and exited 0 with all 535 scripts compiling. [Selected raw logs, structured controls, source hashes and verification records](evidence/2026-10-18-boss-delivery/) accompany this audit. These are focused checks, not a claim that all historical project suites were rerun.

Behavioral RED runs precede the fixes: SharedRules 35/5 and later edge cases through 53/2; slow-slam teaching 55/2; wall placement 1/24, followed by a real-capsule 28/1 regression. Review found and corrected reward-quality ordering, repeatable objective Resonance, wrong-segment legacy restoration, delayed Encore scaling and insufficient corridor width. Independent scoped reviews approved the corrected implementations.

## Remaining human assessment

Human runs still need to judge crowded readability, animation weight, audible mix, both random choices across mixed builds, the proposed S5/S10 pacing bands and a complete city/Rite escape. Synthetic controls establish lifecycle, damage access and the particular routes they exercise; they do not establish encounter satisfaction or all-build balance. HP and damage have not been retuned from these controls.

The previously declined extra Split Fan follow-up and damaging debris lane remain deliberate design exclusions. Debug attempts retain the previously documented profile gains; redesigning their inventory scope is outside this delivery.
