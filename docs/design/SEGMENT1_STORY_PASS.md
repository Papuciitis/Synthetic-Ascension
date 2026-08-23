# Segment 1 spatial + story pass — design (2026-08-23)

Implements the designer's priority-1 ruling (docs/OPTIMIZATION_HANDOFF.md,
"Direction rulings"): treat Segment 1 as a full level redesign following the
ten-beat arc, and build the final Exit Rite LOCKED/LOCATED/READY checklist UI
during the pass. This doc is the authored plan; each section names the code it
lands in. Everything here is revertable per-commit.

## The ten beats, mapped

| # | Designer beat | Where it lives | Status before this pass |
|---|---|---|---|
| 1 | Normal institution | NEW admissions/public wing (south of the lab) | did not exist — run opened mid-crime |
| 2 | Something wrong | Lattice-flicker beats in the admissions gallery | did not exist |
| 3 | Incident | Synthesis + containment alarm (opening controller) | shipped (0.23) |
| 4 | First confrontation | Officer arrest (opening controller) | shipped (0.23) |
| 5 | Lethal escalation | Aftermath: time-scale drop, LETHAL card | shipped (0.23) |
| 6 | Hostile building | Archive → courtyard → service escape, re-staged: the institution is the antagonist (containment-perimeter cards, threat phases finally advancing) | geometry shipped; staging flat |
| 7 | First build choice | NEW evidence-store beat in the service district (mid-level augment pick) | pick happened at run start, menu-only |
| 8 | Transition out | Outer checkpoint breach (existing seals) | shipped |
| 9 | City reveal | NEW overlook beat past the breach: camera zoom-out toward a city backdrop strip, reveal card | did not exist |
| 10 | Outer objective / Exit Rite | Gate plaza + the new checklist UI | gate shipped; no checklist vocabulary |

## Spatial plan (all cells 64 px, same builder tech: planned dicts → autotiled batched geometry)

Existing five spaces are kept as the proven skeleton. Deltas:

### New: Admissions wing (beats 1–2)
- Rect TL (-2, 31), size 24×15 (x −2..21, y 31..45), attached to the facility's
  south wall. South entrance gap at x 8..10 on y=45. Lab-entry gap cut in the
  facility south perimeter at x 14..16 on y=30 (lines up with the existing lab
  corridor; old start cell (15,25) becomes that corridor).
- South half (y 38..44): reception — non-hostile OpeningActor as the night
  desk warden, notice-board half-cover along walls.
- North half (y 31..37): registry gallery narrowing toward the lab door.
- **Full-opening runs start at (9, 43)** (inside the entrance). Short/skip
  runs keep starting at (15, 25) beside the apparatus — veterans skip the walk.
- Beat script: `m_admitted` area at the desk (institutional badge card),
  `m_lattice_flicker` in the gallery (vignette pulse + SFX + "SCHEDULED WARD
  MAINTENANCE — DISREGARD LATTICE IRREGULARITIES" notice, second flicker at
  the lab door). No enemies, no resonance — normalcy is the point.
- No retro-seal on the wing after the incident: the escape has always been
  forward-driven by seals that open, never walls that close. The wing simply
  holds nothing after the incident; a containment card narrates the lockdown.

### Recut: evidence store (beat 7)
- The maintenance kiosk (25,−12) 8×5 is re-purposed as the CONFISCATED
  THAUMIC INSTRUMENTS store. New milestone `m_evidence` inside.
- If `Global.pending_augment_pick`: the augment picker fires here as an
  awaited, in-world beat (see "Mid-level build choice" below) instead of at
  run start. Otherwise: one deterministic item roll + a flavor card.
- Positioned after the security encounter and before Wardstone 2, so the
  choice lands mid-escape with real pressure behind it.

### New: overlook + city backdrop (beat 9)
- Overlook milestone `m_city_reveal` at (49, −45) 7×7 — directly on the
  post-breach route north, east of the sealed warehouse.
- City backdrop strip: 3 decorative ground stamps beyond the north fence
  (y −75..−61, x 30..60) using the existing city block/paving textures —
  non-playable dressing the camera can look at.
- Camera beat: control locked, slow zoom-out (~0.8×) + pan north-east
  (beyond the old 144 px clamp — new camera-beat helper with mandatory
  restore-before-control-returns), HISTORICAL-style reveal card, then zoom
  back. Reduced-motion setting respected via AccessibilityPresentation.
- The warrant copy ("By morning, copies of the report…") stays on the
  completion card; the reveal card is about scale: the city, and the Rite as
  the institution's outermost ward.

### Unchanged
Lab/archive interior, courtyard, service district rooms (except kiosk),
approach/warehouse/plaza geometry, wardstone and gate cells, all opening
anchors (`get_opening_anchors()` cells are untouched).

## Progression changes

- New milestones (persisted in the same array): `m_admitted`,
  `m_lattice_flicker`, `m_evidence`, `m_city_reveal`. All restore-safe:
  matching arms in `_place_story_areas`, `_on_milestone_reached`, and the
  restore path.
- `SEGMENT1_LAYOUT_VERSION` 2 → 3 (mandatory: new walkable space + moved
  start; stale checkpoints reset by the existing mechanism).
- **Threat phases finally advance in Segment 1** (backlog #2): mirror
  milestone → `ThreatDirector.set_segment_phase` at COURTYARD→disturbance,
  OUTER_APPROACH→ascension, EXIT_RITE→collapse, including
  `_apply_restored_spawn_stage`. Spawn caps stay stage-driven; the director
  only touches interval/elite in the two threat-allowed stages, so the blast
  radius is controlled. The authored tut heat peak (1.0 at 100%) becomes
  reachable for the first time.
- Resonance economy: untouched (93% authored). New beats grant 0 — normalcy
  and reveal are not economy events.

## Exit Rite checklist UI (built now, per ruling)

- New signal `RunEvents.gate_checklist_changed(state: StringName,
  items: Array[Dictionary], next_hint: String)`; items are
  `{id, label, done: bool, progress: float}` (progress −1 for booleans).
- Emitters: `Level1Builder` (new) and `SegmentProcBuilder` (refactor of the
  existing flattened-text block at `_push_objective_ui`). The proc objective
  panel stops embedding checklist lines; title + "Next:" hint remain there.
- Segment 1 states: LOCKED before `final_checkpoint` (gate position hidden,
  as today) → LOCATED at `final_checkpoint` (arrow on) → READY when
  resonance ≥ 0.999 and `final_plaza`. Items: Wardstone I, Wardstone II,
  outer checkpoint, resonance (with live %), reach the Rite.
- Proc states keep their current semantics (LOCATED = marker revealed at 75%
  resonance).
- UI: new `HudGateChecklistController` + compact panel in GateOverlay.tscn
  beside the objective panel; ✓/○ rows, state-colored header; hides in
  management mode. **Never derives READY from the resonance bar** — the
  0.998 clamp on the public signal is load-bearing and stays.

## Enabling fixes landed with the pass

1. **Dead authored spawn filter** — `spawner.gd` caches the debug autoload in
   `_spawn_filter`, so `Level1Builder.is_spawn_position_allowed()` never ran:
   enemies could spawn in the void outside the 75×91 footprint and behind
   unopened seals. Fix: resolve the `segment_spawn_filter` group node first,
   with the autoload as fallback.
2. **Loot rooms → tracked secondaries** (backlog #9) — pass the omitted
   `loot_cfg` to `IndoorVolume.configure`; the service warehouse also gets a
   local encounter ("controlled security encounter" per SEGMENT1_REBUILD).
3. **Mid-level build choice contract** — the augment picker is portable but
   needs three fixes to fire mid-level safely: an awaitable wrapper,
   save/restore of prior pause state, and `reset_spawn_clock()` on dismissal
   (matching the tutorial-modal contract).

## Copy

New strings live in `data/narrative/Segment1Text.gd` (admissions/flicker/
evidence/reveal) in the established voice: restrained, clinical, short
declaratives. Placeholder rules unchanged: geometric props, existing SFX as
stand-ins, no new licensed assets.

## Explicitly out of scope (noted for the designer)

- 2D lighting, music cues/stems, fade-to-black: no such systems exist; the
  pass stages everything with cards, vignette dials, time-scale, SFX loops
  and the new camera beat. A lighting/music pass is its own future project.
- Blending wall-clock into ThreatDirector (ruled: test inside the new
  Segment 1 first — the milestone mirror is that testbed).
- Boss/miniboss content in Segment 1.
- Heat-valley ownership (backlog #10) — phase floors vs authored curve is a
  tuning decision; this pass only makes Segment 1 participate in phases at
  all.
