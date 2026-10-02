shader_type canvas_item;

// The Ascension tree's nodes in one instanced draw. Each instance is a quad
// round one node; this draws the node as a signed-distance shape, so its
// fill, rim and marks stay crisp at every zoom without a draw call apiece.
//
// AscensionTreeView packs per node:
//   COLOR            rim colour, and the node's alpha (the opening fades it)
//   INSTANCE_CUSTOM  fill colour, and a code: shape (bits 0-2: circle, hex,
//                    triangle, octagon, diamond, square), lens 8, pip 16,
//                    slash 32, equipped ring 64, outer ring 128, halo 256;
//                    the rim width / 4 rides in the fraction.
// A quad is the node's radius times 2.6 when it carries a halo, the outer
// ring or the equipped ring, 1.35 otherwise.

const vec3 GOLD = vec3(0.86, 0.64, 0.36);
const vec3 GOLD_BRIGHT = vec3(0.99, 0.84, 0.58);
const vec3 PARCHMENT = vec3(0.91, 0.86, 0.77);
const vec3 DANGER = vec3(0.86, 0.32, 0.24);

varying flat vec4 v_rim;
varying flat vec4 v_fill;

void vertex() {
	v_rim = COLOR;
	v_fill = INSTANCE_CUSTOM;
}

// A regular n-gon with a vertex at the top and circumradius r (mitred).
float sd_ngon(vec2 p, float r, float n) {
	float sector = TAU / n;
	float a = atan(p.y, p.x) + PI * 0.5 - sector * 0.5;
	float k = floor(a / sector + 0.5);
	float na = -PI * 0.5 + sector * 0.5 + k * sector;
	return dot(p, vec2(cos(na), sin(na))) - r * cos(PI / n);
}

// A line of width w px at signed distance d px, anti-aliased over a pixel.
float stroke(float d, float w) {
	return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, abs(d));
}

vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / a, a);
}

void fragment() {
	vec2 local = UV * 2.0 - 1.0;
	// Screen px per local unit: the quad's half size.
	float px = 1.0 / max(fwidth(local.x), 0.00001);
	int bits = int(floor(v_fill.a + 0.0005));
	float rim_width = fract(v_fill.a + 0.0005) * 4.0;
	int shape = bits & 7;
	bool wide = (bits & (256 | 128 | 64)) != 0;
	float rp = px / (wide ? 2.6 : 1.35);
	vec2 p = local * px;
	float d;
	if (shape == 1) {
		d = sd_ngon(p, rp, 6.0);
	} else if (shape == 2) {
		d = sd_ngon(p, rp, 3.0);
	} else if (shape == 3) {
		d = sd_ngon(p, rp, 8.0);
	} else if (shape == 4) {
		d = sd_ngon(p, rp, 4.0);
	} else if (shape == 5) {
		d = max(abs(p.x), abs(p.y)) - rp * 0.8;
	} else {
		d = length(p) - rp;
	}
	float inside = 1.0 - smoothstep(-0.6, 0.6, d);
	vec3 fill = v_fill.rgb;
	if ((bits & 8) != 0) {
		// The lit lens of an owned node, brightest a little above centre.
		fill = mix(fill, GOLD, (1.0 - smoothstep(0.0, rp * 0.78, length(p))) * 0.55);
		fill = mix(fill, GOLD_BRIGHT, (1.0 - smoothstep(0.0, rp * 0.44, length(p - vec2(0.0, -rp * 0.2)))) * 0.42);
	}
	if ((bits & 16) != 0 && rp > 3.0) {
		float pip = (abs(p.x) + abs(p.y) - rp * 0.27) * 0.7071;
		fill = mix(fill, PARCHMENT, (1.0 - smoothstep(-0.5, 0.5, pip)) * 0.92);
	}
	if ((bits & 32) != 0 && rp > 3.0) {
		vec2 a = vec2(-0.55, 0.55) * rp;
		vec2 ba = vec2(1.1, -1.1) * rp;
		vec2 pa = p - a;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		fill = mix(fill, DANGER, stroke(length(pa - ba * h), 1.3) * 0.7);
	}
	vec4 node = vec4(fill, inside);
	float rim = stroke(d, rim_width);
	node.rgb = mix(node.rgb, v_rim.rgb, rim);
	node.a = max(node.a, rim);
	vec4 c = vec4(0.0);
	if ((bits & 256) != 0) {
		float outside = max(d, 0.0);
		float glow = exp(-pow(outside / (rp * 0.95 + 3.0), 2.0)) * 0.26;
		c = vec4(GOLD, glow * (1.0 - smoothstep(0.82, 1.0, length(local))));
	}
	if ((bits & 64) != 0) {
		c = over(vec4(PARCHMENT, stroke(length(p) - (rp + 3.5), 1.2) * 0.85), c);
	}
	if ((bits & 128) != 0) {
		c = over(vec4(v_rim.rgb, stroke(length(p) - (rp + 3.0), 1.0) * 0.45), c);
	}
	c = over(node, c);
	COLOR = vec4(c.rgb, c.a * v_rim.a);
}
