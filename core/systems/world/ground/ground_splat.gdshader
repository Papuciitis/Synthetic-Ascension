shader_type canvas_item;

// The whole world ground in one pass (GroundSplatRenderer.gd).
//
// Classic terrain splatting on the 64 px cell grid. Up to eight materials
// share two one-hot coverage maps (cover_a = slots 0-3, cover_b = slots 4-7),
// one texel per cell, wrapped; the hardware bilinear filter turns them into
// smooth per-slot coverage for free. A pixel takes the slot with the most
// coverage at a noise-warped point, so material edges wander and corners round
// off while the grid underneath (walkability, keepout, walls) is untouched.
// Overgrowth slots win ties, so grass creeps over the paving, and paving just
// below-left of another material gets a lip shadow (light from the top right).
//
// light_map: R = brightness / 2, G = stain amount (the stain draws
// stain_layer through a noise cut, never as a rectangle), B = household care,
// A = ground openness (1 = open sky, lower = occluded by nearby walls/props).
//
// District ground policy (DistrictGroundPolicy.gd, 2026-10-21): procedural
// districts present each semantic material through a role (road, lane,
// footway, yard, lawn, soil) with the theme's own source, mid tone and grade.
// Paved-to-paved boundaries are decided on a smoothed, almost unwarped
// coverage (the coverage mip chain), so they are crisp; a kerb with a light
// top, a south-facing face and a gutter/cast shadow is drawn where a kerbed
// carriageway meets other paving. The noise warp stays only where paving
// meets soil or grass. Policy off = the original raw palette (S1, Hub).
//
// Budget: 7 filtered fetches and one material sample per pixel (the legacy
// lip probe and the policy's smoothed coverage share the same two fetches);
// stain, cared lawn, verge and yard-patch samples are conditional. The S2-only
// palette this replaces sampled two materials per sett pixel. (A first version
// resolved four texel-fetched corners per lookup with hashed noise: ~10 ms of
// GPU on an Intel UHD 620 at 1080p against ~1 ms for the old sprite floors.)

uniform sampler2DArray materials : filter_linear_mipmap, repeat_enable;
uniform sampler2D cover_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D cover_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D light_map : filter_linear, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float map_size = 256.0;
uniform float cell_px = 64.0;
uniform float slot_layer[8];
uniform float slot_index[8];
uniform float cared_lawn_layer = 13.0;
uniform float cared_lawn_repeat_px = 320.0;
uniform float slot_repeat_px[8];
uniform vec4 slot_tint[8];
uniform vec4 overgrowth_a = vec4(0.0);
uniform vec4 overgrowth_b = vec4(0.0);
uniform float stain_layer = 5.0;
uniform float stain_repeat_px = 384.0;
uniform vec4 world_tint = vec4(1.0);
uniform float warp_cells = 0.62;
uniform float grain = 0.3;
uniform float overgrowth_bias = 0.08;
uniform float lip_shadow = 0.36;
uniform float seam_shadow = 0.12;
uniform float stain_strength = 0.8;

uniform bool policy_enabled = false;
uniform sampler2D city_setts : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D city_limestone : source_color, filter_linear_mipmap, repeat_enable;
// Per slot: presentation role (DistrictGroundPolicy.ROLE_*).
uniform float slot_role[8];
// Per-slot masks: paved (road, lane, footway, yard), kerbed road, flush lane.
uniform vec4 hard_a = vec4(0.0);
uniform vec4 hard_b = vec4(0.0);
uniform vec4 road_a = vec4(0.0);
uniform vec4 road_b = vec4(0.0);
uniform vec4 lane_a = vec4(0.0);
uniform vec4 lane_b = vec4(0.0);
// Per role: x = source (0 own layer, 1 setts, 2 flags, 3 array layer y),
// z = repeat in world px, w = 1 for paved roles.
uniform vec4 role_sample[8];
// Per role: rgb = quiet mid tone, a = how much of the texture shows through.
uniform vec4 role_mid[8];
// Per role: rgb grade applied to the texture before the mix.
uniform vec4 role_tint[8];
uniform float kerb_strength = 0.0;
uniform float gutter_strength = 0.0;
uniform float joint_strength = 0.0;
uniform float kerb_lod = 1.0;
uniform float kerb_warp_cells = 0.1;
uniform float ao_strength = 0.0;
uniform float lawn_mottle = 0.0;
uniform float paving_variation = 0.0;
uniform float paved_stain_strength = 1.0;
uniform float verge_layer = -1.0;
uniform float verge_strength = 0.0;
uniform float verge_repeat_px = 320.0;
// Darker, cooler standing-water patches on the district surface (puddled yards).
uniform float wet_patches = 0.0;
// A second material in broad noise patches on the district surface (dirt
// among setts, weeds in worn flags): x = array layer (-1 off), y = coverage,
// z = repeat px, w = texture weight; rgb tint in yard_patch_tint.
uniform vec4 yard_patch = vec4(-1.0, 0.0, 384.0, 0.5);
uniform vec4 yard_patch_tint = vec4(1.0);
// Diagnostics only (GroundSplatRenderer reads SA_GROUND_DEBUG_VIEW in debug
// builds): 1 = presentation roles, 2 = occlusion (grey) and care (green).
uniform int debug_view = 0;

// Toward the sun (top right) and the projected shadow direction
// (WorldDepthStyle.SHADOW_DIRECTION), normalised.
const vec2 TO_SUN = vec2(0.8214, -0.5704);
const vec2 SHADOW_DIR = vec2(-0.8214, 0.5704);
// Kerb geometry in cells (64 px): dressed top, south face, gutter, cast shadow.
const float KERB_TOP = 0.16;
const float KERB_FACE = 0.075;
const float GUTTER = 0.20;
const float KERB_CAST = 0.16;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

int argmax8(vec4 a, vec4 b) {
	int slot = 0;
	float best = a.x;
	if (a.y > best) { best = a.y; slot = 1; }
	if (a.z > best) { best = a.z; slot = 2; }
	if (a.w > best) { best = a.w; slot = 3; }
	if (b.x > best) { best = b.x; slot = 4; }
	if (b.y > best) { best = b.y; slot = 5; }
	if (b.z > best) { best = b.z; slot = 6; }
	if (b.w > best) { best = b.w; slot = 7; }
	return slot;
}

float slot_value(vec4 a, vec4 b, int slot) {
	return slot < 4 ? a[slot] : b[slot - 4];
}

void fragment() {
	vec2 p = world_pos / cell_px;
	vec4 n = texture(noise_tex, p * 0.036);
	vec2 wp = p + (n.rg - 0.5) * (2.0 * warp_cells);
	float g = (n.b - 0.5) * grain;
	vec2 uv = wp / map_size;

	// Level 0 explicitly: the coverage now carries a mip chain for the kerb
	// field, and the winner must stay identical to ground_air's mirror.
	vec4 ca = textureLod(cover_a, uv, 0.0);
	vec4 cb = textureLod(cover_b, uv, 0.0);
	// Grain only moves slots that are actually present here.
	vec4 sa = ca + step(0.004, ca) * ((overgrowth_a * 2.0 - 1.0) * g + overgrowth_a * overgrowth_bias);
	vec4 sb = cb + step(0.004, cb) * ((overgrowth_b * 2.0 - 1.0) * g + overgrowth_b * overgrowth_bias);
	int slot = argmax8(sa, sb);

	// Second coverage pair: the legacy lip probe toward the light, or the
	// policy's smoothed, almost unwarped coverage. Derivatives are taken here,
	// in uniform control flow.
	vec4 ka;
	vec4 kb;
	float road_s = 0.0;
	float lane_s = 0.0;
	float og_w = dot(ca, overgrowth_a) + dot(cb, overgrowth_b);
	vec2 road_grad = vec2(0.0);
	vec2 lane_grad = vec2(0.0);
	vec2 og_grad = vec2(0.0);
	float road_fw = 0.0;
	float lane_fw = 0.0;
	vec2 ddx = dFdx(world_pos);
	vec2 ddy = dFdy(world_pos);
	if (policy_enabled) {
		vec2 kp = (p + (n.rg - 0.5) * (2.0 * kerb_warp_cells)) / map_size;
		ka = textureLod(cover_a, kp, kerb_lod);
		kb = textureLod(cover_b, kp, kerb_lod);
		road_s = dot(ka, road_a) + dot(kb, road_b);
		lane_s = dot(ka, lane_a) + dot(kb, lane_b);
		vec2 dp = max(vec2(abs(dFdx(p.x)), abs(dFdy(p.y))), vec2(1e-6));
		road_grad = vec2(dFdx(road_s), dFdy(road_s)) / dp;
		lane_grad = vec2(dFdx(lane_s), dFdy(lane_s)) / dp;
		og_grad = vec2(dFdx(og_w), dFdy(og_w)) / dp;
		road_fw = fwidth(road_s);
		lane_fw = fwidth(lane_s);
	} else {
		vec2 puv = uv + vec2(0.2, -0.3) / map_size;
		ka = textureLod(cover_a, puv, 0.0);
		kb = textureLod(cover_b, puv, 0.0);
	}

	float total = dot(ca, vec4(1.0)) + dot(cb, vec4(1.0));
	if (total < 0.5) {
		COLOR = vec4(0.0);
	} else {
		int out_slot = slot;
		bool paved = false;
		if (policy_enabled) {
			paved = slot_value(hard_a, hard_b, slot) > 0.5;
			if (paved) {
				// Paving meets paving on the smoothed field: crisp, no grain.
				vec4 ma = road_s > 0.5 ? ka * road_a : ka * (hard_a - road_a);
				vec4 mb = road_s > 0.5 ? kb * road_b : kb * (hard_b - road_b);
				if (dot(ma, vec4(1.0)) + dot(mb, vec4(1.0)) > 0.001) {
					out_slot = argmax8(ma, mb);
				}
			}
		}
		int role = policy_enabled ? int(slot_role[out_slot] + 0.5) : 0;
		vec4 rs = role_sample[role];
		vec3 col;
		if (role == 0 || rs.x < 0.5) {
			float rep = slot_repeat_px[out_slot];
			col = textureGrad(materials, vec3(world_pos / rep, slot_layer[out_slot]), ddx / rep, ddy / rep).rgb;
			col *= slot_tint[out_slot].rgb;
		} else if (rs.x < 1.5) {
			col = textureGrad(city_setts, world_pos / rs.z, ddx / rs.z, ddy / rs.z).rgb;
		} else if (rs.x < 2.5) {
			col = textureGrad(city_limestone, world_pos / rs.z, ddx / rs.z, ddy / rs.z).rgb;
		} else {
			col = textureGrad(materials, vec3(world_pos / rs.z, rs.y), ddx / rs.z, ddy / rs.z).rgb;
		}
		if (role > 0) {
			vec4 mid = role_mid[role];
			col = mix(mid.rgb, col * role_tint[role].rgb, mid.a);
			if (rs.w > 0.5) {
				col *= 1.0 + (n.g - 0.5) * paving_variation;
				if (role == 4 && yard_patch.x >= 0.0) {
					// Broad patches (the low warp channel) with a little edge detail.
					float field = n.g * 0.7 + n.a * 0.3;
					float edge = 0.5 - yard_patch.y * 0.25;
					float amount = smoothstep(edge + 0.05, edge - 0.05, field);
					if (amount > 0.001) {
						vec3 pc = textureGrad(materials, vec3(world_pos / yard_patch.z, yard_patch.x), ddx / yard_patch.z, ddy / yard_patch.z).rgb;
						pc = mix(mid.rgb * 0.92, pc * yard_patch_tint.rgb, yard_patch.w);
						col = mix(col, pc, amount);
					}
				}
				if (role == 4 && wet_patches > 0.0) {
					float wet = smoothstep(0.35, 0.29, n.a) * wet_patches;
					col = mix(col, col * vec3(0.76, 0.81, 0.88), wet);
				}
			} else if (role == 5) {
				col *= 1.0 + (n.r - 0.5) * lawn_mottle;
			}
			// Weed / moss / scrub verge where wild ground meets paving.
			if (rs.w < 0.5 && verge_layer >= 0.0) {
				float hard_w = dot(ca, hard_a) + dot(cb, hard_b);
				float verge = smoothstep(0.10, 0.40, hard_w) * verge_strength;
				if (verge > 0.01) {
					vec3 v = textureGrad(materials, vec3(world_pos / verge_repeat_px, verge_layer), ddx / verge_repeat_px, ddy / verge_repeat_px).rgb;
					col = mix(col, mix(role_mid[5].rgb, v * role_tint[5].rgb, 0.6), verge);
				}
			}
		}
		// Kerb terms for paved pixels, worked out before care so a planted bed
		// keeps its stone kerb; they are applied after the lighting below.
		float kerb_top = 0.0;
		float kerb_inner = 0.0;
		float kerb_face = 0.0;
		float kerb_gutter = 0.0;
		float kerb_cast = 0.0;
		float kerb_sun = 0.0;
		float kerb_zone = 0.0;
		float paved_zone = 0.0;
		float lane_joint = 0.0;
		if (policy_enabled && rs.w > 0.5) {
			float hard_s = dot(ka, hard_a) + dot(kb, hard_b);
			// Kerbs run between carriageway and footway/yard; a setts lane or
			// carriage entrance meets the road flush (a dropped kerb).
			paved_zone = smoothstep(0.60, 0.85, hard_s);
			kerb_zone = paved_zone * (1.0 - smoothstep(0.12, 0.35, lane_s));
			float gl = length(road_grad);
			if (kerb_zone > 0.0 && gl > 0.08) {
				// A dressed light top on the non-road side (brighter where the
				// kerb's edge faces the top-right sun), a south-facing face where
				// the 3/4 view shows it, then the gutter and the kerb's cast
				// shadow on the carriageway.
				float dist = (road_s - 0.5) / gl;
				vec2 nrm = road_grad / gl;
				float aa = clamp(road_fw / gl * 0.75, 0.004, 0.08);
				kerb_top = (1.0 - smoothstep(-aa, aa, dist)) * smoothstep(-KERB_TOP - aa, -KERB_TOP + aa, dist);
				kerb_inner = (1.0 - smoothstep(-KERB_TOP - aa, -KERB_TOP + aa, dist)) * smoothstep(-KERB_TOP - 0.08, -KERB_TOP - 0.02, dist);
				float face_w = KERB_FACE * clamp(nrm.y * 1.6, 0.0, 1.0);
				kerb_face = smoothstep(-aa, aa, dist) * (1.0 - smoothstep(face_w - aa, face_w + aa, dist));
				kerb_cast = clamp(dot(nrm, SHADOW_DIR), 0.0, 1.0);
				kerb_sun = clamp(dot(nrm, TO_SUN), 0.0, 1.0);
				float gutter_w = GUTTER + KERB_CAST * kerb_cast;
				kerb_gutter = smoothstep(-aa, aa, dist) * (1.0 - smoothstep(gutter_w * 0.30, gutter_w, dist));
			}
			float ll = length(lane_grad);
			if (paved_zone > 0.0 && ll > 0.08 && road_s < 0.3) {
				// Flush setts lanes and aprons: a narrow joint, no step.
				float ld = (lane_s - 0.5) / ll;
				float aa2 = clamp(lane_fw / ll * 0.75, 0.004, 0.08);
				lane_joint = 1.0 - smoothstep(0.02, 0.05 + aa2, abs(ld));
			}
		}

		vec4 light = texture(light_map, p / map_size);
		if (policy_enabled && light.b > 0.001 && (role == 4 || role == 5 || role == 6)) {
			vec3 lawn = textureGrad(materials, vec3(world_pos / cared_lawn_repeat_px, cared_lawn_layer), ddx / cared_lawn_repeat_px, ddy / cared_lawn_repeat_px).rgb;
			lawn = mix(vec3(0.38, 0.43, 0.29), lawn * vec3(1.10, 1.12, 1.0), 0.78);
			lawn *= 1.0 + (n.r - 0.5) * lawn_mottle;
			float amount = light.b;
			if (role != 5) {
				// On stone or bare earth a tended pocket is a planted plot with a
				// definite edge: a light dressed-stone edging on the paving side and
				// a thin shaded soil line inside it, not a translucent wash.
				float e = light.b + (n.a - 0.5) * 0.10;
				amount = smoothstep(0.47, 0.51, e);
				float edging = smoothstep(0.39, 0.42, e) * (1.0 - smoothstep(0.46, 0.49, e));
				float soil = smoothstep(0.49, 0.52, e) * (1.0 - smoothstep(0.54, 0.60, e));
				col *= 1.0 + edging * 0.16;
				lawn *= 1.0 - max(soil, kerb_inner) * 0.28;
				// A bed against a carriageway keeps its kerb stones.
				amount *= 1.0 - kerb_top * kerb_zone;
			}
			col = mix(col, lawn, amount);
		}

		col *= light.r * 2.0;

		if (light.g > 0.01) {
			float cut = smoothstep(0.4, 0.62, light.g * 0.9 + (n.a - 0.5) * 0.9);
			vec3 stain = textureGrad(materials, vec3(world_pos / stain_repeat_px, stain_layer), ddx / stain_repeat_px, ddy / stain_repeat_px).rgb;
			float strength = stain_strength * ((policy_enabled && paved) ? paved_stain_strength : 1.0);
			col = mix(col, stain * light.r * 2.0, cut * strength);
		}

		if (!policy_enabled) {
			bool own_overgrowth = slot < 4 ? overgrowth_a[slot] > 0.5 : overgrowth_b[slot - 4] > 0.5;
			if (!own_overgrowth) {
				float own = slot_value(ka, kb, slot);
				float grassy = dot(ka, overgrowth_a) + dot(kb, overgrowth_b);
				float shade = smoothstep(0.55, 0.3, own - g);
				col *= 1.0 - shade * mix(seam_shadow, lip_shadow, step(0.3, grassy));
			}
			col *= world_tint.rgb;
		} else {
			if (rs.w > 0.5) {
				col *= 1.0 + kerb_top * (0.13 + 0.12 * kerb_sun) * kerb_strength * kerb_zone;
				col *= 1.0 - kerb_face * 0.40 * kerb_strength * kerb_zone;
				col *= 1.0 - kerb_gutter * (0.10 + 0.26 * kerb_cast) * gutter_strength * kerb_zone;
				col *= 1.0 - lane_joint * 0.22 * joint_strength * paved_zone;
				// Grass up-right of paving casts a short lip shadow on it.
				float ol = length(og_grad);
				if (ol > 0.08) {
					float od = (og_w - 0.5) / ol;
					float toward = clamp(dot(og_grad / ol, TO_SUN), 0.0, 1.0);
					float lip = smoothstep(-0.32, -0.04, od) * (1.0 - smoothstep(-0.04, 0.10, od));
					col *= 1.0 - lip * toward * lip_shadow;
				}
			} else {
				// The district wash tints only wild and soil ground: paving has its
				// own policy grade, and the warm washes would drift stone to beige.
				col *= world_tint.rgb;
			}
			col *= mix(1.0, light.a, ao_strength);
		}
		if (debug_view == 1) {
			vec3 role_colours[7] = vec3[7](vec3(1.0, 0.0, 1.0), vec3(0.15, 0.2, 0.55), vec3(0.2, 0.75, 0.8), vec3(0.95, 0.85, 0.3), vec3(0.75, 0.75, 0.75), vec3(0.2, 0.6, 0.2), vec3(0.5, 0.33, 0.2));
			col = mix(role_colours[clamp(role, 0, 6)], col, 0.35);
		} else if (debug_view == 2) {
			col = mix(vec3(light.a), vec3(0.1, 0.9, 0.2), light.b);
		}
		COLOR = vec4(col, 1.0);
	}
}
