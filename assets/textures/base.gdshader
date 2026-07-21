shader_type canvas_item;

uniform float vignette_strength = 0.30;
uniform float noise_strength = 0.02;
uniform float noise_scale = 260.0;

float hash(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 p = uv * 2.0 - 1.0;

	float d = length(p);
	float edge = smoothstep(0.45, 1.15, d); // 0 center → 1 edges

	float n = hash(uv * noise_scale);
	float a = edge * vignette_strength + (n - 0.5) * noise_strength;
	a = clamp(a, 0.0, 0.45);

	COLOR = vec4(0.0, 0.0, 0.0, a);
}
