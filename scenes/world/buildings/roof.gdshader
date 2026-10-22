shader_type canvas_item;

// Textured roof (RoofOverlay.gd, building pass 2026-09-27). The roof art is a
// flat shingle field; this gives it a gable so the building reads as a mass
// under the one top-right sun (WorldDepthStyle): the slope facing the light
// brighter, the other in shade, each slope opening toward the ridge, a lit
// ridge cap with a dark line under it on the shaded side, and a directional
// edge: north/east rims catch light while south/west eaves drip into shade.
// Footprints that are not rectangles (L shapes) skip the gable and keep only
// the edges. eave_px scales every edge cue; ~0 disables them (fascia strips).

uniform vec4 bounds = vec4(0.0, 0.0, 256.0, 256.0);
uniform float ridge_along_x = 1.0;
uniform float gable = 1.0;
uniform float lit_slope = 1.12;
uniform float shade_slope = 0.72;
uniform float ridge_light = 0.4;
uniform float eave_px = 12.0;
// Defaults preserve existing city roofs; the composed first-block kit quiets
// its material units while keeping the structural ridge/eave shading crisp.
uniform float material_contrast = 1.0;
uniform vec3 material_mid = vec3(0.3);
// Sky opening toward the ridge (+/-), lit north/east rim, south/west drip.
uniform float pitch_gradient = 0.06;
uniform float rim_light = 0.08;
uniform float drip_shade = 0.74;
uniform float under_ridge = 0.84;

varying vec2 local_pos;
varying vec4 surface_tint;
varying flat float plane_seed;
// Lichen near shaded eaves (CityWeathering). The lead's roof_lichen mask
// (512x512, eave strip at the bottom, red = linear coverage) maps onto the
// plane's south eave band and repeats along it; the theme sets the strength
// once through project shader globals (0 = clean), and each roof plane varies
// by a stable hash of its world position. It moves and fades with the roof.
global uniform float sa_weather_lichen;
global uniform vec4 sa_weather_lichen_tint;
global uniform sampler2D sa_weather_lichen_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
const float LICHEN_BAND_PX = 112.0;

void vertex() {
	local_pos = VERTEX;
	surface_tint = COLOR;
	vec2 origin = floor((MODEL_MATRIX * vec4(bounds.xy, 0.0, 1.0)).xy / 16.0);
	plane_seed = fract(sin(dot(origin, vec2(39.3468, 11.1355))) * 24634.6345);
}

void fragment() {
	// COLOR already carries the texture (Godot 4 canvas_item).
	vec4 c = COLOR;
	c.rgb = mix(material_mid * surface_tint.rgb, c.rgb, material_contrast);
	vec2 size = max(bounds.zw - bounds.xy, vec2(1.0));
	vec2 local = local_pos - bounds.xy;
	vec2 t = local / size;
	float shade = 1.0;
	if (gable > 0.5) {
		bool along_x = ridge_along_x > 0.5;
		// Seen from the south at a steep angle, the far (north) slope is
		// foreshortened, so the ridge sits above the middle.
		float across = along_x ? t.y : t.x;
		float ridge = along_x ? 0.42 : 0.5;
		float span = along_x ? size.y : size.x;
		// Light from the top right: the north slope of an east-west ridge,
		// the EAST slope of a north-south one.
		bool lit = along_x ? across < ridge : across > ridge;
		shade = lit ? lit_slope : shade_slope;
		float d = abs(across - ridge) * span;
		float slope = max(1.0, (across < ridge ? ridge : 1.0 - ridge) * span);
		shade *= mix(1.0 - pitch_gradient, 1.0 + pitch_gradient, 1.0 - clamp(d / slope, 0.0, 1.0));
		shade += smoothstep(4.0, 0.0, d) * ridge_light;
		if (!lit) {
			shade *= mix(under_ridge, 1.0, smoothstep(3.0, 9.0, d));
		}
	}
	float edge = clamp(eave_px / 12.0, 0.0, 1.0);
	float rim_px = max(0.01, 3.0 * edge);
	float drip_px = max(0.01, 9.0 * edge);
	float lit_rim = max(smoothstep(rim_px, 0.0, local.y), smoothstep(rim_px, 0.0, size.x - local.x));
	float drip = max(smoothstep(drip_px, 0.0, size.y - local.y), smoothstep(drip_px * 0.75, 0.0, local.x));
	shade *= 1.0 + rim_light * edge * lit_rim;
	shade *= mix(1.0, drip_shade, drip * edge);
	if (sa_weather_lichen > 0.0) {
		float above_eave = size.y - local.y;
		if (above_eave < LICHEN_BAND_PX) {
			vec2 lichen_uv = vec2(local.x / 512.0 + plane_seed * 5.0, 1.0 - above_eave / LICHEN_BAND_PX);
			float coverage = texture(sa_weather_lichen_mask, vec2(lichen_uv.x, min(lichen_uv.y, 0.995))).r;
			// Shaded slopes and older (high-seed) roofs carry more growth.
			float shaded = shade < 1.0 ? 1.0 : 0.55;
			float amount = coverage * sa_weather_lichen * shaded * mix(0.4, 1.5, plane_seed);
			c.rgb = mix(c.rgb, sa_weather_lichen_tint.rgb * dot(c.rgb, vec3(0.333)) * 1.6, clamp(amount * 2.5, 0.0, 1.0));
		}
	}
	COLOR = vec4(c.rgb * shade, c.a);
}
