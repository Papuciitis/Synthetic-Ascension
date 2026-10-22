shader_type canvas_item;
// One cause-based stain quad (CityWeathering): rain or mineral runoff below a
// real sill, soot above a working vent. The mask's red channel is linear
// coverage (black = clean). The quad's vertex alpha carries the stain's
// strength, and the roof cutaway fades it with the facade group.
uniform sampler2D mask : hint_default_black, filter_linear_mipmap;
uniform vec3 stain = vec3(0.35);

void fragment() {
	float coverage = texture(mask, UV).r;
	COLOR = vec4(stain, coverage * COLOR.a);
}
