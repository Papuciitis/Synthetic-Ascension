extends Node

# Damage attribution answers two questions per hit independently: what
# initiated the chain (origin) and what directly dealt it (emitter). Both
# tables are groupings of the same authoritative HP removed and must each sum
# to it; unknown and mixed stay visible. This drives real tree strikes, real
# pooled projectiles (including a same-frame batch of unlike shots and slot
# reuse), real burn ticks, a telemetry-only set payload and a tagless hit.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceAttributionTest.tscn

const PLAYER = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _spawned: Array[int] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _spawn(hp: float, at: Vector2) -> int:
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"attribution_fixture", "res://attribution_fixture.tscn", at, hp, 0.0, 8.0, 0, 0, {"follower_reward_min": 0, "follower_reward_max": 0}))
	_spawned.append(handle)
	return handle


func _native(core: String, path: String, cast: int = 1) -> PackedStringArray:
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:native:%d" % cast)
	return tags


func _tree(core: String, root: String, path: String, cast: String) -> PackedStringArray:
	var tags := AscensionTags.make(core, AscensionTags.FAMILY_TREE, root, path, 1, 0.6, PackedStringArray(["core_strike", "v"]))
	tags.append("cast:" + cast)
	return tags


func _row(recorder: Node, table: String, key: String) -> Dictionary:
	return (recorder.get_summary().totals.attribution[table] as Dictionary).get(key, {"hp_removed": 0.0, "overkill": 0.0, "hits": 0, "kills": 0, "casts": 0})


func _table_sum(recorder: Node, table: String, field: String) -> float:
	var total := 0.0
	for row in (recorder.get_summary().totals.attribution[table] as Dictionary).values():
		total += float(row[field])
	return total


func _settle() -> void:
	for _i in range(600):
		await get_tree().process_frame
		if ProjectileManager.active_count() == 0:
			break
	await get_tree().process_frame


func _run() -> void:
	# Pure normalization first.
	var basic := BalanceAttribution.from_tags(_native("melee", "slash"))
	_check(basic.origin_id == "native:melee" and basic.emitter_id == "native:melee:slash" and basic.cast_id == "native:1", "a native slash is its own origin and emitter")
	var blink := BalanceAttribution.from_tags(_tree("melee", "MOV", "lunge", "blink:1"))
	_check(blink.origin_id == "ascension:MOV" and blink.emitter_id == "ascension:MOV:lunge", "a BLINK strike is rooted at BLINK")
	var descendant := BalanceAttribution.from_tags(_tree("melee", "MOV3", "afterimage", "blink:1"))
	_check(descendant.origin_id == "ascension:MOV" and descendant.emitter_id == "ascension:MOV3:afterimage" and descendant.generation == 1, "a BLINK descendant keeps BLINK as origin while its emitter changes")
	var spill := BalanceAttribution.from_tags(_tree("melee", "EX03", "bolt", "native:4"))
	_check(spill.origin_id == "native:melee" and spill.emitter_id == "ascension:EX03:bolt", "a tree payload spawned by a native input is rooted at the native attack")
	_check(BalanceAttribution.from_payload(null).origin_id == "unknown" and BalanceAttribution.from_payload(BalanceAttribution.status(&"burn")).emitter_id == "status:burn", "no payload is unknown; a status tick names its status")
	var as_payload: Variant = BalanceAttribution.status(&"burn")
	_check((as_payload as HitLedger) == null, "a provenance object is not a HitLedger, so combat's casts see a null payload")

	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100)
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	player.max_hp = 100.0
	player.hp = 100.0
	var runner := player.get_node("AscensionRunner") as AscensionRunner
	runner.set_process(false)
	ProjectileManager.clear_for_run_end()
	# The manager re-syncs its scene references on its next frame and drops
	# anything spawned before that; give it the frame before the first shot.
	await get_tree().process_frame
	var dir := "user://balance_attribution_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording(), "explicit headless capture starts")
	var origin: Vector2 = player.global_position

	# 1. 30 basic + 100 BLINK on a 100 HP target: 30 basic, 70 BLINK, 30 overkill, one kill.
	var target := _spawn(100.0, origin + Vector2(400, 0))
	runner.damage_enemy(target, 30.0, _native("melee", "slash"))
	runner.damage_enemy(target, 100.0, _tree("melee", "MOV", "lunge", "blink:1"))
	var t: Dictionary = recorder.get_summary().totals
	var native_row := _row(recorder, "by_origin", "native:melee")
	var blink_row := _row(recorder, "by_origin", "ascension:MOV")
	_check(float(native_row.hp_removed) == 30.0 and float(blink_row.hp_removed) == 70.0 and float(blink_row.overkill) == 30.0, "basic removes 30, BLINK removes 70 with 30 overkill (%.1f / %.1f / %.1f)" % [float(native_row.hp_removed), float(blink_row.hp_removed), float(blink_row.overkill)])
	_check(int(blink_row.kills) == 1 and int(native_row.kills) == 0 and t.kills == 1.0 and t.enemy_hp_removed == 100.0, "the kill is credited once, to the hit that emptied the bar")
	_check(int(blink_row.casts) == 1 and int(native_row.casts) == 1, "one BLINK cast and one native input counted as activations")
	_check(float(_row(recorder, "by_emitter", "ascension:MOV:lunge").hp_removed) == 70.0, "the immediate-source table carries the same HP under the emitter")

	# 2. A descendant keeps BLINK as origin; the same cast id is not a new cast.
	var second := _spawn(100.0, origin + Vector2(400, 0))
	runner.damage_enemy(second, 20.0, _tree("melee", "MOV3", "afterimage", "blink:1"))
	blink_row = _row(recorder, "by_origin", "ascension:MOV")
	_check(float(blink_row.hp_removed) == 90.0 and int(blink_row.casts) == 1 and float(_row(recorder, "by_emitter", "ascension:MOV3:afterimage").hp_removed) == 20.0, "a Don't Blink afterimage adds to BLINK's origin under its own emitter, without a second cast")

	# 3. Real pooled projectiles: a BLINK-tagged bullet, then the reused slot
	# carries a native bullet that must not inherit BLINK.
	_spawn(500.0, origin + Vector2(60, 0))
	var profile := HitProfileAdapter.new()
	profile.reset(10.0)
	profile.set_meta("asc_tags", _tree("ranged", "MOV1", "ghost", "blink:2"))
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, profile, player)
	await _settle()
	var ghost_before := float(_row(recorder, "by_emitter", "ascension:MOV1:ghost").hp_removed)
	profile.reset(10.0)
	profile.set_meta("asc_tags", _native("ranged", "bullet", 2))
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, profile, player)
	await _settle()
	_check(ghost_before == 10.0 and float(_row(recorder, "by_emitter", "ascension:MOV1:ghost").hp_removed) == 10.0 and float(_row(recorder, "by_emitter", "native:ranged:bullet").hp_removed) == 10.0, "a reused projectile slot carries its own provenance, not the previous shot's")

	# 4. Two unlike shots resolving on one target in the same frame are one
	# batch: reported as mixed with a raw breakdown, never as the first shot.
	var batched := _spawn(500.0, origin + Vector2(60, 0))
	profile.reset(10.0)
	profile.set_meta("asc_tags", _native("ranged", "bullet", 3))
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, profile, player)
	var other := HitProfileAdapter.new()
	other.reset(10.0)
	other.set_meta("asc_tags", _tree("ranged", "BR05", "fragment", "native:3"))
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, other, player)
	await _settle()
	var mixed_row := _row(recorder, "by_origin", "mixed")
	var breakdown: Dictionary = recorder.get_summary().totals.attribution.mixed_raw_breakdown
	_check(float(mixed_row.hp_removed) == 20.0 and int(mixed_row.hits) == 2 and breakdown.size() == 2, "a same-frame batch of unlike shots is mixed (%.1f HP, %d raw sources)" % [float(mixed_row.hp_removed), breakdown.size()])

	# 5. A burn tick names its status; a telemetry-only set payload names the
	# set; a tagless hit stays unknown. All of it sums to the authoritative HP.
	EnemyStatus.apply_burn(batched, 1, 2.0, 0.5, 5.0, player)
	EnemyStatus.advance(0.6)
	EnemyCombat.apply_damage(batched, 10.0, 1, player, BalanceAttribution.provenance("set:gravemarch:6", "set:gravemarch:6:mass_arrest", "set"))
	EnemyCombat.apply_damage(batched, 10.0, 1, player)
	_check(float(_row(recorder, "by_origin", "status:burn").hp_removed) == 5.0 and float(_row(recorder, "by_emitter", "set:gravemarch:6:mass_arrest").hp_removed) == 10.0 and float(_row(recorder, "by_origin", "unknown").hp_removed) == 10.0, "burn ticks, set payloads and tagless hits are each named honestly")
	t = recorder.get_summary().totals
	_check(is_equal_approx(_table_sum(recorder, "by_origin", "hp_removed"), t.enemy_hp_removed) and is_equal_approx(_table_sum(recorder, "by_emitter", "hp_removed"), t.enemy_hp_removed), "both tables sum to the authoritative HP removed (%.1f)" % t.enemy_hp_removed)
	_check(int(_table_sum(recorder, "by_origin", "kills")) == int(t.kills) and int(_table_sum(recorder, "by_emitter", "kills")) == int(t.kills), "kills are credited exactly once across each table")
	var coverage: Dictionary = recorder.get_summary().attribution_coverage
	_check(is_equal_approx(float(coverage.attributed) + float(coverage.unknown) + float(coverage.mixed), t.enemy_hp_removed) and float(coverage.unknown) == 10.0 and float(coverage.mixed) == 20.0, "coverage reports attributed, unknown and mixed shares")

	# 6. Proxy promotion: the same handle bound to an actor mid-fight keeps its rows.
	var promoted := _spawn(30.0, origin + Vector2(400, 0))
	runner.damage_enemy(promoted, 10.0, _native("melee", "slash", 5))
	var actor := Node2D.new()
	actor.global_position = origin + Vector2(400, 0)
	add_child(actor)
	EnemyWorld.bind_actor(promoted, actor)
	runner.damage_enemy(promoted, 50.0, _native("melee", "slash", 6))
	native_row = _row(recorder, "by_origin", "native:melee")
	_check(not runner.enemy_alive(promoted), "fixture: the promoted enemy died")
	_check(float(native_row.hp_removed) == 60.0 and int(native_row.kills) == 1, "damage before and after promotion lands in the same rows and the kill is credited once (%.1f)" % float(native_row.hp_removed))
	actor.free()

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and bool(saved.metadata.features.source_attribution) and saved.totals.attribution.by_origin.has("ascension:MOV"), "the saved summary declares attribution and carries the tables")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	_check(report.contains("## Damage attribution") and report.contains("ascension:MOV"), "the report explains attribution")
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	ProjectileManager.clear_for_run_end()
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceAttributionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
