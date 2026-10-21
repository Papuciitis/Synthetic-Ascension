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
// stain_layer through a noise cut, never as a rectangle), B = household care
// (a tended wash on lawn and bare earth; on the district paving a planted bed,
// which CityGroundCare keeps to a strip against the house wall), A = ground
// openness (1 = open sky, lower = occluded by nearby walls/props; the pass is
// continuous across chunk lines).
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
// lip probe and the policy's smoothed coverage are the same two fetches);
// stain, cared lawn, verge and yard-patch samples are conditional.
// Register pressure matters as much as fetches on the target Intel UHD 620
// (Gen9): a first policy version carried three coverage gradients and two
// fwidths through the whole fragment, failed SIMD16 register allocation and
// cost ~+4 ms of GPU at 1080p. Everything that needs the second coverage pair
// or a screen derivative is therefore settled at the top, in uniform control
// flow, and reduced at once to a few scalars (the paved winner and one
// multiplicative relief term). (An earlier ground resolved four texel-fetched
// corners per lookup with hashed noise: ~10 ms against ~1 ms for the old
// sprite floors.)

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
// z = repeat px, w = texture weight; rgb tint in yard_patch_tint, the
// patch's own mid tone in yard_patch_mid (GroundSplatRenderer defaults it
// to the yard's mid, a shade darker).
uniform vec4 yard_patch = vec4(-1.0, 0.0, 384.0, 0.5);
uniform vec4 yard_patch_tint = vec4(1.0);
uniform vec4 yard_patch_mid = vec4(0.5, 0.5, 0.5, 1.0);
// Diagnostics only (GroundSplatRenderer reads SA_GROUND_DEBUG_VIEW in debug
// builds): 1 = presentation roles, 2 = occlusion (grey) and care (green).
uniform int debug_view = 0;

// Toward the sun (top right); the projected shadow direction
// (WorldDepthStyle.SHADOW_DIRECTION) is its opposite.
const vec2 TO_SUN = vec2(0.8214, -0.5704);
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

// The policy's relief on a paved pixel, as one multiplier: where the kerbed
// carriageway meets other paving a dressed light top on the non-road side
// (brighter where the kerb's edge faces the top-right sun), a south-facing
// face where the 3/4 view shows it, then the gutter and the kerb's cast
// shadow on the carriageway; a narrow joint where a flush setts lane meets
// flags (a dropped kerb, no step); and a short lip shadow below grass that
// lies up-right of the paving. Inputs are smoothed coverages and their screen
// derivatives (taken by the caller in uniform control flow); dp = cells per
// pixel along x and y.
float paving_relief(float road_s, float lane_s, float hard_s, vec2 road_d, vec2 lane_d, float og_w, vec2 og_d, vec2 dp) {
	float relief = 1.0;
	float paved_zone = smoothstep(0.60, 0.85, hard_s);
	float kerb_zone = paved_zone * (1.0 - smoothstep(0.12, 0.35, lane_s));
	vec2 road_grad = road_d / dp;
	float gl = length(road_grad);
	if (kerb_zone > 0.0 && gl > 0.08) {
		float dist = (road_s - 0.5) / gl;
		vec2 nrm = road_grad / gl;
		float aa = clamp((abs(road_d.x) + abs(road_d.y)) / gl * 0.75, 0.004, 0.08);
		float road_side = smoothstep(-aa, aa, dist);
		float top = (1.0 - road_side) * smoothstep(-KERB_TOP - aa, -KERB_TOP + aa, dist);
		float face_w = KERB_FACE * clamp(nrm.y * 1.6, 0.0, 1.0);
		float face = road_side * (1.0 - smoothstep(face_w - aa, face_w + aa, dist));
		float sun = dot(nrm, TO_SUN);
		float cast = clamp(-sun, 0.0, 1.0);
		float gutter_w = GUTTER + KERB_CAST * cast;
		float gutter = road_side * (1.0 - smoothstep(gutter_w * 0.30, gutter_w, dist));
		relief *= 1.0 + top * (0.13 + 0.12 * clamp(sun, 0.0, 1.0)) * kerb_strength * kerb_zone;
		relief *= 1.0 - face * 0.40 * kerb_strength * kerb_zone;
		relief *= 1.0 - gutter * (0.10 + 0.26 * cast) * gutter_strength * kerb_zone;
	}
	vec2 lane_grad = lane_d / dp;
	float ll = length(lane_grad);
	if (paved_zone > 0.0 && ll > 0.08 && road_s < 0.3) {
		float ld = (lane_s - 0.5) / ll;
		float aa2 = clamp((abs(lane_d.x) + abs(lane_d.y)) / ll * 0.75, 0.004, 0.08);
		float joint = 1.0 - smoothstep(0.02, 0.05 + aa2, abs(ld));
		relief *= 1.0 - joint * 0.22 * joint_strength * paved_zone;
	}
	vec2 og_grad = og_d / dp;
	float ol = length(og_grad);
	if (ol > 0.08) {
		float od = (og_w - 0.5) / ol;
		float toward = clamp(dot(og_grad / ol, TO_SUN), 0.0, 1.0);
		float lip = smoothstep(-0.32, -0.04, od) * (1.0 - smoothstep(-0.04, 0.10, od));
		relief *= 1.0 - lip * toward * lip_shadow;
	}
	return relief;
}

void fragment() {
	vec2 p = world_pos / cell_px;
	vec4 n = texture(noise_tex, p * 0.036);
	vec2 wp = p + (n.rg - 0.5) * (2.0 * warp_cells);
	float g = (n.b - 0.5) * grain;
	vec2 uv = wp / map_size;
	vec2 ddx = dFdx(world_pos);
	vec2 ddy = dFdy(world_pos);

	// Level 0 explicitly: the coverage carries a mip chain for the kerb
	// field, and the winner must stay identical to ground_air's mirror.
	vec4 ca = textureLod(cover_a, uv, 0.0);
	vec4 cb = textureLod(cover_b, uv, 0.0);
	float total = dot(ca, vec4(1.0)) + dot(cb, vec4(1.0));
	// Grain only moves slots that are actually present here.
	vec4 sa = ca + step(0.004, ca) * ((overgrowth_a * 2.0 - 1.0) * g + overgrowth_a * overgrowth_bias);
	vec4 sb = cb + step(0.004, cb) * ((overgrowth_b * 2.0 - 1.0) * g + overgrowth_b * overgrowth_bias);
	int slot = argmax8(sa, sb);

	// The second coverage pair (the policy's smoothed, almost unwarped field,
	// or the legacy lip probe toward the light) and every derivative are used
	// here and nowhere else.
	int out_slot = slot;
	bool paved = false;
	float relief = 1.0;
	float hard_w = 0.0;
	if (policy_enabled) {
		paved = slot_value(hard_a, hard_b, slot) > 0.5;
		hard_w = dot(ca, hard_a) + dot(cb, hard_b);
		float og_w = dot(ca, overgrowth_a) + dot(cb, overgrowth_b);
		vec2 kp = (p + (n.rg - 0.5) * (2.0 * kerb_warp_cells)) / map_size;
		vec4 ka = textureLod(cover_a, kp, kerb_lod);
		vec4 kb = textureLod(cover_b, kp, kerb_lod);
		float road_s = dot(ka, road_a) + dot(kb, road_b);
		float lane_s = dot(ka, lane_a) + dot(kb, lane_b);
		float hard_s = dot(ka, hard_a) + dot(kb, hard_b);
		if (paved) {
			// Paving meets paving on the smoothed field: crisp, no grain.
			vec4 ma = road_s > 0.5 ? ka * road_a : ka * (hard_a - road_a);
			vec4 mb = road_s > 0.5 ? kb * road_b : kb * (hard_b - road_b);
			if (dot(ma, vec4(1.0)) + dot(mb, vec4(1.0)) > 0.001) {
				out_slot = argmax8(ma, mb);
			}
		}
		vec2 road_d = vec2(dFdx(road_s), dFdy(road_s));
		vec2 lane_d = vec2(dFdx(lane_s), dFdy(lane_s));
		vec2 og_d = vec2(dFdx(og_w), dFdy(og_w));
		if (paved) {
			vec2 dp = max(abs(vec2(ddx.x, ddy.y)) / cell_px, vec2(1e-6));
			relief = paving_relief(road_s, lane_s, hard_s, road_d, lane_d, og_w, og_d, dp);
		}
	} else if (slot_value(overgrowth_a, overgrowth_b, slot) < 0.5) {
		vec2 puv = uv + vec2(0.2, -0.3) / map_size;
		vec4 pa = textureLod(cover_a, puv, 0.0);
		vec4 pb = textureLod(cover_b, puv, 0.0);
		float grassy = dot(pa, overgrowth_a) + dot(pb, overgrowth_b);
		float shade = smoothstep(0.55, 0.3, slot_value(pa, pb, slot) - g);
		relief = 1.0 - shade * mix(seam_shadow, lip_shadow, step(0.3, grassy));
	}

	if (total < 0.5) {
		COLOR = vec4(0.0);
	} else {
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
		vec4 light = texture(light_map, p / map_size);
		if (role > 0) {
			vec4 mid = role_mid[role];
			col = mix(mid.rgb, col * role_tint[role].rgb, mid.a);
			if (paved) {
				col *= 1.0 + (n.g - 0.5) * paving_variation;
				if (role == 4) {
					if (yard_patch.x >= 0.0) {
						// Broad patches (the low warp channel) with a little edge detail.
						float field = n.g * 0.7 + n.a * 0.3;
						float edge = 0.5 - yard_patch.y * 0.25;
						float amount = smoothstep(edge + 0.05, edge - 0.05, field);
						if (amount > 0.001) {
							vec3 pc = textureGrad(materials, vec3(world_pos / yard_patch.z, yard_patch.x), ddx / yard_patch.z, ddy / yard_patch.z).rgb;
							pc = mix(yard_patch_mid.rgb, pc * yard_patch_tint.rgb, yard_patch.w);
							col = mix(col, pc, amount);
						}
					}
					if (wet_patches > 0.0) {
						float wet = smoothstep(0.35, 0.29, n.a) * wet_patches;
						col = mix(col, col * vec3(0.76, 0.81, 0.88), wet);
					}
					if (light.b > 0.001) {
						// A tended bed on the district paving. CityGroundCare lays
						// it as a strip of cells against the house wall; here it is
						// cut exactly on those cells (no soft lozenge), planted
						// inside a margin of dug soil that meets the stone flush,
						// without a pale rim.
						ivec2 cell = ivec2(mod(floor(p), map_size));
						int last = int(map_size) - 1;
						if (texelFetch(light_map, cell, 0).b > 0.5) {
							vec2 f = fract(p);
							float side = 1.0;
							if (texelFetch(light_map, ivec2(cell.x == 0 ? last : cell.x - 1, cell.y), 0).b <= 0.5) { side = min(side, f.x); }
							if (texelFetch(light_map, ivec2(cell.x == last ? 0 : cell.x + 1, cell.y), 0).b <= 0.5) { side = min(side, 1.0 - f.x); }
							if (texelFetch(light_map, ivec2(cell.x, cell.y == 0 ? last : cell.y - 1), 0).b <= 0.5) { side = min(side, f.y); }
							if (texelFetch(light_map, ivec2(cell.x, cell.y == last ? 0 : cell.y + 1), 0).b <= 0.5) { side = min(side, 1.0 - f.y); }
							vec3 plant = textureGrad(materials, vec3(world_pos / cared_lawn_repeat_px, cared_lawn_layer), ddx / cared_lawn_repeat_px, ddy / cared_lawn_repeat_px).rgb;
							plant = mix(vec3(0.38, 0.45, 0.28), plant * vec3(1.14, 1.20, 1.02), 0.85);
							vec3 soil = role_mid[6].rgb * (0.88 + (n.b - 0.5) * 0.10);
							col = mix(soil, plant, smoothstep(0.11, 0.18, side + (n.a - 0.5) * 0.05));
						}
					}
				}
			} else {
				if (role == 5) {
					col *= 1.0 + (n.r - 0.5) * lawn_mottle;
				}
				// Weed / moss / scrub verge where wild ground meets paving.
				if (verge_layer >= 0.0) {
					float verge = smoothstep(0.10, 0.40, hard_w) * verge_strength;
					if (verge > 0.01) {
						vec3 v = textureGrad(materials, vec3(world_pos / verge_repeat_px, verge_layer), ddx / verge_repeat_px, ddy / verge_repeat_px).rgb;
						col = mix(col, mix(role_mid[5].rgb, v * role_tint[5].rgb, 0.6), verge);
					}
				}
				// Household care on lawn or bare earth: a tended wash over the
				// household's own ground.
				if (light.b > 0.001) {
					vec3 lawn = textureGrad(materials, vec3(world_pos / cared_lawn_repeat_px, cared_lawn_layer), ddx / cared_lawn_repeat_px, ddy / cared_lawn_repeat_px).rgb;
					lawn = mix(vec3(0.38, 0.43, 0.29), lawn * vec3(1.10, 1.12, 1.0), 0.78);
					lawn *= 1.0 + (n.r - 0.5) * lawn_mottle;
					col = mix(col, lawn, light.b);
				}
			}
		}

		col *= light.r * 2.0;

		if (light.g > 0.01) {
			float cut = smoothstep(0.4, 0.62, light.g * 0.9 + (n.a - 0.5) * 0.9);
			vec3 stain = textureGrad(materials, vec3(world_pos / stain_repeat_px, stain_layer), ddx / stain_repeat_px, ddy / stain_repeat_px).rgb;
			col = mix(col, stain * light.r * 2.0, cut * stain_strength * (paved ? paved_stain_strength : 1.0));
		}

		if (policy_enabled) {
			// The district wash tints only wild and soil ground: paving has its
			// own policy grade, and the warm washes would drift stone to beige.
			col *= paved ? vec3(relief) : world_tint.rgb;
			col *= mix(1.0, light.a, ao_strength);
		} else {
			col *= relief * world_tint.rgb;
		}
		if (debug_view == 1) {
			// The calibration tooling reads these role colours back: keep them.
			vec3 rc = vec3(1.0, 0.0, 1.0);
			if (role == 1) { rc = vec3(0.15, 0.2, 0.55); }
			else if (role == 2) { rc = vec3(0.2, 0.75, 0.8); }
			else if (role == 3) { rc = vec3(0.95, 0.85, 0.3); }
			else if (role == 4) { rc = vec3(0.75, 0.75, 0.75); }
			else if (role == 5) { rc = vec3(0.2, 0.6, 0.2); }
			else if (role >= 6) { rc = vec3(0.5, 0.33, 0.2); }
			col = mix(rc, col, 0.35);
		} else if (debug_view == 2) {
			col = mix(vec3(light.a), vec3(0.1, 0.9, 0.2), light.b);
		}
		COLOR = vec4(col, 1.0);
	}
}
