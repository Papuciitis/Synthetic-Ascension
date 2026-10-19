shader_type canvas_item;

uniform int triangle_count = 0;
uniform vec4 triangle_ab[32];
uniform vec4 triangle_ca[32];
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float side(vec2 a, vec2 b, vec2 point) {
	vec2 edge = b - a;
	vec2 delta = point - a;
	return edge.x * delta.y - edge.y * delta.x;
}

void fragment() {
	float covered = 0.0;
	for (int index = 0; index < 32; index++) {
		if (index >= triangle_count) { break; }
		vec2 a = triangle_ab[index].xy;
		vec2 b = triangle_ab[index].zw;
		vec2 c = triangle_ca[index].xy;
		float first = side(a, b, world_position);
		float second = side(b, c, world_position);
		float third = side(c, a, world_position);
		bool positive = first >= 0.0 && second >= 0.0 && third >= 0.0;
		bool negative = first <= 0.0 && second <= 0.0 && third <= 0.0;
		if (positive || negative) { covered = max(covered, triangle_ca[index].z); }
	}
	// A quiet cool shadow through the cover, rather than full-colour art
	// painted on a roof. Exposed pixels and normal damage alpha are retained.
	COLOR.rgb = mix(COLOR.rgb, vec3(0.08, 0.13, 0.16), covered * 0.94);
	COLOR.a *= mix(1.0, 0.56, covered);
}
