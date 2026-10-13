# Quiet Alcove Library Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the independent discovery and content tasks, with the coordinating agent implementing presentation. The user explicitly authorized autonomous execution; do not pause for design questions.

**Goal:** A consistent physical library whose readable books support discovery, builds and lore.

**Architecture:** Global persists profile knowledge and observes successful gameplay acquisitions. HubLibraryData adapts live definitions into spoiler-safe pages. HubLibrary and small drawing widgets present shelves and a reader without changing gameplay state.

**Tech Stack:** Godot 4.7.1, GDScript, existing ChamberKit/ArcaneMenuTheme.

**Spec:** docs/superpowers/specs/2026-10-14-alcove-library-design.md

## Global constraints

- Preserve all pre-existing working-tree changes and use the current isolated worktree.
- Reuse existing enemy/Grimoire discovery, authored lore, theme/fonts and balance definitions.
- Never discover vendor stock, consume gameplay RNG, or invent historical discoveries.
- Protect actual player save slots in every test and screenshot probe.

## Review focus

- Unknown names or effects must not be searchable or visible in tooltips.
- Vendor generation, failed acquisition and reading must not grant discoveries.
- Knowledge survives death but switching profiles restores only that profile.
- Older saves retain known evidence; missing fields use safe defaults.
- At 150% scale all navigation stays accessible and the reader remains scrollable.

### Task 1: Persistent discovery

**Files:** autoload/global.gd, autoload/SaveData.gd, narrowly selected successful-acquisition/pair hooks, tools/tests/LibraryDiscoveryTest.gd/.tscn.

**Interfaces:** Produces the Global library fields and methods named in the spec. Reuses RunEvents item operations and enemy/Grimoire state.

- [x] Write/run failing discovery, acquisition, persistence, backfill and profile-isolation tests.
- [x] Implement the additive saved fields, APIs and real gameplay hooks.
- [x] Run LibraryDiscoveryTest and relevant inventory/Grimoire regressions; confirm no player saves touched.
- [x] Self-review and report exact changed files and results to coordinator; coordinator reviews integration.

### Task 2: Spoiler-safe books and content

**Files:** ui/screens/HubLibraryData.gd, new focused Buildcraft content helper if useful, tools/tests/HubLibraryDataTest.gd/.tscn.

**Interfaces:** Consumes Global library APIs; produces `build_entries() -> Array[Dictionary]`, `filter_entries(entries, category, query) -> Array[Dictionary]`, nine CATEGORIES, and safe page dictionaries described in the spec.

- [x] Write/run failing unknown-search, visible-hint, live-Grimoire/story and no-side-effect tests.
- [x] Adapt existing entries with safe knowledge presentation; add Buildcraft, Recipes and Chronicles.
- [x] Generate teaching text from live levels/thresholds and avoid naming undiscovered ordinary items in references.
- [x] Run data tests; self-review and report exact files/results; coordinator reviews integration.

### Task 3: Shelves and open-book reader

**Files:** ui/screens/HubLibrary.gd, focused ui/widgets/library drawing widgets, tools/tests/HubLibraryTest.gd, tools/dev/HubLibraryShotProbe.gd.

**Interfaces:** Consumes safe dictionaries and Global read/target APIs; preserves `set_filter(category, query)`, `result_count`, pause restoration and `closed` signal.

- [x] Add failing interface tests for books, page navigation, bookmarks/target and spoiler-safe selection.
- [x] Implement physical subject books, open reader, discovery filter and research bookmark using existing palette/fonts.
- [x] Update screenshot probe with isolated save directory and known/unknown/recipe/lore/empty-search cases.
- [x] Run interface regressions and inspect captures at 1280x720, 1920x1080 and 150% scale; fix observed defects.
- [x] Obtain a fresh independent code review; resolve material findings and rerun affected tests.
- [x] Record verified results and commit only this request's files as one coherent local change.
