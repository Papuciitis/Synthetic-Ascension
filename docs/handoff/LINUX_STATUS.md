# Linux production status

Owner: Linux production worker. Updated 20 October 2026.
Read [HANDOFF](../../HANDOFF.md) and [ART_STATUS](ART_STATUS.md) before working.

## Pickup acknowledgment

- Latest received continuation review: `6554c100305ab96444af86dccab84d3420f200c9`.
  On 20 October, `git fetch origin` followed by
  `git merge --ff-only origin/enemy-world-work` advanced this branch from
  `fd80106a` without conflicts. Both remote refs confirm the human published
  `fd80106a`; the previous credential failure is historical.
  The [current lead review](../art/reviews/2026-10-20-linux-city-continuation-review/README.md)
  keeps the bounded ground, roof, domestic material, atmosphere and body/icon
  improvements. Continuation now targets household/entry composition using the
  supplied rush mat, remaining moving cue/projectile/collection depth, and
  occupied movement/streaming cost without capture readback. Natural care
  continuation across chunk boundaries remains open. No new district or
  ground-source packet is planned.
- State: **Visibility, useful lawn core, selected wet earth, connected paving,
  actual-footprint casts, fitted irregular roofs, furnished domestic homes
  and theme atmosphere through `fd80106a` are published and reviewed as WIP.
  Their retained final integration checks pass; the next correction is active.**
  L1 garden fit is retained; full ground/street acceptance remains open.
- Received integration commit: `b5de9d53d081fa5fecde4188f811bf38d3f97cff`.
  `git fetch --all` confirmed local HEAD and `origin/enemy-world-work` agree.
- Latest received review commit: `24d838f77df1b85ca3ec8636ec6a4900a6b19f7d`.
  After `git fetch origin`, `git merge --ff-only origin/enemy-world-work`
  advanced this branch from `1fa7a552` without conflicts. This incoming change
  contains direction/review documentation and sampled images, no runtime code.
- Latest L2 review received: `faf0e7f4b24a07fc4d288d229341b0d28135e9bb`.
  After `git fetch origin`, `git merge --ff-only origin/enemy-world-work`
  advanced this branch without conflicts and retained the visibility WIP.
  Remote production ref confirms the human published `ce5671e6`; the previous
  HTTPS failure is historical, not an outstanding L2 publication blocker.
- Production branch: `codex/linux-world-production`, created from that tip;
  `git merge --ff-only origin/enemy-world-work` reported already up to date.
  Existing untracked local assets/import sidecars remain untouched.
- Host: Linux Mint 22.2, X11 display `:0`, Mesa 25.2.8 Intel UHD Graphics 620,
  direct hardware rendering. Physical memory 31,833 MiB; initially 19,298 MiB
  available, no swap. The monitor will measure each run separately.
- Engine: `/home/user/Downloads/Godot_v4.7.2-stable_linux.x86_64`, reported
  `4.7.2.stable.official.ed1daf0bf` by a monitored `--version` run.
- Human confirmed the editor/playtest closed before engine checks. Process
  exclusion and an advisory launcher lock will be checked for every run.
- Run data/config/cache and logs will be isolated under `.superpowers/`;
  no existing user profile is used.

## 20 October — local implementation continuation

The user authorized continuing while asleep and committing checked stages.
`4c4a6cb2` adds sparse cot, cold hearth, table and crate groups with six explicit
streamed low-cover cells where the deterministic household fit permits.
`276e5e15` finishes domestic plaster, upper masonry and the supported south-entry
header. Four actual-home runs at 960×540 and 1280×720 each passed entry, four prop
contacts, a short occupied fight, exit/roof restoration and zero save writes.
Their plates, measured routes, source bindings and four decoded clips are in the
[domestic packet](../art/reference/2026-10-20-linux-domestic-interiors/README.md),
committed as `2caa696a`. Reward comparisons exercise actual chance/claim and full
single-item factory paths, beyond planner RNG.

`9eab80dc` fits footways to actual entrances and softens their external edges.
`346518ee` adds connected S2 irregular roof planes, coherent tile directions and
fitted fascia, and corrects actual-outline casts for non-guard families. S3 keeps
its reviewed custom treatment. The [scene packet](../art/reference/2026-10-20-linux-scene-depth/README.md),
committed as `eb78988e`, retains matched actual-Game roof pairs at both sizes.
These improve the measured samples; whole-street art acceptance remains open.

The procedural survey exposed a stale rectangular-interior assertion: seed 2026
casts into its L-shaped northwest exterior notch with no intersection against
any actual occupied outline. Test correction `02ee8d3a` checks every real receiver,
includes deliberate transformed interior-overlap controls, and explicitly runs
S2. It passes 6,318 assertions across 20 layouts. The failed and diagnostic
runs remain retained.

Atmosphere implementation `de93d886` uses the already selected theme,
world-anchored cloud daylight, profile-specific direct/fill response and quiet
damp-ground air. All eight selected Game/authored runs pass without diagnostics
or save writes. Native samples cover S2 courtyards, S3 checkpoint lanes and S7
canal services at both sizes; fourteen profiles have data coverage. The
[atmosphere packet](../art/reference/2026-10-20-linux-theme-atmosphere/README.md)
is committed as `81e9567e`. Actual S1 and Hub keep their authored owners
(13 assertions). The first S2 pan probe's
pixel-rounding failure is preserved; the corrected texel-center probe changes
by at most 1/255 during fixed-phase camera pans. S7 normal includes 25 distinct
paused weather samples; the Reduced Motion fight records 34 frames, 25 fires
and 27 hits, with a cleanly decoded clip. No new district architecture, magic
weather, biome reroll or gameplay/save ownership is added.

The [integration packet](../art/reference/2026-10-20-linux-integration/README.md)
retains the original failed assertion, diagnosis, corrected checks and combined
visibility review: 11 plates, no failures, no saves and no monitor diagnostics
with all new runtime slices present. Final main-tree
footprint 11/0, care 125/0 and parse 557/0 checks are clean at `de93d886`. Earlier
integrated kit 1300/0, roof 99/0, shared cover 25/0, domestic 336/0 and reward 43/0
records keep their original launch hashes. Whole-street art review, general care
continuation across chunk borders, missing district-specific architecture and
ordinary human play remain open.

The current continuation is retained on `codex/linux-world-production`.
A noninteractive HTTPS push attempt failed because this process has no GitHub
username credential; no authentication or machine settings were changed.
The user authorized continuing locally without waiting for publication. When
ready, publish the existing commits from this PC with:

```bash
git push -u origin codex/linux-world-production
```

Windows can then fetch this branch and review the dated evidence packets.
Linux does not publish the integration branch. The older publication history
below concerns previously received packets and does not establish publication
of this newer continuation. ART_STATUS remains Windows-owned.

## Current bounded packet

The supplied wet-earth candidate is selected locally for semantic5 after native
same-camera comparison. Only source/layer5 changes; the other13 prepared layers
match. Cache38/0, terrain23/0 and native exact layer+mip warmup3/0 pass, with
largest loading gap197.122ms against the unchanged250ms gate. Normal/reduced
occupied captures each report34frames,24fires,26hits,0failures/0saves and decode
cleanly. The real dry1/no-stain3×3 control and the failed5×5 search are retained.
See [wet-earth packet](../art/reference/2026-10-20-linux-wet-earth/README.md).
This is a production selection pending lead art review, not complete L2/street
acceptance. Paving/actual-footprint shadows are separately committed as9eab80dc
and merged locally. The newer completed roof-plane, domestic and atmosphere
stages are recorded above; broader art review remains open.

Local checked continuation,20October: the household care inner plateau is now
0.50 instead of0.20, preserving the bed’s15-cell support while filling its legal
3×3 core. Care125/0, natural preservation8chunks/0failures, splat33/0 and two
native same-camera seam runs are clean; both neighbor signatures survive streamed
reload. See [ground-core checkpoint](../art/reference/2026-10-20-linux-ground-core/README.md).
General cross-chunk shape continuation and complete L2 art acceptance remain
open. Wet-earth production selection is retained pending lead art review.
Paving/actual-footprint casts, domestic purpose and theme atmosphere have since
been integrated locally, with their measured limits recorded above.
The user explicitly requested continuing autonomously and committing as work is
checked; publication is not a work blocker.

L0 and the L1 evidence packet are complete; Windows has kept the sampled garden
fit while leaving complete-street acceptance open. Windows received L2 as
qualified WIP: keep moss and the care foundation; correct lawn readability,
inspect the bed chunk seam and verify/correct wet earth with a real dry control.
The user reprioritized enemy/item visibility behind buildings and trees, then
authorized autonomous L2/L3, scene massing/paving and theme-atmosphere work.
Those checked stages are committed separately. New district architecture and
whole-street visual acceptance remain open; current captured samples do not
validate every generated layout. Windows retains lead art review/source generation.

Execution checklist for this packet (the existing HANDOFF is the scope/spec):

- [x] L0: implement and exercise a Linux process/resource monitor; import and
  run the handoff's focused checks sequentially, preserving exact commands,
  exits, diagnostics and source hashes.
- [x] L1: emit actual runtime building IDs from the natural survey and verify
  both named homes rather than treating a profile seed as an identity.
- [x] L1: capture both real homes at 960×540 and 1280×720 with natural context
  and normal HUD after transient tips; resolve observed contact/camera faults.
- [x] L1: capture physical entry/cutaway/exit, deterministic streamed reload,
  occupied moving combat and reduced-motion review; package useful stills,
  bounded moving evidence and result JSON with fixture limitations.
- [x] Independently review the scoped changes and evidence.
- [x] Publish the checked Linux packet and receive the Windows lead's
  keep/rework decision (publication confirmed by remote refs and lead review).

The lead keeps the measured native garden fit in these fixtures. Whole-street
approval, ordinary human play and full L2/L3 visual acceptance remain open.
Domestic furnishing is now implemented and captured above. The earlier user
screenshot reproduced an enemy fully coloured over an opaque lower wall;
`31a1f6ce` corrected that body/icon fault, with the combined native check retaining
it after the new visual work. Broader tell/projectile depth and complete occupied-
street acceptance remain open.

## 20 October — body/icon visibility checkpoint and continued local work

Implementation `31a1f6ce00eedaf07bc73368c355625788f9be98` fixes the user's
fully coloured enemy over an opaque lower house face. A shared per-viewport,
world-canvas spatial snapshot now feeds player body/head, default ordinary/elite
proxy and materialized batches, equipment and health icons. Actual city/fruit
tree alpha, painted façade pixels and bounded upright masonry join live roof
coverage. Depth, source gaps and roof cutaways preserve normal exposed art;
the rendered path has no old32-triangle cap. Existing hurt/elite/lock/glow and
eligibility owners remain intact. No simulation, collision, RNG or save changes.

The [native packet](../art/reference/2026-10-20-linux-entity-cover/README.md)
contains44 final actual-Game plates on the two real homes,9 real-player canopy
route plates, an explicitly earlier22-plate isolated fixture, and one short
occupied clip with measured timing/clean decode. All four full runs have11
plates/0 failures/0 saves; the same five consumers restore roof strength1→0→1
through actual player entry/exit. Three player routes pass, including reduced
motion. Fixed samples explicitly protect staged actors from retirement and
disable staged pickup collection; they do not prove ordinary play or collection.

Clean focused checks include shared25/0, façade46/0, descriptors47/0, native
batch coordinates23/0, enemy consumers38/0, pickup consumers33/0, isolated
player95/0, shared guard411/0 and final gameplay parse553/0. Relevant city,
dungeon, enemy, elite, cast-shadow, pickup/loot and streamed reward regressions
pass. The occupied sample has34 frames/25 fires/28 hits/0 failures. Independent
source/native review supports the bounded result. Per-run input snapshots,
failed attempts and33 scoped committed input bindings are preserved; all nine
final actual-Game/parse records match the implementation commit exactly.

Evidence commit: `b62da7e47b03e81b5936ff9d6bd2d97143c9cba7`. Root verified
all379 packet artifact hashes/lengths from the committed Git blobs. The normal
own-branch push was attempted and still failed with `could not read Username
for 'https://github.com': terminal prompts disabled`. Both local commits are
retained. When the human is back, relay the latest branch tip with
`git push -u origin codex/linux-world-production`; authorized local work continues.

This does not establish whole-street art acceptance. Façade imagery proves
partial per-pixel coverage, not whole-body concealment everywhere. Existing
armour collars, lock/exploration markers, attack tells/projectiles and authored
boss/debug exceptions are not universally covered. Solid textured masonry
approximates tiny exported alpha fringes; registered sprites use actual alpha.
Sampled shared refresh is about4–11ms with first-use peaks71–110ms in these
fixtures, not a general performance or warmup guarantee.

The user explicitly asked to continue locally while asleep, without waiting for
a push, and to commit checked work as it progresses. They pointed again to the
[concept-fidelity audit](../audits/2026-10-20-concept-fidelity-and-chat-audit.md),
which was read in full. New concrete priorities: remove the rough square paving
apron, repair cast shadows for L-shaped/nonrectangular houses, address whole-scene
flatness and give established segment themes distinct physical lighting/weather/
atmosphere. These join the authorized bounded L2 correction and L3 domestic
purpose/masonry; they do not authorize speculative asset packs or reopening
completed S3 architecture. The audit's whole generated street, usable circulation,
daylight hierarchy and inhabited infrastructure remain the visual objective.

Three isolated local worktrees from31a1f6ce separate scene depth/transitions,
domestic interiors and theme atmosphere from the main ground correction. Root
retains all Git mutations and the single monitored engine lane. Tests/native
review precede integration; commits remain separate. Windows retains asset
direction and final keep/rework. Publication is a relay step, not a reason to
leave authorized implementation idle.

## 20 October — L2 implementation and native packet ready

Implementation `0d6f761acd2adff963efff5619d0a34f1bff4f9b` follows working base
`3646a781` and received art direction `24d838f7` on this Linux branch.
The [L2 packet](../art/reference/2026-10-20-linux-l2-ground/README.md) contains
paired small/normal native plates, wild and actual untended controls, natural S7,
three short occupied clips, process records and exact source-commit bindings.
The [plan](../superpowers/plans/2026-10-20-l2-ground-care.md) records the scope.

Implemented one bounded irregular light_map.B care pocket for actual S2 noncivic
row_house use, fitted to its footprint, doors, measured planting and final
available vegetation. Stable variant3 remains untended. Paving, terrain IDs,
eight coverage slots, physical generation/routes/rewards and RNG are preserved.
Lawn uses presentation layer13 at320 world px. Semantic moss12 now uses the
accepted damp moss/soil; original rough grass/meadow/scrub stay intact. The kept
bed/tree sources, scale, anchors and placement are unchanged.

Fresh native bake produced14 original-algorithm layers. Source-checkout cache
loading validates ordered PNG/import/cache provenance, while exported loading
remains resource-only. Transition preparation yields between hashing and array
load/upload, retaining synchronous direct startup. The250ms assertion was not
relaxed. Final native warmup passes3/0,19 cue frames, largest201.2ms, and exact
cached/fresh layer+mipmap equality. An earlier254.2ms failure and MP3 fixture
shutdown leak are disclosed in the packet, with clean correction checks.

Final checks all exit0 with no monitor diagnostics: CityGroundCare123/0,
WorldGroundSplat33/0, WorldTerrain23/0, GroundMaterialCache38/0,
CityBlockPreviewCamera3/0, CityGenerationMaterial0failures,
CityServiceNatural12chunks/0failures, CityBlockProcedural5,430/0,
CityStreetFrontage19checks/0failures, PlayerRoofOcclusion11/0 and last code
check ScriptParseAudit550/0. CityGroundCareNatural covers8 actual chunks with
zero failures and preserved physical/coverage/RNG state, repeated/rebuilt exact
care, named home IDs and natural S7 seed4 canal_services. Valid RED precedes the
implementation and the production-footway correction; an early malformed test
adapter is not passing evidence.

Native review found and corrected the bed pocket being clipped to3 weak cells
by its actual footway. It now has15 cared cells/5 substantial cells; the tree
retains19/5. Root and an independent visual reviewer retain the corrected local,
soft, quieter olive patches for lead review; distinction at960 remains modest.
The wild probe is an actual25-cell uncared walkable neighborhood. The untended
comparison is runtime ID1647847571, genuine noncivic row_house variant3; care
elsewhere in its shared chunk belongs to other eligible homes.

S7 now has subdued low moss/soil beside natural mud/paving with no blue leaf
carpet. Normal and reduced-motion short fights retain clear bright cues in
inspected samples. Three34-frame clips preserve measured wall timing, encode
without resizing and decode cleanly. These are scripted god-mode fixtures with
controlled enemies, staged placement, normal props/HUD and streaming frozen
after explicit actual unload/reload; no profile/save writes or local security.
They do not establish human comfort, ordinary horde play or build balance.

Open findings: existing S7 wet mud has visible vertical banding; there is no
native dry-earth control here, so complete wet/dry material acceptance stays
open. V1 actors/tells crossing façade/roof edges remains a named blocking visual
issue, visibly present in bed combat. L3 household furnishings, masonry/UVs and
entry finish remain queued. No new district families, balance changes or source
generation were added. The user clarified the available Godot capabilities are
the installed GDScript, game-feel, level-design and roguelike skills; relevant
code, readability, route and evidence guidance was applied.

Independent runtime, ground-correction, cache-transition and capture-adapter
reviews found no important correctness defect. Final packet audit reconciled34
process records,19 scoped bindings,9 captures and3 videos/102 raw frames.
Lead keep/rework is still needed
on the bounded L2 result; tests do not close art findings. ART_STATUS is unchanged.
Evidence commit: `d4b647a1b5ef51c10b7e4d98ab599ce2b7a259c7`. Root verified
all151 packet artifact hashes/lengths from those committed Git blobs. The normal
own-branch push was attempted after committing and failed:
`fatal: could not read Username for 'https://github.com': terminal prompts disabled`.
This machine still lacks HTTPS credentials; the local implementation/evidence
commits remain intact. Human relay command:
`git push -u origin codex/linux-world-production`.
Push the current branch tip, including this publication-status update. No push
to the integration branch was attempted.

## 20 October — Windows review received

Fetched and merged `24d838f77df1b85ca3ec8636ec6a4900a6b19f7d`. Remote
`codex/linux-world-production` confirms the prior packet was published at
`1fa7a55202bf2276ccbde99450256fe8ef20c375`, and that exact commit is now an
ancestor of the integration branch. The earlier authentication failure below is
historical; publication is no longer a blocker. The human may relay Git pushes
when local authentication is unavailable.

Read the [lead review](../art/reviews/2026-10-20-linux-s2-lead-review/README.md)
and updated ART_STATUS. Acknowledged decisions:

- Keep the tested herb-bed/tree source, scale and contact, irregular home
  footprints and fitted neighboring workshop.
- L2 next: local irregular cared ground around the same two homes, an actual
  untended/wild comparison, and natural S7 seed 4/canal_services. Reuse the
  supplied lawn and subdued moss/soil sources. Preserve terrain IDs, routes,
  RNG, wilderness and the eight-slot splat limit; rebuild and verify the baked
  array when changing its sources.
- Return paired native ground views with actors, an occupied comparison and
  scoped terrain/cache/reload evidence. Preserve the prior before captures.
- L3 then addresses purposeful furnishings, domestic masonry, the stretched
  tan exterior band and large dark doorway without obstructing the opening.
- V1 roof/entity compositing remains required before occupied-street approval.
  Garden fit acceptance does not close it or authorize district expansion.

This pickup only updates the branch and acknowledgment. L2 runtime changes and
new engine evidence have not yet been produced. Incoming files are docs/images,
so no engine or gameplay test rerun was needed for this merge. Existing local
untracked files remain untouched; ART_STATUS remains Windows-owned.

## 20 October — fresh Linux checks

The existing checkout was preserved and explicitly imported; this was not a
fresh clone. Import completed with exit 0, no diagnostics, peak RSS 1,417 MiB
and minimum available memory 20,486 MiB. The source records retain this fact.

`tools/capture/run_city_linux.py` runs one owned process group with a fixed
per-user advisory lock, isolated XDG data/config/cache, fresh output directories,
logged stdout/stderr/engine output, timeout and RSS/available-memory monitoring.
It refuses another Godot process and never kills that process. Defaults are
6,144 MiB maximum process-group RSS and 4,096 MiB minimum available system/
cgroup memory, sampled every 100 ms. No address-space limit or OS settings were
changed. The Windows guard remains unchanged.

Fresh sequential checks, all exit 0 with no diagnostics:

| Check | Linux result |
| --- | --- |
| CityStreetFrontageTest | 19 checks, 0 failures |
| CityServiceFrontageTest | 8 fixtures, 0 failures |
| CityServiceNaturalTest | 12 chunks / 4 seeds, 0 failures |
| CityPlannedBuildingTest | 20 chunks / 62 buildings / 4 directions, 0 failures |
| CityBlockKitTest | 1,298 passed, 0 failed |
| CityBlockProceduralTest | 5,430 passed, 0 failed |
| PlayerRoofOcclusionTest | 11 passed, 0 failed |
| ScriptParseAuditTest | 549 gameplay scripts / 8 roots, 0 failures |

The seven-category strict-warning snapshot has not been rerun on Linux; the
549-script parse suite does not make that claim or cover the editor's entire
warning panel.

The survey now joins each kit to its actual roof-owned IndoorVolumes and
confirms these genuine generated samples:

| Attempt seed / chunk | Runtime building ID | Actual identity |
| --- | --- | --- |
| 16102026 / (0,3) | 944996572 | irregular row_house, south entry, two indoor volumes, herb-bed variant 0 |
| 17 / (-3,5) | 2128236757 | rectangular row_house, north entry, overhead fruit-tree variant 1 |

The preview's per-frame camera overwrote its whole-building still position.
`CityBlockPreviewCameraTest` reproduced this (2 passed / 1 failed), then passed
3 / 0 after the fix. All automated modes now wait for temporary HUD tips.
Reload signatures include garden source paths, transforms, contacts and soil
geometry; output records actual dwelling use, garden and capture conditions.
These are tooling changes; city generation, art pixels and gameplay rules have
not changed in this packet.

## 20 October — L1 native evidence packet

Implementation commit: `5f851103`. Changed paths are the Linux launcher and its
focused Python tests, CityBlockPlayablePreview, its camera regression scene/test,
the natural survey, and this status file. Native results are committed separately
under [2026-10-20-linux-s2-street](../art/reference/2026-10-20-linux-s2-street/README.md).
The received integration base remains `b5de9d53d081fa5fecde4188f811bf38d3f97cff`.

Seven monitored native runs exit 0 with no diagnostics, failures or save writes:

| Run | Evidence / moving results |
| --- | --- |
| Bed small / normal | Whole-home exterior/contact at 960×540 and 1280×720 |
| Tree small / normal | Whole-home exterior/contact at 960×540 and 1280×720 |
| Bed normal walkthrough | 135 frames, 59 fires, 72 hits, 25 deaths |
| Tree small walkthrough | 160 frames, 56 fires, 58 hits, 24 deaths |
| Bed Reduced Motion / Combat Flashes Off | 134 frames, 57 fires, 56 hits, 23 deaths |

All three walkthroughs pass five perimeter waypoints, physical entry (roof
alpha 0), exit (alpha 1), zero remaining inside count, streamed architectural
and garden equality, and zero wall instances after unload. Each has 12 seconds
of occupied moving exterior combat and frame-level projectile/population
evidence. Total 429 frames / 172 fires / 186 hits / 72 deaths. Native peak RSS
is 816 MiB, minimum available memory 19,610 MiB. No resource stop occurred.

All seven runs share 2,128 current matching script/resource/world-image/import
hashes. Exact commands, exits, diagnostics, isolated profile paths, CPU/memory
samples, native camera/window, contacts, source paths and identities are in the
packet JSON/logs. Initial checks retain their actual earlier monitor revisions;
camera RED remains labeled as an intentional regression reproduction.

The final root verification passes 19 monitor tests plus 8 encoder tests with
real FFmpeg enabled and no skips. Three bounded silent MP4s retain original
PNG timing/dimensions and decode with exit 0 and no diagnostics. Initial decode
verification's coarse-clock duplicate-DTS messages were resolved by an explicit
VFR/microsecond output clock; source images and video encoding were unchanged.
Raw frames remain local rather than publishing hundreds of individual PNGs.

Independent read-only code/evidence review found no remaining blocking defect.
It confirmed the runtime ownership join, camera regression result, both real
home samples, physical/reload/fight records and stated evidence limits.

### Limits and requested Windows decision

The previews use scripted input, god mode, controlled exterior enemies and a
disabled ambient spawner; chunk updates freeze after the reload check. These
homes have no security encounter. Normal HUD/foliage/ground are retained; initial
tips clear and ordinary milestone toasts can recur during combat. The north-entry
tree walkthrough's actor-following camera crops the lower home; use the dedicated
whole-home stills for the complete fit. Timing with viewport readback and monitor
overhead is not a comparative benchmark. No ordinary human playtest was done.

The garden sources fit without a reproduced clipping/contact/scale fault that
warranted a runtime edit. Windows must decide keep/rework from these actual
images. Empty pale interiors are retained as the L3 baseline. Ground care/lawn,
S7 moss/soil, furnishings and domestic masonry are not integrated. Enemies can
draw over the neighboring annex roof; the staged entity-visibility packet remains
separate. No civic/S3 treatment or game generation/balance/save rules changed.

Next request: Windows lead reviews both exterior sizes and the three moving
artifacts, records a concrete keep/rework verdict in ART_STATUS, and selects the
next correction or L2 ground/S7 work, followed by L3. No new asset request is
needed from this first fit. New district families/S4A remain out of scope.

### Historical publication attempt and relay instructions

Implementation commit: `5f851103`. Evidence packet commit:
`1e90f92a3b73a564d1984b6441203dd4e449ad8f`. This later status-only commit records
the publication failure; the complete packet is already retained in local Git.

`git push -u origin codex/linux-world-production` failed with:
`fatal: could not read Username for 'https://github.com': No such device or address`.
`gh auth status` reports no logged-in GitHub host. Existing SSH-agent identities
were tried with batch authentication; GitHub returned
`Permission denied (publickey)`. No credential, key or machine setting was
changed, and that worker's push did not succeed. Subsequent publication of the
packet is now confirmed by the remote branch and Windows review above.
ART_STATUS remains Windows-owned.

On this Linux PC, authenticate interactively, configure the Git credential
helper, then publish the existing branch normally:

```bash
gh auth login --hostname github.com --git-protocol https
gh auth setup-git
git push -u origin codex/linux-world-production
git rev-parse HEAD
```

Relay that branch/hash to the Windows lead, who can fetch it and review this
packet. Linux does not push `enemy-world-work`. Do not force-push, copy credentials
between PCs or restart the archived design conversations to work around this.
