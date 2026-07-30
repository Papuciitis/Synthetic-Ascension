extends Node

const CYCLES := 12
const PER_CYCLE := 40

var _failures := 0
var _peak_indexed := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var index := get_node("/root/EnemyIndex")
	var spawner := EnemySpawner.new()
	add_child(spawner)
	await get_tree().process_frame
	for cycle in range(CYCLES):
		var created: Array[Node2D] = []
		for i in range(PER_CYCLE):
			var enemy := Node2D.new()
			enemy.add_to_group(&"enemies")
			enemy.position = Vector2(5000.0 + float(i * 10), float(cycle * 64))
			match i % 4:
				1:
					enemy.set_meta("special_spawn_kind", &"split")
				2:
					enemy.set_meta("special_spawn_kind", &"interior")
					enemy.set_meta("interior_active", false)
				3:
					enemy.set_meta("special_spawn_kind", &"boss_add")
					enemy.set_meta("encounter_active", false)
			add_child(enemy)
			index.call("register", enemy)
			created.append(enemy)
		_peak_indexed = maxi(_peak_indexed, int(index.call("alive_count")))
		for enemy in created:
			if spawner.call("is_enemy_cull_eligible", enemy, Vector2.ZERO):
				index.call("retire_enemy", enemy, &"stress")
		await get_tree().process_frame
		var indexed := int(index.call("alive_count"))
		var scene_count := get_tree().get_node_count_in_group(&"enemies")
		if indexed != 0 or scene_count != 0:
			_failures += 1
			push_error(
				"Stress cycle %d retained scene/index enemies: %d/%d"
				% [cycle, scene_count, indexed]
			)
	print(
		"EnemyLifecycleStressTest: cycles=%d spawned=%d peak_indexed=%d failures=%d"
		% [CYCLES, CYCLES * PER_CYCLE, _peak_indexed, _failures]
	)
	get_tree().quit(1 if _failures > 0 else 0)
