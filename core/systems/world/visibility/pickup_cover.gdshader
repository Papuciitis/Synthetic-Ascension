shader_type canvas_item;

#include "res://core/systems/world/visibility/world_cover.gdshaderinc"

uniform float world_cover_feet_y = 0.0;
varying vec2 world_cover_position;

void vertex() {
	world_cover_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// COLOR already contains native Sprite2D texture/atlas sampling and the
	// live polarity, lock, parent and glow modulation authored by their owners.
	COLOR = world_cover_composite(COLOR, world_cover_strength(world_cover_position, world_cover_feet_y));
}
