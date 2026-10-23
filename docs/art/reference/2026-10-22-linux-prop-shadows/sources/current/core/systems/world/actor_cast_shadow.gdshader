shader_type canvas_item;
render_mode unshaded;

// The same alpha silhouette serves player AtlasTextures and enemy batches.
// Enemy custom data selects its current frame; abs(w) discards hit-flash flags.
uniform bool use_instance_region = false;
uniform vec4 texture_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.018, 0.024, 0.032, 0.32);

void vertex() {
	if (use_instance_region) {
		UV = INSTANCE_CUSTOM.xy + UV * vec2(INSTANCE_CUSTOM.z, abs(INSTANCE_CUSTOM.w));
	} else {
		UV = texture_region.xy + UV * texture_region.zw;
	}
}

void fragment() {
	COLOR = vec4(shadow_color.rgb, COLOR.a * shadow_color.a);
}
