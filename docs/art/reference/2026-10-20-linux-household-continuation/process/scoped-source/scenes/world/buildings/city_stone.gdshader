shader_type canvas_item;
// S3/default keeps the original cool limestone grade exactly. S2's separate
// material can recover the same source kit's joints and worn face variation.
uniform float source_relief : hint_range(0.0,1.0) = 0.0;
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 stone = mix(vec3(0.50, 0.53, 0.51), vec3(0.67, 0.70, 0.65), smoothstep(0.08, 0.8, value));
	if (source_relief > 0.0) {
		vec3 grain = tex.rgb - vec3(value);
		vec3 pale = clamp(vec3(0.35 + value * 0.75) * vec3(0.98, 1.015, 0.985) + grain * 0.16, vec3(0.0), vec3(0.94));
		stone = mix(stone, pale, source_relief);
	}
	COLOR = vec4(stone, tex.a) * instance_color;
}
