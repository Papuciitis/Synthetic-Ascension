# First city block kit — 18 October 2026

Six original raster components generated with the built-in `image_gen` tool.
No stock/downloaded artwork or external API/CLI was used. The original PNG
pixels were copied unchanged into this folder; transparency is the tool's
generated alpha. Runtime source rectangles, scale, roof tint/shading and ground
composition are code, not claims of hand-repainted source art.

| Asset | Source size | Runtime use |
| --- | --- | --- |
| civic_arcade.png | 1983×793 RGBA | Shallow three-bay south frontage, sliced around the real two-cell doorway |
| house_front.png | 2172×724 RGBA | Shuttered attached frontage with linen shade, same doorway fitting |
| slate.png | 1254×1254 RGB | Quiet blue slate field under existing gable shader |
| clay.png | 1254×1254 RGB | Separate muted terracotta field for neighbouring roof masses |
| paving.png | 1254×1254 RGB | Broad limestone frontage strips, excluding every parcel footprint |
| pressure_plant.png | 1010×1558 RGBA | Small foundation-mounted municipal pressure plant, fades with roof |

`scenes/world/buildings/CityBlockKit.gd` installs the kit. The existing shared
wall renderer retains connection geometry and alpha; `city_stone.gdshader`
compresses its small mortar edges into a cool limestone value range. Existing
olive-shrub art is reused sparingly. Curbs, drains, coarse service connections
and chimney caps are simple native geometry, with no per-brick or per-tile nodes.

Scope: Segment 2's existing searchable-building block. This is an opt-in
district role, not the whole city. Full painted arcade/house fronts currently
support south-facing entrances; other directions retain their actual walls,
doors and the shared roof/material treatment. A larger directional kit is
later rollout work.

Source originals are preserved under:
`C:/Users/NaurisKrišjānis/.codex/generated_images/01a14fff-3528-77c1-867f-59c8167188eb/`.

| Asset | Original filename |
| --- | --- |
| civic_arcade.png | exec-e205f3e3-5be4-4bbe-a6cf-c30df93a5cf5.png |
| slate.png | exec-37ddf604-8259-440a-89e2-a4027a120fa4.png |
| house_front.png | exec-b67ac6cd-c6ae-4a01-bf5e-bb733c1126e6.png |
| paving.png | exec-d707c002-cec7-463b-b23f-b2cfcbc70c65.png |
| clay.png | exec-a4235adb-b7ce-404a-bc08-8c0bdc5f963d.png |
| pressure_plant.png | exec-65768b8b-ad11-4614-a441-3a66c2728e66.png |

The exact generation prompts are in `PROMPTS.md`. Native review evidence,
known limits and the isolated playable launcher are documented in
`docs/audits/2026-10-18-first-city-block.md`.
