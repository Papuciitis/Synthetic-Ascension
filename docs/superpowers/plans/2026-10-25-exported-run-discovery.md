# Exported run resource discovery implementation plan

> **For agentic workers:** Use the existing isolated checkout and execute the
> regression, narrow loader correction, packaged checks and review in order.

**Goal:** A Windows playtest can select ancestry/path, begin an ordinary run and
choose an augment using the authored catalogues included in its package.

**Architecture:** Enumerate logical resource names with
`ResourceLoader.list_directory`, as the existing HubLibraryData already does.
Retain the existing recursive loader callbacks, type/ID checks and disabled-item
filter. MajorChoiceDB keeps its independent resource loader and uses the same
export-aware enumeration. Do not change save-file directory operations.

**Tech stack:** Godot 4.7.2, GDScript, the existing Windows Playtest preset.

**Spec:** User's 25 October exported-Windows screenshots and launch confirmation;
existing normal flow in `ui/screens/base.gd` and `ui/augments/AugmentSelect.gd`.
Visual work is paused. Source base is production `6bdd4cc0`.

## Constraints and review focus

- Keep existing portraits, menu layout, gameplay, rewards and player saves.
- Preserve nested directories, logical resource paths and starter weapon IDs
  derived from filenames when authored IDs are empty.
- Exclude disabled `item_test` and the empty-ID set template as before.
- All eight startup catalogues must load in a package, not only the checkout.
- A zero-choice screen must fail tests; equality to an empty DB is insufficient.
- Keep old broken binaries and actual failed run records. Build the replacement
  at a separate path and record its exact hash/source.
- One guarded engine at a time. Helpers do not run engines or mutate Git.
- Loading an EXE's embedded PCK on Linux checks packaged game data, not Windows
  OS execution. Label cinematic/reward staging honestly.

## Task 1: Reproduce and fix packaged discovery

Files: `autoload/global.gd`,
`core/systems/major_choice/MajorChoiceDB.gd`,
`tools/tests/PackedFrontEndFlowTest.gd`, `tools/tests/FrontEndFlowTest.gd`.

- [x] Freeze a packed regression with known ancestry/path/augment IDs, nonempty
  other catalogues, actual Base choices/start validation and augment-card use.
- [x] Run it through the guard against the original EXE. Expected: failing
  catalogue assertions, not parse/setup failures. Confirm source Global matches
  the original export record. The offline PCK receipt already establishes
  remapped files exist and raw-extension enumeration skips all of them.
- [x] Change the shared Global scanner to logical resource enumeration. Route
  sets/items/augments through that helper, retaining their exact filters/logs.
- [x] Update MajorChoiceDB's independent scan in the same way.
- [ ] Run focused checkout front-end, augment and major-choice regressions;
  retain results and repair relevant failures before claiming completion.

## Task 2: Verify and deliver the corrected playtest

- [ ] Export a separate Windows Playtest EXE from the corrected checkout.
- [ ] Run the same frozen packed regression against its embedded PCK; require
  correct catalogues, populated menus and functional selection, with exit 0.
- [ ] Run a native packed UI check and inspect original populated Base/augment
  views. Do not equate staged opening completion with a full human playtest.
- [ ] Independently review source and actual results, then commit and normal
  merge. Confirm production runtime sources equal the tested sources.
- [ ] Supply a separate corrected ZIP/README with exact build/source hashes;
  publish concise evidence and update Linux handoff. Human handles Git push.

Checkpoint: original EXE regression is actual 5/12 with exactly twelve expected
assertion diagnostics and exit 1. Source FrontEndFlowTest is actual 46/0;
AugmentBinding 64/0, AugmentOffer 5/0 and AscensionDoctrine 36/0, all exit 0
and zero diagnostics. Independent loader diff review is clear.

The first rebuilt EXE fixes all catalogues but its frozen packed flow stalls
after Begin (19/1). Shutdown then reports preload failures. Offline inspection
verifies those scenes and 57 literal dependencies are present. Separate direct
scene and Game-script warmup diagnostics load successfully but do not resolve
the stall; both are preserved as interrupted diagnostics, and no warmup ships.

The text-resource-format candidate also fails 19/1 and is rejected. Restore
`project.godot` exactly. The verbose progress diagnostic locates the stall at
Game threaded status IN_PROGRESS / 0%, before world construction, during the
first nested scene-script load. A separate retained synchronous full-Game scene
diagnostic reaches 38/0, with one headless-only viewport-read diagnostic in the
augment flight effect. This is attribution evidence, not a shipping pass.

The next candidate uses `script_export_mode=0` (TEXT) in both Windows presets.
Keep authored `.gd` paths instead of remapped `.gdc` paths while retaining binary
scene/resource conversion and the existing asynchronous router. This packages
readable scripts and can affect package size/parse cost; no performance claim.
The existing icon fallback also handles headless viewport capture explicitly.
Require the same frozen cold packed flow without any diagnostic warming, then
native proof of the real UI and selection. No direct synchronous Game load ships.
