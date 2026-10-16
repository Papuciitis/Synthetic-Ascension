# Boss step 2 sprite provenance — 16 October 2026

Twelve transparent raster sprites were generated or edited with the built-in `image_gen.imagegen` tool. They are rough proportion studies and effect assets for review; this record does not establish human approval of final character art or animation. The exact twelve prompts are preserved in [the generation record](2026-10-16-boss-step2-image-prompts.json).

All twelve repository PNGs were checked byte-for-byte against their original generated outputs and the recorded SHA-256 values. Their original canvas sizes and pixels remain unchanged: no external crop, resize, repaint or background-removal pass was applied. Godot handles runtime fitting, tint/opacity, and the beam's AtlasTexture region. Imports use lossless compression, no mipmaps and no source-size limit; ordinary alpha-border processing affects the engine resource, not these source PNG files.

Original output directory: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a143cf-14e6-7c93-8fbe-b1d3914bf001/`. The filenames below identify the exact original outputs.

## Character studies

Files are under `scenes/world/bosses/art/forms/`.

| Sprite | Intended form | Canvas | Original output filename | SHA-256 |
| --- | --- | --- | --- | --- |
| [bulldozer_s5_v1.png](../../scenes/world/bosses/art/forms/bulldozer_s5_v1.png) | S5 human-sized armored enforcer; compact plough and maul | 1199×1312 | `exec-7d359e84-4546-447d-802c-9266693fea27.png` | `9b17cdbf5b7c71c9cb196fa2ab93a9203edf1695314da09de036d5888c2f2e8d` |
| [bulldozer_s10_v1.png](../../scenes/world/bosses/art/forms/bulldozer_s10_v1.png) | S10 bracing harness, plough and impact hammer; same anatomy height | 1154×1363 | `exec-d040d2d2-a119-47be-8f9c-48923be3f0eb.png` | `9df126fa7d5237090e5467fcad34827fb1f0cf903ba51888b6d75f05bfd6b10e` |
| [arcanist_s5_v1.png](../../scenes/world/bosses/art/forms/arcanist_s5_v1.png) | S5 grounded caster with modest staff and readable hand | 1024×1536 | `exec-583e7a11-6b0d-4056-88a8-ff514069df5c.png` | `0cea9affcc5810386ad5dce9c4b3805c570dcb9d4305bcd4445390389f7b1cb6` |
| [arcanist_s10_v1.png](../../scenes/world/bosses/art/forms/arcanist_s10_v1.png) | S10 focusing rack and forked staff; equipment adds presence | 1024×1536 | `exec-fc8b07d0-8413-4807-a5a9-5a40dc1629f0.png` | `fae4d2e6e24a4b49d0146d92b98b044b45bcafbb484a9d3091234ba8ce5ee26e` |

## Effect sprites

Files are under `scenes/world/bosses/art/vfx/` or `assets/textures/vfx/encounters/`, as linked. The beam edit starts from the previous [beam sprite](../../scenes/world/bosses/art/vfx/arcane_beam_v1.png); the other prompts request isolated new assets.

| Sprite | Intended effect | Canvas | Original output filename | SHA-256 |
| --- | --- | --- | --- | --- |
| [arcane_beam_v2.png](../../scenes/world/bosses/art/vfx/arcane_beam_v2.png) | Transparent energy filaments replacing the hard dark beam backing | 2172×724 | `exec-ff0ca997-ca10-4a43-a021-46394fcf87c3.png` | `83d4083c93e52dca07e1908c9a35daefe7aa4d5208ea8867f4629adafc00c117` |
| [pulse_ripple_v1.png](../../assets/textures/vfx/encounters/pulse_ripple_v1.png) | Detailed force ripple; also reused as bracing/casting accents | 1254×1254 | `exec-7560500c-3bee-47e8-be00-b934f68fb4ae.png` | `f664cc55023b2db6c8356d1c540332541dca91da09dff42be7e2f44032e82f0d` |
| [bomber_perimeter_v1.png](../../assets/textures/vfx/encounters/bomber_perimeter_v1.png) | Fixed amber/red blast perimeter during the fuse | 1254×1254 | `exec-8c305cc4-bcd2-4c30-9b12-96cdafd44efb.png` | `3b779ed7d4574f2a8b548e793064bcd299b544f618e25280204104d94334555d` |
| [bomber_blast_v1.png](../../assets/textures/vfx/encounters/bomber_blast_v1.png) | Compact fire/dust blast and fuse buildup | 1254×1254 | `exec-fb19710c-e127-4087-b80f-44874bb135ef.png` | `3811897eaab1f25b091930b1cb1f008c06180645a7f11876c169e24178f9bdd8` |
| [slam_fracture_v1.png](../../scenes/world/bosses/art/vfx/slam_fracture_v1.png) | Physical fracture/crater identity and impact overlay | 1254×1254 | `exec-82fd3238-6555-4536-b1a7-7a059e42b047.png` | `89e5d4996d6275849749ea0c6dcabd24866ec88de3f6084432f748be2fa14c88` |
| [shock_crackle_v1.png](../../scenes/world/bosses/art/vfx/shock_crackle_v1.png) | Forked pressure-lightning identity and ground-shock impact | 1254×1254 | `exec-e1ee51d7-885e-4d7b-a562-335190e0eae5.png` | `3b7b2833707bb27a7217ae0f87d185150f1494f859d3216ea1dc3a01d4ad3ff2` |
| [mine_sigil_v1.png](../../scenes/world/bosses/art/vfx/mine_sigil_v1.png) | Planted crystal trap with separated violet danger arcs | 1254×1254 | `exec-f04923d7-57d1-4a49-94a2-cb55c3469782.png` | `a12bedaf0177090b967d0401bd6cb9a3ff449e01036a6133e2a8d664ef557903` |
| [charge_windup_v1.png](../../scenes/world/bosses/art/vfx/charge_windup_v1.png) | Directional chevrons fitted to the committed rush lane | 2172×724 | `exec-277cab68-e7b7-4956-9466-d872713ec7bd.png` | `3d373d0d03d853e8991645527ab92b5919ec797f31382f096ed63b17986a288f` |

## Measurement and runtime conventions

Bodies, equipment and collision are measured independently. Transparent canvas padding is never treated as body height. Source alpha bounds are recorded at thresholds 10, 51, 128 and 200 in [form measurements](../audits/evidence/2026-10-16-boss-step2/form-source-measurements.json); boxes use left/top and exclusive right/bottom coordinates. The alpha≥128 equipment envelope excludes near-invisible export pixels. Anatomy boxes and foot anchors are separately annotated so staff tops, focusing apparatus and hammer hardware do not enlarge the body measurement.

The human comparison is 77 occupied world pixels including hair; it is an art reference, not an exact biological measurement. [BossAppearance](../../scenes/world/bosses/BossAppearance.gd) fits each annotated anatomy height, places the feet 42 world pixels below the shared combat origin, and keeps the actor root at scale 1. Existing walking-circle and square contact extents remain explicit.

| Form | Anatomy height, world px | Equipment envelope, world px | Walking radius | Contact square side |
| --- | ---: | ---: | ---: | ---: |
| S5 Bulldozer | 88 | 81.411×88.000 | 39.015 | 78.03 |
| S10 Bulldozer | 88 | 79.536×94.348 | 44.795 | 89.59 |
| S5 Arcanist | 82 | 45.974×84.101 | 36.720 | 73.44 |
| S10 Arcanist | 86 | 58.223×100.368 | 42.160 | 84.32 |

Effect alpha coverage and calibration are preserved in [effect measurements](../audits/evidence/2026-10-16-boss-step2/generated-art-measurements.json). Circular identities fit their measured alpha>0.2 radial extent to the configured attack radius; the source canvas edge is not the damage boundary. The beam reads source region `(42,287,2088,148)` through [its AtlasTexture](../../scenes/world/bosses/art/vfx/arcane_beam_body.tres). Charge chevrons use their measured visible extents to fit the committed travel distance. Source PNGs remain intact. Physics shapes and existing attack clocks remain authoritative; fracture imagery adds no permanent terrain collision.

## Rendered references

- [Scale board](reference/2026-10-16-boss-proportions/): all four races, Brute, Herald and four boss forms; art, silhouettes and footprint views at 1280×720 and 960×540.
- [Arena courts](reference/2026-10-16-boss-arena-courts/): actual generated S5/S10 courts with player and staged boss at 960×540, plus court/entry metadata.
- [Effect gallery](reference/2026-10-16-boss-step2-vfx/): staged production windups, warnings and impacts in the actual Game scene.

These use the production 1920×1080 canvas and camera zoom 1. A 960×540 capture displays one world pixel as half an image pixel. The references are frozen visual evidence; they do not establish fight balance, dense-combat readability or finished animation.
