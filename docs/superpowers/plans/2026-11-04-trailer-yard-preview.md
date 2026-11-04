# Trailer yard preview implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task by task. The user authorized autonomous overnight execution and incremental local commits.

**Goal:** Produce a bounded, testable yard-outline preview for visual review.

**Architecture:** A pure footprint helper supplies weights to a separate wrapped
presentation texture. Only S7 urban-yard pixels use it, behind an opt-in switch.

**Tech Stack:** Godot 4.7 GDScript/shader, existing Windows capture guards.

**Spec:** `docs/superpowers/specs/2026-11-04-trailer-yard-preview-design.md`

**4 November checkpoint:** Tasks1/2a and the bounded Task2b implementation are
committed/reviewed through `6de56bed`; proof/handoff `5976de88`. Actual current
results are renderer75/0, helper82/0, mask69/0, retained ground subset60/0 and
native material fixture46/0. Whole-project parse was refused before launch;
actual generated S7 visual/traversal/reload/cost acceptance remains open.
See `docs/audits/2026-11-04-overnight-trailer-checkpoint.md`. The broader eight-hour
goal is still active. Read-only feasibility of a real isolated household is next.

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

- [x] Write standalone SceneTree tests requiring positive, nonrectangular
  support outside one actual corner and no footprint/door/garden coverage.
- [x] Run RED against the absent helper with an explicit failed assertion.
- [x] Implement bounded deterministic geometry, zero-on-invalid behavior and
  four-direction access protection; rerun to GREEN in a minimal data project.
- [x] Add independent edge-case fixtures and verify input/RNG preservation.
- [x] Commit helper/tests with actual results; do not claim native visual fit.

## Task 2a: independent wrapped mask data

**Files:** create `core/systems/world/ground/CityYardSupportMap.gd`,
`tools/tests/CityYardSupportMapTest.gd` and a reproducible Windows data-only
launcher `tools/tests/run_yard_support_data_tests.ps1`.

**Interfaces:** fixed 256x256 byte buffer; `replace_chunk(coord: Vector2i,
cells_per_chunk: int, proposed: PackedByteArray, semantic: PackedInt32Array,
care: PackedByteArray) -> bool`; `clear_rect(rect: Rect2i)`, `clear()`,
`signature(coord: Vector2i, cells_per_chunk: int) -> PackedByteArray`, and
`snapshot_image() -> Image` for the future L8 texture upload. Proposed input is
already the maximum of every household field. Return false on malformed input;
clear a valid target chunk on malformed fields so stale preview cannot survive.

- [x] Write standalone tests first and run a real absent-owner RED assertion.
- [x] Implement index-6/zero-care clipping, bounded clear/reset, negative and
  nondivisor wrapping, idempotent replacement, and independent snapshots.
- [x] Prove input arrays unchanged and old aliased chunks cleared. Run GREEN.
- [x] Add a Windows launcher copying only explicitly named data helper/test
  files into a fresh project with no autoloads/assets, preserving hashes/logs,
  refusing another engine and propagating native/guard/diagnostic failures.
- [x] Test real launcher success plus no-overwrite behavior, then review/commit.

## Task 2b: separate opt-in presentation mask

**Files:** modify `GroundSplatRenderer.gd` and `ChunkManager.gd`; create
`YardSupportPreviewShader.gd`, a focused renderer regression, and a tiny fixture
builder/guarded runner. Keep `ground_splat.gdshader` unchanged.

**Interface:** `paint_yard_support(coord: Vector2i, specs: Array[Dictionary])`
uses Task 1 weights and Task 2a storage after household care; probes expose a
byte signature for verification. Default-off texture sampling must not alter
the existing path.

Use a separately generated preview shader only for the explicitly selected S7
target. Validate source hooks and fail closed; restore the original shader
resource/shared uniforms when off. The tiny actual-renderer fixture substitutes
only the two asset-loader leaves. Native tests bind the original baseline shader
separately and compare identical world coordinates. See the execution brief in
this plan's scratch directory for the complete interfaces and fixture contracts.

- [x] Write/run RED for independent mask, semantic/care vetoes, idempotence,
  chunk reset, wrap, and unchanged coverage/light/slot signatures.
- [x] Implement only if the regression can run under resource guards.
- [ ] Run GREEN plus relevant existing ground-care, splat and parse suites.
- [ ] Capture native fixture and matching S7 before/after only if guarded runs
  fit; otherwise leave this task pending, never label untested code complete.
- [x] Commit a qualified preview only after its code checks pass. Native visual
  acceptance remains a separate explicit finding.

## Task 3: visual review and handoff

- [x] Review source range independently and address concrete blocking findings.
- [x] Record actual commands/results, original images if any, and memory stops.
- [x] Update the overnight audit with committed work and exact remaining gates.
- [ ] Continue the next justified trailer task while time/tokens remain.
