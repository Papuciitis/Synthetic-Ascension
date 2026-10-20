# Windows art direction ↔ Linux production handoff

Updated 20 October 2026. This is a working checkpoint, not visual acceptance of
the game. The user asked Windows to lead art direction and provide assets, and
Linux to take the heavier implementation, testing and native capture work.

**Latest continuation, 20 October:** Linux `fd80106a` is received and reviewed.
Keep the selected soil, useful lawn core, rough domestic masonry/furnishings,
connected roof planes/paving, selected daylight and sampled body/icon depth.
Household composition and entry character still need work; ground boundary
continuation, remaining cue depth and ordinary moving-play/performance acceptance
stay open. A single plain rush-mat source is supplied for the sleeping corner.
Read the [new lead review](docs/art/reviews/2026-10-20-linux-city-continuation-review/README.md)
and [ART_STATUS](docs/handoff/ART_STATUS.md). Linux should acknowledge the received
feedback commit and return the bounded household/visibility/performance packet.
No Windows engine ran. Full concept fidelity remains the governing goal, not an
achieved milestone. The checkpoints below are history.

**Previous L2 update, 20 October:** Linux `ce5671e6` is received and integrated as
qualified WIP. KEEP the subdued S7 moss and local care foundation; one bounded
L2 correction is still needed for lawn readability, chunk-edge continuity and
wet/dry earth. A single new wet-earth source candidate is supplied for a native
trial after sampling/cache inspection. See the [L2 lead review](docs/art/reviews/2026-10-20-linux-l2-lead-review/README.md)
and current ART_STATUS. L3 and V1 remain open. The older checkpoints below are history.

**Earlier update, 20 October:** Linux packet `1fa7a552` is published and reviewed.
L0 is established; the two native garden fits are kept at their tested scale.
The complete street still needs work. Current direction is **L2 next**, then L3,
with roof/entity visibility retained as a required visual gate. Read the updated
[ART_STATUS](docs/handoff/ART_STATUS.md) and [lead review](docs/art/reviews/2026-10-20-linux-s2-lead-review/README.md)
before the original checkpoint/evidence snapshot below. The old publication
authentication failure in Linux's status is historical; manual Git relay is available.

## Start here

Repository: `https://github.com/Papuciitis/Synthetic-Ascension.git`.
The integration branch is **`enemy-world-work`**, not the remote default branch.
Windows currently calls its local branch `feat/authoritative-enemy-world`, which
tracks `origin/enemy-world-work`. The last commit before this checkpoint was
`acafb7c53f49e02fc5125f2ca1a14d98de85cdb1`. Use the received tip containing this
file, and record its actual hash in [LINUX_STATUS](docs/handoff/LINUX_STATUS.md).

Read, in order:

1. [Vision](docs/SYNTHETIC_ASCENSION_VISION.md), the latest relevant
   [roadmap entries](docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md), and
   [README](README.md).
2. [Accepted direction image](docs/art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png)
   and its [implementation handoff](docs/art/concepts/2026-10-18-city-directions/IMPLEMENTATION_HANDOFF.md).
3. [Lead's concept/game/chat audit](docs/audits/2026-10-20-concept-fidelity-and-chat-audit.md).
4. [Gardens and ordinary-house interiors](docs/art/2026-10-20-medieval-gardens-and-domestic-interiors.md)
   and [ground material direction](docs/art/2026-10-20-ground-material-direction.md).
5. [Current production result and evidence limits](docs/art/reference/2026-10-20-s2-street/RECOVERY_STATUS.md)
   and [ART_STATUS](docs/handoff/ART_STATUS.md).

The four old visual chats are archived. Their requests are historical context;
do not restart their open-ended loops. For older decisions, follow
`docs/history/chat_archive/README.md`, `HISTORY.md` and `coverage.json`; the archive
is incomplete. Current user instructions and project records govern the work.

## What we are trying to make

A bright, temperate Mediterranean city with Greek/Roman civic bones, inhabited
medieval European development, and restrained industrial/authoritarian science
fiction. Preserve crooked routes, asymmetric lots, uneven growth and room for
horde combat. Houses may have tended grass, a useful bed or a small fruit tree;
open land beyond human care remains procedural wilderness. Keep some untended
homes. Do not turn every gap into a square lawn or paved ring.

The first milestone is one convincing **real generated S2 street**, including a
genuine home, then its ground and household interior. Passing structural checks
and producing concept paintings do not satisfy the visual goal. S3's already
accepted guard-loggia refinements should survive. New district families, S4A and
whole-city expansion are outside this packet.

## Roles and how the two PCs communicate

| Owner | Work | Record |
| --- | --- | --- |
| Windows lead | Art direction, source generation/selection, anchors and scale, critical review of native images, integration and normal pushes | `docs/handoff/ART_STATUS.md` |
| Linux production | Runtime code, portable test/capture tooling, imports/bakes, performance investigation, native captures and checks | `docs/handoff/LINUX_STATUS.md` |

The status files and Git commits are the durable message channel. These local
Codex chats cannot assume they can send live messages to a chat on the other PC.
The human can relay a branch/hash or a short request when needed. A pushed file
does not mean the other worker has fetched it or accepted the result: record an
acknowledgment with the received hash. Credentials and machine-local settings
stay off Git.

Windows owns asset source packs and direction documents. Linux owns runtime
implementation, Linux tooling, its status file, and new dated evidence folders.
Ask for a specific asset with footprint, anchor, view and native crop; Windows
can supply it. Propose cross-owner edits in the status record before overlapping
work. One worker owns Git mutations in a given checkout, and only one engine
runs on a machine at a time, including human playtests.

Use bounded packets: name the task, received base hash, changed paths, checks,
native evidence, limitations and next request. The lead will explicitly keep
or rework the result. Useful progress deserves to be retained; a weak visual
result needs a concrete correction, not another round of general reassurance.

## Linux pickup and Git exchange

For a fresh clone (Bash):

```bash
git clone --branch enemy-world-work https://github.com/Papuciitis/Synthetic-Ascension.git
cd Synthetic-Ascension
git switch -c codex/linux-world-production
git rev-parse HEAD
```

If that Linux branch already exists, switch to it rather than creating it again.
In an existing checkout, inspect `git status` and preserve its own work before
merging. Do not reset, clean or blindly stash local changes. A fresh clone is
preferable to copying this Windows worktree: its `.git` linkage, `.godot` import
cache, junctions, `.superpowers` state and save files are machine-local.

Linux receives art/integration updates on its production branch:

```bash
git fetch origin
git merge origin/enemy-world-work
# Inspect ART_STATUS; acknowledge the received commit in LINUX_STATUS.
```

After a small reviewed implementation packet, Linux stages explicit relevant
paths, commits code plus results/status, and publishes its own branch:

```bash
git push -u origin codex/linux-world-production
```

Windows fetches that branch, reads its status/diffs and personally inspects new
images before integration. With a suitable clean integration checkout:

```bash
git fetch origin
git merge origin/codex/linux-world-production
git push origin HEAD:refs/heads/enemy-world-work
```

Both sides keep normal ancestry and retain each other's commits. Linux does not
also push the integration branch. Never force-push or blanket-stage a checkout.
If either branch moved incompatibly, stop the Git mutation, report the actual
conflict, and resolve it deliberately. If automatic Git access fails, give the
human the exact branch/hash and push or pull command to relay manually.

## Current implementation and source assets

The checkpoint includes raised S2 wall masses, fitted street aprons, sparse
service workshops, coherent irregular upper returns, and household-only seeded
garden dressing. Original parcels/RNG/rewards remain preserved in checked
fixtures; added service annexes explicitly disable encounters and exploration
loot. A zero chance alone was not sufficient because Luck can increase it.
Outdoor garden dressing remains visible when the house roof fades.

The complete implementation requires the new
`scenes/world/buildings/CityStreetFrontage.gd`, the three new CityStreet/CityService
tests, and `tools/capture/city_resource_guard.ps1`; do not transplant only the
modified tracked files. The Windows `.ps1` launchers use Windows process/memory
APIs and are not Linux launchers.

Selected source packets are included, with prompts, manifests and measurements:

| Packet | Selection and integration status |
| --- | --- |
| `assets/world/domestic_gardens/v1/` | Use `fruit_tree_overhead_v2.png`, not the rejected first frontal tree. Root anchor `(660,1060)`, uniform scale `135/1167`. Flower/herb bed anchor `(955,485)`, up to 115 world px visible width, preserve aspect; a separate soil patch supplies depth. In runtime, native fit still pending. |
| `assets/world/domestic_interiors/v1/` | `timber_cot.png` and `cooking_hearth.png` are source candidates only. Cot front contact `(530,1345)`, ground center `(530,800)`; start near 60 world px width. Hearth front `(800,805)`, center `(800,540)`. Use manifest footprint estimates, preserve alpha/aspect, do not stretch. |
| `assets/world/ground/city_care/v1/` | `cared_lawn.png` and `damp_moss_soil.png` provisionally kept after source/repeat review. QA previews are not runtime textures. Native scale, blending and repetition still need review. |

Neither new ground textures nor household furnishings/domestic masonry are
integrated yet. Source approval is provisional and may change after native fit.

## Ordered Linux tasks

**L0 — establish a reproducible Linux lane.** Record the received commit, Godot
version, OS/display/GPU, available memory and branch in LINUX_STATUS. Import the
fresh clone. Make a small monitored Linux launcher with isolated data, logs,
timeouts, owned-process cleanup and sensible measured memory headroom. Do not
weaken the Windows guard or reproduce its resource failure. Reuse committed
GDScript scenes/tests; do not depend on absent Windows scratch runners. Preserve
exact commands, source hashes, exits and diagnostics.

**L1 — finish the current S2 exterior checkpoint.** First inspect the natural
home at seed `16102026`, chunk `(0,3)`: irregular south-entry `row_house`, bed
variant 0. Second fit: seed `17`, chunk `(-3,5)`, north-entry `row_house`, fruit
tree variant 1. These are generated ChunkManager samples, not invented scenes.
The existing survey identifies parcel bounds/usage/doors but does not emit the
runtime building IDs needed by the native preview. Add a bounded sample lookup
or emit those IDs; do not assume visual_seed is a building ID. The older v2
image at chunk `(-1,3)` shows passage/workshop, not a home.

Capture current-source exterior/contact at 960×540 and 1280×720, then real
entry/cutaway/exit, deterministic streamed reload and occupied moving combat.
Use normal ground/foliage/actors and ordinary HUD after transient tips clear.
Resolve specific clipping, scale, contact or composition faults. Send a small
set of useful stills plus result JSON and a short moving review artifact rather
than thousands of raw frames. This is the next visual gate; do not call the
street accepted before the lead reviews it.

**L2 — ground care and S7.** Follow the ground brief. Keep semantic terrain IDs,
RNG, organic coverage and physical rules. Distinguish tended household ground
from rough/neglected open ground using actual domestic use, footprint and door
context. The active GroundSplat palette has eight slots; a ninth silently aliases
to the first. Do not casually add more IDs or redesign the renderer. Existing
grass/dirt cover much of the wild range. `ground_dirt_path_01.png` is flagstone
paving despite its name. The old moss source is a cyan/purple large-leaf carpet;
S7's cool tint slightly amplifies it. Use the subdued moss/soil candidate and
review natural S7 seed 4/canal_services plus the underpass treatment.

`WorldArt.ground_material_array()` prefers
`assets/world/ground/baked/ground_materials.res`; its shape/format validation alone
does not establish source freshness. Rebuild with
`tools/dev/BakeGroundMaterials.gd` when changing array sources and validate with
`tools/tests/GroundMaterialCacheTest.tscn` as well as relevant terrain/splat tests.
Inspect actual native rendered ground to rule out stale cache pixels.

**L3 — genuine domestic interiors.** Use the real clay-roof row_house evidence
in the domestic brief; the slate civic arcade/security interior is not a home.
Add sleeping, cooking, work and storage purpose with sparse suitable furnishings,
clear routes and consistent collision/cover. Restore stronger stone/mortar/face
character on domestic surfaces. Original rough wall kit sources survive;
`city_stone.gdshader` currently remaps them to a pale cool range. Scope domestic
materials to the actual perimeter/interior faces too: `VARIANT_UNDER_ROOF` only
marks partitions. Preserve the existing civic/S3 treatment and roof/occlusion
behavior. Judge at actual gameplay size, including occupied interiors.

## Linux command starting points

Use the project's Godot 4.7.x Compatibility editor build and record the exact
version. Set the executable to the installed Linux binary; the Windows binary
path is not portable. These are direct commands, not a monitored Linux runner.
Complete L0 and check available resources before starting an engine. Do not run
them while a human game or another test is running.

```bash
SA_GODOT=/absolute/path/to/Godot_4.7.x_linux.x86_64
SA_RUN_ROOT="$PWD/.superpowers/handoff-linux/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$SA_RUN_ROOT/data" "$SA_RUN_ROOT/config" "$SA_RUN_ROOT/cache" "$SA_RUN_ROOT/logs"
export XDG_DATA_HOME="$SA_RUN_ROOT/data"
export XDG_CONFIG_HOME="$SA_RUN_ROOT/config"
export XDG_CACHE_HOME="$SA_RUN_ROOT/cache"
"$SA_GODOT" --version
"$SA_GODOT" --headless --path . --import --log-file "$SA_RUN_ROOT/logs/import.log"
```

Run focused checks sequentially; inspect each exit and log before the next:

```bash
"$SA_GODOT" --headless --path . --script res://tools/tests/CityStreetFrontageTest.gd --log-file "$SA_RUN_ROOT/logs/footways.log"
"$SA_GODOT" --headless --path . res://tools/tests/CityServiceFrontageTest.tscn --log-file "$SA_RUN_ROOT/logs/service.log"
"$SA_GODOT" --headless --path . res://tools/tests/CityServiceNaturalTest.tscn --log-file "$SA_RUN_ROOT/logs/natural.log" -- "--out=$SA_RUN_ROOT/natural-streets.json"
"$SA_GODOT" --headless --path . res://tools/tests/CityPlannedBuildingTest.tscn --log-file "$SA_RUN_ROOT/logs/planned.log"
"$SA_GODOT" --headless --path . res://tools/tests/ScriptParseAuditTest.tscn --log-file "$SA_RUN_ROOT/logs/parse.log"
```

Also use CityBlockKitTest, CityBlockProceduralTest and PlayerRoofOcclusionTest
when the changed paths warrant them. Strict warning evidence covered 14 targets
and seven categories, not the entire editor warning panel. To reproduce it on
Linux, make an isolated source snapshot, set the seven warning severities listed
in the [strict warning record](docs/art/reference/2026-10-20-s2-street/review-checks/strict-warning-audit.json)
to 2 in that snapshot's project file,
import it, then run `res://tools/dev/ReportedWarningAudit.gd` with
`REPORTED_WARNING_AUDIT_OUT` set to its output JSON. Keep the working project's
warning configuration unchanged. Do not copy the Windows snapshot's junctions.

For a bounded native still, the committed starting scene is
`res://tools/dev/CityBlockPlayablePreview.tscn`. Example after L0, on a functioning
graphical desktop, using a fresh output folder:

```bash
"$SA_GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
  res://tools/dev/CityBlockPlayablePreview.tscn -- \
  --review=small --world-seed=16102026 --segment=2 --still-only \
  "--out=$SA_RUN_ROOT/native-default"
```

The default selects a searchable reward building, not the queued home. After
resolving its actual ID, supply both `--target-building-id=<id>` and
`--target-chunk=0,3`. A chunk argument alone does not select a home. Use
`--entry-only` only for ambient parcels; guarded reward buildings require the
full security run. `--review=normal` gives 1280×720. `--review=reduced` is a
separate reduced-motion check. Do not hide natural district details for the main
evidence. Headless execution cannot supply native image evidence.

This preview uses the production Game, but scripted input, god mode and
controlled spawns. `--playable` restores human controls and camera, but its ambient
spawner remains disabled. Qualify these conditions and supplement them with a
normal occupied playtest where needed; do not call the preview ordinary live play.

## What the existing evidence actually proves

The post-review source hashes covered 15 files, all verified before packaging.
Asset documentation then received terminal-newline cleanup; the original hash
record is retained and [packaging-normalization.json](docs/art/reference/2026-10-20-s2-street/review-checks/packaging-normalization.json)
records the affected metadata hashes. Asset pixels, JSON values and tested code
are unchanged. Git can additionally normalize text line endings between PCs;
use Git commits plus the explicit source records, not assumed cross-OS byte
identity. An independent reviewer checked actual exits/logs and found no blocking correctness
defect in the scoped changes: final service regression 8 fixtures/0 failures,
natural survey 12 chunks/4 seeds/0 failures, planned buildings 20 chunks/62 styled
buildings/0 failures, parse audit 549 scripts/8 roots/0 failures, strict warning
audit 14 targets/7 categories/0 failures. Earlier kit/procedural/roof/footway runs
predate the last two review fixes; see RECOVERY_STATUS for their exact scope.
Linux should establish its own fresh-clone results before expanding the work.

The 24 v1 Game environment plates and two environment-v2 images are historical
visual evidence. V2 has one frozen production chunk with ground/props, but no
Game/HUD/player/entry/combat, and predates current garden integration and fixes.
No completed current-source home-garden fit or full native gameplay result exists.
Stopped v2 attempts and failed initial regression/survey records are labeled;
they are not passing evidence. Some JSON records retain original Windows scratch
paths for provenance. They are records, not portable launch instructions.

Historical capture helper sources are preserved as data in
[capture-source](docs/art/reference/2026-10-20-capture-source/README.md).
They reference old scratch paths; port/promote them if useful, or extend the
committed preview. A new run against new source is new evidence, never a
reconstruction of the old source state.

Windows suffered two hard freezes requiring forced restart. Event 41 documents
the forced restarts, not their cause. Memory pressure is observed; the cause is
not established. Guarded native attempts stopped before producing the missing
images. Windows should continue art generation/review and small Git operations;
Linux takes the heavy engine work. Do not close unrelated applications or change
OS/driver/pagefile settings as part of this handoff.

## First message to a Linux coding chat

> Read HANDOFF.md and its linked current direction/evidence records. You own the
> Linux production branch and LINUX_STATUS.md; Windows owns art direction and
> ART_STATUS.md. Start by acknowledging the received commit, set up isolated,
> monitored Godot 4.7.x checks, then finish L1 on the two actual generated homes.
> Keep the irregular medieval city and wild/tended distinction. Publish small
> checked commits, native images and honest limitations to your branch for the
> Windows lead's visual review. Do not restart the four archived design chats or
> expand district families. Coordinate through the two status files and Git;
> request a precise asset when needed.

Godot reference for these command/data conventions:
[command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
and [Linux data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).
