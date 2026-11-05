extends RefCounted
## Narrow opt-in S7 prototype. Keep the original GPU program/resource untouched.
## Future source changes must explicitly requalify these unique hooks.

const LIGHT := "uniform sampler2D light_map : filter_linear, repeat_enable;"
const FRAGMENT := "void fragment() {"
const INSIDE := "float inside = 0.5 - yard_patch.y * 0.25 - field;"
const BOUNDS := "if (inside > -soft - 0.03) {"
const AMOUNT := "float amount = smoothstep(-soft, soft, inside);"
const DEBUG := "} else if (debug_view == 2) {"


static func build(base: Shader) -> Shader:
	if base == null:
		return null
	var code := base.code
	for hook in [LIGHT, FRAGMENT, INSIDE, BOUNDS, AMOUNT, DEBUG]:
		if code.count(hook) != 1:
			return null
	if code.contains("yard_support_map") or code.contains("yard_support_amount"):
		return null
	code = code.replace(LIGHT, LIGHT + "\nuniform sampler2D yard_support_map : filter_linear, repeat_enable;")
	code = code.replace(FRAGMENT, """// Unwarped cell-space, matching light_map. A zero centre may never receive
// a filtered neighbour; positive care vetoes the preview independently of CPU.
float yard_support_amount(vec2 p) {
	ivec2 cell = ivec2(mod(floor(p), map_size));
	if (texelFetch(yard_support_map, cell, 0).r <= 0.0 || texelFetch(light_map, cell, 0).b > 0.0) {
		return 0.0;
	}
	return clamp(texture(yard_support_map, p / map_size).r, 0.0, 0.86);
}

""" + FRAGMENT)
	code = code.replace(INSIDE, INSIDE + "\n\t\t\t\t\t\tfloat support = yard_support_amount(p);")
	code = code.replace(BOUNDS, "if (inside > -soft - 0.03 || support > 0.0) {")
	code = code.replace(AMOUNT, "float amount = max(smoothstep(-soft, soft, inside), support);")
	code = code.replace(DEBUG, "} else if (debug_view == 3) {\n\t\t\tcol = vec3(role == 4 ? yard_support_amount(p) : 0.0);\n\t\t" + DEBUG)
	var preview := Shader.new()
	preview.code = code
	return preview
