shader_type canvas_item;
// The front-end painting, brought to life without repainting it:
// - B mask: cloud the painting may slide (two-phase flow, never near a castle)
// - R mask: open air that drifting cloud shadow and moonlit wisps may cross
// - G mask: the valley mist band
// - lights: flickering pools over the painted flames and glyphs
// - beam: the castle's column pulses
// Moods only move uniforms; ArcaneBackdrop eases them. t_cloud is integrated
// on the CPU so a mood's cloud speed never makes the sky jump.

uniform sampler2D masks : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

uniform float t_cloud = 0.0;
uniform float aspect = 1.7778;
uniform float exposure = 1.0;
uniform vec4 sky_tint : source_color = vec4(1.0);
uniform vec4 fog_color : source_color = vec4(0.6, 0.65, 0.78, 1.0);
uniform float cloud_amount = 1.0;
uniform float mist_amount = 1.0;
uniform float warp_amount = 1.0;
uniform float warm_gain = 1.0;
uniform float cool_gain = 1.0;

// Castle beam: x, top y, bottom y (UV), half-width in UV of height.
uniform vec4 beam = vec4(-1.0, 0.0, 0.0, 0.01);
uniform float beam_gain = 1.0;
// The beam's pulse, computed once per frame by ArcaneBackdrop.
uniform float beam_pulse = 1.0;

// Window the stars may twinkle in (UV rect x0, y0, x1, y1).
uniform vec4 star_rect = vec4(0.0, 0.0, 0.0, 0.0);

uniform int light_count = 0;
// xy = UV centre, z = radius (fraction of height), w = flicker seed
uniform vec4 light_pos[10];
// rgb = colour, a = strength (negative = cool light, scaled by cool_gain)
uniform vec4 light_col[10];
// Each light's flicker x strength x mood gain, computed once per frame on the
// CPU (it depends only on time and the light's seed, never on the pixel).
uniform float light_amp[10];

varying vec4 v_modulate;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 uv = UV;
	vec3 m = texture(masks, uv).rgb;
	vec3 col;
	float warp = m.b * warp_amount;
	if (warp > 0.004) {
		vec2 flow = vec2(0.0065, 0.0009);
		float ph0 = fract(t_cloud * 0.045);
		float ph1 = fract(t_cloud * 0.045 + 0.5);
		float w1 = abs(ph0 * 2.0 - 1.0);
		vec2 jitter = (texture(noise_tex, uv * vec2(1.6, 1.1) + vec2(t_cloud * 0.004, 0.0)).rg - 0.5) * 0.003;
		vec3 c0 = texture(TEXTURE, uv - (flow * ph0 + jitter) * warp).rgb;
		vec3 c1 = texture(TEXTURE, uv - (flow * ph1 + jitter) * warp).rgb;
		col = mix(c0, c1, w1);
	} else {
		col = texture(TEXTURE, uv).rgb;
	}

	vec2 auv = vec2(uv.x * aspect, uv.y);
	float air = m.r * cloud_amount;
	if (air > 0.003) {
		float n1 = texture(noise_tex, auv * 0.42 + vec2(t_cloud * 0.010, t_cloud * 0.0012)).r;
		float n2 = texture(noise_tex, auv * 1.15 + vec2(t_cloud * 0.019, -t_cloud * 0.002)).g;
		float body = n1 * 0.62 + n2 * 0.38;
		float shade = smoothstep(0.52, 0.30, body);
		float wisp = smoothstep(0.55, 0.80, body);
		col *= 1.0 - shade * air * 0.24;
		col += fog_color.rgb * wisp * air * 0.12;
	}

	float mist = m.g * mist_amount;
	if (mist > 0.003) {
		float f1 = texture(noise_tex, vec2(auv.x * 0.7 + t_cloud * 0.016, uv.y * 2.4)).b;
		float f2 = texture(noise_tex, vec2(auv.x * 1.5 - t_cloud * 0.011, uv.y * 3.4 + 0.37)).r;
		float fog = smoothstep(0.36, 0.78, f1 * 0.58 + f2 * 0.42);
		col = mix(col, fog_color.rgb * 0.92, clamp(fog * mist * 0.34, 0.0, 0.6));
	}

	float open_air = max(m.r, m.g);
	col = mix(col, col * sky_tint.rgb, open_air);

	if (star_rect.z > star_rect.x && uv.x > star_rect.x && uv.x < star_rect.z && uv.y > star_rect.y && uv.y < star_rect.w) {
		vec2 grid = auv * 150.0;
		vec2 cell = floor(grid);
		float h = hash(cell);
		if (h > 0.982) {
			vec2 at = (vec2(hash(cell + 1.7), hash(cell + 9.2)) - 0.5) * 0.6;
			float d = length(fract(grid) - 0.5 - at);
			float twinkle = 0.5 + 0.5 * sin(TIME * (1.2 + h * 3.0) + h * 80.0);
			float dark = 1.0 - smoothstep(0.10, 0.26, dot(col, vec3(0.3, 0.59, 0.11)));
			col += vec3(0.82, 0.86, 1.0) * smoothstep(0.16, 0.0, d) * twinkle * twinkle * dark * 0.75;
		}
	}

	if (beam.x >= 0.0) {
		float pulse = beam_pulse;
		float bx = (uv.x - beam.x) * aspect;
		float along = smoothstep(beam.y - 0.02, beam.y + 0.05, uv.y) * smoothstep(beam.z + 0.03, beam.z - 0.06, uv.y);
		float column = exp(-bx * bx / (beam.w * beam.w)) * along;
		float halo = exp(-bx * bx / (beam.w * beam.w * 16.0)) * along;
		float blue = smoothstep(0.12, 0.35, col.b - col.r) * smoothstep(0.42, 0.85, col.b);
		float gain = beam_gain * cool_gain;
		col += col * blue * (gain * pulse - 1.0) * 0.55;
		col += vec3(0.35, 0.55, 1.0) * (column * 0.20 + halo * 0.05) * gain * pulse;
	}

	for (int i = 0; i < light_count; i++) {
		vec2 d = (uv - light_pos[i].xy) * vec2(aspect, 1.0);
		float r = light_pos[i].z;
		col += light_col[i].rgb * light_amp[i] * exp(-dot(d, d) / (r * r));
	}

	COLOR = vec4(col * exposure, 1.0) * v_modulate;
}
