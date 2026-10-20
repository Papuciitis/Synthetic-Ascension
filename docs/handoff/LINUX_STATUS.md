# Linux production status

Owner: Linux production worker. Updated 20 October 2026.
Read [HANDOFF](../../HANDOFF.md) and [ART_STATUS](ART_STATUS.md) before working.

## Pickup acknowledgment

- State: **picked up; L0 engine checks passed, L1 native review in progress**.
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

- [ ] L0: implement and exercise a Linux process/resource monitor; import and
  run the handoff's focused checks sequentially, preserving exact commands,
  exits, diagnostics and source hashes.
- [ ] L1: emit actual runtime building IDs from the natural survey and verify
  both named homes rather than treating a profile seed as an identity.
- [ ] L1: capture both real homes at 960×540 and 1280×720 with natural context
  and normal HUD after transient tips; resolve observed contact/camera faults.
- [ ] L1: capture physical entry/cutaway/exit, deterministic streamed reload,
  occupied moving combat and reduced-motion review; package useful stills,
  bounded moving evidence and result JSON with fixture limitations.
- [ ] Independently review the scoped changes, publish a normal checked Linux
  branch commit and request the Windows lead's keep/rework decision.

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

## Results to publish with each packet

Replace the pending fields with facts; keep a short dated history when moving
to the next packet.

- Task ID and received art/integration commit:
- Implementation commit and changed paths:
- Exact commands, isolated profile, exits and diagnostics:
- Relevant test counts and source hashes:
- Native evidence paths, seed/chunk/building ID, camera/resolution:
- Input/spawn/god-mode/frozen-world conditions and save-write delta:
- Resource measurements, failures or stopped attempts:
- Remaining limitations and specific asset/review request:
- Pushed branch/hash and next action:

Commit this status with the relevant implementation/evidence and push the Linux
branch. Leave ART_STATUS to the Windows lead. Do not write a visual acceptance
on the lead's behalf. If unable to push, report the exact command and branch/hash
for the human to relay; do not force or reset either machine's work.
