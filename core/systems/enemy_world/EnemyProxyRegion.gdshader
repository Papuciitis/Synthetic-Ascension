shader_type canvas_item;

// Proxy batches draw one unit quad per instance. INSTANCE_CUSTOM carries the
// atlas region (x, y, w, h in 0..1 of the batch texture) so a single batch can
// show any frame of an enemy sheet; a whole-texture instance passes (0,0,1,1).
//
// Hit flash (FPS audit 2026-10-04): a negative region height marks an instance
// that was just damaged. Heights are positive otherwise, so the sign costs the
// region and the colour no precision. The instance mixes toward white by
// hit_flash_strength, which the renderer sets from the combat-flash
// accessibility setting (1 full, 0.4 reduced, 0 off).
uniform float hit_flash_strength : hint_range(0.0, 1.0) = 1.0;
varying flat float hit_flash;

void vertex() {
	hit_flash = INSTANCE_CUSTOM.w < 0.0 ? 1.0 : 0.0;
	UV = INSTANCE_CUSTOM.xy + UV * vec2(INSTANCE_CUSTOM.z, abs(INSTANCE_CUSTOM.w));
}

void fragment() {
	// COLOR arrives as texture * vertex colour; only the flash changes it.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), hit_flash * hit_flash_strength);
}
