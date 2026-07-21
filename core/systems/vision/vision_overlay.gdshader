shader_type canvas_item;

// Fullscreen darkness with a soft circular "light" around the center.
// Designed to be subtle and readable (walls pop, ground calms down).

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.68);
uniform float radius_px = 430.0;
uniform float softness_px = 220.0;
uniform float vignette_strength = 0.22;

void fragment() {
	// Viewport size in pixels (derived from SCREEN_PIXEL_SIZE).
	vec2 viewport_size = vec2(1.0 / SCREEN_PIXEL_SIZE.x, 1.0 / SCREEN_PIXEL_SIZE.y);
	vec2 center_px = viewport_size * 0.5;

	float dist_px = length(FRAGCOORD.xy - center_px);
	float t = smoothstep(radius_px, radius_px + softness_px, dist_px);

	// Base darkness: 0 near center, reaches shadow_color.a outside.
	float a = shadow_color.a * t;

	// Vignette: extra darkness near screen edges (very subtle).
	vec2 uv = SCREEN_UV;
	float edge = smoothstep(0.40, 0.95, length(uv - vec2(0.5)) * 1.6);
	a = clamp(a + edge * vignette_strength * 0.35, 0.0, 1.0);

	COLOR = vec4(shadow_color.rgb, a);
}
