# Ranged V5 handoff — phase checklist and checkpoint

Era: 2026-09-25 handoff (`Synthetic_Ascension_Claude_Handoff_2026-09-25.md`).
Companion docs: `2026-09-25-v5-decision-log.md`, `docs/art/asset-manifest.md`.

**Session start state:** HEAD `167c1ba` (matches handoff audit snapshot).
`data/ascension/tree_v4.json` LF-normalized SHA-256 matches the handoff
baseline (`73926E2F…`); the checkout stores CRLF, hence the raw-hash
difference. Working tree clean apart from untracked docs/archives.

## Phase 1 — Ranged V5 mechanics (V4 kept as control)

### Checkpoint 1 — V5 data and rank foundation  ✅ 2026-09-25
- [x] Recheck handoff findings A–F: all six confirmed live (A: player.gd:749
      cap + engine ×2; B: OR12 requires OR09 in data; C: aggregated `paid`;
      D: status replace-not-strongest; E: 4096 cap + dropped counter;
      F: ORQ hold pattern inverted vs V5)
- [x] V4 untouched; V5 = `data/ascension/tree_v5_ranged.json` from
      `tools/design/build_tree_v5.py`; ledger state stamped `tree_version`
      (old saves default v4, never converted)
- [x] Generator validates ids/requires/conflicts/links/edges/starters/
      build subtotals (P1 2500 / B1 2850 / B2 3400 / O1 2150 confirmed)
- [x] Ledger ranks: receipts, gates (r3: 2 others, r4: 4), downgrade,
      cascade, refund_value; Hub-only downgrades (D-5)
- [x] AscensionScreen: rank I–IV, now/next effect, next cost, total paid,
      actual refund on the button; TreeView rank markers
- [x] `AscensionLedgerV5RankTest`: 63/63 (RANK-01..08)

### Checkpoint 2 — Precision ranks and no-Heat Barrage  ✅ core mechanics 2026-09-25
- [x] Precision ranks via virtual getters (V4 defaults untouched);
      PRF2 -15%; PRC boss fallback (3 hits / 12D on one durable target)
- [x] Finding A resolved (D-4): cap kept, Burst ×2 post-cap, V4 unchanged
- [x] BR01 Spin Up (stages, hold, decay), BRQ V5 (input accounting, fan as
      one 0.7-credit activation, cancel rules)
- [x] No-BR03 audit: BR04 unheated named burn, BR07 Kill Throttle,
      BR08 Vent Volley, BR11 Reserve Feed, BRC 20-stage-3-inputs route —
      all tested with zero Heat
- [x] Functional feedback: stage popups + HUD lines (full VFX = Phase 2)
- [x] `AscensionBarrageV5Test` 37/37, `AscensionPrecisionV5Test` 23/23

### Checkpoint 3 — Grenadier and Ordnance controls  ✅ core mechanics 2026-09-25
- [x] Grenade payload (flight 0.35 s → attach 0.40 s / ground 0.80 s, one
      detonation, chain-eligible when not in flight)
- [x] OR05 Sticky (+0.8D, oldest, once per activation), OR06 chain incl.
      grenades, OR09 Running Barrage (rank distances, 2L bank, 0.5 s rate),
      OR10 Bandolier (credits, cap, one spare per launch)
- [x] Mines/traps unchanged for MR6/MR9/RM7/ORQ4; V5 RM7 converts a
      travelling grenade at a Sigil
- [x] Tap-Q instant / hold-Q placement; placement allowed during fire
      cooldown (runner routing hook); nothing fires before classification
- [x] OR12 Shell-only (D-11); grenades never advance the counter
- [x] `AscensionOrdnanceV5Test` 33/33 (subset of OR-01..13; rest at CP4/5)

### Checkpoint 4 — Optional Heat, attribution, hybrids
- [ ] Named burn attribution + strongest-rate refresh
- [ ] BR03 Hot Core tiers, world-space aura, Meltdown, Overclock
- [ ] Q mutations, forks, keystones, revelations, Axioms, sinks adapted
- [ ] Foreign Witness adapters (§5.4)
- [ ] Cross-Core matrix (§5.1–5.2) incl. RM7 Rune Bomb, Mine producers
- [ ] Remaining spec acceptance cases; deferred items reported separately

### Checkpoint 5 — Capacity, balance, presentation evidence
- [ ] Projectile overflow policy implemented and stressed
- [ ] Matched V4/V5 runs: P1/B1/B2/O1/O2, 3+ seeds, free-choice run
- [ ] Rank-purchase noticeability evidence
- [ ] Exact test commands + results recorded
- [ ] Production VFX asset list carried into Phase 2

## Phase 2 — Ranged visuals (all three disciplines)
- [ ] Asset workflow per handoff §13 for each effect family
- [ ] Precision visual language (white/gold/violet accents, needles)
- [ ] Barrage: Spin Up stages, density, Heat cues, Meltdown, aura
- [ ] Ordnance: grenade/Mine/Shell silhouettes, Big One, chains, tap/hold Q
- [ ] Legibility at gameplay zoom over light roads and dark interiors

## Phase 3 — 2D world shapes and shallow depth
- [ ] Small proof scene: irregular footprint, recessed entrance,
      street-width transition, shallow wall depth
- [ ] Footprint drives floor/walls/doors/collision/indoor/roof consistently
- [ ] Overlap/batching strategy proven vs ChunkBlockRenderer/EnemyProxyRenderer
- [ ] Extended into Level1Builder AND procedural paths

## Phase 4 — Items: Beka first, then batches; existing-item textures
- [ ] Beka: Comfortable Company shield (approved numbers)
- [ ] Beka: 12 s / 320 u pulse — pull health pickups, highlight equipment
- [ ] Beka presentation (provisional art labelled as such until real
      markings/reference obtained)
- [ ] Beka required checks (handoff §14.2 list)
- [ ] Existing-item texture audit → asset manifest
- [ ] Remaining item ideas: per-item status (implemented / designed / blocked)

## Phase 5 — Walkable between-segment hub
- [ ] Hub world scene: arrival, merchant, Ascension/choice station,
      gear/stash, quiet alcove, exit gate
- [ ] Transition rewire without double segment advance
- [ ] Save/resume in hub; old-save compatibility route
- [ ] Hub checks (§15.6)

## Current checkpoint

**Now:** Phase 1 Checkpoint 4 — hybrids/foreign completion. Named burn
attribution (EnemyStatusService.apply_named_burn + tagged ticks) is done;
foreign BR01/BR07/BRQ/BR11/BRC adapters are in BarrageEngineV5 but only
the native path is test-covered so far.
**Next task:** hybrid/foreign regression suite (HYB-01..05 V5 variants,
foreign witness adapters), then Checkpoint 5 capacity/balance evidence.
**Test state (2026-09-25):** V5 suites 63+37+33+23 all green; V4 battery
(Barrage 38, Precision 47, Ordnance 63, Hybrid 41, SharedRules 32, Runner
29, Screen 20, Status 19, Combat 38) all green; parse audit 422/422.
