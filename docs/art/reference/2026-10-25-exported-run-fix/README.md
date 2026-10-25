# Exported Windows run blockers — 25 October 2026

The original Windows playtest contains authored catalogue resources as logical
`.tres.remap` entries with valid binary targets. Its filesystem suffix scanners
accept none of them, leaving all eight startup databases empty. That removes
ancestry/path choices, disables Begin and leaves the first augment picker empty.
The loaders now enumerate logical resources through ResourceLoader, retaining
recursive discovery, type/ID filters and filename-derived weapon IDs.

Testing the real Begin button exposed a second blocker: cold background loading
of the Game scene stalls while compiling nested scripted-scene preloads. Direct
scene loading and script-graph preparation diagnostics reach the full flow.
The router now prepares script dependencies on the main thread, yielding between
cold scripts and budgeting dependency metadata work. It keeps references local
through each background request, handles supersession/terminal priority, and
keeps scene loading and progressive world construction asynchronous. Both export
presets and project.godot match the original settings. Rejected export-format
experiments and interrupted diagnostics remain individually classified.

A headless-only viewport read exposed by the complete augment-choice test now
uses the existing icon fallback. Native flight capture follows its prior path.

## Accepted verification

Build source checkpoint: `ee6ff2f8164c447645f9bdef7fe62171092fcf45`.
EXE SHA256: `30f5aa224258abdf56bd0e4477e06a1ba67a140ff8e7907c69481c8388053702`
(376,358,640 bytes). Final source and package runs have no test-side warming.

| Check | Actual result |
|---|---|
| FrontEndFlow / Binding / Offer / Doctrine owners | 46/0, 64/0, 5/0, 36/0; zero diagnostics |
| Fresh source normal flow | 38/0; zero diagnostics |
| Existing late interruption controls | 21/0; three intentional diagnostics |
| Cold preparation cancellation: menu / terminal | 21/0 and 22/0; zero diagnostics |
| Final exporter | exit 0; zero diagnostics |
| Unchanged cold packed flow | 38/0; zero diagnostics |
| Final native packed flow | 62/0; zero diagnostics |

All final guards complete. Both final original PNGs are actual 1280×720,
logical 1920×1080, 20 FPS rendering and 60 Hz physics. Root and independent
reviews accept four ancestry choices, three paths, enabled named Elf/Magic
Begin, and three fully revealed/readable augment cards. The first native run
was functionally 61/0 but its early augment capture remained under the loading
fade. Both rejected originals/reviews are retained; a separately pinned wrapper
and new run wait for the real loading-card and individual card reveal states.
No PNG is edited or replaced in place.

The local delivery ZIP is `build/SyntheticAscension-playtest-20261025.zip`
(308,491,100 bytes), SHA256
`3ff8c42ebfae2f60bcea0ca3d92155ce6d131cec7cc9d9d5422a77d899deb691`.
Its six members pass CRC verification; the contained EXE hash equals the tested
artifact. The original broken EXE remains unchanged. Build outputs are ignored
and must be transferred separately from Git.

The existing interruption suite deliberately requests a missing race atlas; its
three exact resource/failure diagnostics are expected controls, not clean output.
The first preparation-cancellation fixture also exposed a freed Node capture in
the test; that actual record is retained and the reruns use stable instance IDs.

## Scope and reproduction

`tools/tests/PackedFrontEndFlowTest.gd` is frozen at SHA256
`21b0e0aff690ef81d2e271ef36fe8389144842e495bcfc36077b7e7b5ebd3892`.
The original EXE fails 5/12 with twelve expected assertions. The final package
must run the same script without test-side script or scene warming. The native
wrapper adds exact catalogue/filter controls and two original viewport images.
The preparation cases run in separate cold engines with `--preparation-case=menu`
and `--preparation-case=terminal`.

Stage 1 selects a named Elf/Magic vessel through the real Base controls and
presses Begin, requiring an ordinary Segment 1 world and its full opening entry.
Stage 2 explicitly stages opening completion, then uses the real Game Binding
API and card to verify equipping, closure and pause restoration. It does not
complete the cinematic, walk to the evidence store, or establish combat quality.
All runs isolate XDG/save paths from the player's real profile.

Linux Godot 4.7.2 runs the Windows EXE's embedded package. This checks the shipped
resources and game flow; an actual Windows OS launch remains the human playtest.
These guarded 20 FPS functional checks do not establish loading-frame latency or
whole-game performance. Individual script compilation/preloads can still hitch.
The script-cache contention explanation is consistent with
[Godot issue120827](https://github.com/godotengine/godot/issues/120827), but no engine
stack trace was captured, so an exact internal mutex cause is not asserted.

`manifest.json` binds complete raw run records (lossless gzip), guard/launcher
records, unfiltered logs, source snapshots, observations and both reviews. It
references binaries by exact SHA256 without committing them. Historical failed
and diagnostic outcomes remain distinct from final acceptance.

The runner omits `export_presets.cfg` from `source_hashes`. Configuration is
bound separately by its clean recorded Git heads, hashed Git objects and the
direct source snapshot (`export-config-provenance.json`); no missing runtime
hash is invented.
