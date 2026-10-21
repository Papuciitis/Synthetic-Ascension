// Shared wall-kit masonry grade (city_stone / domestic_stone): one country's
// building stone in two local colours. The baked kit lights its top and
// shades its south face (about 2.6:1); a gentle power curve keeps that plane
// ratio near 1.9:1, and a stone tint replaces the source's colour except for
// a share of its own grain. No flat remap.
float masonry_value(vec3 rgb) {
	return max(dot(rgb, vec3(0.299, 0.587, 0.114)), 0.001);
}

vec3 masonry_grade(vec3 rgb, float value, vec3 tint, float brightness, float curve, float grain_keep) {
	float graded = brightness * pow(value, curve);
	vec3 grain = mix(vec3(1.0), rgb / masonry_value(rgb), grain_keep);
	return clamp(graded * tint * grain, vec3(0.0), vec3(1.0));
}

// Dressed ashlar has fine joints: a dark texel next to brighter stone (two
// diagonal taps) is lifted toward it, thinning mortar lines without touching
// the top/face plane split or the stones themselves.
float masonry_fine_joints(sampler2D source, vec2 uv, vec2 texel, float value, float lift) {
	vec2 step = texel * 2.5;
	float a = masonry_value(texture(source, uv + step).rgb);
	float b = masonry_value(texture(source, uv - step).rgb);
	return max(value, mix(value, max(a, b), lift));
}
