shader_type canvas_item;
// The veil Game Over draws over the frozen world: the last frame drains toward
// a warm ash grey and sinks into the dark, deepest at the edges, while a low
// ember warmth lingers at the foot of the screen. One screen read per pixel,
// and `amount` only moves while the moment settles.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.018, 0.014, 0.011, 1.0);
uniform vec4 ember : source_color = vec4(0.55, 0.22, 0.07, 1.0);

void fragment() {
	vec3 world = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(world, vec3(0.3, 0.59, 0.11));
	vec3 ash = vec3(lum) * vec3(1.0, 0.93, 0.84);
	vec3 c = mix(world, ash, amount * 0.88);
	vec2 d = (UV - vec2(0.5, 0.52)) * vec2(1.0, 1.3);
	float edge = smoothstep(0.2, 0.8, length(d));
	float dark = amount * (0.75 + 0.2 * edge);
	c = mix(c, ink.rgb, clamp(dark, 0.0, 0.96));
	float low = smoothstep(0.62, 1.0, UV.y) * (1.0 - smoothstep(0.05, 0.62, abs(UV.x - 0.5)));
	c += ember.rgb * low * 0.09 * amount;
	COLOR = vec4(c, 1.0);
}
