shader_type canvas_item;
// Polygon UVs encode texels at one isotropic world density. Canvas converts
// them to normalized UV before this stage; repeat only the clean source field.
uniform vec4 source_rect;
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
void fragment() {
	vec2 pixel = source_rect.xy + mod(UV / TEXTURE_PIXEL_SIZE, source_rect.zw);
	pixel = clamp(pixel, source_rect.xy + vec2(0.5), source_rect.xy + source_rect.zw - vec2(0.5));
	COLOR = texture(TEXTURE, pixel * TEXTURE_PIXEL_SIZE) * instance_color;
}
