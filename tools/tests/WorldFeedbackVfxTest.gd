extends Node

# The textured burst layer: every kind loads, plays from the pool, fires
# `finished` back into the pool, and the death listener is capped per frame.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/WorldFeedbackVfxTest.tscn

const DEATH_CONTEXT := preload("res://core/systems/enemy_world/EnemyDeathContext.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _bursts() -> Array:
	var out: Array = []
	for child in get_tree().current_scene.get_children():
		if child is VfxBurst:
			out.append(child)
	return out


func _run() -> void:
	var feedback := get_node_or_null("/root/WorldFeedbackVfx")
	_check(feedback != null, "the WorldFeedbackVfx autoload is present")
	var all_load := true
	for kind in VfxBursts.kinds():
		if VfxBursts.scene(kind) == null:
			all_load = false
	_check(all_load and VfxBursts.kinds().size() == 6, "every burst kind loads (%d)" % VfxBursts.kinds().size())
	var burst := VfxBursts.play(&"pickup", Vector2(100, 100))
	_check(burst != null and burst.emitting and burst.global_position == Vector2(100, 100) and burst.get_parent() == get_tree().current_scene, "a pickup glint plays under the current scene")
	_check(burst.material == PooledVfx.additive_material() and burst.texture != null, "with the shared additive material and its texture")
	await _wait(1.6)
	_check(is_instance_valid(burst) and bool(burst.get_meta("__in_pool", false)) and not burst.emitting, "after its lifetime the burst is parked in the pool, not freed")
	var again := VfxBursts.play(&"pickup", Vector2(0, 0))
	_check(again == burst and again.emitting, "the next glint reuses it")
	var dash := VfxBursts.play(&"dash", Vector2.ZERO, 1.0, Color.WHITE, Vector2(0, 1))
	_check(dash != null and dash.direction == Vector2(0, 1) and dash.material == null, "a dash wisp is aimed and blends normally (smoke)")
	# Fodder deaths cannot consume the elite's separate visual allowance.
	var before := _bursts().size()
	for i in 30:
		var context := DEATH_CONTEXT.new(1000 + i, &"enemy_grunt", Vector2(i * 20, 0), 0, null, {})
		RunEvents.enemy_defeated.emit(context)
	var deaths := _bursts().size() - before
	_check(deaths == feedback.DEATHS_PER_FRAME, "thirty deaths in one frame play %d bursts (cap %d)" % [deaths, feedback.DEATHS_PER_FRAME])
	var elite := DEATH_CONTEXT.new(5000, &"enemy_herald", Vector2(300, 300), EnemyWorldTypes.Flags.ELITE, null, {})
	var before_elite := _bursts().size()
	RunEvents.enemy_defeated.emit(elite)
	var newest: VfxBurst = null
	for child in _bursts():
		if child.global_position == Vector2(300, 300):
			newest = child
	_check(_bursts().size() == before_elite + 1 and newest != null and newest.name.begins_with("BurstEliteDeath"), "an elite still plays its burst after thirty fodder deaths in the same frame")
	for i in 30:
		RunEvents.enemy_defeated.emit(DEATH_CONTEXT.new(5100 + i, &"enemy_herald", Vector2(600 + i * 20, 300), EnemyWorldTypes.Flags.ELITE, null, {}))
	var elite_bursts := _elite_burst_count()
	_check(elite_bursts == 2, "a storm of elite deaths retains two distinctive bursts and stays bounded (%d)" % elite_bursts)
	# The next frame gets a fresh elite allowance and the complete fodder
	# allowance, even when the elite defeats arrive first.
	await get_tree().process_frame
	await get_tree().process_frame
	var before_next := _bursts().size()
	for i in 30:
		RunEvents.enemy_defeated.emit(DEATH_CONTEXT.new(5200 + i, &"enemy_herald", Vector2(600 + i * 20, 600), EnemyWorldTypes.Flags.ELITE, null, {}))
	for i in 30:
		RunEvents.enemy_defeated.emit(DEATH_CONTEXT.new(5300 + i, &"enemy_grunt", Vector2(i * 20, 600), 0, null, {}))
	_check(_elite_burst_count() == elite_bursts + 2 and _bursts().size() == before_next + 12, "the next frame resets both allowances and elites do not starve fodder feedback")
	await _wait(1.6)
	var live := 0
	for child in _bursts():
		if not bool(child.get_meta("__in_pool", false)):
			live += 1
	_check(live == 0 and PooledVfx.live_count(VfxBursts.scene(&"death")) == 0, "every burst returned to the pool after the storm")
	print("WorldFeedbackVfxTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _elite_burst_count() -> int:
	var count := 0
	for child in _bursts():
		if child.scene_file_path == "res://assets/vfx/world/bursts/Burst_EliteDeath.tscn" and child.emitting:
			count += 1
	return count
