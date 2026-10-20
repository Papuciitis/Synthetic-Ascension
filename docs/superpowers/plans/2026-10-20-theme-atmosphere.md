# Theme atmosphere implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Root owns engine and Git operations; this implementer waits for observed RED before production edits.

**Goal:** Give the fourteen actual procedural themes physically coherent daylight/air profiles, replacing the common dark vignette and universal magical flies while preserving combat and separate authored spaces.

**Architecture:** An immutable profile catalogue resolves the selected theme ID and explicit scene context. A visual-only Game binder reads the actual ChunkManager family after theme selection and configures the persistent WorldAtmosphere overlay; world-space clouds and shallow bounded air effects retain a neutral readability floor. Structural roof/wall planes and cast-shadow geometry remain with the scene-depth owner.

**Tech Stack:** Godot4.7, typed GDScript, Compatibility canvas shaders, native Game capture tooling.

**Spec:** `docs/design/2026-10-20-theme-atmosphere-audit.md` and the latest direct user direction to continue checked local work autonomously.

## Global constraints

- No gameplay/RNG/save/physics/balance, theme-selection or visibility-eligibility changes.
- No WorldArt material paths, ground-care grading, shadow projection, roof/wall geometry, VisionRig or Hub lighting edits in this slice.
- All fourteen exact theme IDs resolve complete profiles; S1 uses an explicit conservative authored context and Hub bypasses the procedural component.
- No new magical glow, lightning, strobe, night/noir or beige/desert drift. Effects are physically motivated and bounded.
- No engine or Git operations by this worker. Root runs fresh import, RED/GREEN, native captures, review and checked local commits. No approval wait from the sleeping user.

## Review focus

- Theme application happens after ChunkManager._ready: the actual selected alternative must replace the startup default and fully reset prior weather.
- Reduced Motion must stop cloud/particle movement without freezing combat or removing the static environment identity.
- Camera motion must not drag a bright spot/cloud over world objects; world-space sample positions remain stable at fixed presentation time.
- S1/Hub must not inherit S7 mist or a second lighting owner; unknown IDs need a stable neutral fallback.
- World overlays must leave dark actors, health/loot, elite surfaces and essential attack colors readable at960x540; data tests are insufficient for that judgment.

### Task1: Explicit physical profile catalogue and configuration contract

**Files:**
- Create `core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd`.
- Modify `core/systems/world/atmosphere/WorldAtmosphere.gd` and `world_atmosphere.gdshader`.
- Create `tools/tests/ThemeAtmosphereTest.gd` and `.tscn`.

**Interfaces:**
- `ThemeAtmosphereProfiles.resolve(theme_id:StringName, context:StringName=&"procedural") -> Dictionary` returns a fresh complete profile with `id`, `context`, `enabled`, `ambient_fill`, `direct_light`, `environment_tint`, `cloud_opacity`, `cloud_scale_px`, `cloud_velocity`, `mist_opacity`, `mist_tint`, `wind`, `particle_kind`, `particle_density` and `vignette_strength`.
- `WorldAtmosphere.apply_theme(theme_id:StringName, context:StringName=&"procedural", reduced_motion:bool=false) -> void` resolves and applies every field, including reset-to-zero fields.
- Existing `get_shader_material()->ShaderMaterial` remains the renderer boundary. `weather_time:float` is the local presentation clock consumed by weather shader uniforms; Reduced Motion stops its advance.

- [x] Write guarded missing-profile RED plus actual profile/configuration tests.
- [x] Root runs `res://tools/tests/ThemeAtmosphereTest.tscn`; expect exactly the missing-profile assertion, exit1, no parse errors.
- [x] After root confirms RED, implement all fourteen literal profiles from the audit, conservative S1 and Hub bypass; return copies and consume no RNG.
- [x] Apply profiles to persistent materials, replace camera-relative dark-edge identity with high-fill world-space cloud/air presentation, and bound mist/particle contribution. Use source coordinates plus local weather_time, never shader TIME with unbounded flash behavior.
- [ ] Root runs focused GREEN in headless and native; verify reset, unknown fallback, all-theme coverage, world anchoring and motion/readability constraints.
- [ ] Root reviews and records a scoped checked local implementation commit when the integration below also passes; no remote publication by this worker.

### Task2: Actual Game theme binder and ordinary daylight particles

**Files:**
- Create `core/systems/world/atmosphere/GameAtmosphereBinder.gd`.
- Modify `scenes/game.tscn` only for the visual binder/universal Fireflies node wiring.
- Extend `tools/tests/ThemeAtmosphereTest.gd` with actual binder/context/reset checks once native integration exists.

**Interfaces:**
- Binder extends Node, discovers the sibling ChunkManager and its existing WorldAtmosphere, reads actual `district_family`, and calls Task1's `apply_theme()` only when selected family/context/accessibility changes.
- S1 explicit context is `institution`; Hub context is `hub` and disables the procedural overlay. There is no new save data or theme reroll.

- [x] Preserve the first valid selected-family handoff; do not infer paired theme identity from segment number.
- [x] Remove the Game scene's universal additive blue Fireflies instance. Retain its resource/script for other explicitly authored users; do not introduce replacement particles without actual physical source/budget.
- [x] Test theme changes and reduced-motion changes against a configured live component and verify no Global RNG/save writes.
- [ ] Root runs actual Game S1/S2/S3/S7 and Hub regression checks, confirming one atmosphere owner and no missing profile/renderer diagnostics.

### Task3: Bounded native comparisons and evidence

**Files:**
- Create `tools/dev/ThemeAtmospherePreview.gd` and `.tscn` using existing native Game preview infrastructure.
- Evidence/audit packaging belongs to root after outputs are reviewed.

- [ ] Capture explicit S2 home944996572 seed16102026 chunk(0,3), an exact S3 guard-loggia sample and seed4 S7 Canal Services at the existing real moss/wet-earth crop.
- [ ] Return same-camera before/after1280x720 and960x540; a Reduced Motion sample; genuine player/enemy/elite/loot/health; roof entry/exit; one short occupied moving comparison. Record actual theme, profile, weather phase/clock, camera and qualifiers.
- [ ] Verify world anchoring under camera pan, slow bounded cloud motion, no indoor rain/mist leak, and clear tell/actor colors. Preserve all gameplay counts, route/terrain hashes, RNG and save writes.
- [ ] Root runs appropriate cover/roof/city and other affected regressions, then final parse audit; independent review of source and actual images precedes checked local commits.
- [ ] Report all14 data coverage separately from native acceptance of the three sampled themes. Preserve outstanding L2/L3 and district-structure work.

## Current state

Root observed the clean missing-profile RED and authorized production edits.
Core verification after repairing the test World2D fixture: root reported
headless87/0 and native92/0, clean including verbose teardown. Root then
observed the additional actual-receiver RED (exactly0/1 missing API, exit1,
no extra diagnostics) and authorized the receiver/direct-light follow-up.
The follow-up is written and awaits root GREEN. This worker has run no
engine/Git commands and makes no unobserved verification claims.

The actual low-air material is exposed by `get_mist_material()` and uses a
conservative lazy indoor mask at absolute Z-8, separate from the daylight pass.
Low air now restricts itself to actual wet5/moss12 and wet/moss-stain fragments
from matching GroundSplat textures/slot identities, defaulting off without a
matching host. Following scene-depth coordination, `direct_light` now changes
actual roof.gdshader plane/ridge factors and city_sun_shadow alpha from exact
per-instance baselines. Shared clipped-fragment materials deduplicate by ID;
host draw alpha, cutaway modulation, geometry, actor/item/HUD materials and
shadow projection are preserved. Clear/authored/removal/teardown resets and
native rendered wet/dry/roof/shadow assertions are in the focused test.

## Native execution record — 20 October

Root observed final focused native core92/0, receivers35/0 and dry guard6/0.
All eight explicitly selected Game/authored runs finished with exit0, no monitor
diagnostics, zero fixture failures and zero saves. S2 small includes actual
entry/cutaway/exit; S2/S3/S7 each have960×540 and1280×720 profile/daylight-ablation
plates and corresponding fixed-world camera-pan probes. The first S2 boundary-
pixel probe failed and remains retained; the corrected tool selects an actual
texel center without loosening its tolerance. S7 normal adds25 distinct paused
weather samples; S7 Reduced Motion records34 fight frames,25 fires and27 hits,
with a measured-timestamp MP4 that fully decodes. Actual S1/Hub owner checks13/0
retain their authored atmosphere/VisionRig/practical lighting.

Independent source review found no blocking lifecycle, material/fade, canvas,
receiver-mask or gameplay ownership issue. Final combined entity-cover and
main-tree parse/regression checks follow integration. Native samples establish
these three themes only; all fourteen profiles have data coverage. Full street
art acceptance, missing district infrastructure, ordinary human play and a
matched performance budget remain outside this bounded result. See the dated
Linux atmosphere packet and LINUX_STATUS for final commit/check bindings.
