shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.38;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.70;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float t = smoothstep(inner_radius, outer_radius, d);
	float a = t * strength;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
