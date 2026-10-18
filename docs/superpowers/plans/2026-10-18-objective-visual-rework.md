# Objective visual rework implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement the independent presentation tasks and review them before delivery. Steps use checkbox syntax for tracking.

**Goal:** Implement the visual designer's recommendations so objective forms belong to the current terrain and communicate their actual actions and states.

**Architecture:** Keep all gameplay authorities and world origins intact. Replace the shared full-canvas anchor with explicit per-asset contact/footprint metadata, add physical state artwork and sparse code-native mechanical details, and quiet the exact-radius boundaries. Prototype one breach in the actual Game before producing the remaining replacement assets. Separate tasks own disjoint production scripts; the coordinator owns shared art and integration.

**Tech stack:** Godot 4.7.1, GDScript, native Compatibility renderer, generated transparent PNGs.

**Spec:** `docs/art/reviews/2026-10-18-objective-visual-design-review.md`, approved by the user's “Okey, do them”. Earlier authorization covers autonomous work, subagents, commits/pushes and image generation. No repeated design approval is required.

## Global constraints

- Preserve all current gameplay distances, timers, spawning, damage, reward, save and settlement rules.
- Use the reviewed weathered city containment direction: broad muted stone, restrained metal, consistent overhead view, believable ground contact; avoid another family of ornate shrines.
- Low forms anchor their ground footprint; upright forms anchor their physical base. Alpha-bound centers/bottoms are not universal anchors.
- Physical open/closed/spent shapes must remain understandable in frozen, small, grayscale and Reduced Motion/flashes-off views. Essential information cannot depend on glow or hue.
- Keep exact interaction circles circular and at their true radii. Separate temporary progress, banked progress, durable thirds and safeguards.
- Preserve the existing dirty workspace files and all real saves/settings/reports. Original editor PID 29136 may remain; no game was running at inventory. Isolate every native check and use actual process exit codes.
- All generated project assets and prompts/provenance must be saved in the repository. No downloaded artwork and no Python image editing substitute.
- The coordinator owns Git operations and native graphical engine scheduling. Agents do not stage/commit/push shared state.

## Review focus

- A restored/completed site immediately shows the physical completed state without another gameplay tick.
- Leaving boundaries preserves each objective's distinct reset/bank/decay/settlement behavior; presentation never advances gameplay.
- Contact footprint and actor layering remain correct on moss and pale paving, including front/back traversal.
- Locked, unaffordable, spent and dangerous forms cannot look like ready beneficial hold areas.
- Real cache rewards and real vault payout/cost transitions are verified rather than fabricated by staging.

### Task 1 — Shared art and one breach prototype (coordinator)

**Files:** `core/systems/world/objectives/ObjectiveWorldArt.gd`, `objective_world_art.gdshader`, `BreachSealObjective.gd`; `assets/world/objectives/painted/*_v2.png`; focused presentation tests and native preview tools.

**Interfaces:** retain `install(parent, art_name, height, at, node_name) -> Sprite2D`, `configure(art_name, height)`, `set_state(state, progress=0)`, `draw_boundary(item, at, radius, color, progress=-1)` and `draw_complete(item, at, size)`. Add per-art variant/anchor/occupied-size metadata internally. Callers continue passing real progress and states. Expose a clearly named optional helper for physical state details only if needed; no gameplay callbacks.

- [ ] Add meaningful checks for per-asset anchoring, physically distinct complete textures, exactly three actionable breach forms and unchanged radii/layout.
- [ ] Generate/inspect a low embedded open rupture, then a matching physically closed/capped state through the built-in image tool. Record source paths/prompts.
- [ ] Remove the decorative fourth breach and decorative radial links; retain actual site geometry/count and source spawning.
- [ ] Implement anchors, subdued contact shadows and boundary hierarchy. Show the breach half sealing and decaying with static direction/shape cues.
- [ ] Capture the prototype at normal/small sizes, moss/paving and actor overlaps, with motion/flash settings. Get independent visual feedback in the existing visual-designer chat and correct it before bulk asset generation.
- [ ] Verify focused tests and existing PrimaryObjective suite; commit/push a concrete checkpoint.

### Task 2 — Relay, Vigil and Wager (agent)

**Files:** `DistrictRelayObjective.gd`, `WardVigilObjective.gd`, `WagerShrineObjective.gd`, focused tests; owned v2 PNGs after the prototype style is established.

**Interfaces:** existing shared art APIs above. Use `dormant`, `working`, `draining`, `complete`, `spent` states. New textures are keyed by existing art names so scene callers do not need paths.

- [ ] Remove misleading actionable Relay center form; use a clearly passive low junction or sparse network cue. Three components remain the only sites.
- [ ] Give Relay silencing a shutter/disconnect shape and a steady banked partial indicator.
- [ ] Give Vigil a low embedded construction and distinct held/grace/draining/completed static shapes; keep actual 190 px area and wave thresholds.
- [ ] Retain Wager scales identity but simplify material detail; display paid tier, real current odds, next scaled cost, purchase dwell, reserve refusal, “Step out to settle”, and structurally spent state. Display proposals never spend currency.
- [ ] Add focused state/geometry/transaction invariants, run the native suites when scheduled, self-review and report exact files/results to coordinator.

### Task 3 — Wardstone and Exit Rite (agent)

**Files:** `Wardstone.gd`, `ExitRite.gd`, their scene resources if required, focused presentation tests; owned v2 PNGs after prototype style established.

- [ ] Retain Wardstone obelisk identity, simplify and ground it, visibly engage its base on anchoring; prioritize active sanctuary field over obsolete capture ornament.
- [ ] Replace frontal gate with an overhead threshold/ground pad connected to the full real channel zone.
- [ ] Implement visually distinct locked/ready/channeling/grace/draining/completed states. Quiet progress arc and use different shapes for durable thirds and safeguards.
- [ ] Preserve exactly the existing Rite channel/cost/healing/wave/Last Chance spawning behavior, including restored progress and zero/max safeguards.
- [ ] Add focused presentation/geometry/restoration checks, run compatibility suites when scheduled and report results.

### Task 4 — Vaults, exploration and adjacent hazard (agent)

**Files:** `CursedVault.gd`, `RitualInterference.gd`, `IndoorVolume.gd`, relevant `ChunkGenDistrict.gd`/pickup presentation code only as justified; focused tests and owned v2 vault PNGs.

- [ ] Add a distinct compact locked vault body and physically open/spent variant, 64 px hold edge, honest progress/decay, explicit guaranteed Manifestation and pre-commitment costs.
- [ ] Last Chance uses the same vault family but visibly sacrifices the real safeguard count; distinguish its no-extra-encounter price from ordinary vaults.
- [ ] Improve actual building entry/guarded/cleared/reward affordances using existing architecture and production state. Do not add a click interaction or fake chest.
- [ ] Investigate missing tagged cache pickups with actual production generation/streaming. Correct a confirmed defect if found; otherwise preserve an honest evidence limit. Improve real loose-pickup/endpoint identity only.
- [ ] Give Ritual Interference an unmistakable dangerous broken/spiked boundary and affected-corpse cue, distinct from sanctuary. Preserve resurrection lifecycle/caps.
- [ ] Verify genuine vault opening/reward/cost and building clearing, zero save writes, cleanup and accessibility; report results.

### Task 5 — Integration, independent review and delivery (coordinator)

- [ ] Review all task diffs for untouched gameplay math and allocation/lifecycle hazards. Resolve and recheck any findings.
- [ ] Generate final actual Game images covering all world objective forms and unreviewed locked/draining/spent/cost states, normal/small/settings-off, plus actor overlap and real spawn/payout samples.
- [ ] Feed new images to the visual designer and address concrete visual issues. Do not substitute a test count for visual acceptance.
- [ ] Run relevant gameplay compatibility suites, import and script audit using native exit codes. No broad numeric rebalance.
- [ ] Commit/push only this task's changes; verify remote HEAD and preservation of pre-existing edits. Update roadmap/audits with exact evidence and remaining human-playtest limits.

## Execution ledger

- Plan created from the completed independent visual review. The user approved implementation and already authorized autonomous execution; keep progressing without repeated permission prompts.
- Baseline `c099436c`, branch `feat/authoritative-enemy-world`; push explicitly to that branch. Existing unrelated dirty edits remain outside this task.
- Task status: 1–5 pending. Coordinator owns shared art, asset integration, native graphical scheduling and commits; independent agents own the disjoint presentation scripts.

### First implementation checkpoint

- Tasks 2–4 presentation code and focused compatibility checks are complete;
  final v2 texture integration and visual captures remain pending.
- Native completed summaries: Wardstone/Rite 30 + 58 + 21; Relay/Vigil/Wager
  39 + primary 236 + secondary 35; vault/exploration 32 + cache 6 + vault 32
  + ritual 35 + footprint 11 + loot cap 6; breach grounding 9; shared objective
  presentation 21. Each final launch exited 0 with completed summary and clean
  full output. Initial expected failures and intermediate errors remain in
  isolated evidence and are not passing runs.
- Exact cache reproduction proved initial placement preceded chunk registration.
  Deferring that first attempt creates two genuine walkable tagged pickups,
  preserves them across reload, duplicates no payout and writes no saves.
- Nine original generated PNGs and prompt/source provenance are saved. Apart
  from the breach pair, these remain candidates awaiting native integration.
- The first breach capture needed stronger danger/decay cues and valid rendered
  enemies. A refined 18-image pass now shows those fixes; independent refreshed
  pixel review reports no remaining blocker for the material/anchor direction.
- Both full Game prototype passes exposed three native cursor teardown leaks.
  A separate Game-free baseline reproduced the exact sizes, an explicit cleanup
  control removed them, and the production CursorManager teardown fix passed a
  clean native graphical probe. The final full Game rerun remains required.
