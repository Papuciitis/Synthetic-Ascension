# Finish the boss delivery

Source design: `docs/design/2026-10-16-boss-overhaul-proposal.md`.
Current gaps: `docs/audits/2026-10-17-pull-review-and-s10-boss-kits.md`, Owed.
User authorization: finish Claude's remaining implementation, excluding human playtesting.

## Constraints and decisions

- Work in the existing `enemy-world` linked worktree; preserve all pre-existing edits.
- Complete the existing approved encounter design. No new mandatory patterns or balance inflation.
- Keep current HP, damage, warnings and seeded role selection, except corrections needed for slow-player escape.
- Guaranteed item floor is the existing minimum request: 2 S5 items and 5 S10 items; existing rarity bands remain. Luck may improve rewards without removing the floor.
- Persist rolled item instances and claim state with the attempt. A repeated clear or Continue must never reroll or duplicate payouts. Full inventory leaves rewards recoverable.
- Final art must retain existing humorous portraits and recognizable role silhouettes; presentation never changes damage geometry.
- Developer runs may keep the currently documented profile gains; unrelated attempt-scoped inventory work is outside this encounter delivery.
- No damaging debris or extra Split Fan follow-up: the existing design deliberately uses the Breach/Convergence compositions.
- All engine checks use isolated user data. No tests during a human playtest. Human assessment of pacing, mix and readability remains excluded.
- User explicitly requested periodic commits and pushes during this delivery. Push validated milestones to the existing feature branch without force or changing the other remote branch.

## Task 1: durable boss rewards and Continue

Owner: reward implementer. Own arena reward integration, SaveData/Global attempt persistence, item pickup/drop integration, dedicated reward regression suites.

1. Trace death, drops, wallet transactions, save/Continue and completed Rite recovery.
2. Add failing regressions for floor at low Luck, stored item identities, repeated clear, reload before/after claims, full inventory and segment handoff.
3. Implement one encounter settlement, once-only wallet payout and durable pending items. Keep normal enemy drops unchanged.
4. Run focused persistence tests and existing arena/Continue/Rite suites, report exact evidence.

## Task 2: main-boss music and defeat/release audio

Owner: audio implementer. Own AudioManager, new original/reusable licensed audio and audio suites. Coordinate any boss lifecycle hook edits with root.

1. Inspect existing adaptive music, priority/mix and boss lifecycle signals.
2. Add failing tests for phase progression, no retrigger on healing, disengage/reset, defeat, pause and scene cleanup.
3. Integrate a three-phase music treatment plus defeat/release cue; retain warning priority and restore the ordinary music route.
4. Record asset provenance and verify audio lifecycle/compatibility suites.

## Task 3: distinct S10 portraits, forms and phase acting

Owner: presentation implementer. Own BossAppearance, boss portrait/form assets, HudBossController and presentation tests. Ask root before touching arena or brain files.

1. Inspect current forms/portraits and attack presentation hooks.
2. Finish distinct role portraits using established humorous tone and S10 world identity; add phase/equipment/acting changes using visual children only.
3. Verify footprint invariance, reduced motion, phase monotonicity and cleanup; create actual-game normal/small-window captures for visual inspection.
4. Record asset provenance and concrete verification, without claiming human art or readability approval.

## Task 4: remaining encounter correctness

Owner: root. Own boss brains, player/ascension engine fixes and their regression tests.

1. Reproduce S5 slow-player slam failure and wall-adjacent mine/blink refusal; fix geometry/timing with focused tests.
2. Reproduce Encore held guard/Compel repeat lifecycle; ensure repeats end, retain reduced Encore payload and recovery semantics.
3. Add matched three-seed controls for both boss choices and relevant build access, without tuning damage/HP from synthetic measurements.
4. Run affected teaching/main/oracle/interruption/ascension suites.

## Task 5: integration, independent review and evidence

1. Review each task against the source design and correctness constraints.
2. Fix review findings, inspect actual-game captures and run relevant compatibility suites plus ScriptParseAuditTest last.
3. Update the audit/roadmap with results, any genuine remaining limitation and the explicit human-playtest exclusion.
4. Commit and push only this delivery's files as validated milestones; report the final result and evidence.
