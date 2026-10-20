shader_type canvas_item;

#include "res://core/systems/world/visibility/world_cover.gdshaderinc"

// Proxy batches draw one unit quad per instance. INSTANCE_CUSTOM carries the
// atlas region (x, y, w, h in 0..1 of the batch texture) so a single batch can
// show any frame of an enemy sheet; a whole-texture instance passes (0,0,1,1).
//
// Hit flash (FPS audit 2026-10-04): a negative region height marks an instance
// that was just damaged. Heights are positive otherwise, so the sign costs the
// region and the colour no precision. The instance mixes toward white by
// hit_flash_strength, which the renderer sets from the combat-flash
// accessibility setting (1 full, 0.4 reduced, 0 off).
uniform float hit_flash_strength : hint_range(0.0, 1.0) = 1.0;
// The same surface also serves unbatched Sprite2Ds. Their native REGION_RECT
// follows animated atlas frames without a second per-enemy animation update.
uniform bool use_instance_region = true;
uniform bool elite_enabled = false;
uniform bool glint_motion = true;
uniform float glint_phase = 0.0;
uniform float edge_width : hint_range(0.5, 3.0) = 1.25;
uniform float glint_period = 2.6;
varying flat float hit_flash;
varying flat vec4 frame_region;
varying flat float phase;
varying vec4 vertex_modulate;
varying vec2 cover_world_position;
varying flat float cover_feet_y;

void vertex() {
	cover_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Both proxy and materialized batches use a Y-inverted unit quad. This
	// is the same lower-frame-center anchor used by their cast shadows.
	cover_feet_y = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).y;
	vertex_modulate = COLOR;
	hit_flash = 0.0;
	phase = glint_phase;
	frame_region = vec4(0.0, 0.0, 1.0, 1.0);
	if (use_instance_region) {
		hit_flash = INSTANCE_CUSTOM.w < 0.0 ? 1.0 : 0.0;
		frame_region = vec4(INSTANCE_CUSTOM.xyz, abs(INSTANCE_CUSTOM.w));
		UV = frame_region.xy + UV * frame_region.zw;
		// Spread a batch's sweeps without another per-instance CPU upload.
		phase = fract(float(INSTANCE_ID) * 0.61803399);
	}
}

vec3 frame_sample(vec2 pixel_size, vec2 uv, vec2 lo, vec2 hi) {
	// A neighbouring atlas frame must never contribute to the silhouette.
	vec2 inside = step(lo, uv) * step(uv, hi);
	vec2 half_pixel = pixel_size * 0.5;
	return vec3(clamp(uv, lo + half_pixel, hi - half_pixel), inside.x * inside.y);
}

void fragment() {
	if (elite_enabled) {
		vec4 region = use_instance_region ? frame_region : REGION_RECT;
		vec2 lo = min(region.xy, region.xy + region.zw);
		vec2 hi = max(region.xy, region.xy + region.zw);
		vec2 local_uv = (UV - lo) / max(hi - lo, vec2(0.00001));
		vec4 tex = texture(TEXTURE, UV);
		// The first modifier already owns this per-instance tint. Derive its
		// family before clamping so brightness pulses cannot turn it another
		// colour, and unlike a material uniform, different families can share
		// the same texture batch. Plain elites keep their authored gold tint.
		float peak = max(max(vertex_modulate.r, vertex_modulate.g), vertex_modulate.b);
		vec3 family = vertex_modulate.rgb / max(peak, 0.001);
		// Retain the painting and a hint of the modifier colour. Preserve
		// overbright hit feedback, and all actor/texture alpha, independently.
		vec3 tint = min(vertex_modulate.rgb, vec3(1.0));
		vec3 brightness = max(vertex_modulate.rgb, vec3(1.0));
		COLOR.rgb = tex.rgb * mix(vec3(1.0), tint, 0.28) * brightness;
		// Derivatives keep the inside rim roughly a screen pixel wide on
		// both small baked sprites and downscaled high-resolution role art.
		vec2 d = (abs(dFdx(UV)) + abs(dFdy(UV))) * edge_width;
		vec3 xp = frame_sample(TEXTURE_PIXEL_SIZE, UV + vec2(d.x, 0.0), lo, hi);
		vec3 xm = frame_sample(TEXTURE_PIXEL_SIZE, UV - vec2(d.x, 0.0), lo, hi);
		vec3 yp = frame_sample(TEXTURE_PIXEL_SIZE, UV + vec2(0.0, d.y), lo, hi);
		vec3 ym = frame_sample(TEXTURE_PIXEL_SIZE, UV - vec2(0.0, d.y), lo, hi);
		float neighbour = min(
			min(texture(TEXTURE, xp.xy).a * xp.z, texture(TEXTURE, xm.xy).a * xm.z),
			min(texture(TEXTURE, yp.xy).a * yp.z, texture(TEXTURE, ym.xy).a * ym.z)
		);
		float edge = clamp(tex.a - neighbour, 0.0, 1.0);
		vec3 rim = mix(family, mix(family, vec3(1.0), 0.22), 1.0 - local_uv.y);
		COLOR.rgb = mix(COLOR.rgb, rim * brightness, edge * 0.82);
		if (glint_motion) {
			float sweep = fract(TIME / glint_period + phase) * 2.3 - 0.45;
			float distance_to_band = abs(local_uv.x + local_uv.y * 0.45 - sweep);
			float band = 1.0 - smoothstep(0.025, 0.18, distance_to_band);
			COLOR.rgb = mix(COLOR.rgb, mix(family, vec3(1.0), 0.42) * brightness, band * 0.48);
		}
	}
	// Damage feedback wins over the decorative sheen.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), hit_flash * hit_flash_strength);
	if (use_instance_region) {
		// Coverage composes with the completed body/elite/hurt presentation.
		// Sprite fallback materials retain their existing owner and geometry.
		COLOR = world_cover_composite(COLOR, world_cover_strength(cover_world_position, cover_feet_y));
	}
}
