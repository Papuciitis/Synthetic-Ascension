shader_type canvas_item;
// Composed frontage wall field (CityFacadeComposer). One material per masonry
// family is shared by every run. UV.y carries the run's 0..1 height (0 = eave,
// 1 = wall base) for the baked south-face light: a contact shade above the plinth.
#include "res://scenes/world/buildings/facade_wall.gdshaderinc"
uniform float base_fraction = 0.18;
uniform float base_strength = 0.14;
varying vec2 world_pos;
varying vec4 instance_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	instance_color = COLOR;
}

void fragment() {
	vec3 col = facade_wall(world_pos);
	float base = smoothstep(1.0 - base_fraction, 1.0, UV.y);
	col *= 1.0 - base * base_strength;
	COLOR = vec4(col, 1.0) * instance_color;
}
