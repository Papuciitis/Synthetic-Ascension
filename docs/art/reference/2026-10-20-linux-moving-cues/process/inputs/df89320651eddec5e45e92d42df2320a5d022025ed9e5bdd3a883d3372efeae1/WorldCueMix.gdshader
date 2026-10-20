shader_type canvas_item;
render_mode blend_mix;
#include "res://core/systems/world/visibility/world_cover.gdshaderinc"
uniform bool ground_points = false;
// A raised sprite can keep a physical owner contact separately from its
// painted origin. Only the bomber fuse owns this small material variant.
uniform bool use_ground_anchor_override = false;
uniform float ground_anchor_y = 0.0;
varying vec2 cover_world_position;
varying flat float cover_anchor_y;
void vertex() {
	cover_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	cover_anchor_y = use_ground_anchor_override ? ground_anchor_y : (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}
void fragment() {
	float feet = ground_points ? cover_world_position.y : cover_anchor_y;
	float covered = world_cover_strength(cover_world_position, feet);
	COLOR = world_cover_composite(COLOR, covered);
}
