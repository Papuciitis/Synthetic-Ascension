extends Node

# Performance war room M2: the set VFX pool. Pulse rings, spokes, arc
# lines, cleave arcs and shockwaves come from the PoolManager through
# PooledVfx, reset on reuse, share one additive material, respect a live
# cap, and cost less per frame than instantiate / queue_free churn.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/SetVfxPoolTest.tscn

const PULSE := preload("res://assets/vfx/world/sets/conduit/VFX_PulseRing.tscn")
const SPOKES := preload("res://assets/vfx/world/sets/conduit/VFX_SpokesBurst.tscn")
const ARC := preload("res://assets/vfx/world/sets/conduit/VFX_ArcLine.tscn")
const CLEAVE := preload("res://assets/vfx/world/sets/conduit/VFX_CleaveArc.tscn")
const SHOCK := preload("res://assets/vfx/world/sets/conduit/VFX_Shockwave.tscn")

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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Headless frames run as fast as the machine allows (about 7 ms), so the
## VFX lifetimes are waited out on the clock, not in frames.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)])


func _run() -> void:
	var pool := get_node_or_null("/root/PoolManager")
	_check(pool != null, "the PoolManager autoload is present")
	await _test_reuse_and_reset()
	await _test_live_cap_and_retention()
	await _test_arc_line()
	await _test_unpooled_fallback()
	await _test_churn()
	print("SetVfxPoolTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_reuse_and_reset() -> void:
	var pool := get_node_or_null("/root/PoolManager")
	var before: Dictionary = pool.call("get_debug_counters")
	var ring := PooledVfx.obtain(PULSE, self) as Node2D
	_check(ring != null and ring.get_parent() == self, "a pulse ring is obtained under the requested parent")
	ring.call("setup", Vector2(100, 100), 80.0)
	_check(ring.material == PooledVfx.additive_material() and ring.material == pool.call("get_additive_material"), "the ring shares the pool's additive material")
	_check(PooledVfx.live_count(PULSE) == 1, "one pulse ring is live")
	await _wait(0.45)
	_check(is_instance_valid(ring) and ring.get_parent() == pool and bool(ring.get_meta("__in_pool", false)), "after its 0.26 s the ring went back to the pool (parked under the PoolManager) instead of being freed")
	_check(int(pool.call("pool_size_for_scene", PULSE)) == 1 and PooledVfx.live_count(PULSE) == 0, "the pool retains it and nothing is live")
	var again := PooledVfx.obtain(PULSE, self) as Node2D
	var after: Dictionary = pool.call("get_debug_counters")
	_check(again == ring and int(after.get("reuse_hits", 0)) == int(before.get("reuse_hits", 0)) + 1, "the next obtain reuses the same node")
	_check(is_zero_approx(float(again.get("_t"))) and again.is_inside_tree() and again.visible and again.is_processing(), "a reused ring restarts at its first frame, visible and processing")
	var spokes := PooledVfx.obtain(SPOKES, self) as Node2D
	spokes.rotation = 1.0
	await _wait(0.3)
	var spokes_again := PooledVfx.obtain(SPOKES, self) as Node2D
	_check(spokes_again == spokes and is_zero_approx(spokes_again.rotation) and (spokes_again.get("_angles") as PackedFloat32Array).size() == int(spokes_again.get("spokes")), "reused spokes reset their rotation and reroll their angles")
	var cleave := PooledVfx.obtain(CLEAVE, self) as Node2D
	cleave.scale = Vector2(0.5, 0.5)
	await _wait(0.3)
	var cleave_again := PooledVfx.obtain(CLEAVE, self) as Node2D
	_check(cleave_again == cleave and cleave_again.scale == Vector2.ONE and (cleave_again.get("_sparks") as Array).size() == int(cleave_again.get("spark_count")), "a reused cleave arc is back at unit scale with fresh sparks")
	var shock := PooledVfx.obtain(SHOCK, self) as Node2D
	shock.call("setup", Vector2.ZERO, 200.0)
	await _wait(0.4)
	var shock_again := PooledVfx.obtain(SHOCK, self) as Node2D
	_check(shock_again == shock and is_zero_approx(float(shock_again.get("_t"))), "a reused shockwave restarts")
	await _wait(0.5)


func _test_live_cap_and_retention() -> void:
	var pool := get_node_or_null("/root/PoolManager")
	var refused_before := PooledVfx.refused
	var obtained := 0
	for i in PooledVfx.LIVE_CAP_PER_KIND + 6:
		var node := PooledVfx.obtain(SPOKES, self)
		if node != null:
			obtained += 1
			node.call("setup", Vector2(i * 10, 0))
	_check(obtained == PooledVfx.LIVE_CAP_PER_KIND and PooledVfx.refused == refused_before + 6, "the live cap admits %d spokes bursts and refuses the six beyond it" % PooledVfx.LIVE_CAP_PER_KIND)
	await _wait(0.4)
	_check(PooledVfx.live_count(SPOKES) == 0, "every burst released after its 0.14 s")
	_check(int(pool.call("pool_size_for_scene", SPOKES)) == PooledVfx.RETAINED_PER_KIND, "the pool retains %d and discards the rest" % PooledVfx.RETAINED_PER_KIND)


func _test_arc_line() -> void:
	var arc := PooledVfx.obtain(ARC, self) as Line2D
	arc.call("setup", Vector2.ZERO, Vector2(120, 40))
	_check(arc != null and arc.points.size() == int(arc.get("segments")) + 1, "an arc line draws its jittered segments")
	await _wait(0.3)
	_check(is_instance_valid(arc) and bool(arc.get_meta("__in_pool", false)), "the arc line went back to the pool after its fade")
	var again := PooledVfx.obtain(ARC, self) as Line2D
	_check(again == arc and is_equal_approx(again.modulate.a, 1.0) and again.points.size() == 0, "a reused arc line is opaque again with its points cleared")
	again.call("setup", Vector2.ZERO, Vector2(50, 50))
	await _wait(0.3)
	_check(bool(again.get_meta("__in_pool", false)), "and fades back into the pool a second time")


func _test_unpooled_fallback() -> void:
	var raw := PULSE.instantiate() as Node2D
	add_child(raw)
	raw.call("setup", Vector2.ZERO, 40.0)
	await _wait(0.5)
	_check(not is_instance_valid(raw), "a ring instantiated outside the pool still frees itself")


func _test_churn() -> void:
	var raw_ms: Array = []
	var pooled_ms: Array = []
	var frames := 150
	var per_frame := 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Raw churn: instantiate, add, self-free (never pooled).
	for f in frames:
		var started := Time.get_ticks_usec()
		for i in per_frame:
			var node := PULSE.instantiate() as Node2D
			add_child(node)
			node.call("setup", Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400)), 80.0)
		await get_tree().process_frame
		raw_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	await _wait(0.5)
	# Pooled churn through PooledVfx (the cap bounds the live set).
	for f in frames:
		var started := Time.get_ticks_usec()
		for i in per_frame:
			var node := PooledVfx.obtain(PULSE, self) as Node2D
			if node != null:
				node.call("setup", Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400)), 80.0)
		await get_tree().process_frame
		pooled_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	await _wait(0.5)
	var raw_p50 := _pct(raw_ms, 0.5)
	var pooled_p50 := _pct(pooled_ms, 0.5)
	print("churn: %d rings per frame for %d frames: raw p50 %.2f p95 %.2f ms, pooled p50 %.2f p95 %.2f ms (live cap %d)" % [per_frame, frames, raw_p50, _pct(raw_ms, 0.95), pooled_p50, _pct(pooled_ms, 0.95), PooledVfx.LIVE_CAP_PER_KIND])
	_check(pooled_p50 <= raw_p50, "pooled bursts cost no more per frame than raw churn (headless: node work only)")
	_check(PooledVfx.live_count(PULSE) == 0 and int((get_node("/root/PoolManager")).call("pool_size_for_scene", PULSE)) <= PooledVfx.RETAINED_PER_KIND, "the pool is bounded after the storm")
