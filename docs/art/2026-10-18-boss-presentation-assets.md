# S10 boss presentation — 18 October 2026

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

This is runtime acting of the established whole-form raster, not a newly drawn frame animation sheet. Normal/small-window representative production-renderer boards compare all three equipment phases and windup/release/recovery with and without Reduced Motion. They hide foreground attack VFX for body inspection; they do not establish dense-fight readability, final animation weight or human approval. The attempted actual-Game capture did not finish and is retained as a failed diagnostic separately from the successful representative-renderer captures.

## Reproducible rendered references

Four selected final frames are saved in [the reference folder](reference/2026-10-18-boss-presentation/), with [capture conditions and pixel checks](reference/2026-10-18-boss-presentation/capture-info.json):

- [Bulldozer, normal 1280×720](reference/2026-10-18-boss-presentation/bulldozer-normal-1280x720.png)
- [Arcanist, normal 1280×720](reference/2026-10-18-boss-presentation/arcanist-normal-1280x720.png)
- [Bulldozer, Reduced Motion 960×540](reference/2026-10-18-boss-presentation/bulldozer-reduced-960x540.png)
- [Arcanist, Reduced Motion 960×540](reference/2026-10-18-boss-presentation/arcanist-reduced-960x540.png)

Reproduce all eight combinations with `res://tools/dev/BossPresentationPreview.tscn -- --out=/absolute/output/folder`, using an isolated user-data environment and no concurrent human playtest. The final native renderer exited 0, recorded eight captures with zero failures and zero save writes, and produced no runtime diagnostics. All eight were inspected. Phase-1 versus phase-3 body-region comparisons changed 297/173 Bulldozer pixels and 136/82 Arcanist pixels at 1280/960 widths; Reduced Motion preserved those same phase differences.

The focused real-brain presentation regression passes 29 checks, with compatibility suites passing 72 proportion, 15 phase-bar and 44 main-interruption checks. The final combined parse audit belongs to the enclosing delivery; these scoped results do not claim a human encounter or art verdict.
