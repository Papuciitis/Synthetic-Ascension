# Linux integration evidence — 20 October 2026

This packet records the combined generated-city regression after the domestic, roof/shadow, care-ground, entity-cover and atmosphere work. Its reviewed runtime/source target is **`de93d886a2b6392b1ff21d46147c3dd0cbf9287e`**. It retains an actual integration failure, the diagnostic reproduction and the subsequent test-only correction. It does not turn earlier launch HEADs into launches at this commit.

The packager defaults to read-only validation. From the repository root, run `python3 docs/art/reference/2026-10-20-linux-integration/package-integration.py`; add `--write` to copy the validated evidence. The script uses read-only `git show` for explicit committed blobs and invokes no engine or image processing. Before `--write`, this directory contains the draft README, packager and `.gdignore`; the links below become available when the validated evidence is copied.

<!-- RECORDED_INTEGRATION_SUMMARY_START -->

| Original run label | Result | Seconds | Original launch HEAD |
| --- | --- | ---: | --- |
| [integrated-CityBlockKitTest](process/runs/integrated-CityBlockKitTest/run-results.json) | 1300 / 0 | 7.895 | `276e5e15` |
| [integrated-DungeonRoofContractTest](process/runs/integrated-DungeonRoofContractTest/run-results.json) | 99 / 0 | 8.326 | `276e5e15` |
| [integrated-WorldCoverTest](process/runs/integrated-WorldCoverTest/run-results.json) | 25 / 0 | 8.127 | `276e5e15` |
| [integrated-CityDomesticInteriorTest](process/runs/integrated-CityDomesticInteriorTest/run-results.json) | 336 / 0 | 9.047 | `276e5e15` |
| [integrated-DomesticRewardStabilityTest](process/runs/integrated-DomesticRewardStabilityTest/run-results.json) | 43 / 0 | 8.492 | `276e5e15` |
| [integrated-CityBlockProceduralTest](process/runs/integrated-CityBlockProceduralTest/run-results.json) | 6092 / 1 | 9.742 | `276e5e15` |
| [integrated-procedural-diagnostic](process/runs/integrated-procedural-diagnostic/run-results.json) | 6092 / 1 | 9.513 | `2caa696a` |
| [integrated-procedural-actual-outline](process/runs/integrated-procedural-actual-outline/run-results.json) | 6318 / 0 | 10.025 | `eb78988e` |
| [integrated-entity-cover](process/runs/integrated-entity-cover/run-results.json) | 11 plates; 0 failures/saves | 47.383 | `276e5e15` |
| [final-WorldFootprintTest](process/runs/final-WorldFootprintTest/run-results.json) | 11 / 0 | 8.742 | `de93d886` |
| [final-CityGroundCareTest](process/runs/final-CityGroundCareTest/run-results.json) | 125 / 0 | 8.975 | `de93d886` |
| [final-ScriptParseAuditTest](process/runs/final-ScriptParseAuditTest/run-results.json) | 557 / 0 | 14.621 | `de93d886` |

<!-- RECORDED_INTEGRATION_SUMMARY_END -->

The two runs with one failed assertion are preserved as failures. Every other listed process completed with exit 0 and no monitor diagnostics. [Summary](process/summary.json) includes exact elapsed times, sampled memory peaks and evidence classification. Each linked original `run-results.json` is copied byte for byte, including its command, project path, launch HEAD/status, complete source hashes, process exits and resource time series. Its full stdout, stderr and engine logs are adjacent. The samples describe bounded checks on this machine, not a frame-rate or capacity benchmark.

The earlier integrated Kit, Dungeon, WorldCover, Domestic and Reward checks launched at `276e5e15`. The combined native Game capture also reports that launch HEAD in the atmosphere checkout, with atmosphere changes still uncommitted. [Source bindings](process/source-bindings.json) independently compare the explicit capture runtime, tool, selected ground source/import and baked-resource hashes with bytes from `de93d886`; those scoped native inputs match. The corrected procedural test launched with test WIP at its own recorded HEAD, then became commit `02ee8d3a`; its checked source matches the bound commit. The final three checks launched directly on main at `de93d886`.

## The procedural failure and correction

The original `integrated-CityBlockProceduralTest` reported **6092 passed / 1 failed**: “building sun shadows exclude their own and neighboring interiors.” The diagnostic reproduction reported the same failure. Its exact [diagnostic JSON](process/procedural-diagnosis.json) and full stdout identify seed 2026, segment 1 and an intersection area of 14560.5625 with an L-shaped parcel's *bounding box*. The shadow polygon lies in that building's empty northwest notch. All three actual occupied-outline intersections are empty with area 0. This is evidence of an obsolete test geometry assumption; the failure is not discarded or labeled a production rendering fix.

The corrected test explicitly selects S2 for its intended fixture and restores the prior segment. It independently transforms each actual RoofOverlay occupied outline into each shadow's coordinates, retains every shadow×receiver no-overlap assertion, and adds a positive overlap control under translation, rotation and scale. Existing paving checks remain. No shadow, footprint, physical or RNG production code changed for this correction. Its result is **6318/0**; the changed count reflects explicit S2 fixtures and the strengthened checks, so it is not a count-for-count or timing comparison with the segment 1 failure.

The [original failing script](process/original-failing-source/tools/tests/CityBlockProceduralTest.gd) and [committed corrected script](process/committed-source/tools/tests/CityBlockProceduralTest.gd) are included. The temporary diagnostic script's bytes were not retained; its exact launch hash and complete raw diagnostic output are retained, without inventing a replacement source snapshot.

## Combined native Game stills

The [unchanged capture metadata](native/capture-info.json) records actual generated Game, S2 seed 16102026, chunk (0, 3), row-house 944996572, ordinary city tree, OpenGL compatibility on Mesa Intel UHD 620, and the original capture arguments. All eleven unedited PNGs are **960×540**. This combined packet contains one household and one ordinary tree; the separate [domestic](../2026-10-20-linux-domestic-interiors/README.md), [entity-cover](../2026-10-20-linux-entity-cover/README.md), [roof/shadow](../2026-10-20-linux-scene-depth/README.md) and [atmosphere](../2026-10-20-linux-theme-atmosphere/README.md) packets carry their own broader fixtures and limits.

| Condition | Unedited stills |
| --- | --- |
| Roof behind/front | [Covered](native/roof-covered.png), [front controls](native/roof-front-controls.png) |
| Lower façade behind/front | [Covered](native/facade-covered.png), [front controls](native/facade-front-controls.png) |
| Ordinary-tree enemy bodies | [Covered](native/ordinary-tree-enemies-covered.png), [front controls](native/ordinary-tree-enemies-front-controls.png) |
| Ordinary-tree pickup icons | [Covered](native/ordinary-tree-pickups-covered.png), [front controls](native/ordinary-tree-pickups-front-controls.png) |
| Physical roof entry/exit | [Before entry](native/roof-before-entry.png), [inside cutaway](native/roof-player-inside-cutaway.png), [outside restored](native/roof-player-outside-restored.png) |

The fixture uses real ordinary/elite actors, production batch entries and genuine equipment/health pickup scenes. It freezes enemy physics/scheduling, suppresses ambient spawning/encounter beats, retains the existing fixture `never_cull` metadata, disables staged pickup monitoring, uses a god-mode player and fixes the camera. Streaming is frozen after a verified unload/reload; entry/exit then uses production input and Area2D signals. Tutorial tips and floating callouts expire before stills. Requested and actual visual positions, coverage samples, walkability, world handles, batch status and selected surfaces are disclosed per entity. Some covered and front-control staging points are non-walkable. These are controlled rendering regressions, not encounter reachability, collection, continuous human play or a full V1 acceptance claim. Center strength diagnostics accompany the native pixels; they are not whole-body pixel measurements. The façade elite's exposed portion can correctly retain its normal appearance.

The metadata records roof alpha 1→0→1 and inside count 0→1→0, zero fixture failures and zero save writes. Final shared-cover counters are 62 primitives, 3 cached foreground source reads and 23 peak candidates; the sampled peak refresh is 78.678 ms. Those are this fixture's reported counters, not a performance guarantee.

## Original reward contents and source scope

The integrated **43/0** reward check's [exact extracted JSON](process/integrated-reward-comparisons.json) preserves the raw log values. This run rolled `lattice_focusnode` for household 944996572 and `curse_sour_providence` for 2128236757. Each home's actual chance/claim path and guaranteed full-factory control match before/furnished in item identity, complete mods, polarity, progression, claims, positions, secondary state and run RNG for these fixtures. These rolls differ from the earlier domestic packet's original rolls, which remain unchanged. The synchronous baseline switch and its limits are preserved in each original record; this is not a proof of all possible future reward policies.

[Source bindings](process/source-bindings.json) lists every explicitly scoped committed hash, content snapshot path and per-run recorded hash comparison. [Committed source snapshots](process/committed-source/) cover the selected runtime, capture tool and checked test sources; selected source/import textures and baked ground resources are hash-bound rather than duplicated. The original full monitor source maps remain in the exact process records. This source scope does not claim to bundle every project dependency, asset or import cache.

[Evidence index](evidence-index.json) gives SHA-256 and byte size for every bundled file except itself. All eleven named stills, original capture JSON, original process records and full logs are copied unchanged. Only the explicit allowlist is copied; native shader caches, user data and raw frame directories are excluded.
