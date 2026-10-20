// One view-bounded snapshot, shared by every eligible rendered consumer.
// Candidate lists grow to their actual size; no actor-local triangle cap.
uniform bool world_cover_enabled = false;
uniform sampler2D world_cover_grid : filter_nearest, repeat_disable;
uniform sampler2D world_cover_indices : filter_nearest, repeat_disable;
uniform sampler2D world_cover_data : filter_nearest, repeat_disable;
uniform sampler2DArray world_cover_alpha : filter_linear, repeat_disable;
uniform vec2 world_cover_origin = vec2(0.0);
uniform ivec2 world_cover_grid_size = ivec2(1);
uniform float world_cover_cell_px = 256.0;
uniform int world_cover_index_width = 256;
uniform int world_cover_data_width = 256;
uniform vec2 world_cover_alpha_size = vec2(1.0);

vec4 world_cover_record(int offset) {
	return texelFetch(world_cover_data, ivec2(offset % world_cover_data_width, offset / world_cover_data_width), 0);
}

float world_cover_side(vec2 a, vec2 b, vec2 p) {
	vec2 edge = b - a;
	vec2 delta = p - a;
	return edge.x * delta.y - edge.y * delta.x;
}

float world_cover_strength(vec2 point, float feet_y) {
	if (!world_cover_enabled) { return 0.0; }
	ivec2 cell = ivec2(floor((point - world_cover_origin) / world_cover_cell_px));
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, world_cover_grid_size))) { return 0.0; }
	vec2 header = texelFetch(world_cover_grid, cell, 0).rg;
	int first = int(header.x + 0.5);
	int count = int(header.y + 0.5);
	float strength = 0.0;
	for (int slot = 0; slot < count; slot++) {
		int packed_index = first + slot;
		int texel_index = packed_index / 4;
		vec4 ids = texelFetch(world_cover_indices, ivec2(texel_index % world_cover_index_width, texel_index / world_cover_index_width), 0);
		int record = int(ids[packed_index % 4] + 0.5) * 4;
		vec4 meta = world_cover_record(record);
		if (feet_y >= meta.z || meta.y <= strength) { continue; }
		vec4 first_row = world_cover_record(record + 1);
		vec4 second_row = world_cover_record(record + 2);
		if (meta.x < 0.5) {
			float a = world_cover_side(first_row.xy, first_row.zw, point);
			float b = world_cover_side(first_row.zw, second_row.xy, point);
			float c = world_cover_side(second_row.xy, first_row.xy, point);
			if ((a >= 0.0 && b >= 0.0 && c >= 0.0) || (a <= 0.0 && b <= 0.0 && c <= 0.0)) {
				strength = max(strength, meta.y);
			}
		} else {
			vec2 local_uv = vec2(dot(first_row.xy, point) + first_row.z, dot(second_row.xy, point) + second_row.z);
			if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThanEqual(local_uv, vec2(1.0)))) { continue; }
			vec4 region = world_cover_record(record + 3);
			// Match the registered city tree's linear, non-mipmapped source.
			// A generated mask mip would fill visible leaf gaps when minified.
			vec2 source_pixel = clamp(region.xy + local_uv * region.zw, region.xy + vec2(0.5), region.xy + region.zw - vec2(0.5));
			vec2 uv = source_pixel / world_cover_alpha_size;
			float alpha = textureLod(world_cover_alpha, vec3(uv, meta.w), 0.0).a;
			strength = max(strength, alpha * meta.y);
		}
		if (strength >= 0.9999) { break; }
	}
	return strength;
}

vec4 world_cover_composite(vec4 authored, float covered) {
	covered = clamp(covered, 0.0, 1.0);
	authored.rgb = mix(authored.rgb, vec3(0.08, 0.13, 0.16), covered * 0.94);
	authored.a *= mix(1.0, 0.56, covered);
	return authored;
}
