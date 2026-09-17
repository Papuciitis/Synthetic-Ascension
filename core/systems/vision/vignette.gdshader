shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.38;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.70;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;
// Exit Rite distortion (plan 2.8): the colour the edge darkens toward, and a
// flat wash of it across the whole screen. Black and 0 render the plain
// vignette exactly; the VisionRig ramps both with the rite's level.
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float wash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float t = smoothstep(inner_radius, outer_radius, d);
	float a = clamp(t * strength + wash, 0.0, 1.0);
	COLOR = vec4(tint.rgb, a);
}
