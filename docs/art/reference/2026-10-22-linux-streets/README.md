# Street continuation — 22 October 2026

Candidate `b2982024` was normally merged into production at `84f19582`.
All fourteen dressed themes plus the original five aggregate assertions pass
(92,621 checks). The selected S2/S7/S6 occupied routes and reward pair are
checked, and root reviewed all 17 original images. Broad paving/grass-property
topology remains OPEN; final combined-production verification is separate. See [EVIDENCE](EVIDENCE.md), the [machine run index](evidence-index.json)
and [source bindings](sources/source-bindings.json).

The candidate streams discovery chunks before testing their walkability, validates
optional pinned passage chunks, and constrains later crossing pathfinding and
sidesteps to the corridor and its mouths. Actual player-cell traces must visit
near mouth, passage interior and far mouth in order, without outside detours or
skipped cells. The headless blocked-passage regression exercises the planner,
sidestep selector and trace validator; it does not physically walk the player.
The selected actual native traversals provide that proof with decoration,
collision, AI, director and streaming running.

Shared-ground allocation now applies to the secondary reward building. A further
correction paints only the actual doorway approach core, using the recorded
presentation entry and direction for rectangular and recessed L-shaped homes.
The eight-fixture regression checks both forms in four directions: connected
opaque approach cells, unpainted shoulders/beyond cells, footprint clearance and
three-cell physical approach width. This fixes a ground allocation error; source
assertions alone do not establish that every house/yard transition looks finished.
Underlying material indices remain their recorded numeric roles: index 2 must
not be described as earth (it includes the footway/floor role).

The care-measure run completed with 148 passing and two old histogram failures
after narrowing the apron. Its observed continuity-on histogram is
`{0:562, 2:124, 3:151, 4:181, 7:6}`; continuity-off is
`{0:719, 2:130, 4:169, 7:6}`. The earlier expectation bytes were preserved before
updating them. The old expected on/off values were
`{0:546, 2:114, 3:151, 4:207, 7:6}` and
`{0:716, 2:125, 4:177, 7:6}`. The measured failure is retained as a fixture
review outcome, never counted as GREEN. The later matching care-green rerun passes 150/0; its exact updated pins and
source-bound raw record are retained separately. All 148 other assertions passed, including positive bed support
(15 cells) and substantial lawn support (9 cells) in both modes.

## Evidence limits

Final launch records retain commands, dirty Git state, untracked source lists,
source maps, resources, diagnostics and exit/cleanup metadata. Scoped source
snapshots are deduplicated by SHA256 and bind to a run only when their bytes
exactly match its recorded launch hash. Historical dirty drafts whose bytes were
not retained stay hash-only. The initial packaging-time source snapshot is dated;
it does not retrospectively establish launch identity. The pre-apron source
backup is kept and matched separately.

Recorded PNG/import-sidecar hashes are indexed from the original launch maps;
packaging does not rehash the project's assets. A source inventory is not loaded
resource telemetry. No complete historical Game or generated `.godot/imported`
byte closure is supplied. Missing generated cache hashes/bytes and dynamic paths
remain missing; later current files are never substituted as historical evidence.
Packaging-time harness copies do not establish earlier unrecorded launcher bytes.

Earlier no-engine thermal preflight refusals, targeted assertion REDs and any
parser/import failures are distinct classifications in the index. A test footer
with missing imports, interrupted cleanup or nonzero diagnostics is never a clean
GREEN. Functional runs use the recorded one-engine guard and external runnable
duty; their wall durations are not comparative FPS, GPU or whole-Game budget
measurements. The optional 70°C functional start gate is recorded per run and is
separate from the prior 65°C comparative timing protocol. The first wrapper
thermal sample may precede Godot launch.

Selected native outputs retain exact original PNGs and manifests. Discovery
warps/staging are distinct from the required physical acceptance route. Check the
actual manifest for god mode, scripted input/attacks, staged pickups, live actor
and director state, collection, entry/exit, stream boundary and every failure.
A screenshot or successful exit alone is not physical traversal or visual acceptance.

Large raw records are deterministically compressed above 128 KiB; PNG bytes are
unchanged. [Compression map](compression-map.json) binds raw hashes and sizes to
packed copies, and [manifest](manifest.json) inventories delivered files. Inspect
packed JSON with `gzip -dc file.json.gz`.

## Refreshing this packet

Use the separately reviewed R3 adapter after actual source/raw/guard/image gates
and root review are complete:

```sh
nice -n 19 python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/street-packet-r3-adapter/build_street_packet_r3.py
```

The original builder and R2 adapter remain unchanged historical sources. R3
reuses the actual parser/S2 and adds only the two manual S7/S6 commands. The
original R1 failure and stopped R2 positive-ObjectID verifier verdict remain
unchanged; later source-corrected signed-ID acceptance is separate. Ordinary
collection still requires exact staged pickup telemetry and retained ownership
or quantitative feeding proof. The old/new apron reward pair changes only
SiteParcels; shared ground is true in both, so its separate configuration fix
is not isolated by that image pair.

Seventeen preexisting excluded unreachable cases remain baseline limitations.
The selected improvements do not complete all paving topology or establish
whole-Game performance. No engine or mutating Git command is launched by the
packet builder.
