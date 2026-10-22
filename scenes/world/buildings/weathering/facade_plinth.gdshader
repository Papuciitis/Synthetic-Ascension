shader_type canvas_item;
// Composed frontage plinth (CityFacadeComposer): its rough masonry tile, with
// the wall-foot damp rising from the street (UV.y 0 = plinth top, 1 = foot).
#include "res://scenes/world/buildings/weathering/facade_damp.gdshaderinc"
const float PLINTH_PX = 22.0;
varying vec2 world_pos;
varying flat float building_seed;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	building_seed = facade_building_seed(MODEL_MATRIX);
}

void fragment() {
	vec4 c = COLOR;
	c.rgb = facade_damp(c.rgb, world_pos, (1.0 - fract(UV.y)) * PLINTH_PX, building_seed);
	COLOR = c;
}
