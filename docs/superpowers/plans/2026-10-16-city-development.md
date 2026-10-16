# First-city cumulative development implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for these disjoint tasks; root owns engine scheduling, scoped review, integration and commit/push.

**Goal:** Let a player accumulate individual stat, capacity, training and conditional reward-rule purchases across attempts while preserving temporary builds and first-city pacing.

**Architecture:** Extend the existing profile/attempt split with a validated profile development ledger and an immutable-for-the-run attempt snapshot. A data-driven scrolling screen reuses existing menu/Hub overlay patterns and presents individual alternatives.

**Tech Stack:** Godot 4.7.1, GDScript, existing Arcane UI.

**Spec:** Current human instruction and clarification on 2026-10-16: implement and test one chosen level-2 augment, broaden permanent choices to HP/bag/stats, and allow purchases to accumulate across attempts. Earlier exclusive-boon proposal is superseded. This plan records routine prototype values selected for that authorized work.

## Global constraints

- Each first profile completion of city segment 1–10 awards one Research point once; no rewards for death, reconstruction, overtime, kills or Followers. Legacy profiles gain no retrospective points inferred from old story counters.
- One point per purchase: health +5 HP x3, armor +1 x3, bag +1 slot x3, augment training x1; haste, Luck and Power +0.02 each x3; movement speed +2 world px/s x3; native weapon reach and native attack size +5% each x3. Training lets one owned chosen augment start future attempts at level 2 and can be reassigned for the next attempt. Each earned increase buys exactly ONE chosen rank; previous choices remain and accumulate across attempts. The screen must say “Choose one improvement”, with no automatic bundle.
- A one-rank Binding Echo alternative costs 1 Research. On future snapshotted attempts, completing S5 permits two sequential normal Binding choices instead of one. Its counter/once-per-attempt milestone claim are saved together; repeated callbacks, death and reload never mint another reward. These Binding rewards remain temporary.
- Every purchase changes profile preparation only. The next start_new_attempt snapshots effective ranks/target; an active or reloaded attempt retains its original snapshot. Missing old snapshot means zero permanent bonus for that active attempt.
- Temporary augment levels/forms, tree spending, carried gear and Followers retain current reset rules. Existing owned augments/Stash/commitment retention stays intact.
- Native reach/size use narrow player attack factory hooks; descriptions name the native attacks they actually affect.
- Bag growth is seeded once on fresh creation; loading never repeatedly adds capacity or truncates occupied tail slots.
- Existing fresh S8/S9 Revelation gates remain; comparison flag --city-no-permanent-development suppresses effective development while retaining stored state. Record selected flag and profile/attempt development in captures.
- Preserve unrelated dirty combat/player/boss/story/history work. No opening/PeeP/lore presentation edits here. Never launch an engine during a human playtest; use serial test processes and isolated user data.

## Review focus

- Duplicate completion callbacks and interrupted settlement grant each first-clear point once.
- Buying/reassigning while an attempt exists does not alter that attempt, including after reload.
- A free starting level cannot be repeatedly donated or reselected into extra temporary levels.
- Old/damaged saves and profile switches cannot resurrect reserved legacy levels or leak ranks/targets.
- Full bags with temporary extra capacity and occupied tail items survive reload/disabled comparison without shrinkage.

## Task 1: Backend and save boundary

Files: new core/systems/progression/CityDevelopment.gd; narrow autoload/SaveData.gd and autoload/global.gd; new tools/tests/CityDevelopmentTest.*.

Interfaces: Global.get_city_development_summary(), purchase_city_development(upgrade_id, augment_id), select_trained_augment(id), city_development_capture_metadata(); city_development profile state and attempt_city_development snapshot. Summary exposes points/earned/ranks/augment_id/claimed_segments and next_hp_bonus/next_armor_bonus/next_bag_slots.

- [x] Write regression against missing development API and observe a behavioral RED (exit1, missing backend).
- [x] Implement pure validation/purchase/claim helpers and Global save/reset/stat/level/bag hooks.
- [x] Verify budget/caps, once-only settlement/recovery, old/damaged saves, no-slot/dev guards, active snapshot isolation, higher temporary levels, terminal reset and transfusion safety.

## Task 2: Existing-menu development screen

Files: new ui/screens/CityDevelopmentScreen.*; narrow MainMenu.gd, base.gd, HubShop.gd and Game Binding queue presentation; new CityDevelopmentUiTest.* and CityDevelopmentPreview.*.

Consumes Task 1's Global API. Shows Research source/balance, cumulative purchased ranks/caps, target selection and explicit next-attempt application.

- [x] Observe existing MainMenu missing Development entry as clean behavioral RED (exit1, missing native button).
- [x] Add themed scrollable native focusable purchase screen and menu/base/merchant entry points.
- [x] Verify empty/invalid/owned targets, native controller/keyboard and cancel ownership, insufficient funds/caps, honest active-versus-next state and save persistence.
- [x] Verify real sequential Binding Echo choices, paused input boundary and between-choice reload.
- [x] Render and inspect normal and small-window layouts.

## Task 3: Pacing comparison and recorder

Files: CityBalanceExperiments.gd, BalanceRecorder.gd, focused CityFarmingExperimentsTest metadata expectation, new CityDevelopmentPacingProbe.*.

Produces NO_CITY_DEVELOPMENT flag and development capture metadata; consumes Task 1 API.

- [x] Verify independent comparison flag/default metadata behavior.
- [x] Implement controlled matched baseline, trained-only and defensive and offensive ten-choice allocation comparisons using real mechanics and fixed setup.
- [x] Record early/late outputs, actual stats/capacity and unchanged S8/S9 gates. Clearly distinguish controlled comparison from a full city playtest.

## Task 4: Verification and integration

- [x] Run focused development/UI/pacing, affected save/continuation/settlement/augment/inventory and menu checks serially.
- [x] Obtain independent scoped correctness review and resolve material findings.
- [x] Run gameplay parse audit last; inspect all process exits and diagnostics.
- [x] Record exact evidence/results, selected prototype caps and owed human city comparison; append current roadmap.
- [x] Stage only owned changes, verify staged diff, commit and push to the existing tracked branch; verify remote HEAD.
