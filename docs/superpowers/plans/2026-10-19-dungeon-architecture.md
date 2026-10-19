# Procedural dungeon architecture

The human approved trying the two dungeon concepts. Implementation is native in
the existing coding chat; the art chat remains reviewer. The human subsequently
authorized applicable scoped commits across chats; no new push was requested.
Design reference: `docs/art/concepts/2026-10-19-donjon-directions/DESIGN_HANDOFF.md`.

## Design and constraints

Replace the large facilities' arbitrary room fragments with an enclosed compound:
three roofed wings around an open court, connected side chambers and an entrance
route from the original real doorway. Compact district Donjons use an enclosed
hall with side chambers inside a rectangle that excludes protected street/access
cells. Their identity and reward rules retain the original region's stable key;
their indoor volumes follow the new actual enclosure. Ordinary parcel houses and
their room-first carver stay unchanged. Complete-plan masks remain authoritative
when multi-chunk geometry is sliced. Architectural topology changes are deliberate.

Rendering uses original modular roofs, quiet stone and wall-bound entrance/service
details. Every streamed slice clips presentation to its own bounds. Shared full-site
coordinates keep roof texture/ridges aligned; roof cutaway follows the whole site
from any loaded slice, including reload while indoors. No complete concept painting
is used as an asset. Large roofs are separate wings, never one giant slab.

## Steps

1. Add failing dungeon layout regressions: full envelope except declared door cells;
   all walkable floor connected to entrance; chamber connections; 1x1, 2x1, 1x2,
   2x2 and compact region dimensions; protected-space fit; deterministic output.
2. Implement `DungeonLayout.build(region, seed, entrance_cells)` and
   `fit_region(region, keepouts)` in the procedural directory. Return authoritative
   carve plus roof/chamber/court metadata, without global RNG mutation.
3. Integrate the plan with SiteOverlay (keep IDs, door selection, masks); integrate
   compact district Donjons before final clipping/pruning, preserving their complete
   walls and real indoor ownership. Validate protected routes in production sweeps.
4. Add streamed dungeon presentation: distinct roof wings, framed real portal,
   buttresses, wall lamps, restrained chamber/storage/service cues. Test slice
   clipping, cutaway/reload and roof bounds against authoritative region/door data.
5. Run focused and existing house/site/route/parse checks, then versioned actual Game
   normal/small captures of three real facilities and S3 attempt2026 (-3,-3).
   Verify physical entry/exit, roof restoration, seam collision, streamed reload
   and populated outside combat. Record hashes and fixture limits; request art review.

## Review focus

Negative coordinates and reverse streaming must retain topology/roof alignment.
North/east entrances retain both declared open cells. Compact regions fragmented
by access corridors cannot receive painted roofs or indoor tags over streets.
Player already indoors at reload must cut away every newly loaded roof slice.
Visual chamber dressing must not become an unrecorded movement blocker.
