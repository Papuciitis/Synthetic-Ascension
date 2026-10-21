extends Node
## District ground presentation is a per-family policy (DistrictGroundPolicy),
## not an S2-only switch: every procedural theme binds its own palette, the
## S11+ fallback shares Service Courtyards, and S1/Hub (no family) keep the
## original raw palette. Presentation never changes material ownership.

const POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")


func _ready() -> void:
	var failures := 0
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var renderer := GroundSplatRenderer.new()
	add_child(renderer)
	renderer.configure(64,32)
	if not renderer.has_method("set_ground_policy") or not renderer.has_method("set_ground_family"):
		push_error("Production ground needs a reversible per-family district presentation")
		failures += 1
	else:
		renderer.set_chunk_base(Vector2i.ZERO,6)
		renderer.paint_rect(Rect2i(2,2,8,3),7,0.9)
		renderer.paint_rect(Rect2i(2,5,8,1),2,0.9)
		renderer.paint_rect(Rect2i(12,2,4,4),0,0.95)
		var probes := [Vector2i(3,3),Vector2i(3,5),Vector2i(3,6),Vector2i(13,3)]
		var before: Array = []
		for cell: Vector2i in probes: before.append(renderer.material_at(cell))
		var slots_before: PackedInt32Array = renderer.active_slot_materials()
		var material := renderer.get_shader_material()
		renderer.set_ground_family(&"service_courtyards")
		if material.get_shader_parameter("policy_enabled") != true or material.get_shader_parameter("city_setts") == null or material.get_shader_parameter("city_limestone") == null:
			push_error("A district family must bind its original city materials")
			failures += 1
		var roles: PackedFloat32Array = material.get_shader_parameter("slot_role")
		var expected_roles := {6: POLICY.ROLE_YARD, 7: POLICY.ROLE_ROAD, 2: POLICY.ROLE_FOOTWAY, 0: POLICY.ROLE_LAWN}
		var slot_materials: PackedInt32Array = renderer.get("_slot_material")
		for slot in roles.size():
			var index := int(slot_materials[slot])
			if index >= 0 and int(roles[slot]) != int(expected_roles.get(index, -99)):
				push_error("Slot %d (material %d) must present as role %d, got %d" % [slot, index, int(expected_roles.get(index, -99)), int(roles[slot])])
				failures += 1
		var after: Array = []
		for cell: Vector2i in probes: after.append(renderer.material_at(cell))
		if before != after or slots_before != renderer.active_slot_materials():
			push_error("District rendering must preserve road, frontage, yard and grass ownership and slots")
			failures += 1
		var sett_road: Vector4 = (material.get_shader_parameter("role_sample") as PackedVector4Array)[POLICY.ROLE_ROAD]
		renderer.set_ground_family(&"inner_district_gate")
		var gate_road: Vector4 = (material.get_shader_parameter("role_sample") as PackedVector4Array)[POLICY.ROLE_ROAD]
		if int(sett_road.x) != POLICY.SOURCE_SETTS or int(gate_road.x) != POLICY.SOURCE_FLAGS:
			push_error("Families must change the actual road source (S2 setts, S5 ashlar flags): %s / %s" % [sett_road, gate_road])
			failures += 1
		renderer.set_ground_family(&"")
		if material.get_shader_parameter("policy_enabled") != false or float(material.get_shader_parameter("kerb_strength")) != 0.0 or float(material.get_shader_parameter("ao_strength")) != 0.0:
			push_error("Authored worlds without a district family must retain their raw materials")
			failures += 1
	var old_segment := Global.attempt_segment
	var cm := ChunkManager.new()
	cm.generation_enabled = false
	add_child(cm)
	Global.attempt_segment = 2
	cm.district_family = &"service_courtyards"
	var shared := cm._ensure_ground_splat()
	if shared.get_shader_material().get_shader_parameter("policy_enabled") != true or StringName(shared.ground_policy().get("id", &"")) != &"service_courtyards":
		push_error("Actual ChunkManager must present the S2 family's district ground")
		failures += 1
	Global.attempt_segment = 3
	cm.district_family = &"checkpoint_lanes"
	cm._ensure_ground_splat()
	if StringName(shared.ground_policy().get("id", &"")) != &"checkpoint_lanes" or shared.get_shader_material().get_shader_parameter("policy_enabled") != true:
		push_error("Reused ground renderer must switch to the S3 family's own ground")
		failures += 1
	Global.attempt_segment = 11
	cm.district_family = &"service_courtyards"
	cm._ensure_ground_splat()
	if StringName(shared.ground_policy().get("id", &"")) != &"service_courtyards":
		push_error("The S11+ fallback theme keeps the Service Courtyards ground (keyed by family, not segment)")
		failures += 1
	Global.attempt_segment = 1
	cm.district_family = &""
	cm._ensure_ground_splat()
	if shared.get_shader_material().get_shader_parameter("policy_enabled") != false:
		push_error("S1/Hub without a district family must disable district presentation")
		failures += 1
	Global.attempt_segment = old_segment
	print("CityGenerationMaterialTest: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
