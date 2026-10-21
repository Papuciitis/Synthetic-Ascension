shader_type canvas_item;
// Pale dressed ashlar for city walls in every segment, matching the pale
// facade family (facade_plaster_pale): warm cream-grey stone whose lit tops
// and shaded south faces keep the kit's baked relief, with fine joints.
// source_relief blends back toward the legacy flat limestone (0 = legacy).
#include "res://scenes/world/buildings/masonry_grade.gdshaderinc"
uniform float source_relief : hint_range(0.0,1.0) = 1.0;
uniform vec3 stone_tint = vec3(1.05, 0.99, 0.90);
uniform float stone_brightness = 1.18;
uniform float stone_curve = 0.667;
uniform float grain_keep = 0.30;
uniform float joint_lift = 0.55;
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float value = masonry_value(tex.rgb);
	vec3 legacy = mix(vec3(0.50, 0.53, 0.51), vec3(0.67, 0.70, 0.65), smoothstep(0.08, 0.8, value));
	vec2 joint_step = TEXTURE_PIXEL_SIZE * 2.5;
	float neighbour_a = masonry_value(texture(TEXTURE, UV + joint_step).rgb);
	float neighbour_b = masonry_value(texture(TEXTURE, UV - joint_step).rgb);
	float dressed = masonry_fine_joints(value, neighbour_a, neighbour_b, joint_lift);
	vec3 ashlar = masonry_grade(tex.rgb, dressed, stone_tint, stone_brightness, stone_curve, grain_keep);
	COLOR = vec4(mix(legacy, ashlar, source_relief), tex.a) * instance_color;
}
