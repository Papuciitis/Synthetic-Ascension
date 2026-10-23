# Ground care edges and outer-wall paving continuation

Continuation authorized by the user's choice to continue remaining city visuals.
Governing direction: `2026-10-22-city-continuation.md`,
`docs/art/2026-10-20-ground-material-direction.md`, and current LINUX_STATUS.
Base: production `67728a93`, including Claude's merged playtest fixes.

- [x] Capture current S7/S9 at the previously checked cameras, with actual
  per-cell care attribution and inherited exterior, HUD, save and cap controls.
- [x] Reproduce the lost fractional care in a small native render regression
  using the real splat shader; preserve zero-care and restricted paving.
- [x] In `ground_splat.gdshader`, retain fractional care in the planted blend
  while keeping inward support feathering and all CPU ownership unchanged.
- [x] In `DistrictGroundPolicy.gd`, reduce only Outer Wall yard stone scale
  and remove its lavender grade; keep its grassy cobble outskirts character.
- [x] Run the render regression and focused care/splat/policy ownership checks.
  Review matched S7/S9 after images and a small-window control. Review source
  independently, commit checked changes, normal-merge, and update LINUX_STATUS.

No new textures, semantic IDs, generator/RNG, parcel, collision, door, route,
roof, atmosphere or global grading changes. Preserve useful care cores,
untended homes, actual wall contact, and clean stream reset/reload.
One guarded engine at a time; thermal stops remain failed/incomplete attempts.
Static captures establish selected appearance, not combat or performance.

Initial 23 October checkpoint: care correction `9a2ef8b8` is merged at `572ed5b7`,
native regression 49/0 and selected S7 before/after accepted. S9 source candidate
`745f96ef` is retained on `codex/c23-ground`, outside production. Its catalogue
passes 116/0; native after and small-window review remain pending because of
thermal interruptions. The broader plan is not complete.

Completed this bounded plan at `10d07c8a`: the saved policy candidate was tested
at `6905e7ea`, then normal-merged with identical runtime sources. Fresh normal
and small S9 views pass actual exit 0/zero diagnostics and root/independent
original review; full ground/care ownership records remain exact. Fresh Care
150/0 and Splat 63/0 close the previously interrupted owner checks. The earlier
render 49/0 and policy catalogue 116/0 retain their original raw/source records;
their relevant sources are unchanged. Evidence is in
`docs/art/reference/2026-10-23-outer-wall-paving/` and the prior care-edge packet.

The local runner now discovers startup owners before its sensor tick. Normal
uses the default 90 C instantaneous stop; the final three checks select an
optional 98 C ceiling with the existing 85 C three-sample sustained stop,
65 C launch gate and bounded duty. Defaults and failed histories are retained;
this is not hardware-safety or performance acceptance. Broad yard/plaza support
geometry and the square care footprint remain follow-up work.
