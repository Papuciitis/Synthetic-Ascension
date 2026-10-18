shader_type canvas_item;
// Sparse ink-grain erosion of the existing authored form, never a white flash.
uniform float dissolve = -0.16;
uniform vec4 ash_color : source_color = vec4(0.9, 0.39, 0.12, 1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec2 cell = floor(UV * vec2(87.0, 123.0));
	float grain = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float edge = smoothstep(dissolve - 0.10, dissolve + 0.08, grain);
	float fringe = (1.0 - smoothstep(0.0, 0.12, grain - dissolve)) * edge;
	source.rgb = mix(source.rgb, ash_color.rgb * 0.52, fringe * 0.5);
	source.a *= edge;
	COLOR = source;
}
