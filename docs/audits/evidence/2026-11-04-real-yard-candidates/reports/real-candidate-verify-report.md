# Recovered household candidate verification packet — 4 November 2026

**Historical preparation/refusal report; final corrected result is in
`real-candidate-verify-fix1-report.md`: actual Godot14/0.** Original bytes and
the original mixed-indentation failure remain retained unchanged. Read that
final report for accepted helper evidence and explicit remaining limits.

**This worker's single startup attempt was refused before engine launch.** The
pinned guard was loaded/compiled before the final memory check. The unchanged
512 MB available RAM / 1536 MB available commit startup gate reported only
402 MB RAM and 3866 MB commit (the immediately preceding recorded snapshot was
404.59 / 3866.87 MB). No Godot process was started by this worker, so this
worker has **zero actual-GDScript verified IDs or geometry results**. Host
expectations remain expectations until an independently retained successful
engine result exists. No local recovery, retry, app trim, app kill, cap change,
production edit, activation, or commit was performed.

The parent was sent the exact command below for its separately authorized
single guard-preloaded recovery and run; its result must be assessed separately
from `first-run-result.json`:

```powershell
& '.superpowers/sdd/2026-11-04-trailer-yard-preview/real-candidate-verify-run.ps1' -EvidenceName 'parent-recovery'
```

## Packet and source binding

The bounded packet is `real-candidate-verify/` alongside this report. Its
`.gdignore` was the first file written, then a fresh `fixture/.gdignore` before
project/script creation. The project has no autoload, main scene, Game, assets,
import pass, copied cache, replacement manager, or Global double. Its only
script preloads are unchanged `RectFacilityCarver.gd` and `DonjonCarver.gd`.
`verify.gd` contains a single **verbatim method extraction** of `_mix_seed`
from current `SiteParcelsImpl.gd`, with extraction-count guard `1`; this is
explicitly not an implementation of SiteParcels or ChunkManager.

All 24 packet source/file pins were independently checked after preparation.
`source-pins.json` binds current source snapshots, fixture files and guard;
`supplemental-pins.json` binds the builder, runner and exact historical manager
snapshot. `runner-pin.json` and `engine-pin.json` are checked before launch.
Exact historical sample, run binding and compressed raw launch result are
retained as source payloads; their original paths are in the pins. Source payload
filenames are shortened to avoid the Windows path-length limit.

Historical git: `b298202447a5b3a0cf2b0e8c55c46bf507a7f1c9`.

* Part08 sample SHA256:
  `43938c18fa45cbc8ca3248d4bdbcf3bf22922c23789e5bcd10ff5a193c60390b`.
* Run binding SHA256:
  `f2abbe70c7e2e34a8ce7b373052c4b78ee614558253127574513ab89cd23c179`.
* Raw run-results gzip SHA256:
  `73769e1806a46ee5ae27292e3851211814854b7d5e5d84fd53ce2a937dd80c3f`.
  The original launch says actual exit0, runner exit0, `stop_reason: completed`,
  diagnostics empty. This historical evidence is separate from the refused
  current run.
* SiteParcels source equals exact historical launch:
  `fa31541044a4da8d11d6e3d57cea654bc0ea0cc0911de880f04ac3828b3e7503`.
* RectFacilityCarver current and historical launch bytes equal:
  `19831055637b899d146f9e3b67cf8867ff990fead39663deb30efaf57991f6c5`.
* DonjonCarver current and historical launch bytes equal:
  `42850a329b0d2ee8250fbe7ee01c6858c271c4f65f80ca9aa6964d03f551e688`.
* ChunkGenImpl, ChunkGenDistrict, SegmentThemeData, SegmentThemePicker,
  SegmentProcBuilder, CityStreetContinuityTest, ProcChunkReachabilityTest,
  CityBlockKit and resource guard current bytes match historical launch hashes.
  Current ChunkManager differs; no whole-manager identity is claimed. The exact
  historical manager snapshot `354d2dfc...6ee15` is retained separately and its
  required defaults were read directly.

## Historical observations versus proposed derivations

`fixture/observed-inputs.json` preserves the full selected sample and three
exact building records. Observed: theme `canal_services`, segment7, attempt
seed16102028, generation attempt1, **plan seed1208827904**, chunk(-8,-4),
role `dangerous_alley`. The records are original rectangular noncivic
`row_house`, not infill, with these rects and doors:

| Rect | Saved door x,y,dx,dy | Host expected ID | Expected variant |
| --- | --- | --- | --- |
| 21,7,8,7 | 25,13,0,1 | 1910440753 | 1 |
| 3,6,8,8 | 7,13,0,1 | 2052381668 | 0 |
| 21,20,8,8 | 25,20,0,-1 | 1928485795 | 3 |

The harness asserts all three IDs using the extracted method with actual
Godot signed64 arithmetic: global interior top-left is
`coord*32 + rect.grow(-1).position`, salt77, then
`int(mixed & 0x7fffffff)+1`; variant is `absi(id)%4`. It consumes no RNG for
these derivations and does not rewrite historical input. Expected identities
are not relabelled observed identities.

For the first two only, the harness calls the unchanged actual carver and
records all returned walls, windows, partition cells, floor stamps and half
cover, plus exact derived door cells, signed seed/state and footprint before
roof insets. It checks two open door cells, bounded walls and a closed perimeter
except doors. Normal carve parameters were unambiguously traced:

* Historical ChunkManager exports chunk2048px / cell64px, door2, window0.22.
* Theme application and the street test do not override door/window fields.
* ChunkGenImpl copies those manager fields; ChunkGenDistrict passes them in
  parcel config and passes residential/corridor floor texture2.
* SiteParcels row-house path sets room attempts12, minimum4x4,
  maximum(min(9,width-2),min(8,height-2)) with each axis at least5,
  padding1 and corridor1. Carve RNG is newly created and seeded by the exact
  source formula `_mix_seed(plan_seed,cx,cy,4027 + rx*19 + ry*23)`; the real
  carver consumes this RNG unchanged.

Door width2 is **source-derived, not historically observed**. Calling the
actual source on recovered lots is a geometry replay; it is not full district
selection/regeneration or a current Game observation. The planned summary is
14 checks: six ID/variant checks and eight two-lot geometry checks. This is a
planned count until a successful raw engine result exists.

## Guard and raw result

Engine SHA256:
`323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`.
Runner SHA256:
`6d564cc59efb46afd1d2fc0f4c6ebb680ccb169505c5b364e97091fd87b225c1`.
Guard SHA256:
`dfe25730c5e24ac0e4ed6031af387c5fa2038ef30c37c1c7ac087856c19e7382`.

The runner serializes ownership with the existing fixture mutex and refuses
any existing Godot/editor. It retains the exact Process.Handle, uses hidden
Start-Process, redirects raw stdout/stderr, and isolates APPDATA/LOCALAPPDATA.
The pinned guard enforces64 MB private /30sec and running384 MB RAM /768 MB
commit; only its owned process can be stopped. Native exit0, no diagnostics or
stop, positive summary, zero failed checks and exactly three result records are
all required. Existing evidence cannot be overwritten. A missing/zero summary
or failed/absent result is failure. Startup refusal leaves no engine stdout or
stderr because no engine exists; `first-run-result.json` records the refusal.

## Explicit unknowns and limits

True garden contact, party edges/extra reach, final care spec, semantic/care
bytes, current native materials/doorway clearance, neighbourhood, traversal,
stream reload and cost remain unknown or current-runtime pending. The JSON
output schema keeps missing care/garden/native fields separate from observed
historical input and derived verified values. No actual Game target is activated;
the presentation trial remains default off. No inference from this packet can
establish current generated-city visual acceptance or trailer readiness.
