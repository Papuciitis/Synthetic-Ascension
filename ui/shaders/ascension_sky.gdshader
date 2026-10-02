shader_type canvas_item;

// The sky behind the Ascension tree: a dark, warm field with a slow nebula,
// two parallax layers of twinkling stars, the ember glow of the core, the six
// orbits the nodes sit on (with slow-turning ticks), the three territory
// borders, a turning rete round the core and the fixed limb with its degree
// scale. One fullscreen pass.
//
// AscensionTreeView writes the transform uniforms only when the view moves,
// `t` once a frame from real time (so a frozen Engine.time_scale cannot stop
// it), and `wake` / `sweep` only while the opening plays.

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 view_size = vec2(1920.0, 1080.0);
// Screen px of the tree's centre, and of the limb's (a little parallax).
uniform vec2 tree_center = vec2(960.0, 540.0);
uniform vec2 deco_center = vec2(960.0, 540.0);
// The pan away from rest in screen px; the far layers follow a share of it.
uniform vec2 pan = vec2(0.0);
uniform float zoom = 0.6;
uniform float t = 0.0;
// Opening: the glow and the sky fade in with `wake`, rings unfurl with `sweep`.
uniform float wake = 1.0;
uniform float sweep = 1.0;
// 0 under reduced motion: the ticks, rete and nebula hold still and the far
// layers stop sliding against the tree.
uniform float spin = 1.0;
uniform float parallax = 1.0;
uniform vec4 rings_a = vec4(150.0, 300.0, 440.0, 560.0);
uniform vec2 rings_b = vec2(680.0, 800.0);
uniform float limb_inner = 836.0;
uniform float limb_outer = 866.0;
// Unit directions of the three territory borders (two in xy / zw, one alone).
uniform vec4 border_dirs = vec4(0.866, -0.5, 0.0, 1.0);
uniform vec2 border_dir_c = vec2(-0.866, -0.5);
uniform vec3 cores = vec3(-90.0, 30.0, 150.0);
// 1 for each territory the run has opened (the limb warms over it).
uniform vec3 core_lit = vec3(1.0, 0.0, 0.0);

const vec3 BASE = vec3(0.024, 0.021, 0.018);
const vec3 GOLD = vec3(0.86, 0.64, 0.36);
const vec3 GOLD_DIM = vec3(0.62, 0.47, 0.30);
const vec3 EMBER = vec3(1.0, 0.62, 0.30);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 star_layer(vec2 p, float cell, float density, float seed) {
	vec2 g = p / cell;
	vec2 id = floor(g);
	float h = hash12(id + seed);
	if (h > density) {
		return vec3(0.0);
	}
	float k = h / density;
	vec2 spot = hash22(id + seed * 1.7) * 0.7 + 0.15;
	float d = length(fract(g) - spot) * cell;
	float size = mix(0.5, 1.35, k * k);
	float core = 1.0 - smoothstep(0.0, size, d);
	float halo = exp(-d * d / (size * size * 9.0)) * 0.28;
	float twinkle = 0.5 + 0.5 * sin(t * (0.45 + fract(k * 13.7) * 1.9) + h * 517.0);
	vec3 tint = mix(vec3(1.0, 0.88, 0.72), vec3(0.62, 0.74, 1.0), step(0.86, fract(k * 7.31)));
	return tint * (core + halo) * mix(0.3, 1.0, twinkle) * mix(0.45, 1.0, k);
}

// A one-pixel anti-aliased line at `d` px from its centre.
float hair(float d) {
	return clamp(1.0 - abs(d), 0.0, 1.0);
}

// A radial tick every `step_deg` degrees, one pixel wide at radius `r_px`.
float tick(float deg, float step_deg, float r_px) {
	float f = fract(deg / step_deg + 0.5) - 0.5;
	return clamp(1.0 - abs(f * step_deg * (PI / 180.0) * r_px), 0.0, 1.0);
}

float ang_diff(float a, float b) {
	return mod(a - b + 540.0, 360.0) - 180.0;
}

float inside(float x, float a, float b) {
	return step(a, x) * step(x, b);
}

// 0 at the top, rising clockwise to 1: where an unfurling sweep has reached.
float from_top(float deg) {
	return fract((deg + 90.0) / 360.0 + 1.0);
}

// One orbit at `near` px from the pixel: the ring line, its slow-turning
// ticks and, while it unfurls, the bright head of the sweep. Only the nearest
// orbit is ever evaluated, and only within a few px of it.
float orbit(float r, float deg, float rp, float near, float index, inout float head) {
	float reach = clamp(sweep * 1.45 - index * 0.075, 0.0, 1.0);
	float along = from_top(deg);
	float shown = reach >= 1.0 ? 1.0 : 1.0 - smoothstep(reach - 0.012, reach, along);
	float line = hair(near) * 0.85;
	float turning = deg + (mod(index, 2.0) < 0.5 ? 1.0 : -1.0) * t * spin * (0.55 + index * 0.12);
	float spacing = (PI / 18.0) * rp;
	float ticks = tick(turning, 10.0, r) * (1.0 - smoothstep(2.0, 3.6, near)) * smoothstep(5.0, 9.0, spacing) * 0.55;
	if (reach < 1.0) {
		float gap = (along - reach) * TAU * rp;
		head += hair(near) * exp(-gap * gap / 260.0) * step(along, reach + 0.01);
	}
	return max(line, ticks) * shown;
}

// A ray from the centre along unit `dir`: one px wide, forward half only.
float ray(vec2 d, vec2 dir) {
	return hair(abs(d.x * dir.y - d.y * dir.x)) * step(0.0, dot(d, dir));
}

void fragment() {
	vec2 px = UV * view_size;
	vec3 col = BASE;

	// Nebula: three channels of the cloud noise, mostly umber and ember with
	// a cold arcane bloom where the third gathers.
	float drift = t * spin;
	float zs = pow(max(zoom, 0.05) / 0.6, 0.16);
	vec2 np = (px - view_size * 0.5 - pan * 0.2 * parallax) / (780.0 * zs);
	vec3 broad = texture(noise_tex, np + vec2(drift * 0.0036, drift * 0.0021)).rgb;
	float n1 = broad.r;
	float n3 = broad.b;
	float n2 = texture(noise_tex, np * 2.2 + vec2(-drift * 0.0058, drift * 0.0034) + n1 * 0.12).g;
	float neb = smoothstep(0.44, 0.94, n1 * 0.62 + n2 * 0.38);
	vec3 neb_col = mix(vec3(0.19, 0.10, 0.048), vec3(0.34, 0.18, 0.08), n2);
	neb_col = mix(neb_col, vec3(0.08, 0.12, 0.28), smoothstep(0.62, 0.9, n3) * 0.5);
	col += neb_col * neb * 0.30 * wake;

	// Stars: a fine far layer and a sparser near one.
	vec3 stars = star_layer(px - pan * 0.08 * parallax, 33.0, 0.085, 3.1) * 0.55;
	stars += star_layer(px - pan * 0.28 * parallax, 64.0, 0.13, 9.7) * 0.9;
	col += stars * (1.0 - neb * 0.45) * wake;

	// The core's ember glow, tied to the tree.
	vec2 d = px - tree_center;
	float r = length(d);
	float rz = r / max(zoom, 0.01);
	float wide_glow = max(1.0 - rz * rz / (900.0 * 900.0), 0.0);
	float near_glow = max(1.0 - rz * rz / (240.0 * 240.0), 0.0);
	col += EMBER * (wide_glow * wide_glow * wide_glow * 0.07 + near_glow * near_glow * near_glow * 0.07) * wake;

	// The six orbits: only the nearest is evaluated, and only close to it.
	float best = 1e6;
	float best_rp = 0.0;
	float best_index = 0.0;
	vec4 ra = rings_a * zoom;
	vec2 rb = rings_b * zoom;
	float dist = abs(r - ra.x);
	if (dist < best) { best = dist; best_rp = ra.x; best_index = 0.0; }
	dist = abs(r - ra.y);
	if (dist < best) { best = dist; best_rp = ra.y; best_index = 1.0; }
	dist = abs(r - ra.z);
	if (dist < best) { best = dist; best_rp = ra.z; best_index = 2.0; }
	dist = abs(r - ra.w);
	if (dist < best) { best = dist; best_rp = ra.w; best_index = 3.0; }
	dist = abs(r - rb.x);
	if (dist < best) { best = dist; best_rp = rb.x; best_index = 4.0; }
	dist = abs(r - rb.y);
	if (dist < best) { best = dist; best_rp = rb.y; best_index = 5.0; }
	float rete_r = 104.0 * zoom;
	float rete_near = r - rete_r;
	bool in_rete = rete_near > -2.0 && rete_near < 13.0 * zoom + 4.0;
	if (best < 6.0 || in_rete) {
		float deg = degrees(atan(d.y, d.x));
		if (best < 6.0) {
			float head = 0.0;
			float orbits = orbit(r, deg, best_rp, best, best_index, head);
			col += GOLD_DIM * orbits * 0.24;
			col += vec3(1.0, 0.82, 0.55) * head * 0.9;
		}
		if (in_rete) {
			// The rete: a turning dial between the core anchors and the first orbit.
			float rete_turn = deg + t * spin * 1.6;
			float rete = hair(rete_near) * 0.7;
			rete = max(rete, tick(rete_turn, 7.5, r) * inside(rete_near, 0.0, 6.0 * zoom + 2.0) * 0.6);
			rete = max(rete, tick(rete_turn, 30.0, r) * inside(rete_near, 0.0, 13.0 * zoom + 3.0));
			col += GOLD_DIM * rete * 0.3 * smoothstep(0.0, 0.35, sweep);
		}
	}

	// Territory borders, fading toward the limb, drawn out as the sweep runs.
	if (rz > 70.0 && rz < limb_inner) {
		float border = ray(d, border_dirs.xy) + ray(d, border_dirs.zw) + ray(d, border_dir_c);
		float border_fade = smoothstep(70.0, 120.0, rz) * (1.0 - smoothstep(520.0, limb_inner, rz));
		border *= border_fade * (1.0 - smoothstep(sweep * limb_inner * 1.1, sweep * limb_inner * 1.1 + 40.0, rz));
		col += GOLD_DIM * border * 0.15;
	}

	// The limb: fixed degree scale, a little behind the tree, with gaps where
	// the territory names sit. The arc over an opened territory warms.
	vec2 dd = px - deco_center;
	float rr = length(dd);
	float l0 = limb_inner * zoom;
	float l1 = limb_outer * zoom;
	if (rr > l0 - 2.0 && rr < l1 + max(4.0 * zoom, 2.5) + 2.0) {
		float ddeg = degrees(atan(dd.y, dd.x));
		float bw = l1 - l0;
		float limb = max(hair(rr - l0), hair(rr - l1)) * 0.9 + hair(rr - l1 - max(4.0 * zoom, 2.5)) * 0.35;
		float gap = smoothstep(9.0, 10.5, abs(ang_diff(ddeg, cores.x)));
		gap *= smoothstep(9.0, 10.5, abs(ang_diff(ddeg, cores.y)));
		gap *= smoothstep(9.0, 10.5, abs(ang_diff(ddeg, cores.z)));
		float spacing = (PI / 180.0) * l0;
		float minor = tick(ddeg, 1.0, rr) * inside(rr, l0, l0 + bw * 0.28) * smoothstep(2.6, 4.6, spacing) * 0.55;
		float mid = tick(ddeg, 5.0, rr) * inside(rr, l0, l0 + bw * 0.52) * 0.8;
		float major = tick(ddeg, 15.0, rr) * inside(rr, l0, l1);
		limb = max(limb, max(minor, max(mid, major)) * gap);
		float lit = core_lit.x * step(abs(ang_diff(ddeg, cores.x)), 60.0);
		lit = max(lit, core_lit.y * step(abs(ang_diff(ddeg, cores.y)), 60.0));
		lit = max(lit, core_lit.z * step(abs(ang_diff(ddeg, cores.z)), 60.0));
		float limb_shown = 1.0 - smoothstep(sweep * 1.2 - 0.25 - 0.012, sweep * 1.2 - 0.25, from_top(ddeg));
		limb_shown = sweep >= 1.0 ? 1.0 : limb_shown;
		col += mix(GOLD_DIM, GOLD, lit) * limb * mix(0.26, 0.4, lit) * limb_shown;
	}

	// A vignette pulls the corners into the dark.
	vec2 q = (UV - 0.5) * vec2(view_size.x / max(view_size.y, 1.0), 1.0);
	col *= 1.0 - smoothstep(0.42, 1.05, length(q)) * 0.6;
	COLOR = vec4(col, 1.0);
}
