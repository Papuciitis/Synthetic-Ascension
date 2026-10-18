# Boss presentation — 18 October 2026

## Current portraits — coherent world-form set (v2)

The user's later correction replaces the meme blends with portraits matching the actual world artwork, for both S5 and S10. The four active portraits below use only their corresponding established world form as an image input. Bulldozer keeps its closed helmet; Arcanist keeps its stern human face. S5 has simpler armor/hood fittings, while S10 has piston braces or the focusing rack. All four share charcoal, worn brass and a dark painterly background. No meme photographs, animal identities, names or text are present in the v2 artwork.

The built-in `image_gen.imagegen` tool made one square 1254×1254 PNG per portrait. Each generated output was copied unchanged into the game. [Exact prompts, source form hashes, output hashes and original generated filenames](2026-10-18-boss-portrait-v2-prompts.json) preserve the complete generation record. Source world-form provenance remains in [the established form record](2026-10-16-boss-step2-assets.md). No external art was fetched.

| Active portrait | Sole source form | Output SHA-256 |
| --- | --- | --- |
| `ui/boss/portraits/bulldozer_s5_v2.png` | `bulldozer_s5_v1.png` | `d1994f23256376493766a65c314e703cb0dfdc36c0b45ed98451a366e8b19f38` |
| `ui/boss/portraits/arcanist_s5_v2.png` | `arcanist_s5_v1.png` | `475b95eb198f5aa6ad0605ad113207d68a0feced404138e650f03ba111ca28f5` |
| `ui/boss/portraits/bulldozer_s10_v2.png` | `bulldozer_s10_v1.png` | `6808786b501e1c62b86168184bdc838ab84b3ff6c93ede5ae2907cad65178734` |
| `ui/boss/portraits/arcanist_s10_v2.png` | `arcanist_s10_v1.png` | `0770426f34821b4c47234a97945d1edcd283b6a63b6faa29e69286a731e09d6d` |

`BossAppearance.portrait_for` and the production HUD select the correct portrait for both known roles and tiers. Unsupported identities or tiers preserve the caller's fallback. The old meme portraits and v1 blend files are retained as superseded history; production boss HUDs use v2.

## Superseded v1 portrait generation record

The following v1 generation record is retained for provenance. Its meme direction was superseded by the user's later correction above and is no longer the active portrait mapping.

Two role-specific portraits were edited with the built-in `image_gen.imagegen` tool. The source portraits already belonged to this game: the shared S10 Jamal portrait and the S5 Chihuahua portrait. No external imagery was fetched. The original memes and their existing provenance remain unchanged; this record documents only these new edits, not a claim to authorship or a new license for the underlying memes.

The Bulldozer keeps Jamal's expression and name, dressed in the established S10 charcoal iron/brass armor, shoulder pistons, hammer and plough shield. The Arcanist keeps the Chihuahua's glossy eyes and half-smile beneath the established hood, focusing crescents and violet staff crystal. These are intentionally humorous portraits alongside the serious world forms. The original portrait files remain available unchanged.

The two 1254×1254 PNG outputs were copied unchanged from `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14e1f-2243-7fb3-974d-26d1777b04c7/`.

Two native `AtlasTexture` resources frame the faces more tightly in the small boss-bar portrait: Bulldozer `(260,200,760,760)` and Arcanist `(180,220,900,900)`. These runtime regions leave the generated source pixels untouched. `BossAppearance.portrait_for` selects by the actual main boss identity; the HUD preserves arena-authored teaching portraits and unknown-role fallbacks.

| Repository file | Generated source | SHA-256 |
| --- | --- | --- |
| `ui/boss/portraits/bulldozer_s10_v1.png` | `exec-5e8a4ecd-deb8-4819-8214-045056874fce.png` | `669cc9be4dbec2f7c694ac3b1daf71b6daffcf485e6f5c4cfe20df01863a5919` |
| `ui/boss/portraits/arcanist_s10_v1.png` | `exec-67258be1-f20f-4427-b8b7-acf4b61b252d.png` | `c0905ce69223e2c40cd03bc93825c450861a5163e9d5e232d420e9aae7c34b42` |

## Exact prompts and inputs

Bulldozer input 1: `ui/boss/portraits/boss_portrait.png` (edit target). Input 2: `scenes/world/bosses/art/forms/bulldozer_s10_v1.png` (equipment/style reference). `transparent_background: false`.

> Use case: compositing / identity-preserve. Create one square game boss HUD portrait. Image 1 is the EDIT TARGET: preserve exactly the recognizable face, expression, skin, gaze and humorous meme personality from this existing Jamal game portrait; preserve the white word 'Jamal' at the top. Image 2 is the supporting equipment/style reference of the game's S10 Bulldozer. Dress the portrait subject in the reference's battered charcoal iron and brass massive shoulder armor and open-face helmet hardware without covering or altering the meme face. Tight head-and-shoulders framing filling the square, with visible piston brace rising behind each shoulder, small edge of the impact hammer at lower left and plough-shield at lower right. Very dark warm background, hand-painted gritty synthetic-occult brass equipment, intentionally funny face collaged into serious armor. Face must remain the main read at tiny 80px HUD size. No other characters, no new text, no caption, no logos, no watermark. This is a role-specific S10 portrait asset, not full body or a mockup.

Arcanist input 1: `ui/boss/portraits/miniboss_portrait_02.png` (edit target). Input 2: `scenes/world/bosses/art/forms/arcanist_s10_v1.png` (equipment/style reference). `transparent_background: false`.

> Use case: compositing / identity-preserve. Create one square game boss HUD portrait. Image 1 is the EDIT TARGET: preserve the recognizable Chihuahua face, massive glossy watery eyes, tiny nose and awkward smug half-smile of this existing funny game portrait. Image 2 is supporting equipment/style reference: the S10 Arcanist world form. Dress this exact Chihuahua in that dark charcoal hood with ivory front seam, brass synthetic-occult fittings and violet cloth lining. Keep both the dog's enormous eyes completely unobstructed and its original humorous expression and photo-meme personality, as though this familiar meme dog has been promoted to an absurdly powerful city archmage. Tight head-and-shoulders square framing, cropped open brass focusing crescent behind each side of hood; staff fork and violet crystal visible down the right edge, very dark warm background. Equipment hand-painted dark fantasy brass and worn cloth matching reference, humorous face readable at 80px HUD. No human face, no captions, no text, no other characters, no watermark. A finished usable role-specific HUD asset, not a mockup or full body.

## World forms

The established ImageGen S10 form PNGs are retained byte-for-byte. Their source prompts, anatomy/equipment measurements and hashes remain in `docs/art/2026-10-16-boss-step2-assets.md`. Runtime phase equipment treatment and acting use these detailed forms; no new world silhouette or collision footprint is introduced. Human art approval and encounter readability assessment are not claimed by these generated assets.

`BossActing` follows the production brain's accepted attack state and phase. It adds a small feet-anchored lean/compression for anticipation, a 140 ms release follow-through inside the real recovery opening, and an exposed recovery stance. Sustained rush/shock/sweep states follow their existing release clocks. The authored equipment receives static texture-masked amber heat (Bulldozer) or violet focus (Arcanist) as phases advance, without rolling back on healing. Reduced Motion restores the exact authored sprite transform while retaining the static phase identity. Defeat and tier changes restore the original pose/material. No damage geometry or attack clock is changed.

This is runtime acting of the established whole-form raster, not a newly drawn frame animation sheet. Normal/small-window representative production-renderer boards compare all three equipment phases and windup/release/recovery with and without Reduced Motion. They hide foreground attack VFX for body inspection; they do not establish dense-fight readability, final animation weight or human approval. The first actual-Game capture attempt did not finish; a subsequent isolated native run produced the six successful actual-Game references below.

## Reproducible rendered references

Four selected final v2 frames are saved in [the reference folder](reference/2026-10-18-boss-presentation/), with [capture conditions and pixel checks](reference/2026-10-18-boss-presentation/capture-info.json). Each board shows the S10 production boss bar and a second bar previewing the matching S5 portrait, so all four new icons are visible at normal/small HUD size:

- [Bulldozer, normal 1280×720](reference/2026-10-18-boss-presentation/bulldozer-normal-1280x720.png)
- [Arcanist, normal 1280×720](reference/2026-10-18-boss-presentation/arcanist-normal-1280x720.png)
- [Bulldozer, Reduced Motion 960×540](reference/2026-10-18-boss-presentation/bulldozer-reduced-960x540.png)
- [Arcanist, Reduced Motion 960×540](reference/2026-10-18-boss-presentation/arcanist-reduced-960x540.png)

Reproduce all eight combinations with `res://tools/dev/BossPresentationPreview.tscn -- --out=/absolute/output/folder`, using an isolated user-data environment and no concurrent human playtest. The final native renderer exited 0, recorded eight captures with zero failures and zero save writes, and produced no runtime diagnostics. All eight were inspected. Phase-1 versus phase-3 body-region comparisons changed 297/173 Bulldozer pixels and 136/82 Arcanist pixels at 1280/960 widths; Reduced Motion preserved those same phase differences.

The focused real-brain presentation regression passes 37 checks after the v2 correction: all four role/tier portrait routes, distinct assets, unsupported-tier and unknown-role fallbacks, alongside the prior acting/geometry/accessibility checks. Before the correction, the updated suite recorded 32 passes and five expected failures against the previous mapping; after integration it exited natively with 37 passes and zero failures. The enclosing delivery also records compatibility suites of 72 proportion, 15 phase-bar and 44 main-interruption checks. The refreshed boards include a second S5 bar to inspect both tiers. The final combined audit passes all 535 gameplay scripts; these scoped results do not claim a human encounter or art verdict.

## Actual Game references

Six [actual Game frames](reference/2026-10-18-boss-game/) show both roles and the Arcanist's phase-3 mine arc at 1280×720 and 960×540, with the production court, player, boss HUD, role portraits, equipment treatment and attack effects. [Capture metadata](reference/2026-10-18-boss-game/capture-info.json) records seed 16102026, zero save writes and zero capture failures. The native renderer exited 0 without runtime diagnostics; all six frames were inspected.

Reproduce with `res://tools/dev/BossDeliveryGamePreview.tscn -- --out=/absolute/output/folder`, isolated APPDATA/LOCALAPPDATA and no concurrent human playtest. It extends the existing telegraph preview, advances visual acting once and freezes production brain casts at 60% of their tells. These are staged views, not moving encounters or timing tests. Actual-damage walking controls are recorded separately in the delivery audit.
