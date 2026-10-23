# Ground care edges and outer-wall paving continuation

Continuation authorized by the user's choice to continue remaining city visuals.
Governing direction: `2026-10-22-city-continuation.md`,
`docs/art/2026-10-20-ground-material-direction.md`, and current LINUX_STATUS.
Base: production `67728a93`, including Claude's merged playtest fixes.

- [ ] Capture current S7/S9 at the previously checked cameras, with actual
  per-cell care attribution and inherited exterior, HUD, save and cap controls.
- [ ] Reproduce the lost fractional care in a small native render regression
  using the real splat shader; preserve zero-care and restricted paving.
- [ ] In `ground_splat.gdshader`, retain fractional care in the planted blend
  while keeping inward support feathering and all CPU ownership unchanged.
- [ ] In `DistrictGroundPolicy.gd`, reduce only Outer Wall yard stone scale
  and remove its lavender grade; keep its grassy cobble outskirts character.
- [ ] Run the render regression and focused care/splat/policy ownership checks.
  Review matched S7/S9 after images and a small-window control. Review source
  independently, commit checked changes, normal-merge, and update LINUX_STATUS.

No new textures, semantic IDs, generator/RNG, parcel, collision, door, route,
roof, atmosphere or global grading changes. Preserve useful care cores,
untended homes, actual wall contact, and clean stream reset/reload.
One guarded engine at a time; thermal stops remain failed/incomplete attempts.
Static captures establish selected appearance, not combat or performance.
