shader_type canvas_item;

// Re-dye the burgundy weave while retaining the source pixel clusters,
// ochre braid and cut-out silhouette. Labels are separate child canvases.
uniform vec4 cloth_color : source_color = vec4(0.48, 0.14, 0.16, 1.0);
uniform bool palette_enabled = false;
varying vec4 vertex_ink;

void vertex() {
	vertex_ink = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	bool weave = source.r > source.g * 1.45 && source.b > source.g * 0.65;
	if (palette_enabled && weave) {
		float light = clamp(source.r / 0.49, 0.25, 1.35);
		source.rgb = cloth_color.rgb * light;
	}
	COLOR = source * vertex_ink;
}
