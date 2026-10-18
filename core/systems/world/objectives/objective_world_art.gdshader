shader_type canvas_item;
uniform float energy : hint_range(0.0, 1.0) = 0.25;
uniform bool completed = false;
uniform bool draining = false;
uniform bool spent = false;
uniform bool working = false;
varying vec4 object_modulate;

void vertex() {
	object_modulate = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float high = max(source.r, max(source.g, source.b));
	float low = min(source.r, min(source.g, source.b));
	// Identify coloured cores, retaining the painted brass and ivory surfaces.
	float core = smoothstep(0.24, 0.55, high - low) * smoothstep(0.27, 0.6, high);
	// Minification mixes the narrow Breach fissure with dark stone. Detect
	// red dominance at that scale while excluding the yellow brass bands.
	float red_core = smoothstep(0.025, 0.12, source.r - source.g * 1.5) * smoothstep(0.06, 0.25, source.r);
	float cool_core = smoothstep(0.06, 0.3, max(source.g, source.b) - source.r);
	float mask = max(red_core, cool_core * core);
	vec3 painted = source.rgb * mix(0.69, 1.0, energy);
	if (completed) {
		painted = mix(painted, vec3(0.35, 0.8, 0.68) * max(0.5, luminance), mask);
	} else if (draining) {
		painted = mix(painted, vec3(0.95, 0.36, 0.19) * max(0.6, luminance), mask);
	} else {
		painted = mix(painted, source.rgb * energy, mask);
	}
	if (working) { painted += vec3(0.06, 0.045, 0.015) * energy * luminance; }
	if (spent) { painted = mix(painted, vec3(luminance * 0.5), 0.78); }
	COLOR = vec4(painted, source.a) * object_modulate;
}
