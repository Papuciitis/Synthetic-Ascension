# Independent review: first pass (all-family release, reshaped beds)

Reviewer: independent agent given only the native originals and the lead
direction (2026-10-21 lead review, ground material direction, concept 08);
not given the author's conclusions. Reviewed `native/rejected-first-pass/*`
against the production baselines. Verdict: **REWORK** overall.

1. **S9 normal: ACCEPT with notes.** The rounded rectangle and its dark
   gutter ring are gone; the area reads as an off-centre sett path from the
   door to the street through a grassy-cobble yard. Notes:
   - The strip sides are near-straight grid lines (x≈735 for 80 px, x≈547
     and 575 with only 3–5 px wobble), with a square shoulder at y≈432,
     x 549–600.
   - The statue sits in a rounded cobble pocket hugging its base, like a mask
     halo.
   - The bottom edge (x 737–940, y 530–562) looks like torn paper: a V-notch
     at ≈(815,560), a spike at ≈(905,540) and stair-stepped diagonals.
   - The outline cuts individual stones with no contact shading.
2. **S7 normal: REWORK.** The released area fills with the oversized pale
   mossy flags that the 23 Oct review left open, in two new patches. The
   wedge edge is a straight ~220 px diagonal plus a vertical cut at x≈1117,
   slicing flags and setts into triangles, so it reads as a wipe, not as wear
   or laid stone. The moss lobe helps the damp setting but its shape is puffy.
3. **S9 small: ACCEPT with notes.** It matches the normal view; the same
   notes apply.
4. **Court fixture: REWORK.** A single-entrance court becomes a symmetric
   keyhole ending mid-yard in a rounded drip. It reads as a poured puddle,
   neither asymmetric nor usable. There is an angular notch at the shoulder,
   and without the kerb, misaligned sett seams are exposed at the passage
   corners.
5. **Care beds: REWORK (keep the notch fix).** Rounding removes the old
   inner-corner notches; keep that. But the beds now read as blobs: care-100
   as a pillow, household-cared as an S-shaped puzzle piece. A darkened band
   outside the green reads as a halo. The inward wobble pulls edges away; in
   S9 the gap to the wall base grows from about 7 to 15 px, leaving a
   floating cushion. No contact with walls was added, which is what the lead
   review actually asked for.

**Most important follow-up:** draw paving boundaries along whole stones
instead of noise masks, end walking lines at a destination, and keep
wall-facing bed sides straight. Next, fill unused S7 court cells with damp
moss/soil, not oversized flags.

## What the author changed in response

- Release is now per family (`court_release`) and enabled only for Outer
  Wall. S7 keeps its setts as a flush court. A moss-patch release was
  rendered for every family (`sheets/first-pass-*`); it retraced the court
  rectangle and was dropped.
- Walking lines and the middle meander on a hashed field, every entrance
  keeps a full landing, the fine (tearing) edge noise was reduced, and kept
  setts end in a narrow darker course.
- Beds were reverted to their wall-facing shape; only the inner-corner
  fillet remains.
- Snapping edges to whole stones needs a per-stone map of the hand-painted
  sett art, and is recorded as the next step.
