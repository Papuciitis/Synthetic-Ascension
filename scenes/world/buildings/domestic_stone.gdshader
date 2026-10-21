shader_type canvas_item;
// Warm domestic rubble on actual home wall cells, envelope and partitions:
// the same masonry grade as city ashlar (masonry_grade), in the warm plaster
// family's colour with more of the source rubble's own grain and full joints.
#include "res://scenes/world/buildings/masonry_grade.gdshaderinc"
uniform vec3 stone_tint = vec3(1.11, 0.975, 0.80);
uniform float stone_brightness = 0.92;
uniform float stone_curve = 0.72;
uniform float grain_keep = 0.55;
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(masonry_grade(tex.rgb, masonry_value(tex.rgb), stone_tint, stone_brightness, stone_curve, grain_keep), tex.a) * instance_color;
}
