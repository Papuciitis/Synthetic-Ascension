shader_type canvas_item;
// Static, texture-masked equipment heat/focus. No flashes or oscillation;
// Reduced Motion retains the same legible phase identity.
uniform int phase : hint_range(0, 2) = 0;
uniform bool arcanist = false;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float gold = smoothstep(0.035, 0.18, source.r - source.b) * smoothstep(0.12, 0.45, source.g);
	float purple = smoothstep(0.015, 0.15, source.b - source.g) * smoothstep(0.08, 0.35, source.b);
	float hardware = arcanist ? max(1.0 - step(0.31, UV.y), step(0.78, UV.x)) : max(1.0 - step(0.40, UV.y), step(0.73, UV.x));
	float strength = float(phase) * 0.28;
	vec3 emission = arcanist ? vec3(0.56, 0.30, 1.0) * (purple + gold * 0.35) : vec3(1.0, 0.39, 0.06) * gold;
	COLOR.rgb += emission * hardware * strength * COLOR.a;
}
