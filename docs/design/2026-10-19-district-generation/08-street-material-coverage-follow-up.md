# Street-material coverage follow-up

19 October 2026. **Selected follow-up direction; not implemented by the current S3 refinement.** The designer relays the human's concern that the newer street sprites are hardly visible. Keep the S3 three-finding scope intact; address this separately afterward and before treating a later district as visually complete.

## Confirmed cause

- `ChunkManager._ground_splat` enables `set_city_streetscape` only for `Global.attempt_segment == 2` (current line1293). The shared S2+ building rollout did not extend this ground presentation.
- `GroundSplatRenderer.set_city_streetscape` binds `worn_setts.png` and `paving.png` in that mode. The setts shader deliberately mixes their texture at0.30, so even S2 use is restrained.
- Later chunk generation and coverage tests deliberately retain their theme ground and exclude the S2 composed court presentation. That protects terrain/layout but leaves the newer paved-street material presentation narrowly covered.
- `street_setts.png` and `worn_setts.png` are byte-identical, SHA256 `2261EA102D04BF5FE714842F0209A9FA5540C373B3968FDBAC153B2B6D3E045F`; there is no missing removed alternate to restore.

These observations were checked read-only in the current checkout while the S3 native queue ran. They do not claim the larger ground rollout exists.

## Bounded direction

Separate **material presentation for existing semantic roads/paths** from the **S2 court palette/composed rectangular overlay**. Reuse the newer setts on appropriate paved streets and limestone on suitable foot/frontage paths. Preserve organic masks, rounded/irregular joins, clear approaches, existing terrain and main/exploration/route hierarchy. District wear, wetness and soil distinctions must remain readable; rail yards, canal banks, military/service ground and open dirt are not all paving.

Do not globally enable the entire current S2 mode as a shortcut. Any next adapter needs an explicit semantic/family presentation policy, paired physical/route/RNG comparison and proof that later composed court stamps remain absent unless separately selected. Keep new material placement under the existing ground renderer rather than scattering independent street sprites with their own seams/collision.

## Review evidence required

Natural normal/small street views must record actual segment/theme, seed, chunk and route role. Include paved road, limestone foot/frontage path and a genuinely unpaved area, with the original organic joins and terrain transitions visible. Show multiple appropriate themes, not an S2-only close-up. Retain natural foliage, actors and objective/combat context in the review set. Designer judges material visibility, scale, quietness and district distinction; physical navigation, route/loot access, reload and ground-source hashes provide separate correctness evidence.

Current production owner remains this district code/asset integration chat. Selected building sequence stays S3 refinement, then one S4A ruin family after review, followed separately by S4B and S6. This street follow-up is a required visible-coverage step after S3 and before a claim that the next district's full look is finished; it is not permission for a universal ground repaint or an all-district batch.

## Implementation status (21 October 2026, ground package)

Implemented as an explicit family policy, not the S2 switch (`set_city_streetscape` is gone):

- `core/systems/world/ground/DistrictGroundPolicy.gd` resolves every procedural family (14 themes; S11+ shares Service Courtyards through its family; no family = the raw S1/Hub palette). Semantic materials present through roles: kerbed carriageway and squares (7/8/9 and the courts, lips and pads of 3), flush lanes and door aprons (4), footways and house floors (2), the district surface (6), lawn (0/10/11/12) and soil (1/5). Each role picks the setts, the limestone flags or a splat array layer with its own repeat, quiet mid tone and grade. Material ownership, slot allocation, walkability and generator RNG are unchanged; no texture or terrain id was added.
- District chunks stand on the hard "urban" surface (`SegmentThemeData.district_terrain`, used by `DistrictPlan`); the exploration web (service lanes, exploration rewards) and the wilderness keep the theme's wild exploration terrain. Where they meet, one to four cells of the wild ground are laid raggedly into the district chunk from a boundary hash, so no 2048 px chunk line shows. Every theme stays within seven slots in the cross-theme test (no borrowing).
- Paved-to-paved edges are decided on the coverage mip chain with almost no warp (crisp, no grain). A kerb (light top on the footway side, brighter where it faces the sun, a south-facing face, a gutter and the kerb's own cast shadow) marks carriageway edges; a lane or door apron meets the road flush (dropped kerb) and meets flags with a narrow joint. The noise warp remains only where paving meets soil or grass, where wild ground also gets the theme's scrub or moss verge.
- Light-map alpha carries broad ground occlusion from every wall, window, solid and half-cover cell (two-cell radius, heavier on the south-west shadow side), applied per theme.
- Household care is ungated (every procedural segment; stable variant three stays untended; door access excluded) and may tend lawn, bare earth and the district surface; on stone it draws an edged plot and keeps a one-cell paved margin from carriageways, lanes and aprons. Plaza islands in the built district become kerbed planted beds; in wild chunks they are the theme's own wild ground.
- Per-theme looks: limestone flags and setts (S2, S11+), fine pale sett courts (S4B), pale ashlar courts and flag streets (S5), regular civic tiles round flag streets (S10), grey cobble (S3), dark damp flags (S7A), weedy worn flags with rubble patches and scrub verges (S4A), dirt-and-sett yards (S6A), puddled wet earth with sett remnants and damp-moss verges (S6B), mossy quay flags (S7B), ballast gravel (S8A), a packed-earth court (S8B), round cobbles with grass joints and scrub verges (S9A), and a rough stone yard (S9B).

Evidence: native CitySegmentSurvey before/after for all 14 themes (seed 16102026) and the policy, slot, occlusion and care tests (`DistrictGroundPolicyTest`, `WorldGroundSplatTest`, `CityGroundCare*Test`). Lead visual review is still required; this does not claim any district looks finished. Not changed here: wild shrub scatter still lands on paving (vegetation placement), building floor stamps still cover the wall ring, and S2-only `CityStreetFrontage` polygons still draw over the S2 splat.
