# Boss VFX at actual game scale

2026-10-16. The user's concern was confirmed in the actual Game: the old thick rings and stretched beam looked coarse beside the shaded characters and paving. The upgraded boss sprites were generated with built-in ImageGen, then fitted to the existing attack dimensions. Both sets use the same seeded terrain, real player/enemy art, HUD, original 1920 × 1080 viewport, camera zoom 1, and normal canvas scaling.

| Sample | Foundation kit | Upgraded sprites |
|---|---|---|
| Warning, 1280 × 720 | [Before](actual-game-staged-vfx-warning-1280x720.png) | [After](upgraded/actual-game-staged-vfx-warning-1280x720.png) |
| Active beam, 960 × 540 | [Before](actual-game-staged-vfx-active-960x540.png) | [After](upgraded/actual-game-staged-vfx-active-960x540.png) |

The new seal's finer band and larger cardinal accents remain readable at the smaller window size. The beam now has textured energy and a pale core, and its warning is visible against both paving and grass. Independent visual review found no critical readability defects in these samples. Small charge crumbs retain simpler raster rings so fine ornament does not become noise.

These are staged, frozen production components, not a boss fight or a dense-combat/motion test. The real HUD partly covers the left slam; shock and mine circles are unobstructed. The top contextual hint can differ between runs. The actual player, enemies and terrain establish the relevant art scale. Existing pulse, Spirit Slash and elite art are comparison material, not part of this boss-art replacement.

The [source art, exact prompts and hashes](../../../../scenes/world/bosses/art/vfx/PROVENANCE.md) record unchanged original PNGs. The ring uses its measured 570.1 px content radius; the beam uses an AtlasTexture region excluding transparent padding, scaled by its actual 146 px height. A smaller pale core stays inside the beam. Source art does not define collision. Fine source engraving intentionally merges at gameplay scale; linear filtering prevents harsh sampling of the larger source texture.

Both [baseline capture metadata](capture-info.json) and [upgraded metadata](upgraded/capture-info.json) record zero profile writes and four successful captures. Their `kit_sources` field describes the legacy comparison kit; the upgraded boss sources are the art record above. The baseline run exposed a pylon shutdown issue that was subsequently fixed with a failing regression; the upgraded rendered run exited with no engine/script errors. Logs and tests are linked in [the foundation audit](../../../audits/2026-10-16-boss-hazard-foundation.md).

Reproduce with `res://tools/dev/BossVfxGamePreview.tscn`, rendered, using `-- --out=res://docs/art/reference/2026-10-16-boss-vfx-game/upgraded`. Run only when no human playtest is active. Save/recording destinations are isolated before Game readiness and runtime settings are not saved.
