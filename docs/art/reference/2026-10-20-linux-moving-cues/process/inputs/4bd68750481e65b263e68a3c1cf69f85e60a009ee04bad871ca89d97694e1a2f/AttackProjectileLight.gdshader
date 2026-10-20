shader_type canvas_item;
render_mode blend_mix;
#include "res://core/systems/world/visibility/world_cover.gdshaderinc"
varying vec2 cover_world_position;
varying flat float cover_feet_y;

// Player families only: keeps native/needle/tracer silhouettes and the same
// MultiMesh count. Hostile textures, tint and telegraph hues are untouched.
uniform float accent_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(0.25, 0.68, 1.0, 1.0);
varying vec4 instance_color;

void vertex() {
	instance_color = COLOR;
	// Room for a soft halo while the sampled body keeps its original size.
	VERTEX *= vec2(1.18, 2.6);
	cover_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	cover_feet_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}

void fragment() {
	vec2 body_uv = (UV - vec2(0.5)) * vec2(1.18, 2.6) + vec2(0.5);
	float inside = step(0.0, body_uv.x) * step(body_uv.x, 1.0) * step(0.0, body_uv.y) * step(body_uv.y, 1.0);
	vec4 body = texture(TEXTURE, clamp(body_uv, vec2(0.0), vec2(1.0))) * instance_color;
	body.a *= inside;
	float along = smoothstep(0.01, 0.75, body_uv.x) * (1.0 - smoothstep(0.92, 1.08, body_uv.x));
	float cross_section = abs(body_uv.y - 0.5);
	float core = exp(-pow(cross_section / 0.052, 2.0)) * along;
	float halo = exp(-pow(cross_section / 0.48, 2.0)) * along * 0.40;
	float light_alpha = (core * 0.65 + halo) * accent_strength * instance_color.a;
	vec3 light = mix(glow_color.rgb, vec3(1.0, 0.96, 0.82), core);
	float combined = body.a + light_alpha * (1.0 - body.a);
	vec3 rgb = (body.rgb * body.a + light * light_alpha * (1.0 - body.a)) / max(combined, 0.0001);
	COLOR = vec4(mix(rgb, max(rgb, light), core * accent_strength * 0.55), combined);
	COLOR = world_cover_composite(COLOR, world_cover_strength(cover_world_position, cover_feet_y));
}
