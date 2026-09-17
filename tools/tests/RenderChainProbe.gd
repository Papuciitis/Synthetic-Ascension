extends Node

class Driver:
	extends Node
	var _elapsed := 0.0
	var _wall := 0.0
	var _phase := 1

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		Global.goto_game()

	func _dismiss() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _process(delta: float) -> void:
		if _phase != 1:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss()
			return
		_elapsed += delta
		if _elapsed < 5.0:
			return
		_phase = 2
		var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
		var filter := get_node_or_null("/root/DebugEnemySpawnFilter")
		filter.set("cap_mode", 2)
		spawner.call("debug_force_spawn", 60)
		await get_tree().create_timer(2.0).timeout
		var scene := get_tree().current_scene
		print("PROBE scene=", scene.name)
		var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		print("PROBE proxy_root_found=", proxy_root != null)
		if proxy_root != null:
			var parent := proxy_root.get_parent()
			print("PROBE proxy_root_index=", proxy_root.get_index(), " of ", parent.get_child_count(), " parent=", parent.name)
			var after: Array = []
			for i in range(proxy_root.get_index() + 1, parent.get_child_count()):
				after.append(parent.get_child(i).name)
			print("PROBE siblings_after=", after)
			var renderer: Node = proxy_root.get("renderer")
			print("PROBE renderer=", renderer != null, " actors=", renderer.call("registered_actor_count"), " visible=", renderer.call("visible_count"), " batches=", renderer.call("batch_count"))
			for child in renderer.get_children():
				var mm := (child as MultiMeshInstance2D)
				if mm != null and mm.multimesh != null:
					print("PROBE batch ", child.name, " vis_count=", mm.multimesh.visible_instance_count, " inst_count=", mm.multimesh.instance_count, " visible=", mm.visible, " global_pos=", mm.global_position, " z=", mm.z_index)
		var index := get_node_or_null("/root/EnemyIndex")
		var sample: Node = null
		for enemy in (index.call("get_all") as Array):
			if enemy != null and is_instance_valid(enemy):
				sample = enemy
				break
		if sample != null:
			var spr := sample.get_node_or_null("Sprite2D") as Sprite2D
			print("PROBE sample_enemy batched=", sample.get("_visual_batched"), " sprite_visible=", spr.visible if spr != null else "none", " tex=", spr.texture.resource_path.get_file() if spr != null and spr.texture != null else "none")
		var failures := 0
		var drawn := 0
		if proxy_root != null:
			var renderer2: Node = proxy_root.get("renderer")
			for child in renderer2.get_children():
				var mm := child as MultiMeshInstance2D
				if mm != null and mm.multimesh != null:
					drawn += mm.multimesh.visible_instance_count
			if int(renderer2.call("registered_actor_count")) <= 0:
				failures += 1
				push_error("FAIL: no actors registered with the batch renderer")
			if drawn <= 0:
				failures += 1
				push_error("FAIL: no batched instances drawn in a live game")
			if int(proxy_root.get("z_index")) < 10:
				failures += 1
				push_error("FAIL: enemy batches lost their layer backstop")
		else:
			failures += 1
			push_error("FAIL: proxy root missing")
		print("RenderChainProbe: %d drawn, %d failed" % [drawn, failures])
		get_tree().quit(1 if failures > 0 else 0)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
