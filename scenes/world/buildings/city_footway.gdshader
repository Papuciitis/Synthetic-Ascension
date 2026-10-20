shader_type canvas_item;

// The exterior boundary of the whole semantic S2 footway, shared by every
// clipped piece. Data coordinates are chunk-local; edge noise is world-fixed.
uniform sampler2D external_edges : filter_nearest, repeat_disable;
uniform int external_edge_count = 0;
uniform float edge_feather = 18.0;
uniform float surface_contrast = 0.27;
uniform vec3 surface_mid = vec3(0.57, 0.59, 0.55);
varying vec2 point;
varying vec2 world_point;
varying vec4 surface_tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 base = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash(base), hash(base + vec2(1.0, 0.0)), t.x),
		mix(hash(base + vec2(0.0, 1.0)), hash(base + vec2(1.0, 1.0)), t.x), t.y);
}

void vertex() {
	point = VERTEX;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_tint = COLOR;
}

void fragment() {
	float distance_to_edge = 100000.0;
	for (int index = 0; index < external_edge_count; index++) {
		vec4 edge = texelFetch(external_edges, ivec2(index, 0), 0);
		vec2 direction = edge.zw - edge.xy;
		float along = clamp(dot(point - edge.xy, direction) / max(dot(direction, direction), 0.001), 0.0, 1.0);
		distance_to_edge = min(distance_to_edge, length(point - (edge.xy + direction * along)));
	}
	// Inward-only wear returns to the actual splat underneath. There is no
	// painted soil/grass halo, and building contacts/road joins stay opaque.
	float wear = noise(world_point / 57.0) * 7.0 + noise(world_point / 17.0) * 3.0;
	float alpha = smoothstep(0.0, edge_feather, distance_to_edge - wear);
	COLOR = vec4(mix(surface_mid * surface_tint.rgb, COLOR.rgb, surface_contrast), COLOR.a * alpha);
}
