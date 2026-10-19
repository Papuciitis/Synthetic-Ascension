shader_type canvas_item;
// Preserve the shared wall kit's geometry/alpha and baked face shading,
// compressing its tiny mortar edges into a quiet cool limestone range.
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 stone = mix(vec3(0.50, 0.53, 0.51), vec3(0.67, 0.70, 0.65), smoothstep(0.08, 0.8, value));
	COLOR = vec4(stone, tex.a) * instance_color;
}
