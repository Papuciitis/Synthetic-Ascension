# City houses and large interiors designer review

2026-10-19. This historical milestone review covers both city implementation chats, the subsequent house and facility wall repairs, and the human's requested Donjon concept direction. It precedes the separately approved DonJon architecture implementation; its source-correspondence statements describe that earlier checkpoint.

**Pass the bounded procedural family and wall-repair milestones. Large dungeon architecture still requires its own implementation pass.** The progress checkpoint was published separately at the human's explicit request; it does not imply complete-city or concept-art acceptance.

## Decisions

| Work | Visual decision |
| --- | --- |
| Civic and domestic families across generated S2 neighborhoods | Pass the bounded coverage milestone. Actual non-south entrances retain occupied wall depth and the accepted roof/frontage language. Repeated bays and sparse district dressing remain polish. |
| Irregular doorway assembly | Pass the upright recess, masonry frame and flush threshold. The earlier flat slab treatment was reworked. |
| Irregular outer wall continuity | Pass the two shown repaired interiors. Stepped corners now join the perimeter around the declared entrance; the disconnected bars in the user's example are resolved. |
| Ordinary small-house double walls | Pass the v2 interior. The redundant inset enclosure and detached entrance-side strips are gone. The remaining envelope, east doorway and quiet floor form one readable room. |
| Multi-chunk facility wall continuity | Pass the sampled enclosure, seam and entrance correction. This approves the streaming repair and complete-wall presentation. |
| Large-facility architectural identity | Rework as a separate art milestone. The facilities remain uncovered floor plans with uniform masonry and partial room divisions, without the prototype's roof, portal or frontage hierarchy. |
| CA Donjon as an enclosed dungeon | Rework. The genuine S3 example reads as open mossy lanes, paving islands and scattered objects. It does not communicate a dungeon interior. |

The ordinary-house fix applies to the failed multi-room fallback. It is not a blanket removal of interior walls. Recorded regressions retain four successful rooms and 80 partition cells, with the larger output and random sequence unchanged.

## Dungeon direction

The human clarified that Donjon dungeons should look recognizably like dungeons and requested concept art. Two new proposals are saved in [the Donjon handoff](../concepts/2026-10-19-donjon-directions/DESIGN_HANDOFF.md):

- A fortified exterior with a substantial gatehouse, keep, roofed wings, continuous enclosure and arcaded courtyard.
- An interior cutaway with connected halls, cells, storage, framed passages and one restrained industrial service room.

These paintings use the actual facility and accepted concept 08 as references. Their reorganized layout and entrance composition are conceptual. Runtime architecture must derive from actual doors, walls, keepouts and streaming ownership. Simplify their repeated roof, masonry and foliage detail further for production.

A useful next prototype is the existing 2 by 1 facility expressed as a coherent civic or workshop compound: one strong entrance, two or three roofed wings, an intentional court and a service bay. The human has established an enclosed dungeon as the visual target. The CA path's current open-yard generation and indoor-volume contract need deliberate resolution to support that target.

## Evidence and source correspondence

The [house v2 verification packet](../reference/2026-10-19-house-wall-repair-v2/checks.json) records clean native physical entry, security clearance, exit, roof restoration, regeneration and controlled combat. Before the subsequent DonJon architecture changes, the primary designer freshly verified all 16 saved source hashes and all 40 moving-run source or asset hashes against checkpoint `3aa358c5`, with no mismatches. Those older capture hashes do not claim correspondence to later dungeon source changes.

The [facility audit](../../audits/2026-10-19-large-interior-walls.md) records the focused wall, mask, collision and intact-art checks. Its native-v2 captures predate the small fallback change in the shared carver. The [comparison record](../reference/2026-10-19-house-wall-repair-v2/verification/actual-facility-comparison.json) confirms identical complete outputs and masks for all three captured facility plans after that edit: 684, 368 and 421 wall cells. The old capture's carver hash must not be described as matching the new source.

A known integration-test warning comes from its unchanged player-less fixture; the test reports 64 passes and zero failures. It was kept separate from native production diagnostics. Earlier failed and misframed captures remain diagnostic evidence.

## Decision samples

The primary designer personally opened the following final repair samples; an independent art reviewer inspected the same scenes and agreed with the bounded visual decisions:

- House repair v1: both seeds' `frontage-irregular-entered-960x540.png`, and seed 16102026's restored exterior.
- House repair v2: `moving-reduced-211/interior.png`, compared with the rejected v1 interior.
- Large sites native-v2: `facility-2x2-overview-960x540.png`, `facility-2x1-overview-960x540.png`, `facility-2x1-x-seam-960x540.png`, `facility-1x2-inside-960x540.png`.
- Donjon native-v1: `donjon-overview-960x540.png` and `donjon-interior-detail-960x540.png`.

The earlier neighborhood review also compared normal and small civic, domestic, cardinal-door and irregular-frontage samples against the accepted prototype and concept 08. Its sampled populated combat retained the existing crowded-player visibility limitation.

Facility overviews use explicit inspection zoom. The portrait facility overview is a crop, not a complete-building view. The Donjon stills establish architectural appearance, without a physical traversal claim. These reviews use PNG samples rather than full video playback or human continuous-play approval.

## Remaining separate issue and publication

The generic building path creates duplicate IndoorVolumes with different IDs over the same rectangle. A separate read-only audit confirmed possible duplicate first-entry or loot benefits, but no direct wall or roof duplication. It remains a reward-ownership follow-up rather than part of this visual repair.

Checkpoint `3aa358c5f147905a3f6e3f08efaaae3ead57959b` was independently confirmed on `origin/enemy-world-work`. It includes the preceding pending game commits. This review and the dungeon concept folder were authored after that checkpoint. The human subsequently authorized applicable commits across all chats, including the designer's own work; saving these records does not confer new complete-city or dungeon aesthetic approval.
