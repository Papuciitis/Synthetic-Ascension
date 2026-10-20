# Linux entity visibility — 20 October 2026

Implementation: `31a1f6ce00eedaf07bc73368c355625788f9be98`, received art review
`faf0e7f4`. The user’s fully coloured enemy over an opaque house window was a
real failure: roofs alone did not cover the tall façade. The shared silhouette
now reaches the default ordinary/elite enemy batches, equipment and health icons,
player body/head, actual lower house faces, and original city/fruit tree pixels.

Keep this as a bounded visibility improvement. Square paving aprons, incorrect
L-shaped cast shadows, the scene’s flat appearance, segment atmosphere, L2 ground
corrections and L3 domestic purpose remain separate active implementation work.
The user explicitly authorized continuing locally and committing checked stages
while publication is unavailable. The [concept audit](../../../audits/2026-10-20-concept-fidelity-and-chat-audit.md)
and current handoff/reviews govern that work; this packet does not accept the
whole street or reopen already accepted S3 architecture.

Actual generated homes are seed16102026/chunk(0,3)/ID944996572 and
seed17/chunk(-3,5)/ID2128236757. Principal comparisons:

| Condition | Native evidence |
| --- | --- |
| Behind an opaque roof | [bed small](bed-cover-small-final/roof-covered.png), [fruit normal](fruit-cover-normal-final/roof-covered.png) |
| Partial tall-face coverage | [bed](bed-cover-small-final/facade-covered.png), [fruit](fruit-cover-small-final/facade-covered.png); exposed fragments and actual openings retain normal art |
| Front of the same house | [bed control](bed-cover-small-final/facade-front-controls.png) |
| Physical entry clears cover | [cutaway](bed-cover-small-final/roof-player-inside-cutaway.png), [exit restores](bed-cover-small-final/roof-player-outside-restored.png) |
| Actual original canopies | [ordinary enemies](bed-cover-small-final/ordinary-tree-enemies-covered.png), [fruit pickups](fruit-cover-normal-final/fruit-tree-pickups-covered.png) |
| Real player crossing canopy depth | [ordinary small](player-ordinary-small-final/player-tree-behind.png), [fruit normal](player-fruit-normal-final/player-tree-behind.png), [reduced motion](player-ordinary-reduced-final/player-tree-behind.png) |
| Occupied production sample | [fight still](bed-cover-fight-final/fight.png), [measured-time video](bed-cover-fight-final/occupied.mp4) |

Four full actual-Game runs produce44 PNGs, zero failures and zero saves. Five
consumers retain their positions/art and the two enemies retain explicit instance
IDs/world handles through roof strength1→0→1. Three real-player routes produce9
PNGs, zero failures/saves and genuine collision/input traversal. Independent
review inspected native bodies/icons, canopy gaps, front depth, quiet HUD and
restoration. Armour collars, lock/exploration frames, floating callouts and attack
indicators keep their existing owners; they are not body/icon silhouettes.

The occupied sample records34 frames,25 weapon fires,28 hits and zero failures,
with a silent H.264 clip encoded at measured wall timing without resize and a
clean decode. It is scripted god-mode combat with controlled real enemies,
ambient spawn/encounter beats disabled and streaming frozen after actual reload.
The fixed plates freeze staged enemy simulation, use existing never_cull fixture
metadata and disable staged pickup Area2D monitoring. They prove presentation,
not spontaneous spawns, collection, balance, human comfort or encounter reachability.

Focused checks: shared coverage25/0; actual façade46/0; descriptors47/0; native
batch coordinates23/0; enemy consumer38/0; pickup consumer33/0; isolated player
95/0. Existing regressions pass for city kit1300/0, procedural city5430/0,
street19/0, dungeon roof99/0, dungeon production762/0, shared guard411/0,
enemy proxy48/0, batch lifecycle9/0, leases43/0, elite sheen21/0, cast-shadow
render0 failures, health lock8/0, choice5/0, loot cap6/0 and tagged cache0 failures.
The last gameplay parse audit is553/0 across8 roots. Monitor self-tests pass19/0,
including the added shader-include provenance case. Exact commands, intermediate
snapshots and failed attempts are retained below; passing footers with runtime
diagnostics are never counted as clean results.

Shared coverage is spatially indexed per viewport/world canvas and has no old
32-triangle rendering cap. Original foreground alpha is cached once per live
texture resource. View broad-phase reduces offscreen descriptor work. These
captures report sampled CPU refresh around4–11ms and first-use/source-preparation
peaks around71–110ms; they do not certify a frame budget or whole-game warmup.
No physics, AI, rewards, culling eligibility, RNG, saves or scenery Z changed.

The [source bindings](source-commit-bindings.json) match all33 scoped committed
code/test/tool inputs for the eight final actual-Game runs and last parse,
including the shared shader include. The isolated synthetic player plate is an
explicit earlier snapshot. Source/alpha details and exclusions below remain part
of the result: ordinary/elite default batches are proved; authored boss anchors,
debug sprite fallback, broader foreground classes and projectile/tell depth do
not gain universal acceptance from this packet.

`evidence-index.json` is the authoritative list of files actually bundled.

The four city folders contain 44 PNGs and their four `capture-info.json` records.
The three player route folders contain 9 PNGs and their route/capture records.
The final occupied fight includes three named stills, its measured-time video
and encoding/decode records. Raw frames stay in local scratch; their exact
individual hashes and timing remain in the encoding record. Other videos are
included only with complete sidecars; absent videos are not claimed. Original command arguments keep
their local machine paths as provenance, while native plate `file`/`name` entries
resolve within their packaged capture folders. Scratch-only paths in logs do
not imply those files are bundled.

`synthetic-player-final` contains 22 PNGs and `result.json` from the isolated
player fixture after the live Sprite2D AABB prefilter, **before the World2D/canvas
isolation filter**. It is qualified earlier-snapshot evidence. Folder names
ending in `final` designate selected runs, not one universal source revision.
Exact source snapshots are stored per process record; a final code-commit
binding is separate. `parse-final` is the earlier 553-script audit, while
`parse-commitable` is the required later runtime audit.

The two `rejected-trials` stills are historical diagnostics. The occupied trial
exposed fully coloured enemy art over an opaque window below the roof. The
façade trial followed registration work, but moving actor positions differ;
the two pictures cannot establish an exact before/after comparison and are
not the fixed-position acceptance plates. Their complete process records and
diagnostics are retained without bundling their other scratch frames.

`process/summary.json` distinguishes valid feature RED, clean checks and failed
attempts. Parser/compiler failures, invalid invocations, diagnostic-bearing
exit0 runs and the outdated lazy-diagnostic guard test are **not GREEN evidence**.
`player-native-red` also retains its additional native canvas-map diagnostic.
The current shared guard fixture explicitly compares uncapped coverage with
its independent dense-grid reference; old 32-triangle assertions concern only
the retained diagnostic. `process/monitor-tests.*` retains monitor self-tests.

Full monitored commands, exits, diagnostic lists, resource samples and all three
logs are retained. Large `source_hashes`/`source_untracked` records are moved
losslessly to content-deduplicated `process/sources` files. Original machine-wide
Git status is omitted, with the original result JSON SHA-256 retained.

These are scripted native samples. They do not establish continuous human play,
balance acceptance, whole-city art acceptance or a comparative performance
budget. Solid masonry polygons approximate tiny bitmap-edge alpha fringes;
registered sprite façades/trees sample their original bitmap alpha. Existing
boss-owned/debug fallback exemptions remain outside universal coverage claims.
