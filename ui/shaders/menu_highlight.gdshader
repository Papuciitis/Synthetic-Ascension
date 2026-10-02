shader_type canvas_item;
// The gold brush stroke behind a selected menu item. `reveal` wipes it in from
// the star end with a ragged, brush-like edge; a warm sheen slides along the
// paint while it is held.

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float sheen_phase = 0.0;
uniform float sheen_strength = 0.24;
uniform float glow = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float rag = (texture(noise_tex, vec2(UV.y * 1.9, 0.31)).r - 0.5) * 0.22
		+ (texture(noise_tex, vec2(UV.y * 6.0, 0.77)).g - 0.5) * 0.08;
	float edge = reveal * 1.3 - 0.15;
	c.a *= smoothstep(edge + 0.05, edge - 0.05, UV.x + rag);
	float pos = fract(TIME * 0.22 + sheen_phase) * 1.9 - 0.45;
	float band = exp(-pow((UV.x - pos - (UV.y - 0.5) * 0.22) * 7.0, 2.0));
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// The paint is colour-to-alpha output (red already at 1.0), so adding white
	// would clip red and shift the gold toward khaki. Brighten through coverage
	// and the paint's own hue instead.
	float lift = band * sheen_strength * smoothstep(0.35, 0.7, lum) + glow * 0.25;
	c.a = min(1.0, c.a + lift * (1.0 - c.a) * 1.5 * smoothstep(0.0, 0.3, c.a));
	c.rgb = min(c.rgb * (1.0 + lift * 0.6), vec3(1.0));
	COLOR = c * v_modulate;
}
