extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261023-ground/GroundCarePreview.gd"
## Read-only role-uniform attribution for the existing normal city capture.


func _district_evidence() -> Dictionary:
	var result: Dictionary = super._district_evidence()
	result["capture_scene"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261023-ground/GroundPavingPreview.tscn"
	var material: ShaderMaterial = _chunks.get_ground_splat().get_shader_material()
	var samples: PackedVector4Array = material.get_shader_parameter(&"role_sample")
	var mids: PackedColorArray = material.get_shader_parameter(&"role_mid")
	var tints: PackedColorArray = material.get_shader_parameter(&"role_tint")
	var roles: Array[Dictionary] = []
	for role: int in samples.size():
		var sample: Vector4 = samples[role]
		var mid: Color = mids[role]
		var tint: Color = tints[role]
		roles.append({"role": role, "sample": [sample.x, sample.y, sample.z, sample.w], "mid": [mid.r, mid.g, mid.b, mid.a], "tint": [tint.r, tint.g, tint.b, tint.a]})
	result["ground_role_uniforms"] = roles
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GROUND_ART.GROUND_ARRAY_MANIFEST_PATH))
	result["round_cobble_source"] = {"layer": 9, "record": manifest["sources"][9]}
	return result
