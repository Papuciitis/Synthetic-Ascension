// Capillary damp rising from an actual wall foot (CityWeathering). The lead's
// wall_base_damp mask (1024x256, bottom edge = wall foot, red = linear
// coverage) spans DAMP_MASK_PX world px of wall height, so the band itself
// rises roughly 12-44 px. The theme sets the stain once through project shader
// globals: sa_weather_damp is the local value decrease at full coverage (0 =
// clean: S1, the Hub, tests), sa_weather_damp_tint its hue. The deposit varies
// smoothly along the street (world-anchored, 0.75-1.25), not per building.
global uniform float sa_weather_damp;
global uniform vec4 sa_weather_damp_tint;
global uniform sampler2D sa_weather_damp_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
const float DAMP_MASK_PX = 64.0;

float facade_street_variation(vec2 world_pos) {
	float x = world_pos.x / 384.0 + world_pos.y / 2048.0;
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(i * 127.1) * 43758.5453);
	float b = fract(sin((i + 1.0) * 127.1) * 43758.5453);
	return mix(0.75, 1.25, mix(a, b, f));
}

// `above_foot` in world px over the wall foot.
vec3 facade_damp(vec3 col, vec2 world_pos, float above_foot) {
	// Mask gradients come before the band's early return: implicit ones inside
	// it are undefined where a pixel quad straddles DAMP_MASK_PX, and a wrong
	// mip there draws a faint damp line along every wall.
	vec2 uv = vec2(world_pos.x / (DAMP_MASK_PX * 4.0), 1.0 - above_foot / DAMP_MASK_PX);
	vec2 uv_dx = dFdx(uv);
	vec2 uv_dy = dFdy(uv);
	if (sa_weather_damp <= 0.0 || above_foot >= DAMP_MASK_PX) {
		return col;
	}
	// The mask repeats along the wall, so keep v off both edges: filtering
	// would otherwise wrap the wet foot row onto the dry top. The mask's upper
	// quarter is empty.
	uv.y = clamp(uv.y, 0.25, 0.98);
	float coverage = textureGrad(sa_weather_damp_mask, uv, uv_dx, uv_dy).r;
	float amount = clamp(coverage * facade_street_variation(world_pos), 0.0, 1.0);
	vec3 hue = sa_weather_damp_tint.rgb / max(dot(sa_weather_damp_tint.rgb, vec3(0.299, 0.587, 0.114)), 0.001);
	return mix(col, col * (1.0 - sa_weather_damp) * hue, amount);
}
