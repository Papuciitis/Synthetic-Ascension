extends Node

# Roadmap §9 "Elite legibility" / plan §2.7: five readable elite modifiers
# picked by segment phase, each with a mechanic the player can answer, a tell
# on the body and a once-per-run teach. Drives the real enemy scene against
# the EnemyWorld / EnemyCombat / EnemyIndex autoloads and the ThreatDirector's
# segment phase; the beat spawner is the real EnemySpawner.
#
# Run: <godot> --headless --path . res://tools/tests/EliteModifierTest.tscn

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const RUNNER_SCENE_PATH := "res://scenes/world/enemies/EnemyRunner.tscn"
const PolicyScript = preload("res://core/systems/enemy_world/EnemyRepresentationPolicy.gd")
const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

var _passes := 0
var _failures := 0
var _tips: PackedStringArray = PackedStringArray()


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _make_spec(ai: int = EnemySpec.AI.CHASE) -> EnemySpec:
	var spec := EnemySpec.new()
	spec.id = &"enemy_test_elite"
	spec.ai = ai as EnemySpec.AI
	spec.max_hp = 100.0
	spec.speed = 100.0
	spec.elite_hp_mult = 1.6
	spec.elite_speed_mult = 1.15
	spec.drop_chance = 0.0
	return spec


func _spawn_enemy(pos: Vector2, spec: EnemySpec = null) -> EnemyActor:
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	enemy.spec = spec if spec != null else _make_spec()
	# The spec copies its pickup scene over the scene's; keep the scene's so a
	# death does not warn about a missing pickup.
	enemy.spec.item_pickup_scene = enemy.item_pickup_scene
	enemy.health_drop_chance = 0.0
	enemy.position = pos
	add_child(enemy)
	return enemy


## The enemy scene's own max HP, read without leaving an orphan behind.
func _scene_base_hp() -> float:
	var probe := ENEMY_SCENE.instantiate() as EnemyActor
	var base_hp := probe.max_hp
	probe.free()
	return base_hp


func _handle(enemy: EnemyActor) -> int:
	return EnemyCombat.handle_for_actor(enemy)


func _mark_of(enemy: EnemyActor) -> VFX_EliteModifierMark:
	for child in enemy.get_children():
		if child is VFX_EliteModifierMark and not child.is_queued_for_deletion():
			return child
	return null


func _ids_equal(actual: Array[StringName], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if actual[index] != StringName(expected[index]):
			return false
	return true


func _free_all(enemies: Array) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	ThreatDirector.call("reset_run_state")
	ThreatDirector.call("set_segment_phase", &"recon")
	RunEvents.tutorial_tip.connect(_on_tip)
	EliteModifiers.reset_teaching()

	_test_catalog_and_phase_gating()
	await _test_fast()
	await _test_armoured()
	await _test_shielded()
	await _test_vampiric()
	await _test_splitting()
	await _test_explicit_api_teach_and_phase_pick()
	await _test_pool_reset()
	await _test_proxy_pinning()
	await _test_spawner_beat_api()

	RunEvents.tutorial_tip.disconnect(_on_tip)
	ThreatDirector.call("set_segment_phase", &"recon")
	EliteModifiers.reset_teaching()
	print("EliteModifierTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# --- catalog: phase gating, archetype lists, legibility strings ---
func _test_catalog_and_phase_gating() -> void:
	var spec := _make_spec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_check(EliteModifiers.pick_for_phase(&"recon", spec, rng).is_empty(), "recon picks no modifier - today's plain elite")
	_check(EliteModifiers.pick_for_phase(&"disturbance", spec, rng).is_empty(), "disturbance picks none either")
	var one_ok := true
	for _i in range(24):
		var one := EliteModifiers.pick_for_phase(&"ascension", spec, rng)
		one_ok = one_ok and one.size() == 1 and EliteModifiers.is_known(one[0])
	_check(one_ok, "ascension picks exactly one known modifier")
	var two_ok := true
	var seen: Dictionary = {}
	for _i in range(40):
		var two := EliteModifiers.pick_for_phase(&"collapse", spec, rng)
		two_ok = two_ok and two.size() == 2 and two[0] != two[1] and EliteModifiers.is_known(two[0]) and EliteModifiers.is_known(two[1])
		seen[two[0]] = true
		seen[two[1]] = true
	_check(two_ok, "collapse picks two distinct known modifiers")
	_check(seen.size() == EliteModifiers.ALL.size(), "and over many picks every modifier turns up (%d)" % seen.size())
	_check(EliteModifiers.count_for_phase(&"nonsense") == 0 and EliteModifiers.pick_for_phase(&"nonsense", spec, rng).is_empty(), "an unknown phase picks none")
	_check(EliteModifiers.unlocked_for_phase(&"recon").is_empty() and EliteModifiers.unlocked_for_phase(&"ascension").size() == 5, "ascension unlocks all five, recon none")

	# A splitting archetype never gets SPLITTING, even when asked.
	var splitter_spec := _make_spec(EnemySpec.AI.SPLITTER)
	_check(not EliteModifiers.eligible_for_spec(splitter_spec).has(EliteModifiers.SPLITTING), "a splitting archetype is never eligible for SPLITTING")
	var filtered := EliteModifiers.filter_for_spec([EliteModifiers.SPLITTING, EliteModifiers.FAST], splitter_spec)
	_check(_ids_equal(filtered, [EliteModifiers.FAST]), "an explicit SPLITTING request on a splitter is dropped, the rest kept")
	var override_spec := _make_spec()
	override_spec.elite_ai_override = EnemySpec.AI.SPLITTER
	_check(not EliteModifiers.eligible_for_spec(override_spec).has(EliteModifiers.SPLITTING), "an elite AI override to SPLITTER counts as splitting too")

	# Spec deny-list and allow-list.
	var denied := _make_spec()
	denied.elite_modifiers_denied = [EliteModifiers.ARMOURED, EliteModifiers.VAMPIRIC, EliteModifiers.SHIELDED, EliteModifiers.SPLITTING]
	var deny_ok := true
	for _i in range(12):
		var pick := EliteModifiers.pick_for_phase(&"ascension", denied, rng)
		deny_ok = deny_ok and pick.size() == 1 and pick[0] == EliteModifiers.FAST
	_check(deny_ok, "the spec deny-list is honoured by the phase pick")
	var allowed := _make_spec()
	allowed.elite_modifiers_allowed = [EliteModifiers.SHIELDED]
	var allow_pick := EliteModifiers.pick_for_phase(&"collapse", allowed, rng)
	_check(_ids_equal(allow_pick, [EliteModifiers.SHIELDED]), "an allow-list caps collapse's two picks at what the archetype permits")
	_check(_ids_equal(EliteModifiers.filter_for_spec([EliteModifiers.FAST, EliteModifiers.FAST, &"bogus"], spec), [EliteModifiers.FAST]), "explicit requests drop unknown ids and duplicates")

	# Every modifier has a label, a teach line that names it, and a tint.
	var legible := true
	for id in EliteModifiers.ALL:
		legible = (
			legible
			and EliteModifiers.label(id) != ""
			and EliteModifiers.teach_line(id).begins_with(EliteModifiers.label(id))
			and EliteModifiers.tint(id) != Color.WHITE
			and EliteModifiers.bit_for(id) != 0
		)
	_check(legible, "every modifier carries a label, a teach line starting with it, a tint and a bit")
	_check(EliteModifiers.teach_line(EliteModifiers.ARMOURED) == "ARMOURED - small hits bounce, heavy hits get through", "the ARMOURED teach is the roadmap's line")
	_check(EliteModifiers.teach_line(EliteModifiers.SHIELDED) == "SHIELDED - break the shield-bearer first", "the SHIELDED teach is the roadmap's line")
	_check(EliteModifiers.teach_line(EliteModifiers.SPLITTING) == "SPLITTING - kill it away from the crowd", "the SPLITTING teach is the roadmap's line")
	_check(EliteModifiers.phase_summary_line(&"recon").contains("none yet"), "the phase summary says modifiers are locked before ascension")
	var collapse_line := EliteModifiers.phase_summary_line(&"collapse")
	_check(collapse_line.contains("2 per elite") and collapse_line.contains("ARMOURED") and collapse_line.contains("FAST"), "and names them with the count once unlocked (%s)" % collapse_line)

	# Teach-once bookkeeping.
	EliteModifiers.reset_teaching()
	_check(EliteModifiers.consume_teach(EliteModifiers.ARMOURED) and not EliteModifiers.consume_teach(EliteModifiers.ARMOURED), "consume_teach answers once per run per id")
	_check(not EliteModifiers.consume_teach(&"bogus"), "an unknown id never teaches")
	EliteModifiers.reset_teaching()
	_check(EliteModifiers.consume_teach(EliteModifiers.ARMOURED), "reset_teaching starts the run over")
	EliteModifiers.reset_teaching()


# --- FAST: speed up, HP down, on top of the archetype's elite multipliers ---
func _test_fast() -> void:
	var enemy := _spawn_enemy(Vector2(100.0, 100.0))
	await get_tree().process_frame
	var base_hp := enemy.max_hp
	var base_speed := enemy.speed
	enemy.apply_elite_modifiers([EliteModifiers.FAST])
	_check(enemy.is_elite and _ids_equal(enemy.elite_modifier_ids(), [EliteModifiers.FAST]), "apply_elite_modifiers promotes a plain enemy and applies exactly FAST")
	_check(is_equal_approx(enemy.speed, base_speed * enemy.spec.elite_speed_mult * EliteModifiers.FAST_SPEED_MULT), "FAST multiplies speed on top of the elite multiplier (%.1f)" % enemy.speed)
	_check(is_equal_approx(enemy.max_hp, base_hp * enemy.spec.elite_hp_mult * EliteModifiers.FAST_HP_MULT) and is_equal_approx(enemy.hp, enemy.max_hp), "FAST trims max HP and fills it (%.1f)" % enemy.max_hp)
	_check(enemy.has_elite_modifier(EliteModifiers.FAST) and not enemy.has_elite_modifier(EliteModifiers.ARMOURED), "has_elite_modifier reads the live set")
	var sprite := enemy.get_node_or_null("Sprite2D") as CanvasItem
	_check(sprite != null and sprite.modulate == EliteModifiers.tint(EliteModifiers.FAST), "the body carries the FAST tint")
	_check(_mark_of(enemy) != null, "the tell is attached to the body")
	await _free_all([enemy])


# --- ARMOURED: a flat plate per hit ---
func _test_armoured() -> void:
	var enemy := _spawn_enemy(Vector2(100.0, 100.0))
	var plain := _spawn_enemy(Vector2(300.0, 100.0))
	await get_tree().process_frame
	enemy.apply_elite_modifiers([EliteModifiers.ARMOURED])
	var handle := _handle(enemy)
	var flat := enemy.max_hp * EliteModifiers.ARMOUR_FLAT_FRACTION
	_check(is_equal_approx(EnemyCombat.elite_armour_fraction(handle), EliteModifiers.ARMOUR_FLAT_FRACTION), "the plate registers on the elite's handle")
	_check(EnemyCombat.apply_damage(handle, flat * 0.5) == 0.0 and is_equal_approx(enemy.hp, enemy.max_hp), "a hit under the plate bounces")
	var heavy := flat * 5.0
	_check(is_equal_approx(EnemyCombat.apply_damage(handle, heavy), heavy - flat), "a heavy hit loses only the plate")
	_check(is_equal_approx(EnemyCombat.apply_damage(handle, flat * 4.0, 2), flat * 2.0), "a two-pellet ledger pays the plate per pellet")
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(plain), 5.0), 5.0), "an ordinary enemy pays full while a plate is live elsewhere")
	EnemyCombat.apply_damage(handle, 99999.0)
	_check(enemy.dead, "a lethal blow still gets through the plate")
	_check(EnemyCombat.elite_armour_fraction(handle) == 0.0, "and the plate is dropped on death")
	await _free_all([plain])


# --- SHIELDED: non-elite neighbours take less; bearer and elites never ---
func _test_shielded() -> void:
	var origin := Vector2(1000.0, 1000.0)
	var bearer := _spawn_enemy(origin)
	var near := _spawn_enemy(origin + Vector2(EliteModifiers.SHIELD_RADIUS * 0.5, 0.0))
	var far := _spawn_enemy(origin + Vector2(EliteModifiers.SHIELD_RADIUS * 2.0, 0.0))
	var other_elite := _spawn_enemy(origin + Vector2(0.0, 60.0))
	await get_tree().process_frame
	bearer.apply_elite_modifiers([EliteModifiers.SHIELDED])
	other_elite.apply_elite_modifiers([EliteModifiers.FAST])
	_check(EnemyCombat.elite_shield_bearer_count() == 1, "one live shield-bearer registers")
	var reduced := 20.0 * (1.0 - EliteModifiers.SHIELD_ALLY_DAMAGE_REDUCTION)
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(near), 20.0), reduced), "a non-elite inside the radius takes reduced damage")
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(far), 20.0), 20.0), "a non-elite outside the radius takes full damage")
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(bearer), 20.0), 20.0), "the bearer itself is not covered")
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(other_elite), 20.0), 20.0), "another elite inside the radius is not covered")
	EnemyCombat.apply_damage(_handle(bearer), 99999.0)
	_check(bearer.dead and EnemyCombat.elite_shield_bearer_count() == 0, "the shield drops with the bearer")
	_check(is_equal_approx(EnemyCombat.apply_damage(_handle(near), 20.0), 20.0), "and the neighbour pays full again")
	await _free_all([near, far, other_elite])


# --- VAMPIRIC: feeds on nearby non-elite allies on a clock, never lethally ---
func _test_vampiric() -> void:
	var origin := Vector2(2000.0, 2000.0)
	var vamp := _spawn_enemy(origin)
	var ally := _spawn_enemy(origin + Vector2(60.0, 0.0))
	var far_ally := _spawn_enemy(origin + Vector2(EliteModifiers.VAMPIRIC_DRAIN_RADIUS * 3.0, 0.0))
	var elite_ally := _spawn_enemy(origin + Vector2(-60.0, 0.0))
	var weak := _spawn_enemy(origin + Vector2(0.0, 60.0))
	await get_tree().process_frame
	vamp.apply_elite_modifiers([EliteModifiers.VAMPIRIC])
	elite_ally.apply_elite_modifiers([EliteModifiers.FAST])
	EnemyCombat.apply_damage(_handle(weak), weak.max_hp - EliteModifiers.VAMPIRIC_DRAIN_FLOOR_HP)
	_check(is_equal_approx(weak.hp, EliteModifiers.VAMPIRIC_DRAIN_FLOOR_HP), "fixture: an ally sits at the drain floor")

	vamp.call("_tick_vampiric", EliteModifiers.VAMPIRIC_DRAIN_EVERY + 0.1)
	_check(is_equal_approx(ally.hp, ally.max_hp), "a full-health VAMPIRIC does not feed")

	EnemyCombat.apply_damage(_handle(vamp), vamp.max_hp * 0.5)
	var wounded := vamp.hp
	vamp.call("_tick_vampiric", EliteModifiers.VAMPIRIC_DRAIN_EVERY + 0.1)
	var expected_drain := ally.max_hp * EliteModifiers.VAMPIRIC_DRAIN_FRACTION
	_check(is_equal_approx(ally.hp, ally.max_hp - expected_drain), "a non-elite ally inside the radius is drained by the fraction (%.1f)" % ally.hp)
	_check(is_equal_approx(far_ally.hp, far_ally.max_hp), "an ally outside the radius is untouched")
	_check(is_equal_approx(elite_ally.hp, elite_ally.max_hp), "an elite ally is never drained")
	_check(is_equal_approx(weak.hp, EliteModifiers.VAMPIRIC_DRAIN_FLOOR_HP), "the drain never kills - an ally at the floor is left alone")
	_check(is_equal_approx(vamp.hp, wounded + expected_drain), "and the elite heals exactly what it took (%.1f)" % vamp.hp)
	var after := ally.hp
	vamp.call("_tick_vampiric", 0.1)
	_check(is_equal_approx(ally.hp, after), "the drain waits for its clock")
	_check(EnemyCombat.drain_health(_handle(ally), 5.0, 1.0) == 5.0 and is_equal_approx(ally.hp, after - 5.0), "drain_health reports what it took and mirrors it to the actor")
	await _free_all([vamp, ally, far_ally, elite_ally, weak])


# --- SPLITTING: copies through the Splitter's machinery, shrunk, loot-less ---
func _test_splitting() -> void:
	var elite := _spawn_enemy(Vector2(3000.0, 3000.0))
	await get_tree().process_frame
	elite.apply_elite_modifiers([EliteModifiers.SPLITTING])
	_check(elite.has_elite_modifier(EliteModifiers.SPLITTING), "a chase archetype may carry SPLITTING")
	var root_id := elite.get_instance_id()
	var scene_base_hp := _scene_base_hp()
	EnemyCombat.apply_damage(_handle(elite), 99999.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var children: Array[EnemyActor] = []
	for node in get_tree().get_nodes_in_group("splitter_spawned"):
		var child := node as EnemyActor
		if child != null and bool(child.get_meta("elite_split_child", false)) and int(child.get_meta("split_root_id", 0)) == root_id:
			children.append(child)
	_check(children.size() == EliteModifiers.SPLIT_COUNT, "a SPLITTING elite leaves SPLIT_COUNT copies (%d)" % children.size())
	var hp_mul := float(ThreatDirector.enemy_hp_mul)
	var shaped := not children.is_empty()
	for child in children:
		shaped = (
			shaped
			and not child.is_elite
			and child.scale.is_equal_approx(Vector2.ONE * EliteModifiers.SPLIT_CHILD_SCALE)
			and is_equal_approx(child.max_hp, scene_base_hp * hp_mul * EliteModifiers.SPLIT_CHILD_HP_FRACTION)
			and child.drop_chance == 0.0
			and child.get_meta("special_spawn_kind", &"") == &"split"
		)
	_check(shaped, "the copies are non-elite, SPLIT_CHILD_SCALE sized, at SPLIT_CHILD_HP_FRACTION of base HP, carry no loot and count as split specials")

	# The splitter archetype keeps its own curve: it never receives SPLITTING.
	var slime := _spawn_enemy(Vector2(3500.0, 3000.0), _make_spec(EnemySpec.AI.SPLITTER))
	await get_tree().process_frame
	slime.apply_elite_modifiers([EliteModifiers.SPLITTING])
	_check(slime.is_elite and slime.elite_modifier_ids().is_empty(), "a Splitter asked for SPLITTING is promoted plain")
	await _free_all(children + [slime])


# --- explicit API, popup + teach once per run in view, phase pick via the director ---
func _test_explicit_api_teach_and_phase_pick() -> void:
	EliteModifiers.reset_teaching()
	_tips.clear()

	var hidden := _spawn_enemy(Vector2(9000.0, 9000.0))
	await get_tree().process_frame
	hidden.apply_elite_modifiers([EliteModifiers.ARMOURED])
	_check(hidden.has_elite_modifier(EliteModifiers.ARMOURED), "an out-of-view promotion still applies the mechanic")
	_check(_tips.is_empty() and not EliteModifiers.was_taught(EliteModifiers.ARMOURED), "but teaches nothing and keeps the lesson for one the player can see")

	var popups_before := int(BattleText.get("_count"))
	var seen := _spawn_enemy(Vector2(200.0, 200.0))
	await get_tree().process_frame
	# `enabled` alone records counters; the capture state machine (and its
	# report files) only arms through set_enabled, which this does not call.
	var recorder_was_enabled := bool(PerformanceFlightRecorder.get("enabled"))
	PerformanceFlightRecorder.set("enabled", true)
	seen.apply_elite_modifiers([EliteModifiers.ARMOURED, EliteModifiers.FAST])
	PerformanceFlightRecorder.set("enabled", recorder_was_enabled)
	_check(_ids_equal(seen.elite_modifier_ids(), [EliteModifiers.ARMOURED, EliteModifiers.FAST]), "two explicit modifiers apply in the order given")
	var promoted_event: Dictionary = {}
	for event_variant in (PerformanceFlightRecorder.get("_events") as Array):
		var event := event_variant as Dictionary
		if event != null and String(event.get("name", "")) == "elite_promoted":
			promoted_event = event
	_check(
		not promoted_event.is_empty()
		and String((promoted_event.get("details", {}) as Dictionary).get("modifiers", "")) == "armoured,fast",
		"the elite_promoted recorder event carries the modifier ids (%s)" % [promoted_event.get("details", {})],
	)
	_check(
		_tips.size() == 2
		and _tips[0] == EliteModifiers.teach_line(EliteModifiers.ARMOURED)
		and _tips[1] == EliteModifiers.teach_line(EliteModifiers.FAST),
		"the first in-view promotion teaches each modifier once (%s)" % [_tips],
	)
	if BattleText.callouts_enabled():
		_check(int(BattleText.get("_count")) > popups_before, "and the label pops on the body")
	var again := _spawn_enemy(Vector2(240.0, 200.0))
	await get_tree().process_frame
	again.apply_elite_modifiers([EliteModifiers.ARMOURED])
	_check(_tips.size() == 2, "the second ARMOURED this run teaches nothing")

	# Replacing the set on a live elite swaps the registries too.
	seen.apply_elite_modifiers([EliteModifiers.SHIELDED])
	_check(_ids_equal(seen.elite_modifier_ids(), [EliteModifiers.SHIELDED]), "apply_elite_modifiers on a live elite replaces the set")
	_check(EnemyCombat.elite_armour_fraction(_handle(seen)) == 0.0 and EnemyCombat.elite_shield_bearer_count() == 1, "the old plate is unregistered and the new shield registered")
	_check(_tips.size() == 3 and _tips[2] == EliteModifiers.teach_line(EliteModifiers.SHIELDED), "a modifier met for the first time on a replacement still teaches")
	seen.apply_elite_modifiers([])
	var seen_sprite := seen.get_node_or_null("Sprite2D") as CanvasItem
	_check(
		seen.is_elite
		and seen.elite_modifier_ids().is_empty()
		and _mark_of(seen) == null
		and EnemyCombat.elite_shield_bearer_count() == 0,
		"an empty replacement leaves a plain elite with no mark and no registry entry",
	)
	_check(seen_sprite != null and seen_sprite.modulate == seen.spec.elite_tint, "with the archetype's elite tint back on the body")
	again.apply_elite_modifiers([&"bogus", EliteModifiers.VAMPIRIC])
	_check(_ids_equal(again.elite_modifier_ids(), [EliteModifiers.VAMPIRIC]), "unknown ids are dropped from an explicit request")

	# make_elite with no explicit ids picks by the director's segment phase.
	ThreatDirector.call("set_segment_phase", &"ascension")
	var phased := _spawn_enemy(Vector2(300.0, 200.0))
	await get_tree().process_frame
	phased.make_elite()
	_check(phased.is_elite and phased.elite_modifier_ids().size() == 1, "make_elite in ascension picks one modifier from the director's phase (%s)" % [phased.elite_modifier_ids()])
	ThreatDirector.call("set_segment_phase", &"collapse")
	var collapsed := _spawn_enemy(Vector2(340.0, 200.0))
	await get_tree().process_frame
	collapsed.make_elite()
	var pair := collapsed.elite_modifier_ids()
	_check(pair.size() == 2 and pair[0] != pair[1], "make_elite in collapse picks two distinct (%s)" % [pair])
	ThreatDirector.call("set_segment_phase", &"recon")
	var plain := _spawn_enemy(Vector2(380.0, 200.0))
	await get_tree().process_frame
	plain.make_elite()
	var plain_sprite := plain.get_node_or_null("Sprite2D") as CanvasItem
	_check(plain.is_elite and plain.elite_modifier_ids().is_empty(), "make_elite in recon is today's plain elite")
	_check(plain_sprite != null and plain_sprite.modulate == plain.spec.elite_tint and _mark_of(plain) == null, "with the archetype's elite tint and no mark")
	_check(is_equal_approx(plain.max_hp, 100.0 * float(ThreatDirector.enemy_hp_mul) * plain.spec.elite_hp_mult), "and the archetype's elite HP, untouched")
	await _free_all([hidden, seen, again, phased, collapsed, plain])


# --- pooling: a recycled elite carries nothing over ---
func _test_pool_reset() -> void:
	var pool := get_node_or_null("/root/PoolManager")
	if pool == null or not pool.has_method("obtain"):
		_check(false, "PoolManager is available")
		return
	var pooled := pool.call("obtain", ENEMY_SCENE, self) as EnemyActor
	pooled.spec = _make_spec()
	pooled.health_drop_chance = 0.0
	pooled.global_position = Vector2(400.0, 200.0)
	await get_tree().process_frame
	pooled.apply_elite_modifiers([EliteModifiers.ARMOURED, EliteModifiers.VAMPIRIC])
	var pooled_handle := _handle(pooled)
	_check(EnemyCombat.elite_armour_fraction(pooled_handle) > 0.0 and _mark_of(pooled) != null, "fixture: the pooled elite is armoured and marked")
	pooled.dead = true
	pooled.call("despawn", &"elite")
	await get_tree().process_frame
	_check(EnemyCombat.elite_armour_fraction(pooled_handle) == 0.0, "recycling an elite drops its plate before the handle is released")
	var reused := pool.call("obtain", ENEMY_SCENE, self) as EnemyActor
	_check(reused == pooled, "fixture: the same node comes back")
	if reused != null:
		var sprite := reused.get_node_or_null("Sprite2D") as CanvasItem
		_check(
			not reused.is_elite
			and reused.elite_modifier_ids().is_empty()
			and not reused.has_elite_modifier(EliteModifiers.VAMPIRIC)
			and _mark_of(reused) == null,
			"a reused node carries no modifier state or mark",
		)
		_check(sprite != null and sprite.modulate == reused.spec.sprite_modulate, "and its base tint is back")
		reused.call("despawn", &"cleanup")
		await get_tree().process_frame


# --- data-only proxies: an elite is never one, so actor-side state suffices ---
func _test_proxy_pinning() -> void:
	_check((PolicyScript.REQUIRED_FLAGS & Types.Flags.ELITE) != 0, "the representation policy counts ELITE as a required flag")
	var elite := _spawn_enemy(Vector2(500.0, 200.0))
	await get_tree().process_frame
	elite.apply_elite_modifiers([EliteModifiers.ARMOURED])
	var handle := _handle(elite)
	_check(Types.has_flag(EnemyWorld.get_flags(handle), Types.Flags.ELITE), "promotion writes the ELITE flag into world storage at once")
	var policy = PolicyScript.new()
	_check(not policy.is_proxy_eligible(EnemyWorld, handle), "so an elite is never proxy-eligible: it stays materialized and its modifier state lives on the actor and in the combat registries")
	_check(EnemyWorld.get_representation(handle) == Types.Representation.MATERIALIZED, "and the record reads materialized")
	await _free_all([elite])


# --- the Hunter premise from this side: the spawner passes a beat's request through ---
func _test_spawner_beat_api() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	await get_tree().process_frame
	var node := spawner.spawn_beat_member(RUNNER_SCENE_PATH, Vector2(600.0, 200.0), true, [EliteModifiers.FAST, EliteModifiers.VAMPIRIC])
	await get_tree().process_frame
	await get_tree().process_frame
	var member := node as EnemyActor
	_check(member != null and member.is_elite, "spawn_beat_member with modifier ids promotes the member")
	_check(member != null and _ids_equal(member.elite_modifier_ids(), [EliteModifiers.FAST, EliteModifiers.VAMPIRIC]), "and applies exactly the beat's modifiers, not the phase pick")
	_check(member != null and member.get_meta("special_spawn_kind", &"") == &"beat", "the member is still a beat special")
	var plain := spawner.spawn_beat_member(RUNNER_SCENE_PATH, Vector2(700.0, 200.0), true) as EnemyActor
	await get_tree().process_frame
	await get_tree().process_frame
	_check(plain != null and plain.is_elite and plain.elite_modifier_ids().is_empty(), "the three-argument call still promotes by phase (recon: plain)")
	await _free_all([member, plain, spawner])
