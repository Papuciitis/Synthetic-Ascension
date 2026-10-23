shader_type canvas_item;
// One cause-based stain (CityWeathering): a piece of the composed wall, cut out
// of the wall field exactly like a window module, drawing the same wall (family
// tile, baked base light, foot damp) with the stain composited into it. One
// opaque owner per pixel, so it fades once with the facade during the cutaway.
//
// The piece is a unit square scaled to its area, so VERTEX is the mask
// coordinate. UV follows the wall field: UV.y is the 0..1 field height and
// UV.x the field height in px, whose fraction carries this stain's strength
// (the share of the way to the stain colour at full mask coverage).
#include "res://scenes/world/buildings/facade_wall.gdshaderinc"
#include "res://scenes/world/buildings/weathering/facade_damp.gdshaderinc"
const float PLINTH_PX = 22.0;
uniform float base_fraction = 0.18;
uniform float base_strength = 0.14;
uniform sampler2D mask : hint_default_black, filter_linear_mipmap;
uniform vec3 stain = vec3(0.35);
// The mask rows the piece spans, top edge first (the stain's source).
uniform vec2 mask_rows = vec2(0.0, 1.0);
varying vec2 world_pos;
varying vec2 mask_uv;
varying vec4 instance_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	mask_uv = VERTEX;
	instance_color = COLOR;
}

void fragment() {
	float field_h = floor(UV.x);
	float strength = fract(UV.x);
	vec3 col = facade_wall(world_pos);
	col *= 1.0 - smoothstep(1.0 - base_fraction, 1.0, UV.y) * base_strength;
	col = facade_damp(col, world_pos, (1.0 - UV.y) * field_h + PLINTH_PX);
	float coverage = texture(mask, vec2(mask_uv.x, mix(mask_rows.x, mask_rows.y, mask_uv.y))).r;
	col = mix(col, stain, coverage * strength);
	COLOR = vec4(col, 1.0) * instance_color;
}
