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
// stain_layer through a noise cut, never as a rectangle), B = household care.
//
// Budget: 7 filtered fetches and one or two material samples per pixel. (A
// first version resolved four texel-fetched corners per lookup with hashed
// noise: ~10 ms of GPU on an Intel UHD 620 at 1080p against ~1 ms for the old
// sprite floors.)

uniform sampler2DArray materials : filter_linear_mipmap, repeat_enable;
uniform sampler2D cover_a : filter_linear, repeat_enable;
uniform sampler2D cover_b : filter_linear, repeat_enable;
uniform sampler2D light_map : filter_linear, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float map_size = 256.0;
uniform float cell_px = 64.0;
uniform float slot_layer[8];
uniform float slot_index[8];
uniform float cared_lawn_layer = 13.0;
uniform float cared_lawn_repeat_px = 320.0;
uniform bool city_streetscape = false;
uniform sampler2D city_setts : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D city_limestone : source_color, filter_linear_mipmap, repeat_enable;
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

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos / cell_px;
	vec4 n = texture(noise_tex, p * 0.036);
	vec2 wp = p + (n.rg - 0.5) * (2.0 * warp_cells);
	float g = (n.b - 0.5) * grain;
	vec2 uv = wp / map_size;

	vec4 ca = texture(cover_a, uv);
	vec4 cb = texture(cover_b, uv);
	// Grain only moves slots that are actually present here.
	vec4 sa = ca + step(0.004, ca) * ((overgrowth_a * 2.0 - 1.0) * g + overgrowth_a * overgrowth_bias);
	vec4 sb = cb + step(0.004, cb) * ((overgrowth_b * 2.0 - 1.0) * g + overgrowth_b * overgrowth_bias);

	int slot = 0;
	float best = sa.x;
	if (sa.y > best) { best = sa.y; slot = 1; }
	if (sa.z > best) { best = sa.z; slot = 2; }
	if (sa.w > best) { best = sa.w; slot = 3; }
	if (sb.x > best) { best = sb.x; slot = 4; }
	if (sb.y > best) { best = sb.y; slot = 5; }
	if (sb.z > best) { best = sb.z; slot = 6; }
	if (sb.w > best) { best = sb.w; slot = 7; }

	float total = dot(ca, vec4(1.0)) + dot(cb, vec4(1.0));
	if (total < 0.5) {
		COLOR = vec4(0.0);
	} else {
		vec2 ddx = dFdx(world_pos);
		vec2 ddy = dFdy(world_pos);
		float rep = slot_repeat_px[slot];
		vec3 col = textureGrad(materials, vec3(world_pos / rep, slot_layer[slot]), ddx / rep, ddy / rep).rgb;
		col *= slot_tint[slot].rgb;
		vec4 light = texture(light_map, p / map_size);
		if (city_streetscape) {
			float index = slot_index[slot];
			if (index == 4.0 || index == 7.0 || index == 8.0 || index == 9.0) {
				vec3 setts = textureGrad(city_setts, world_pos / 272.0, ddx / 272.0, ddy / 272.0).rgb;
				col = mix(vec3(0.49,0.52,0.51), setts * vec3(0.87,0.93,0.96), 0.30);
				// Access corridors and road arms share one surface at junctions.
				// Dirt retains its own real layers (1/5), not a raised-looking
				// tinted patch every time two road stamps meet.
			} else if (index == 2.0 || index == 3.0 || index == 6.0) {
				vec3 limestone = textureGrad(city_limestone, world_pos / 384.0, ddx / 384.0, ddy / 384.0).rgb;
				col = mix(vec3(0.57,0.59,0.55),limestone,0.40);
			} else if (index == 0.0 || index >= 10.0) {
				col = mix(vec3(0.31,0.37,0.28),col * vec3(1.12,1.16,1.05),0.48);
				if (light.b > 0.001) {
					vec3 lawn = textureGrad(materials,vec3(world_pos / cared_lawn_repeat_px,cared_lawn_layer),ddx / cared_lawn_repeat_px,ddy / cared_lawn_repeat_px).rgb;
					lawn = mix(vec3(0.36,0.39,0.28),lawn * vec3(1.04,1.04,0.99),0.80);
					col = mix(col,lawn,light.b);
				}
			} else if (index == 1.0 || index == 5.0) {
				col = mix(vec3(0.38,0.37,0.30),col,0.42);
			}
		}

		col *= light.r * 2.0;

		if (light.g > 0.01) {
			float cut = smoothstep(0.4, 0.62, light.g * 0.9 + (n.a - 0.5) * 0.9);
			vec3 stain = textureGrad(materials, vec3(world_pos / stain_repeat_px, stain_layer), ddx / stain_repeat_px, ddy / stain_repeat_px).rgb;
			col = mix(col, stain * light.r * 2.0, cut * stain_strength);
		}

		bool own_overgrowth = slot < 4 ? overgrowth_a[slot] > 0.5 : overgrowth_b[slot - 4] > 0.5;
		if (!own_overgrowth) {
			vec2 puv = uv + vec2(0.2, -0.3) / map_size;
			vec4 pa = texture(cover_a, puv);
			vec4 pb = texture(cover_b, puv);
			float own = slot < 4 ? pa[slot] : pb[slot - 4];
			float grassy = dot(pa, overgrowth_a) + dot(pb, overgrowth_b);
			float shade = smoothstep(0.55, 0.3, own - g);
			col *= 1.0 - shade * mix(seam_shadow, lip_shadow, step(0.3, grassy));
		}
		COLOR = vec4(col * world_tint.rgb, 1.0);
	}
}
