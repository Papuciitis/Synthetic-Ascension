shader_type canvas_item;
render_mode unshaded, blend_mul;

// Shared sun shade (WorldDepthStyle). The framebuffer is multiplied, so a cast
// darkens lawn, paving and dirt by one ratio instead of blending toward a dark
// colour. COLOR.a carries vertex feathering, cutaway modulation and any
// texture silhouette; a fully covered pixel multiplies by shade_color.
uniform vec3 shade_color = vec3(0.66, 0.69, 0.76);

void fragment() {
	float amount = clamp(COLOR.a, 0.0, 1.0);
	COLOR = vec4(mix(vec3(1.0), shade_color, amount), 1.0);
}
