# L2: local household care and S7 moss

20 October 2026. Implementation `0d6f761acd2adff963efff5619d0a34f1bff4f9b` on
`codex/linux-world-production`, following received lead review `24d838f7`.
**Ready for Windows keep/rework review; complete-ground and street approval remain open.**

Actual S2 noncivic row_house parcels now receive one soft, bounded lawn pocket
on available vegetation beside their real footprint/garden. Stable variant3
remains untended. Paving, doors, floor ownership, eight material slots, physical
routes, rewards and generation RNG are preserved. Lawn is presentation layer13,
not a terrain ID. Semantic moss remains12 with the selected damp moss/soil source.
Both original accepted garden props, scale and anchors remain intact.

## Paired native views

All plates use actual Game bootstrap, ordinary props/HUD and an actor. The small
plates are960×540; normal plates1280×720. Existing L1 before evidence is preserved.

| Actual sample | Before | L2 small | L2 normal |
| --- | --- | --- | --- |
| Bed: seed16102026, chunk(0,3), ID944996572 | [L1](../2026-10-20-linux-s2-street/bed-small/exterior.png) | [After](bed-small/ground-before.png) | [Context](bed-normal/ground-before.png) |
| North-entry tree: seed17, chunk(-3,5), ID2128236757 | [L1](../2026-10-20-linux-s2-street/tree-small/exterior.png) | [After](tree-small/ground-before.png) | [Context](tree-normal/ground-before.png) |
| Nearby actual rough wild: seed16102026, pixel(224,6752) | Same natural chunk | [Zero-care ground](wild-small/ground-before.png) | [Natural measurements](natural-ground.json) |
| Actual untended home: seed17, chunk(-1,5), ID1647847571 | Qualified by usage and stable variant3 | [No household care spec](untended-small/ground-before.png) | [Natural measurements](natural-ground.json) |
| S7: seed4, canal_services, pixel(-2016,96) | [Earlier blue moss](../2026-10-19-city-foundation/native-s7/exterior.png) | [Natural moss/mud/paving](s7-small/ground-before.png) | [Context](s7-normal/ground-before.png) |

The actual wild control is walkable,495.8px from the bed contact, with25 uncared
walkable overgrowth cells in its5×5 neighborhood. It is not classified from a
missing prop. The untended home is an actual noncivic row_house whose variant3
returns an empty care spec. Its **whole chunk** also contains other eligible
homes, so its chunk-wide18 cared cells must not be attributed to this parcel.

## Occupied comparisons and visual findings

[Bed fight](bed-small/occupied.mp4) and [S7 fight](s7-small/occupied.mp4) retain
measured capture wall timing and dimensions, with encoding/decode sidecars beside
each video. Each is5.017 simulation seconds and34 captured frames. Bed has24 fires,
28 hits and up to8 projectiles; S7 has24 fires,26 hits and up to7 projectiles.
A final [S7 reduced-motion comparison](s7-reduced/occupied.mp4), captured after
implementation commit with combat flashes off, also passes:34 frames,24 fires,
25 hits,5.017 simulation seconds, and no diagnostics. Root inspected its fight
frame; bright orange tells/projectiles remain visible without the normal impact
flash. This is a bounded visual check, not human comfort certification.
No save writes or local security were activated. Raw PNG sequences remain local;
sidecars retain their hashes and times. Native fixture metadata is beside each plate.

Root inspected all principal plates and opening/middle/ending occupied samples;
an independent visual reviewer compared both small homes against their L1 plates
and inspected S7 small/normal/fight. These are sampled sequence observations,
not continuous human play or a balance/performance result.

- **Keep for lead review:** the bed/tree now have a visible, quieter fine olive
  strip near their planted west corner, with rough grass beyond. The distinction
  is restrained at960; props still contribute much of the domestic identity.
  The pockets are soft and asymmetric, with no full-house lawn ring or new hard
  rectangular island. The existing hard-sided dark strips are cast shadows.
- **Keep the S7 moss trial:** subdued low olive/brown-green/mineral structure
  replaces the cyan/purple broadleaf carpet. Moss, darker wet mud and lighter
  paving remain distinct, with irregular natural boundaries. Orange tells and
  bright projectiles remain clear in inspected occupied frames.
- **Open material finding:** existing wet mud has conspicuous repeated vertical
  pale/dark bands, visible in the lower-left S7 area at both sizes. This packet
  does not close the wet/dry-earth gate; no dry-earth control appears in these
  plates. Lead review should assess the original wet-mud source and repeat384px
  against these exact native crops before any new source generation.
- **V1 remains blocking:** actors/tells still cross façade/roof edges in the bed
  fight. Dark enemies on mud and the crowded player also need motion review.
  The camera crops parts of the crowd low in the frame. L3 household furnishing,
  domestic masonry/UVs, doorway completion and whole-street acceptance remain open.

The first [bed trial](rejected-trial/bed-small-v1.png) left only3 weak care cells
because its real footway clipped the proposed pocket. It was rejected visually
although the functional run exited0. A production-footway regression failed
before correction. Final placement fits actual available vegetation: bed15 cells
including5 strong cells; tree19 including5 strong cells, retaining its original
usable pocket. No prop or paving was moved to manufacture the difference.

## Cache and correctness evidence

The bound native array is the committed `ground_materials.res`,14 RGB8 layers
of512×512 with mipmaps. The [bound cache manifest](bound-cache-manifest.json)
and each capture's `ground` metadata identify actual bound resource/layers,
selected uniforms and source/cache hashes. Layer12 is `damp_moss_soil.png`,13 is
`cared_lawn.png`; original rough grass/meadow/scrub remain. The natural S7 plan
seed745886440 produces the adjacent moss/mud chunks and paving without editing
terrain/theme data; its household-care field stays exactly zero.

Source checkout cache acceptance safely rejects missing/malformed/stale ordered
PNG/import/cache provenance. Exports keep resource-only loading. Native warmup
compares every cached layer/mipmap with the original preparation algorithm.
The new guard initially put hashing and upload into one loading frame: a clean
pixel-equivalent run failed the unchanged250ms assertion at254.2ms. Transition
preparation now yields between provenance validation and load/upload; the clean
final warmup passes3/0,19 loading frames, largest201.2ms. Direct synchronous
startup retains its contract. This is a scoped loading check, not a broad
performance claim. The fixture's earlier MP3 shutdown leak was traced and removed
by stopping unrelated menu playback before this resource test.

| Final scoped check | Result |
| --- | --- |
| CityGroundCare |123 passed,0 failed; exact production footways and both real homes |
| WorldGroundSplat |33/0; blue-only writes, slots, paving, reset/wrap/rebuild |
| WorldTerrain |23/0;14 sources, original terrain identities |
| GroundMaterialCache |38/0; malformed/stale provenance and actual cache loading |
| Native TransitionResourceWarmup |3/0; exact pixels/mips and staged loading |
| CityGroundCareNatural |8 chunks,0 failures; real homes/wild/S7, physical/coverage/RNG equality |
| CityBlockPreviewCamera |3/0 |
| CityGenerationMaterial |0 failures |
| CityServiceNatural |12 chunks,0 failures |
| CityBlockProcedural |5,430/0;20 layouts,76 parcels, four entry directions |
| CityStreetFrontage |19 checks,0 failures |
| PlayerRoofOcclusion |11/0; does not close V1 art finding |
| ScriptParseAudit, last code check |550/0 across eight gameplay roots |

[Process summary](process/summary.json) links exact commands, exits, resource
samples and retained diagnostics. Final listed checks exit0 with no monitor
diagnostics. Explicit REDs and rejected warmup runs remain separately labeled.
An early malformed test-adapter attempt was stopped and corrected before valid
RED; its original log remains local and is not passing evidence.

The final independent packet audit reconciled34 process records,19 scoped
source bindings, all9 capture records and3 video sidecars covering102 raw frame
hashes/timestamps. The [artifact manifest](artifact-manifest.json) records all
packet files except itself.

## Provenance and limits

Each process record retains command/exits/resource time series and references
its complete input-hash record. Input hashes are captured **before** a run;
therefore bake inputs include the previous derived cache, while the output
manifest records the replacement. Input records are deduplicated without loss;
the original machine-wide untracked Git status is omitted from the packet and
its original result hash is retained. Existing unrelated local files were preserved.

Most captures/checks ran on tracked working changes before implementation commit;
[commit bindings](source-commit-bindings.json) identify exactly which scoped Git
blobs match each run. Earlier S7/cache runs precede the S2-only ground-aware care
correction; their actual input snapshots are retained, not relabeled as final.
The final natural suite checks S7 remains care-free under the corrected code.

Godot4.7.2 Compatibility/OpenGL3, Mesa25.2.8 Intel UHD620 on Linux Mint/X11.
Every engine ran alone through `tools/capture/run_city_linux.py`, with isolated
XDG paths, exclusion lock, resource guard and owned process-group cleanup. The
normal S7 capture waited while occluded; bringing its existing window forward
allowed readback to finish. Other final capture windows used `--visible`.

Capture controls are scripted: god mode, disabled ambient spawner/encounter
beats, controlled real enemies for fights, staged free-cell placement, fixed
camera and streaming frozen after an explicit actual unload/reload. Production
attacks, AI, projectiles and HUD stay live. This is not ordinary horde play,
human comfort certification, a build/balance test, or broad editor-warning
certification. The installed GDScript, game-feel, level-design and roguelike
guidance informed code, cue priority, route invariants and these evidence limits.
