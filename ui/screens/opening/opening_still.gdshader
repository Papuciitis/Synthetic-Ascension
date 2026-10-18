shader_type canvas_item;

// An opening still arrives the way it was painted: broad slanted strokes
// wash in from the left, each with a warm wet rim while it lands, and leave
// the same way. `reveal` 1 is the plain painting, untouched; 0 is nothing.
// COLOR already carries the texture and the rect's modulate: only alpha
// (and the rim's warmth) change here.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D strokes : repeat_enable, filter_linear;
// The drawn rect in pixels: the pattern follows the rect, not the texture's
// UVs, so cropped stills (AtlasTexture) wash in the same way.
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float softness = 0.2;
// How strongly the wash leads from the left over the strokes' own order.
uniform float lead = 0.5;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.84, 0.58, 1.0);

varying vec2 local_uv;

void vertex() {
	local_uv = VERTEX / max(rect_size, vec2(1.0));
}

void fragment() {
	// Long, broad strokes on a slant, like the paintings' own brushwork.
	vec2 slant = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * local_uv;
	float broad = texture(strokes, slant * vec2(0.7, 2.2)).r;
	float fine = texture(strokes, slant * vec2(1.9, 5.2) + vec2(0.37, 0.11)).r;
	float pattern = clamp((mix(broad, fine, 0.3) - 0.5) * 1.7 + 0.5, 0.0, 1.0);
	// Each pixel's arrival time: the wash's lead, broken up by the strokes.
	float arrival = clamp(mix(pattern, local_uv.x * 0.85 + local_uv.y * 0.15, lead), 0.0, 1.0);
	float shown = smoothstep(arrival, arrival + softness, reveal * (1.0 + softness));
	float rim = shown * (1.0 - shown) * 4.0;
	vec4 painted = COLOR;
	painted.rgb = mix(painted.rgb, min(painted.rgb * rim_tint.rgb * 1.45, vec3(1.0)), rim * 0.45);
	painted.a *= shown;
	COLOR = painted;
}
