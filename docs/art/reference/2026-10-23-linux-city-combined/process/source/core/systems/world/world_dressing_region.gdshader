shader_type canvas_item;

uniform vec4 texture_region = vec4(0.0, 0.0, 1.0, 1.0);

void vertex() {
	UV = texture_region.xy + UV * texture_region.zw;
}
