shader_type canvas_item;

// Textured roof (RoofOverlay.gd, building pass 2026-09-27). The roof art is a
// flat shingle field; this gives it a gable so the building reads as a mass:
// the slope facing the light (top right) a touch brighter, the other in
// shade, a lit ridge between them, and darker eaves at the roof's edge. Footprints that are not rectangles (L shapes) skip the gable
// and keep only the eaves.

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

varying vec2 local_pos;
varying vec4 surface_tint;

void vertex() {
	local_pos = VERTEX;
	surface_tint = COLOR;
}

void fragment() {
	// COLOR already carries the texture (Godot 4 canvas_item).
	vec4 c = COLOR;
	c.rgb = mix(material_mid * surface_tint.rgb, c.rgb, material_contrast);
	vec2 size = max(bounds.zw - bounds.xy, vec2(1.0));
	vec2 t = (local_pos - bounds.xy) / size;
	float shade = 1.0;
	if (gable > 0.5) {
		bool along_x = ridge_along_x > 0.5;
		// Seen from the south at a steep angle, the far (north) slope is
		// foreshortened, so the ridge sits above the middle.
		float across = along_x ? t.y : t.x;
		float ridge = along_x ? 0.42 : 0.5;
		// Light from the top right: the north slope of an east-west ridge,
		// the EAST slope of a north-south one.
		bool lit = along_x ? across < ridge : across > ridge;
		shade = lit ? lit_slope : shade_slope;
		float d = abs(across - ridge) * (along_x ? size.y : size.x);
		shade += smoothstep(4.0, 0.0, d) * ridge_light;
	}
	float edge = min(min(t.x, 1.0 - t.x) * size.x, min(t.y, 1.0 - t.y) * size.y);
	shade *= mix(0.68, 1.0, smoothstep(0.0, eave_px, edge));
	COLOR = vec4(c.rgb * shade, c.a);
}
