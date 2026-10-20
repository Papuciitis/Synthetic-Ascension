# Linux production status

Owner: Linux production worker. Updated 20 October 2026.
Read [HANDOFF](../../HANDOFF.md) and [ART_STATUS](ART_STATUS.md) before working.

## Pickup acknowledgment

- State: **L0 complete; L1 evidence ready locally; publication blocked by
  missing GitHub authentication on this PC**.
- Received integration commit: `b5de9d53d081fa5fecde4188f811bf38d3f97cff`.
  `git fetch --all` confirmed local HEAD and `origin/enemy-world-work` agree.
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

## Current bounded packet

Start with L0, then L1's actual generated S2 home garden and street review.
L2 ground/S7 and L3 ordinary-home interiors follow the linked direction. Do not
silently expand to more district families or claim historical images validate
new code. Windows retains art direction and source generation.

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
- [ ] Publish the checked Linux packet and request the Windows lead's
  keep/rework decision (normal push attempted; local authentication missing).

No native visual acceptance, ground integration or domestic furnishing work is
claimed by this acknowledgment. L2/L3 remain queued behind the L1 review gate.

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

### Publication attempt and exact relay

Implementation commit: `5f851103`. Evidence packet commit:
`1e90f92a3b73a564d1984b6441203dd4e449ad8f`. This later status-only commit records
the publication failure; the complete packet is already retained in local Git.

`git push -u origin codex/linux-world-production` failed with:
`fatal: could not read Username for 'https://github.com': No such device or address`.
`gh auth status` reports no logged-in GitHub host. Existing SSH-agent identities
were tried with batch authentication; GitHub returned
`Permission denied (publickey)`. No credential, key or machine setting was
changed, and nothing was pushed. ART_STATUS remains Windows-owned.

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
