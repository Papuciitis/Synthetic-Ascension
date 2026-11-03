# Trailer yard preview implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task by task. The user authorized autonomous overnight execution and incremental local commits.

**Goal:** Produce a bounded, testable yard-outline preview for visual review.

**Architecture:** A pure footprint helper supplies weights to a separate wrapped
presentation texture. Only S7 urban-yard pixels use it, behind an opt-in switch.

**Tech Stack:** Godot 4.7 GDScript/shader, existing Windows capture guards.

**Spec:** `docs/superpowers/specs/2026-11-04-trailer-yard-preview-design.md`

## Global constraints

- Preserve coverage, slots, light/care bytes, terrain, doors, navigation and RNG.
- Default off; `SA_YARD_SUPPORT_PREVIEW=1` enables the candidate.
- No new assets or simultaneous scale/grade/pickup changes.
- No Game/engine alongside another engine or below its applicable memory gate.
- Keep changes local and commit explicit task paths.

## Review focus

- Concave/duplicate/zero-area geometry must not create interior or distant patches.
- Door approaches remain protected in all four directions and with wide doors.
- Care and semantic ground remain authoritative despite filtered preview edges.
- Negative coordinates, chunk replacement and wrapped-map reuse do not leak patches.
- Preview-off and authored worlds preserve the current rendering path.

## Task 1: pure yard-corner planning

**Files:** create `core/systems/world/ground/CityYardSupport.gd` and
`tools/tests/CityYardSupportTest.gd`.

**Interface:** `static func plan(coord: Vector2i, spec: Dictionary, cell_px: int,
cells_per_chunk: int) -> PackedByteArray`, using `footprint_px`, `doors`,
`garden_contact_px` and `visual_seed` like CityGroundCare.

- [ ] Write standalone SceneTree tests requiring positive, nonrectangular
  support outside one actual corner and no footprint/door/garden coverage.
- [ ] Run RED against the absent helper with an explicit failed assertion.
- [ ] Implement bounded deterministic geometry, zero-on-invalid behavior and
  four-direction access protection; rerun to GREEN in a minimal data project.
- [ ] Add independent edge-case fixtures and verify input/RNG preservation.
- [ ] Commit helper/tests with actual results; do not claim native visual fit.

## Task 2: separate opt-in presentation mask

**Files:** modify `GroundSplatRenderer.gd`, `ground_splat.gdshader` and
`ChunkManager.gd`; create a focused renderer regression scene/test.

**Interface:** `paint_yard_support(coord: Vector2i, specs: Array[Dictionary])`
uses Task 1 weights after household care; probes expose a byte signature for
verification. Default-off texture sampling must not alter the existing path.

- [ ] Write/run RED for independent mask, semantic/care vetoes, idempotence,
  chunk reset, wrap, and unchanged coverage/light/slot signatures.
- [ ] Implement only if the regression can run under resource guards.
- [ ] Run GREEN plus relevant existing ground-care, splat and parse suites.
- [ ] Capture native fixture and matching S7 before/after only if guarded runs
  fit; otherwise leave this task pending, never label untested code complete.
- [ ] Commit a qualified preview only after its code checks pass. Native visual
  acceptance remains a separate explicit finding.

## Task 3: visual review and handoff

- [ ] Review source range independently and address concrete blocking findings.
- [ ] Record actual commands/results, original images if any, and memory stops.
- [ ] Update the overnight audit with committed work and exact remaining gates.
- [ ] Continue the next justified trailer task while time/tokens remain.
