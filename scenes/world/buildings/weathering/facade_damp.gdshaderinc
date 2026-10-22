// Capillary damp rising from an actual wall foot (CityWeathering). The lead's
// wall_base_damp mask (1024x256, bottom edge = wall foot, red = linear
// coverage) spans DAMP_MASK_PX world px of wall height, so the damp band itself
// rises roughly 12-44 px. The theme sets the strength and stain colour once
// through project shader globals (0 = clean: S1, the Hub, tests); each building
// varies by a stable hash of its world origin.
global uniform float sa_weather_damp;
global uniform vec4 sa_weather_damp_tint;
global uniform sampler2D sa_weather_damp_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
const float DAMP_MASK_PX = 64.0;

float facade_building_seed(mat4 model) {
	vec2 origin = floor(model[3].xy / 16.0);
	return fract(sin(dot(origin, vec2(12.9898, 78.233))) * 43758.5453);
}

// `above_foot` in world px over the wall foot; returns the colour change.
vec3 facade_damp(vec3 col, vec2 world_pos, float above_foot, float building_seed) {
	if (sa_weather_damp <= 0.0 || above_foot >= DAMP_MASK_PX) {
		return col;
	}
	float v = 1.0 - clamp(above_foot / DAMP_MASK_PX, 0.0, 1.0);
	float u = world_pos.x / (DAMP_MASK_PX * 4.0) + building_seed * 7.0;
	float coverage = texture(sa_weather_damp_mask, vec2(u, min(v, 0.995))).r;
	float amount = coverage * sa_weather_damp * mix(0.5, 1.4, building_seed);
	return mix(col, col * sa_weather_damp_tint.rgb, clamp(amount * 3.0, 0.0, 1.0));
}
