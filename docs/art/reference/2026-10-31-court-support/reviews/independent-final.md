# Independent re-review: final images

The same independent reviewer judged the final originals against its own
first-pass notes (`review-first-pass.md`). Verdict: **ACCEPT WITH NOTES**.

1. **S9: ACCEPT.**
   - **Resolved:** the statue stands on setts, so there is no cobble pocket.
     The torn-paper bottom edge is now smooth waves with no notch or spike.
     The kerb is removed cleanly, the bed is untouched, and nothing outside
     the court changed.
   - **Remains:** the strip sides are still near-straight cell lines (right
     edge x≈717–727 over y 412–500; left ≈528–537). Edges still cut through
     individual stones. The corner of the statue base sits on the release
     edge.
   - **New:** the narrow darker course is not visible; the edge setts are no
     darker than production.
2. **S7: ACCEPT, no regression.** Dropping the S7 release resolves the flag
   spread, the diagonal slash and the moss lobe. The only change is the kerb
   lines vanishing, which is barely visible. The court is still the same
   broad, centred grey field: the S7 ecology and hierarchy rework is not
   started.
3. **Fixtures: outer_wall REWORK (minor); kept canal court ACCEPT.**
   - **outer_wall:** the paved area still dead-ends mid-yard in a drip. A
     shoulder notch and a misaligned-course wedge remain at the passage
     corner. The edge setts are about 3 luminance lighter than the interior,
     so the darker course only cancels the earlier bright rim.
   - **Kept court:** pixel-identical inside with only the ring gone. Its
     rounded corners cut through the square mossy flags, as before.
   - The reviewer noted the first final-render run failing 1 of 12 (the kept
     corner box overlapped the old gutter band). That check was moved one
     cell in and reran at 12/0 (`runs/c31v2owners-GroundCourtSupportRenderTest-*`).
4. **Beds: ACCEPT.** The rounding and wobble are reverted. Only the inner
   corners change (80 px in the fixture, 163 px at two household notches),
   and those square bites become soft fillets. In-game beds are identical to
   production. The pre-existing beds remain soft, floating squares with no
   edging or wall contact.

**Most important follow-up:** make the release edge look built, either by
snapping it to whole setts or by drawing a visible 1–2 px contact course,
before extending release beyond Outer Wall.
