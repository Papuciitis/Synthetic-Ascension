shader_type canvas_item;
render_mode blend_mul;

// Broad physical sky variation on the world canvas; no camera-edge darkness.
// The CPU supplies a presentation clock so accessibility can freeze phase.
uniform vec4 environment_tint : source_color = vec4(1.0);
uniform vec4 ambient_fill : source_color = vec4(0.98, 0.99, 1.0, 1.0);
uniform float direct_light = 1.0;
uniform float cloud_opacity = 0.0;
uniform float cloud_scale_px = 880.0;
uniform vec2 cloud_velocity = vec2(0.0);
uniform float weather_time = 0.0;
uniform bool weather_motion_enabled = true;
uniform float frozen_weather_time = 0.0;
varying vec2 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float phase = weather_motion_enabled ? weather_time : frozen_weather_time;
	vec2 p = (world_position - cloud_velocity * phase) / max(1.0, cloud_scale_px);
	float field = 0.75 * cloud_noise(p) + 0.25 * cloud_noise(p * 1.73 + vec2(14.0, 7.0));
	float cloud = smoothstep(0.32, 0.72, field);
	vec3 sky = mix(ambient_fill.rgb, vec3(1.0), clamp(direct_light, 0.0, 1.0));
	vec3 daylight = environment_tint.rgb * sky * (1.0 - cloud * clamp(cloud_opacity, 0.0, 0.18));
	COLOR = vec4(daylight, 1.0);
}
