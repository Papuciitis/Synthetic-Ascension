// Shared facade wall sampling (CityFacadeComposer). The seamless family tile is
// world-anchored and sampled twice (the second mirrored at another scale)
// through a broad noise mask, so long walls never repeat one visible stamp;
// contrast is pulled toward the tile mean to keep walls quiet behind actors.
uniform sampler2D wall_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float repeat_px = 360.0;
uniform vec3 tile_mean = vec3(0.9, 0.81, 0.66);
uniform float contrast = 0.72;
uniform vec3 tint = vec3(1.0);

float facade_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float facade_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(facade_hash(i), facade_hash(i + vec2(1.0, 0.0)), f.x), mix(facade_hash(i + vec2(0.0, 1.0)), facade_hash(i + vec2(1.0)), f.x), f.y);
}

vec3 facade_wall(vec2 p) {
	vec3 a = texture(wall_tex, p / repeat_px).rgb;
	vec3 b = texture(wall_tex, vec2(-p.x, p.y) / (repeat_px * 1.31) + vec2(0.37, 0.61)).rgb;
	float m = smoothstep(0.38, 0.62, facade_noise(p / (repeat_px * 0.85)));
	vec3 col = mix(a, b, m);
	return (tile_mean + (col - tile_mean) * contrast) * tint;
}
