# Boss pylon sprite v1

- Created 2026-10-16 with the built-in `image_gen.imagegen` tool, using a
  genuinely transparent background. This asset was not sourced from Canva
  or a third-party pack.
- Existing game art inspected first: `enemy_roles_v4.png`,
  `landmark_obelisk_01.png` and `hub_ascension_obelisk.png`. The existing
  obelisks read as landmarks/safe upgrade stations; the new sprite is a
  squat, destructible hostile device in the existing iron/brass/occult palette.
- Original generated file:
  `C:/Users/NaurisKrišjānis/.codex/generated_images/01a143d0-957b-72c2-8b6a-145112f1027a/exec-4fa3f481-a658-401e-84fb-5e88743f6387.png`.
- Delivered `pylon_v1.png` is copied unchanged from that output, 1254 × 1254
  RGBA; no trimming, repainting, background removal or resampling was applied.
- SHA-256: `82c73d10e3e361eacdaf26b8be9061c2630c5bc0fea6800f5fbdc153ce993fb9`.
- Runtime uses a 0.048 sprite scale, approximately 60 px canvas bounds and
  45 px occupied device height; charge, shadow and destruction feedback
  use separate PNG Sprite2Ds rather than being baked into the body image.

## Exact generation prompt

Use case: stylized-concept. Asset type: one production game sprite, a small hostile destructible energy pylon for the top-down action roguelite Synthetic Ascension. Create exactly ONE isolated squat occult-industrial pylon, with a broad planted iron base, four short armored braces, aged brass fastening bands, and one bright violet focusing crystal held between two dark iron prongs. It should read as a dangerous portable magical turret, about chest-high beside an ordinary person, not a tall landmark, monument, friendly upgrade station, character or boss. Materials and palette should fit a medieval-industrial occult city: blackened iron, worn muted brass, restrained violet crystal and a tiny pale hot center. Style: crisp, deliberately pixel-clustered game sprite, roughly a 64-by-64 logical pixel drawing with large readable material clusters; no painterly blur or photographic texture. Three-quarter top-down camera, looking down enough to see the top faces, matching a top-down game viewed at a shallow 3/4 angle. Symmetric stable base and clear upright silhouette. Composition: entire object visible and centered, around 60 percent of canvas width and 80 percent of height, with clear empty margins. Genuinely transparent alpha background. No floor, no backdrop, no drop shadow baked into the image, no floating aura, no sparks outside the object; the game adds its own shadow and charge effects. No text, letters, UI, labels, numbers, borders or watermark. The violet crystal is a small focal point; most of the body stays solid readable iron. Exactly one sprite, not a sprite sheet or multiple variants.
