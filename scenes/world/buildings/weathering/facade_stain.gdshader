shader_type canvas_item;
// One cause-based stain (CityWeathering): a piece of the composed wall, cut out
// of the wall field exactly like a window module, drawing the same wall (family
// tile, baked base light, foot damp) with the stain composited into it. One
// opaque owner per pixel, so it fades once with the facade during the cutaway.
//
// Geometry uses the same parent-space vertices and identity local transform
// as the wall's cut. UV.x = 2 * field_height_px + mask_corner_x + strength;
// UV.y = field_height_fraction + 2 * mask_corner_y. Decode at vertices before
// interpolation: mask corners are 0/1, strength is below 1, and the wall-height
// fraction is within 0..1. Material sharing needs no per-piece bounds uniform.
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
// Full-field height, wall-height fraction, stain strength.
varying vec3 wall_data;
varying vec4 instance_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float packed_x = floor(UV.x);
	mask_uv = vec2(mod(packed_x, 2.0), floor(UV.y * 0.5));
	wall_data = vec3(floor(packed_x * 0.5), mod(UV.y, 2.0), fract(UV.x));
	instance_color = COLOR;
}

void fragment() {
	float field_h = wall_data.x;
	float wall_y = wall_data.y;
	float strength = wall_data.z;
	vec3 col = facade_wall(world_pos);
	col *= 1.0 - smoothstep(1.0 - base_fraction, 1.0, wall_y) * base_strength;
	col = facade_damp(col, world_pos, (1.0 - wall_y) * field_h + PLINTH_PX);
	float coverage = texture(mask, vec2(mask_uv.x, mix(mask_rows.x, mask_rows.y, mask_uv.y))).r;
	col = mix(col, stain, coverage * strength);
	COLOR = vec4(col, 1.0) * instance_color;
}
