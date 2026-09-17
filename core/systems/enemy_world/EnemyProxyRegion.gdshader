shader_type canvas_item;

// Proxy batches draw one unit quad per instance. INSTANCE_CUSTOM carries the
// atlas region (x, y, w, h in 0..1 of the batch texture) so a single batch can
// show any frame of an enemy sheet; a whole-texture instance passes (0,0,1,1).
void vertex() {
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
}
