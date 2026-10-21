shader_type canvas_item;
// One opaque draw per facade module (window, quoin, vine, cabinet): the module
// texture over its family's wall tile. Every facade pixel therefore belongs to
// exactly one registered solid node, fading once with the roof and covering
// actors behind it without adding foreground alpha layers.
#include "res://scenes/world/buildings/facade_wall.gdshaderinc"
varying vec2 world_pos;
varying vec4 instance_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	instance_color = COLOR;
}

void fragment() {
	vec4 module = texture(TEXTURE, UV);
	COLOR = vec4(mix(facade_wall(world_pos), module.rgb, module.a), 1.0) * instance_color;
}
