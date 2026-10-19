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
