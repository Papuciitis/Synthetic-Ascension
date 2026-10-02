shader_type canvas_item;
// The Archive card's window onto the world: a slice of the painting, clipped
// to the card's pointed arch (ArcaneFrame.arch_y, same curve), drifting very
// slowly, darkened toward the sill and brightened while the card is held.

uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // plate UV x, y, w, h
uniform float arch = 0.27;                      // arch rise, fraction of height
uniform float pan_seed = 0.0;
uniform float lit : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float drift_amount = 1.0;               // 0 under reduced motion

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float arch_y(float x, float h) {
	float half_x = min(x, 1.0 - x);
	float t = sqrt(clamp(half_x * 2.0, 0.0, 1.0));
	float c = h * 0.45;
	return (1.0 - t) * (1.0 - t) * h + 2.0 * (1.0 - t) * t * c;
}

void fragment() {
	vec2 uv = UV;
	float top = arch_y(uv.x, arch);
	float inside = smoothstep(top - 0.003, top + 0.003, uv.y);
	vec2 drift = vec2(sin(TIME * 0.045 + pan_seed) * 0.03, cos(TIME * 0.031 + pan_seed * 1.7) * 0.015) * drift_amount;
	vec2 local = uv * 0.9 + vec2(0.05) + drift;
	vec3 c = texture(TEXTURE, region.xy + local * region.zw).rgb;
	float sill = smoothstep(1.02, 0.45, uv.y);
	c *= mix(0.42, 0.85, lit) * mix(0.3, 1.0, sill);
	c *= tint.rgb;
	COLOR = vec4(c, inside) * v_modulate;
}
