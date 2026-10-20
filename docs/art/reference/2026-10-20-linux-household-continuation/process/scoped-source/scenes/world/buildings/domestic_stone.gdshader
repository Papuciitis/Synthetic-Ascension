shader_type canvas_item;
// Original rough faces and mortar keep their range; this grade belongs only
// to actual domestic wall cells, including envelope and room partitions.
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 neutral = value * vec3(1.03, 1.04, 0.98);
	vec3 stone = mix(tex.rgb, neutral, 0.28);
	stone = clamp(stone * 0.94 + vec3(0.018, 0.022, 0.018), vec3(0.0), vec3(1.0));
	COLOR = vec4(stone, tex.a) * instance_color;
}
