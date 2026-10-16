# Optional City Lore Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the eight approved source documents optional, durable Chronicle discoveries through a safe papers tray beside the Quiet Alcove.

**Architecture:** Keep authored prose in `CityLoreDocuments.gd`. A small discovery helper derives availability from durable story evidence and records explicit collection through the existing Grimoire. `StoryDirector.record_catalogue()` adapts the eight pages into the existing Library; a focused papers panel provides inspection and collection.

**Tech Stack:** Godot 4.7, GDScript, existing StoryDirector/Grimoire/Library/HubStation.

**Spec:** `docs/design/2026-10-16-first-city-story-proposal.md`, optional documents and discovery/persistence sections.

## Global Constraints

- Exactly eight approved documents; preserve their prose and the existing 19 Chronicle records.
- Availability never discovers a page. Only optional inspection followed by **Keep a copy** calls `Global.grimoire_note("record:<id>")`.
- Retain existing profile persistence, unread, search and bookmark behaviour; no new lore currency or inventory.
- Never infer arrival in the hub's next segment from `Global.attempt_segment`.
- No death, reconstruction, Follower, grinding or random dialogue prerequisites.
- Engine launches remain held until the parent provides the shared slot and RED evidence; no commits in this subtask.

## First implementation boundary

The safe hub tray is the complete collection route for all eight texts, including after a successful S10 escape. Five proposed physical placements are deferred because active segments do not provide an established safe inspection contract: the admission-desk slip, S2 service-courtyard notice board, S4 washhouse shutter/laundry basket, S6 workshop/service shelter door and S10 gatehouse paper shelf. The other three documents already belong at the hub. Environmental discovery is deferred; no prose is inaccessible.

## Review Focus

- A hub after completed S3 must not make S4's laundry note available.
- Actual arrival in S4 must remain evidence across a fresh attempt and profile reload without discovering its note.
- Legacy Method/Doctrine/Apotheosis commitments prove completed S3/S6/S9 respectively, without proving the following stage was entered.
- Successful S10 completion must make every earlier note available without requiring a failed escape or repeat boss.
- Inspecting, dismissing or copying a page must preserve its separate discovery/read/bookmark states and spend no Followers.

### Task 1: Availability and existing Chronicle adaptation

**Files:** Create `core/systems/narrative/CityLoreDiscovery.gd`; modify only `StoryDirector.note_progress()` and `StoryDirector.record_catalogue()`; test `tools/tests/CityLoreDiscoveryTest.gd` and `.tscn`.

**Interfaces:** `CityLoreDiscovery.available_documents() -> Array[Dictionary]`, `document(id: String) -> Dictionary`, `collect(id: String) -> bool`. `StoryDirector.note_progress(segment)` latches positive played segments and opening milestones into existing profile flags. Availability uses those flags, saved completed best, completed commitment stages and Area I completion.

- [x] Write tests for additive catalogue integration, optional discovery, actual arrival versus next-hub counter, and conservative legacy evidence.
- [x] Parent runs `res://tools/tests/CityLoreDiscoveryTest.tscn`; confirm missing eight catalogue entries fail before production edits.
- [x] Implement the helper and narrow StoryDirector adaptations. The service lamp's hub copy requires completed S1; interval/Bren require completed S1/S3; remaining notes require reached S2/S4/S6/S7/S10.
- [x] Verify the discovery suite passes after the parent grants the engine slot.

### Task 2: Optional papers panel and collection persistence

**Files:** Create `ui/screens/CityLorePapers.gd`; test in `CityLoreDiscoveryTest.gd`.

**Interfaces:** CanvasLayer with `closed` signal; `inspect_document(id: String) -> bool`, `keep_copy() -> bool`, `leave_document() -> void`, `_close() -> void`. The panel lists available titles, shows only the approved field excerpt and source when inspected, and uses **Keep a copy** / **Leave**. Successful collection saves the existing profile before returning control.

- [x] Write tests that inspection/dismissal do not collect, explicit copying discovers one unread Chronicle once, and existing save fields carry discovery/read/bookmark state.
- [x] Implement a scrollable, keyboard/controller reachable panel using the existing chamber theme; allow 640×480 without reducing type.
- [x] Verify explicit copying, duplicate copying, reopening and pause restoration through the real panel.

### Task 3: Quiet Alcove entry and integration checks

**Files:** Modify `scenes/hub/HubWorld.gd`; update the existing five-station expectation in `tools/tests/HubWorldTest.gd` to six.

**Interfaces:** Add one managed HubStation named **Papers**, verb **Inspect**, beside Quiet Alcove; `_open_papers()` follows the Library panel's existing open/closed chain. Do not add game/Level1 hooks in this pass.

- [x] Add a behaviour test that finds the Papers station beside Quiet Alcove and opens/closes its actual panel without progression, RNG or currency changes.
- [x] Implement the station and focused panel entry.
- [x] Parent serially runs CityLoreDiscoveryTest, HubWorldTest, StoryDirectorTest and existing Library suites, then the final script parse audit, with the shared engine slot.
- [x] Parent captures the list and an inspected excerpt at 640×480 and normal window size; independent review follows. Report the five deferred physical placements with the delivered scope.

## Execution record

- Data-only `CityLoreDocuments.gd` is already complete; eight titles/excerpts/bodies match the approved proposal by read-back comparison.
- Parent observed RED before integration: `CityLoreDiscoveryTest` 20 passed, 11 failed, exit 1; missing catalogue pages, helper and Papers station. Log: `.superpowers/sdd/2026-10-16-painted-opening/CityLoreDiscoveryTest-red.log`.
- Scoped implementation written after that evidence. Parent retains all engine launches, GREEN verification, captures, independent review and commits.

- Final observed review RED80/23 exit1; corrected GREEN108/0 exit0,11 rendered PNGs reviewed. Related suites54/166/1885/230 all0failed, shared530-script parse and21-check runtime safety reused with matching sources. Exactly five physical placements remain deferred.
