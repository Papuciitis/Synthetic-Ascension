# Production city generation designer review

2026-10-19. Governing direction: [Mediterranean medieval industrial city concept 08](../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png).

**Keep the final ground, junction and boundary corrections. Whole-city resemblance to the concept still requires substantial art coverage.** The actual generated city now has quieter paving and more continuous intersections. Most surrounding buildings still use the older shallow roof-and-wall treatment, with scattered shrubs and large grassy gaps. The accepted detailed block remains a stronger local example than the wider city.

## Final visual findings

| Area | Finding | Decision |
| --- | --- | --- |
| Shared ground | The oversized mossy slab pattern is replaced by smaller, quieter setts and limestone. Walking surfaces recede better and the irregular road alignment survives. | Keep. |
| Road junctions | The intermediate packet retained dark rounded road-end patches and overlapping strips. In `final/`, the service-lane T and district-fill center join continuously. The small secondary-route and dangerous-alley views also lose their darker overlay patches. | Keep the final unified response. |
| Kit boundary | The old boundary view showed competing paving regions. The final normal and small views have a cleaner road connection and a softer transition into neighboring coverage. The different roof styles on either side remain conspicuous. | Keep the ground correction; the boundary still exposes incomplete art coverage. |
| Required building in attempt 211 | The initial reward-role view showed an empty crossroads. The final closeup visibly contains the generated building, east entry marker, roof, planting group and cast shadow. The wider reward-role view crops most of that building above the frame. | Clear the empty-building visual finding. Use the closeup to demonstrate building presence. |
| Non-south frontage | The repaired building's east entry reads as a narrow recess at the roof edge. Much of the visible structure remains roof mass with a shallow base. It does not yet carry the occupied facade depth of concept 08. | Retain as an explicit direction-coverage gap. |

The final district-fill surface is still a broad pale paved shape surrounded by grass, and some pale margin strips form blunt ends. These are later streetscape design issues. The corrected material joins themselves no longer demand rework in the inspected views.

## Next art priorities

1. **Carry architectural depth around real generated doors.** Extend the accepted frontage language to non-south entrances and a small eligible neighboring building group. Show enough wall beneath the eaves for the building to feel occupied. Favor broad roof planes, recessed entries, eave shade and contact shadows; reduce the legacy emphasis on every tile's black outline.
2. **Make the planting belong to the city.** Use the existing mature tree and planted stone assets in organized courtyard or facade groups. Combine canopy, low planting and a hard base. The current isolated shrub dots and extensive lawn do little to establish a temperate Mediterranean old city. Preserve clear entries and routes.
3. **Finish physical street relationships selectively.** Introduce a restrained curb course, broken stone margin or wear transition where the architecture explains it. Attach one legible industrial service group to a real facade and drain. Keep the uneven road alignment and quiet ground hierarchy; avoid outlining every paving edge equally.

The tree, planter, awning, lantern and paving assets already supplied in [the streetscape handoff](../../../assets/world/city_block/STREETSCAPE_ASSET_HANDOFF.md) support this next step. This review adds no new asset generation or production code changes.

## Image register and scope

All generation paths below are relative to [the production capture folder](../reference/2026-10-19-city-generation/). `1280x720` and `960x540` identify native window sizes. Seed labels are the capture attempt labels in the manifests, rather than an assertion that the internal mixed plan seed equals the attempt value.

| Reviewer | Packet | Images personally opened |
| --- | --- | --- |
| Primary designer | `before/`, `after/` | `secondary_reward_building-1`, `secondary_route-1`, `service_lane-1`, each at both sizes. |
| Independent art reviewer | `before/`, `after/` | `dangerous_alley-1`, `district_fill-1`, each at both sizes, plus concept 08. |
| Primary designer | `after/` | `dangerous_alley-1-960x540.png`, `district_fill-1-960x540.png`, `kit-east-boundary-960x540.png`. |
| Primary designer | `seed-211/` | `secondary_reward_building-1-960x540.png`, the initial empty-building view. |
| Primary designer | `final/` | `service_lane-1`, `district_fill-1`, `kit-east-boundary`, each at both sizes; `dangerous_alley-1-960x540.png`, `secondary_route-1-960x540.png`. |
| Primary designer | `final-211-joined/` | `required-building-close` at both sizes; `secondary_reward_building-1-960x540.png`, `kit-east-boundary-960x540.png`. |

The primary designer also reopened concept 08 and read the initial and final attempt-211 manifests. The interim `final-211/` packet was superseded before review and is not part of this verdict.

These are frozen, unpopulated environment stills from production generation. The visual decision covers the named surfaces, boundaries and visible building presence. Door reachability, objective security, regeneration, populated combat and continuous-motion comfort require their own implementation checks.
