shader_type canvas_item;

#include "res://core/systems/world/visibility/world_cover.gdshaderinc"

uniform float world_cover_feet_y = 0.0;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Shared live opacity is authoritative. Legacy diagnostic triangles
	// must not resurrect a silhouette beneath transparent/invisible cover.
	if (COLOR.a > 0.0) {
		COLOR = world_cover_composite(COLOR, world_cover_strength(world_position, world_cover_feet_y));
	}
}
