shader_type canvas_item;
// A flat card face (rendered into a SubViewport) shown as a card in space.
//
// Perspective: every output pixel casts a ray from a camera `focal` card
// heights away through the screen plane and meets the card's plane, rotated
// by tilt (degrees about X, then Y). A true homography per pixel, so there is
// no affine seam however far it leans. The quad is inflated by `inflate` so a
// leaning corner has room to swing outside the rest rectangle.
//
// Light: a specular glare that slides opposite the tilt (the light stays put,
// the card moves under it), a glaze sweep (`sweep` runs -0.4 -> 1.9 once when
// the card is dealt or picked), and a faint foil shimmer while it is held.
// Past 90 degrees the back face shows (`back_tex`, mirrored).

uniform vec2 rect_size = vec2(250.0, 380.0);
uniform vec2 tilt = vec2(0.0, 0.0);          // degrees: x = pitch, y = yaw
uniform float focal = 2.4;                   // camera distance, card heights
uniform float inflate = 0.18;
uniform float glare = 0.0;                   // 0..1
uniform float sweep = -1.0;                  // glaze band position along the diagonal
uniform float sweep_strength = 0.55;
uniform float foil = 0.0;                    // 0..1
uniform float shade = 1.0;
uniform sampler2D back_tex : source_color, filter_linear;
uniform bool has_back = false;

varying vec2 q;
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 centred = UV - 0.5;
	VERTEX += centred * rect_size * inflate;
	q = centred * (1.0 + inflate) * rect_size / rect_size.y;
}

mat3 rot_x(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

void fragment() {
	float aspect = rect_size.x / rect_size.y;
	mat3 r = rot_y(radians(tilt.y)) * rot_x(radians(tilt.x));
	vec3 n = r * vec3(0.0, 0.0, 1.0);
	vec3 eye = vec3(0.0, 0.0, focal);
	vec3 dir = vec3(q.x, q.y, -focal);
	float denom = dot(n, dir);
	if (abs(denom) < 1e-5) {
		discard;
	}
	float t = -dot(n, eye) / denom;
	vec3 hit = eye + dir * t;
	vec3 local = transpose(r) * hit;
	vec2 uv = vec2(local.x / aspect + 0.5, local.y + 0.5);
	vec2 edge = min(uv, 1.0 - uv);
	float inside = smoothstep(-0.002, 0.004, min(edge.x, edge.y));
	if (t <= 0.0 || inside <= 0.0) {
		discard;
	}
	bool facing = n.z > 0.0;
	vec4 c;
	if (facing || !has_back) {
		c = texture(TEXTURE, uv);
	} else {
		c = texture(back_tex, vec2(1.0 - uv.x, uv.y));
	}
	// Light falls from the upper left; a card turned from it darkens a little.
	float lean = clamp(dot(n, normalize(vec3(-0.35, -0.45, 1.0))), 0.0, 1.0);
	c.rgb *= mix(0.78, 1.04, lean) * shade;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// Specular glare: where the reflected light lands on the face.
	vec2 spot = vec2(0.5, 0.5) + vec2(-tilt.y, tilt.x) / 40.0;
	float g = exp(-pow(distance(uv * vec2(aspect, 1.0), spot * vec2(aspect, 1.0)) * 2.4, 2.0));
	c.rgb += vec3(1.0, 0.93, 0.8) * g * glare * 0.42;
	// The glaze: one diagonal band of wet light.
	float band = exp(-pow((uv.x * 0.8 + uv.y * 0.6 - sweep) * 7.5, 2.0));
	c.rgb += vec3(1.0, 0.95, 0.85) * band * sweep_strength * (0.35 + 0.65 * smoothstep(0.05, 0.6, lum));
	// Foil: a thin iridescence that shifts with the lean.
	vec3 hue = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + uv.x * 0.8 - uv.y * 0.5 + tilt.y * 0.015 - tilt.x * 0.01));
	c.rgb = mix(c.rgb, c.rgb * (0.75 + hue * 0.5), foil * 0.35 * smoothstep(0.2, 0.75, lum));
	c.a *= inside;
	COLOR = c * v_modulate;
}
