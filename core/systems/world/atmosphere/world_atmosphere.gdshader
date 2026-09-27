shader_type canvas_item;
render_mode blend_mul;

// World grade (WorldAtmosphere.gd): multiplied over the world layer only, so
// the HUD is untouched. A warm grade everywhere, and a vignette whose centre
// sits toward the top right - the light the walls' shadows fall away from -
// so the lower-left corner of the screen settles into shade like the
// reference.

uniform vec4 grade : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 shade : source_color = vec4(0.34, 0.31, 0.36, 1.0);
uniform float strength = 0.62;
uniform float inner = 0.42;
uniform float outer = 1.3;
uniform vec2 light_centre = vec2(0.58, 0.42);
uniform float aspect = 1.7778;

void fragment() {
	vec2 d = UV - light_centre;
	d.x *= aspect / 1.7778 * 1.35;
	float t = smoothstep(inner, outer, length(d) * 1.6);
	COLOR = vec4(mix(grade.rgb, grade.rgb * shade.rgb, t * strength), 1.0);
}
