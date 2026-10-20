shader_type canvas_item;
// Polygon UVs encode texels at one isotropic world density. Canvas converts
// them to normalized UV before this stage; repeat only the clean source field.
uniform vec4 source_rect;
uniform bool organic_plaster = false;
uniform vec2 plaster_origin_texels = vec2(0.0);
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }

vec4 patch_hash(vec2 center) {
	vec4 value = fract(vec4(center.xy, center.xy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	value += dot(value, value.wzxy + 33.33);
	return fract((value.xxyz + value.yzzw) * value.zywx);
}

vec2 plaster_patch_uv(vec2 texel_size, vec2 lattice, vec2 center) {
	vec4 random = patch_hash(center);
	vec2 mirror = step(vec2(0.5), random.xy) * 2.0 - 1.0;
	vec2 jitter = (random.zw - 0.5) * 0.16;
	// Neighboring centers share the same sampled function at cell boundaries.
	// Local deltas remain in [-1,1]; nothing wraps through a crop's edge.
	vec2 local = vec2(0.5) + (lattice - center) * mirror * 0.38 + jitter;
	vec2 pixel = source_rect.xy + local * source_rect.zw;
	pixel = clamp(pixel, source_rect.xy + vec2(0.5), source_rect.xy + source_rect.zw - vec2(0.5));
	return pixel * texel_size;
}

void fragment() {
	if (organic_plaster) {
		vec2 lattice = (UV / TEXTURE_PIXEL_SIZE + plaster_origin_texels) / 256.0;
		vec2 cell = floor(lattice);
		vec2 weight = fract(lattice);
		weight = weight * weight * (3.0 - 2.0 * weight);
		vec3 near_row = mix(
			texture(TEXTURE, plaster_patch_uv(TEXTURE_PIXEL_SIZE, lattice, cell)).rgb,
			texture(TEXTURE, plaster_patch_uv(TEXTURE_PIXEL_SIZE, lattice, cell + vec2(1.0,0.0))).rgb,
			weight.x);
		vec3 far_row = mix(
			texture(TEXTURE, plaster_patch_uv(TEXTURE_PIXEL_SIZE, lattice, cell + vec2(0.0,1.0))).rgb,
			texture(TEXTURE, plaster_patch_uv(TEXTURE_PIXEL_SIZE, lattice, cell + vec2(1.0))).rgb,
			weight.x);
		vec3 sampled = mix(near_row, far_row, weight.y);
		vec3 center = texture(TEXTURE, (source_rect.xy + source_rect.zw * 0.5) * TEXTURE_PIXEL_SIZE).rgb;
		// Original patch mean plus its central plaster tone retain the warm
		// source palette. Quiet contrast keeps sampled frame wear from stamps.
		vec3 tone = mix(vec3(0.8934,0.8213,0.7151), center, 0.25);
		vec3 plaster = tone + clamp((sampled-tone) * 0.45, vec3(-0.06), vec3(0.045));
		// These known wall fields are registered opaque geometry. The source's
		// tiny PNG alpha noise must not weaken their actual solid coverage.
		COLOR = vec4(plaster, 1.0) * instance_color;
	} else {
		// Original tiled branch remains exact for the rough masonry plinth.
		vec2 pixel = source_rect.xy + mod(UV / TEXTURE_PIXEL_SIZE, source_rect.zw);
		pixel = clamp(pixel, source_rect.xy + vec2(0.5), source_rect.xy + source_rect.zw - vec2(0.5));
		COLOR = texture(TEXTURE, pixel * TEXTURE_PIXEL_SIZE) * instance_color;
	}
}
