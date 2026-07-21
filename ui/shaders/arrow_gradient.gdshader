shader_type canvas_item;

// Orange-ish gradient to match the HUD accent.
uniform vec4 top_color : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.38, 0.05, 1.0);

uniform float outline_threshold = 0.12;

void fragment(){
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.01){
		discard;
	}
	float lum = (t.r + t.g + t.b) / 3.0;
	// Preserve the black outline from the source texture.
	// NOTE: Some backends dislike early `return` in fragment.
	float g = 1.0 - UV.y;
	vec4 col = mix(bottom_color, top_color, g);
	vec4 fill = vec4(col.rgb, t.a);
	vec4 outline = vec4(0.0, 0.0, 0.0, t.a);
	COLOR = mix(fill, outline, step(lum, outline_threshold));
}
