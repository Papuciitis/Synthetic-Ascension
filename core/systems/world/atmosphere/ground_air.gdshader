shader_type canvas_item;
render_mode blend_mix;

// Low air is an outdoor ground receiver below actors and building fronts.
// It cannot brighten a roof, an enemy, loot, or an open room's floor.
uniform sampler2D outdoor_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_extent = vec2(1.0);
uniform float mist_opacity = 0.0;
uniform vec4 mist_tint : source_color = vec4(0.70, 0.75, 0.71, 1.0);
uniform vec2 wind = vec2(0.0);
uniform float weather_time = 0.0;
uniform bool weather_motion_enabled = true;
uniform float frozen_weather_time = 0.0;
// Bind the actual GroundSplat maps/slot identities. Absence is explicitly dry.
uniform bool ground_receiver_enabled = false;
uniform sampler2D receiver_cover_a : filter_linear, repeat_enable;
uniform sampler2D receiver_cover_b : filter_linear, repeat_enable;
uniform sampler2D receiver_light_map : filter_linear, repeat_enable;
uniform sampler2D receiver_noise_tex : filter_linear, repeat_enable;
uniform float receiver_cell_px = 64.0;
uniform float receiver_map_size = 256.0;
uniform float receiver_warp_cells = 0.62;
uniform float receiver_grain = 0.3;
uniform float receiver_overgrowth_bias = 0.08;
uniform float receiver_stain_strength = 0.8;
uniform vec4 receiver_overgrowth_a = vec4(0.0);
uniform vec4 receiver_overgrowth_b = vec4(0.0);
uniform vec4 receiver_damp_a = vec4(0.0);
uniform vec4 receiver_damp_b = vec4(0.0);
uniform bool receiver_damp_stain = false;
// District ground policy mirror (ground_splat.gdshader): paved winners are
// refined only among paved slots (never damp), and stains on paving draw at
// the policy's reduced strength.
uniform bool receiver_policy_enabled = false;
uniform vec4 receiver_hard_a = vec4(0.0);
uniform vec4 receiver_hard_b = vec4(0.0);
uniform float receiver_paved_stain_strength = 1.0;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float ground_dampness(vec2 world) {
	if (!ground_receiver_enabled) { return 0.0; }
	// Match the host ground's warped material winner and stain cut, so the
	// air edge follows rendered wet/moss geometry rather than a grid overlay.
	vec2 p = world / receiver_cell_px;
	vec4 n = texture(receiver_noise_tex, p * 0.036);
	vec2 wp = p + (n.rg - 0.5) * (2.0 * receiver_warp_cells);
	float grain = (n.b - 0.5) * receiver_grain;
	vec4 ca = texture(receiver_cover_a, wp / receiver_map_size);
	vec4 cb = texture(receiver_cover_b, wp / receiver_map_size);
	vec4 sa = ca + step(0.004, ca) * ((receiver_overgrowth_a * 2.0 - 1.0) * grain + receiver_overgrowth_a * receiver_overgrowth_bias);
	vec4 sb = cb + step(0.004, cb) * ((receiver_overgrowth_b * 2.0 - 1.0) * grain + receiver_overgrowth_b * receiver_overgrowth_bias);
	float best = sa.x;
	float damp = receiver_damp_a.x;
	float paved = receiver_hard_a.x;
	for (int slot = 1; slot < 4; slot++) {
		if (sa[slot] > best) { best = sa[slot]; damp = receiver_damp_a[slot]; paved = receiver_hard_a[slot]; }
	}
	for (int slot = 0; slot < 4; slot++) {
		if (sb[slot] > best) { best = sb[slot]; damp = receiver_damp_b[slot]; paved = receiver_hard_b[slot]; }
	}
	if (dot(ca, vec4(1.0)) + dot(cb, vec4(1.0)) < 0.5) { return 0.0; }
	// A paved winner may be re-chosen among paved slots by the host's crisp
	// edge pass; paved slots are never damp, so dampness is already final.
	bool on_paving = receiver_policy_enabled && paved > 0.5;
	if (on_paving) { damp = 0.0; }
	if (receiver_damp_stain) {
		float stain = texture(receiver_light_map, p / receiver_map_size).g;
		// Match the host's local stain guard. A noise peak on clean G0 ground
		// must not invent moisture where the ground shader draws no stain.
		if (stain > 0.01) {
			float cut = smoothstep(0.4, 0.62, stain * 0.9 + (n.a - 0.5) * 0.9);
			damp = max(damp, cut * receiver_stain_strength * (on_paving ? receiver_paved_stain_strength : 1.0));
		}
	}
	return clamp(damp, 0.0, 1.0);
}

void fragment() {
	float phase = weather_motion_enabled ? weather_time : frozen_weather_time;
	vec2 p = world_position - wind * phase * 5.0;
	float field = 0.56 + 0.22 * sin(p.x / 240.0 + sin(p.y / 380.0)) + 0.16 * sin(p.y / 170.0);
	float outdoor = texture(outdoor_mask, (world_position - mask_origin) / max(mask_extent, vec2(1.0))).r;
	COLOR = vec4(mist_tint.rgb, clamp(field, 0.0, 1.0) * clamp(mist_opacity, 0.0, 0.06) * outdoor * ground_dampness(world_position));
}
