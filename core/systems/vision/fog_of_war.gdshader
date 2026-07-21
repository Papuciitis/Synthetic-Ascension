shader_type canvas_item;

// Texture alpha encodes fog amount per cell pixel.
uniform vec4 fog_color : source_color = vec4(0.05, 0.055, 0.06, 1.0);

// Blur radius in texels (0 = crisp, >0 = soft edge).
uniform float softness_texels = 0.0;

float sample_alpha(vec2 uv){
	return texture(TEXTURE, uv).a;
}

float blurred_alpha(vec2 uv, vec2 texel, float s){
	// 9-tap blur; s scales offsets.
	float a = 0.0;
	a += sample_alpha(uv + texel * vec2(-s, -s));
	a += sample_alpha(uv + texel * vec2( 0.0, -s));
	a += sample_alpha(uv + texel * vec2( s, -s));
	a += sample_alpha(uv + texel * vec2(-s,  0.0));
	a += sample_alpha(uv);
	a += sample_alpha(uv + texel * vec2( s,  0.0));
	a += sample_alpha(uv + texel * vec2(-s,  s));
	a += sample_alpha(uv + texel * vec2( 0.0,  s));
	a += sample_alpha(uv + texel * vec2( s,  s));
	return a / 9.0;
}

void fragment(){
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float a = sample_alpha(UV);
	float s = softness_texels;
	if (s > 0.0){
		a = blurred_alpha(UV, texel, s);
	}
	COLOR = vec4(fog_color.rgb, fog_color.a * a);
}
