extends Node

func _ready() -> void:
	var failures := 0
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var renderer := GroundSplatRenderer.new()
	add_child(renderer)
	renderer.configure(64,32)
	var method := renderer.has_method("set_city_streetscape")
	if not method:
		push_error("Production ground needs a reversible S2 streetscape material switch")
		failures += 1
	else:
		renderer.set_chunk_base(Vector2i.ZERO,0)
		renderer.paint_rect(Rect2i(2,2,8,3),7,0.9)
		renderer.paint_rect(Rect2i(2,5,8,1),2,0.9)
		var before := [renderer.material_at(Vector2i(3,3)),renderer.material_at(Vector2i(3,5)),renderer.material_at(Vector2i(3,6))]
		renderer.call("set_city_streetscape",true)
		var material := renderer.get_shader_material()
		if material.get_shader_parameter("city_streetscape") != true or material.get_shader_parameter("city_setts") == null or material.get_shader_parameter("city_limestone") == null:
			push_error("S2 shared ground must bind original city materials")
			failures += 1
		if before != [renderer.material_at(Vector2i(3,3)),renderer.material_at(Vector2i(3,5)),renderer.material_at(Vector2i(3,6))]:
			push_error("City rendering must preserve road, frontage and grass ownership")
			failures += 1
		renderer.call("set_city_streetscape",false)
		if material.get_shader_parameter("city_streetscape") != false:
			push_error("Other segments must retain their authored materials")
			failures += 1
	var old_segment := Global.attempt_segment
	var cm := ChunkManager.new()
	cm.generation_enabled = false
	add_child(cm)
	Global.attempt_segment = 2
	var shared := cm._ensure_ground_splat()
	if shared.get_shader_material().get_shader_parameter("city_streetscape") != true:
		push_error("Actual ChunkManager must enable shared city presentation in S2")
		failures += 1
	Global.attempt_segment = 3
	cm._ensure_ground_splat()
	if shared.get_shader_material().get_shader_parameter("city_streetscape") != false:
		push_error("Reused ground renderer must disable S2 presentation outside S2")
		failures += 1
	Global.attempt_segment = old_segment
	print("CityGenerationMaterialTest: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
