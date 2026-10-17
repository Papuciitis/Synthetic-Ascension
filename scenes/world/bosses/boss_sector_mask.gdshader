shader_type canvas_item;

// Shows only the circular sector an attack covers: +X in the sprite's local
// space is the attack's facing, with `half_angle` radians either side. The
// raster art itself is unchanged; it is only clipped to the warned bound.
uniform float half_angle = 1.3;

void fragment() {
	vec2 p = UV - vec2(0.5);
	if (abs(atan(p.y, p.x)) > half_angle) {
		discard;
	}
	// COLOR already carries the texture and the sprite's modulate.
}
