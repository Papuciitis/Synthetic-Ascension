shader_type canvas_item;
// The title logo. On entry it is drawn on: title_reveal.png says when each
// pixel is reached (16-bit time in R/G, class in B: 1 letters, 0.5 gold
// ornament, 0 halo), so the ring and rules engrave first, then the words
// line by line, each letter traced along its strokes, the blade falls through
// the O and the stars come last. A hot ember tip leads the ink. Once drawn, a
// slow light sweep crosses the weathered letters every few seconds.

uniform sampler2D reveal_map : filter_nearest;
uniform float draw : hint_range(0.0, 1.1) = 1.1;
uniform float sweep_period = 7.5;
uniform float sweep_strength = 0.32;
uniform float ember = 0.0;

const float EDGE = 0.012;   // how soft the ink's leading edge is
const float TIP = 0.02;     // how long the ember tip glows behind the front
const float HALO_FADE = 0.07;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 r = texture(reveal_map, UV).rgb;
	float when = (r.r * 255.0 * 256.0 + r.g * 255.0) / 65535.0;
	float drawn = draw >= 1.05 ? 1.0 : 0.0;
	if (drawn < 1.0) {
		float behind = draw - when;
		float halo = 1.0 - step(0.25, r.b);
		float ink = mix(clamp(behind / EDGE, 0.0, 1.0), clamp(behind / HALO_FADE, 0.0, 1.0), halo);
		// The pen tip: hot gold on the letters, brighter ember on the gold.
		float tip = exp(-pow(behind / TIP, 2.0)) * step(-EDGE, behind) * (1.0 - halo);
		vec3 hot = mix(vec3(1.0, 0.62, 0.26), vec3(1.0, 0.86, 0.6), step(0.75, r.b));
		c.rgb = mix(c.rgb, hot, clamp(tip * 0.85, 0.0, 1.0));
		c.rgb += hot * tip * 0.35;
		c.a *= ink;
	}
	// The sweep starts once the title is complete.
	float t = mod(TIME, sweep_period) / sweep_period;
	float pos = t * 2.4 - 0.7;
	float band = exp(-pow((UV.x + (UV.y - 0.5) * 0.45 - pos) * 8.0, 2.0)) * drawn;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float letters = smoothstep(0.45, 0.85, lum);
	c.rgb += vec3(1.0, 0.88, 0.66) * band * sweep_strength * letters;
	// Warm rim on the orange glow and rust, breathing slowly.
	float warm = smoothstep(0.08, 0.3, c.r - c.b) * (1.0 - letters);
	c.rgb += vec3(1.0, 0.55, 0.2) * warm * ember * 0.35;
	COLOR = c * v_modulate;
}
