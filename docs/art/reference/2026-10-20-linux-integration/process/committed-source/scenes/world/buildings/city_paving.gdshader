shader_type canvas_item;
uniform vec4 area;
uniform float edge_feather = 28.0;
uniform float surface_contrast = 1.0;
uniform vec3 surface_mid = vec3(0.55, 0.57, 0.54);
varying vec2 point;
varying vec4 surface_tint;
void vertex() { point = VERTEX; surface_tint = COLOR; }
void fragment() {
	float edge = min(min(point.x-area.x, area.z-point.x), min(point.y-area.y, area.w-point.y));
	COLOR.rgb = mix(surface_mid * surface_tint.rgb, COLOR.rgb, surface_contrast);
	COLOR.a *= smoothstep(0.0, max(edge_feather, 0.1), edge);
}
