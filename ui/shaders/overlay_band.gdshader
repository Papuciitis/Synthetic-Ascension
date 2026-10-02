shader_type canvas_item;
// A soft band of shade behind a ceremonial line of text (the Rite reveal):
// ink in the middle fading to nothing at every edge, warmed by a faint pool
// of candle light at its heart and, below the title, a thin seam of the
// accent colour. Static: nothing writes its parameters per frame.

uniform vec4 ink : source_color = vec4(0.012, 0.009, 0.007, 0.8);
uniform vec4 warmth : source_color = vec4(0.62, 0.38, 0.16, 0.16);
uniform vec4 seam : source_color = vec4(0.55, 0.7, 1.0, 0.22);
// Where the seam runs, as a fraction of the height (0 = top).
uniform float seam_at = 0.64;
uniform float fade_x = 0.3;
uniform float fade_y = 0.34;

void fragment() {
	vec2 uv = UV;
	float fx = smoothstep(0.0, fade_x, uv.x) * smoothstep(0.0, fade_x, 1.0 - uv.x);
	float fy = smoothstep(0.0, fade_y, uv.y) * smoothstep(0.0, fade_y, 1.0 - uv.y);
	vec2 c = uv - vec2(0.5, 0.48);
	float pool = exp(-(c.x * c.x * 7.0 + c.y * c.y * 9.0));
	float dy = (uv.y - seam_at) * 90.0;
	float line = exp(-dy * dy) * smoothstep(0.08, 0.5, uv.x) * smoothstep(0.08, 0.5, 1.0 - uv.x);
	vec3 col = ink.rgb + warmth.rgb * warmth.a * pool;
	col = mix(col, seam.rgb, clamp(line * seam.a * 2.5, 0.0, 1.0));
	float a = max(ink.a * fx * fy, line * seam.a);
	COLOR = vec4(col, a);
}
