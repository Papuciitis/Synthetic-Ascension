extends Node2D
class_name AscensionRunner
## The advancement tree's presence on the player.
##
## Owns the shared combat contract every discipline engine builds on:
##   - hit records: every enemy_damaged from this player, parsed from the
##     payload tags into {core, family, root, path, gen, pp, flags, before,
##     after, applied, unclamped, lethal, overkill, max_hp, is_elite, is_boss}
##   - kill pairing: the lethal hit record travels with enemy_defeated
##   - a per-enemy status registry (tree statuses only; burn and bleed stay in
##     EnemyStatusService) cleared on death
##   - named combat rolls with a shared modifier chain and a 95% cap
##   - generated attacks (slash, impact, bullet) spawned with the player as
##     source and their own provenance tags
##   - Q / V input, cooldowns and the two HUD slots
##   - the multipliers the player already polls on its other runners
##
## Nothing here reads a node's rules text; engines do, one per discipline,
## registered in ENGINE_SCRIPTS as they are built.

signal hit_resolved(hit: Dictionary)
signal kill_resolved(hit: Dictionary, context: RefCounted)
signal roll_resolved(name: StringName, success: bool, chance: float)
signal refreshed()

const ROLL_CAP := 0.95
const STATUS_SWEEP_INTERVAL := 1.0
const ENGINE_SCRIPTS: Dictionary = {
	"BR": "res://core/systems/ascension/engines/BarrageEngine.gd",
	"EX": "res://core/systems/ascension/engines/ExecutionEngine.gd",
}
## Revelation charge: kills fill it, the equipped V spends all of it. Normals
## give half a point (the review's correction), elites eight, bosses thirty;
## at most four charging kills count per second and V-rooted kills never do.
const V_CHARGE_MAX := 100.0
const V_CHARGE_NORMAL := 0.5
const V_CHARGE_ELITE := 8.0
const V_CHARGE_BOSS := 30.0
const V_CHARGE_ACTIONS_PER_SECOND := 4
const L := 240.0   # the design's long distance
const R := 80.0    # the design's radius unit

var ledger: AscensionLedger = null
var native_core: String = "melee"
var engines: Array[AscensionEngine] = []
var _engine_by_discipline: Dictionary = {}
var _engine_by_node: Dictionary = {}
var active_ids: Dictionary = {}

var statuses: Dictionary = {}          # handle -> Dictionary of tree statuses
var _last_lethal: Dictionary = {}      # handle -> hit record
var _sweep_accum: float = 0.0

var q_id: String = ""
var v_id: String = ""
var q_cooldown_left: float = 0.0
var q_cooldown_max: float = 0.0
var v_cooldown_left: float = 0.0
var v_cooldown_max: float = 0.0
var v_charge: float = 0.0
var _v_charge_actions: int = 0
var _v_charge_window: float = 0.0
var _q_slot: AscensionSlotHud = null
var _v_slot: AscensionSlotHud = null

var last_roll_chance: float = 0.0
var rolls_made: int = 0
var rolls_succeeded: int = 0
var _wired: bool = false
var _player: Node = null
var _managed_profile: HitProfileAdapter = null
var _rng: RandomNumberGenerator = null

var telemetry: Dictionary = {"hits": 0, "kills": 0, "tree_hits": 0, "tree_kills": 0, "generated": 0, "seed_kills": 0, "chain_kills": 0}
var _draw_points: Array = []   # [position, radius, color] gathered from engines each frame


func _ready() -> void:
	_player = get_parent()
	refresh()


func _exit_tree() -> void:
	_set_wired(false)


func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = Global._rng if Global != null and Global.get("_rng") != null else RandomNumberGenerator.new()
	return _rng


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if Global == null:
		return
	ledger = Global.ascension_ledger()
	native_core = ledger.native_core()
	active_ids.clear()
	for id in ledger.owned_ids():
		if ledger.effect_active(id):
			active_ids[id] = true
	_rebuild_engines()
	q_id = ledger.equipped("q") if active_ids.has(ledger.equipped("q")) else ""
	v_id = ledger.equipped("v") if active_ids.has(ledger.equipped("v")) else ""
	_q_slot = _sync_slot(_q_slot, "q", q_id)
	_v_slot = _sync_slot(_v_slot, "v", v_id)
	_set_wired(active_ids.size() > 0)
	refreshed.emit()


func _rebuild_engines() -> void:
	var wanted: Dictionary = {}   # discipline -> {id: true}
	for id in active_ids:
		var code := ledger.db.discipline_of(id)
		if code.is_empty():
			code = "_"  # fusions, unions, gates, ascendant: routed by their own engines later
		if not wanted.has(code):
			wanted[code] = {}
		(wanted[code] as Dictionary)[id] = true
	var kept: Array[AscensionEngine] = []
	_engine_by_node.clear()
	for code in wanted:
		var engine: AscensionEngine = _engine_by_discipline.get(code, null)
		if engine == null:
			var script_path: String = String(ENGINE_SCRIPTS.get(code, ""))
			if script_path.is_empty():
				continue
			var script: Script = load(script_path)
			if script == null:
				continue
			engine = script.new() as AscensionEngine
			if engine == null:
				continue
			engine.setup(self)
			_engine_by_discipline[code] = engine
		engine.refresh(wanted[code])
		kept.append(engine)
		for id in wanted[code]:
			_engine_by_node[id] = engine
	for code in _engine_by_discipline.keys():
		if not wanted.has(code):
			_engine_by_discipline.erase(code)
	engines = kept


func _sync_slot(slot: AscensionSlotHud, slot_name: String, id: String) -> AscensionSlotHud:
	if id.is_empty():
		if slot != null and is_instance_valid(slot):
			slot.queue_free()
		return null
	if slot == null or not is_instance_valid(slot):
		slot = AscensionSlotHud.new()
		add_child(slot)
	slot.configure(slot_name, id, String(ledger.db.node(id).get("name", id)))
	return slot


func _set_wired(on: bool) -> void:
	if on == _wired or RunEvents == null:
		return
	_wired = on
	var wiring: Array = [
		[RunEvents.enemy_damaged, Callable(self, "_on_enemy_damaged")],
		[RunEvents.enemy_defeated, Callable(self, "_on_enemy_defeated")],
		[RunEvents.weapon_fired, Callable(self, "_on_weapon_fired")],
		[RunEvents.player_dashed, Callable(self, "_on_player_dashed")],
		[RunEvents.player_damage_taken, Callable(self, "_on_player_damage_taken")],
	]
	for pair in wiring:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if on and not sig.is_connected(cb):
			sig.connect(cb)
		elif not on and sig.is_connected(cb):
			sig.disconnect(cb)


# ---------------------------------------------------------------- queries

func owns(id: String) -> bool:
	return ledger != null and ledger.owns(id)


func active(id: String) -> bool:
	return active_ids.has(id)


func rank(id: String) -> int:
	return ledger.rank(id) if ledger != null else 0


func engine_for(id: String) -> AscensionEngine:
	return _engine_by_node.get(id, null)


func player() -> Node:
	return _player


func player_position() -> Vector2:
	return (_player as Node2D).global_position if _player is Node2D else Vector2.ZERO


## Tests and scripted encounters can pin the aim; INF means "use the cursor".
var aim_override: Vector2 = Vector2.INF


func aim_target() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	if _player != null and _player.has_method("_current_aim_target"):
		return _player.call("_current_aim_target")
	return player_position()


## The native hit's damage before multipliers, D in the design's vocabulary.
func native_damage() -> float:
	if _player == null:
		return 12.0
	var base := float(_player.get("base_weapon_damage"))
	var stats: Variant = _player.get("stats")
	var power := 1.0 + (float(stats.get("power")) if stats != null else 0.0)
	match native_core:
		"melee":
			return base * CombatStyleTuning.MELEE_DAMAGE_MULT * power
		"magic":
			return base * CombatStyleTuning.MAGIC_DAMAGE_MULT * power
	return base * power


# ---------------------------------------------------------------- enemy helpers

func enemy_hp(handle: int) -> float:
	return EnemyWorld.get_health(handle) if EnemyWorld.is_valid_handle(handle) else 0.0


func enemy_max_hp(handle: int) -> float:
	return EnemyWorld.get_max_health(handle) if EnemyWorld.is_valid_handle(handle) else 0.0


func enemy_alive(handle: int) -> bool:
	return EnemyWorld.is_valid_handle(handle) and not EnemyWorld.is_dying(handle) and EnemyWorld.get_health(handle) > 0.0


func enemy_position(handle: int) -> Vector2:
	return EnemyWorld.get_position(handle)


func is_elite(handle: int) -> bool:
	return EnemyWorld.is_valid_handle(handle) and EnemyWorldTypes.has_flag(EnemyWorld.get_flags(handle), EnemyWorldTypes.Flags.ELITE)


func is_boss(handle: int) -> bool:
	var actor := EnemyWorld.actor_for_handle(handle)
	if actor == null or not is_instance_valid(actor):
		return false
	return actor.is_in_group(&"boss_like") or actor.is_in_group(&"boss") or actor.is_in_group(&"miniboss")


## Normals are anything that is neither elite nor boss.
func is_normal(handle: int) -> bool:
	return not is_elite(handle) and not is_boss(handle)


func enemies_in_radius(center: Vector2, radius: float, exclude: int = 0) -> Array[int]:
	var out: Array[int] = []
	EnemyCombat.gather_in_radius(center, radius, out, exclude)
	return out


func nearest_enemy(center: Vector2, radius: float, exclude: int = 0) -> int:
	return EnemyCombat.nearest_enemy(center, radius, exclude)


func lowest_hp_enemy_in_radius(center: Vector2, radius: float, exclude: int = 0) -> int:
	var best := 0
	var best_hp := INF
	for handle in enemies_in_radius(center, radius, exclude):
		var hp := enemy_hp(handle)
		if hp > 0.0 and hp < best_hp:
			best_hp = hp
			best = handle
	return best


func damage_enemy(handle: int, amount: float, tags: PackedStringArray) -> float:
	if not enemy_alive(handle) or amount <= 0.0:
		return 0.0
	var ledger_payload := HitLedger.new()
	ledger_payload.target_handle = handle
	ledger_payload.source = _player
	ledger_payload.hit_count = 1
	ledger_payload.total_raw_damage = amount
	ledger_payload.tags = tags
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return EnemyCombat.apply_hit_ledger(handle, ledger_payload)


# ---------------------------------------------------------------- statuses

func status_of(handle: int) -> Dictionary:
	var record: Dictionary = statuses.get(handle, {})
	if record.is_empty():
		record = {}
		statuses[handle] = record
	return record


func has_status(handle: int, key: String) -> bool:
	return (statuses.get(handle, {}) as Dictionary).has(key)


func clear_status(handle: int, key: String) -> void:
	if statuses.has(handle):
		(statuses[handle] as Dictionary).erase(key)


func _sweep_statuses() -> void:
	for handle in statuses.keys():
		if not enemy_alive(int(handle)):
			statuses.erase(handle)
			_last_lethal.erase(handle)


# ---------------------------------------------------------------- named rolls

## A named combat roll: chance after engine modifiers, times Proc Power,
## capped at 95% unless guaranteed. Failed rolls may be rerolled once when an
## engine grants it. Lucky Crit is not a named roll; its signals stay as is.
func roll(name: StringName, chance: float, proc_power: float = 1.0, guaranteed: bool = false) -> bool:
	var effective := chance
	for engine in engines:
		effective = engine.modify_roll_chance(name, effective)
	effective *= proc_power
	effective = 1.0 if guaranteed else clampf(effective, 0.0, ROLL_CAP)
	last_roll_chance = effective
	rolls_made += 1
	var success := rng().randf() < effective
	if not success and not guaranteed:
		for engine in engines:
			if engine.wants_reroll(name):
				success = rng().randf() < effective
				break
	if success:
		rolls_succeeded += 1
	roll_resolved.emit(name, success, effective)
	for engine in engines:
		engine.on_roll(name, success, effective)
	return success


# ---------------------------------------------------------------- hit contract

func _on_enemy_damaged(handle: int, applied: float, unclamped: float, before: float, source: Node, payload: Variant) -> void:
	if source != _player:
		return
	var hit := _make_hit(handle, applied, unclamped, before, payload)
	telemetry["hits"] = int(telemetry["hits"]) + 1
	if hit["family"] == AscensionTags.FAMILY_TREE:
		telemetry["tree_hits"] = int(telemetry["tree_hits"]) + 1
	if hit["lethal"]:
		_last_lethal[handle] = hit
	hit_resolved.emit(hit)
	for engine in engines:
		engine.on_hit(hit)


func _make_hit(handle: int, applied: float, unclamped: float, before: float, payload: Variant) -> Dictionary:
	var tags := PackedStringArray()
	var crit := false
	var ledger_payload := payload as HitLedger
	if ledger_payload != null:
		tags = ledger_payload.tags
		crit = ledger_payload.critical_hits > 0
	var parsed := AscensionTags.parse(tags)
	var after := maxf(0.0, before - applied)
	var max_hp := enemy_max_hp(handle)
	var hit := {
		"handle": handle,
		"applied": applied,
		"unclamped": unclamped,
		"before": before,
		"after": after,
		"lethal": after <= 0.0,
		"overkill": maxf(0.0, unclamped - before),
		"max_hp": max_hp,
		"fraction_after": (after / max_hp) if max_hp > 0.0 else 0.0,
		"position": enemy_position(handle),
		"is_elite": is_elite(handle),
		"is_boss": is_boss(handle),
		"crit": crit,
		"tags": tags,
		"core": parsed["core"],
		"family": parsed["family"] if not tags.is_empty() else ("status" if ledger_payload == null else ""),
		"root": parsed["root"],
		"path": parsed["path"],
		"gen": parsed["gen"],
		"pp": parsed["pp"],
		"flags": parsed["flags"],
	}
	hit["is_normal"] = not hit["is_elite"] and not hit["is_boss"]
	return hit


func _on_enemy_defeated(context: RefCounted) -> void:
	var handle := int(context.get("handle"))
	var hit: Dictionary = _last_lethal.get(handle, {})
	if hit.is_empty():
		hit = {"handle": handle, "lethal": true, "applied": 0.0, "overkill": 0.0, "family": "", "core": "", "root": "", "path": "", "gen": 0, "pp": 1.0, "flags": PackedStringArray(), "tags": PackedStringArray(), "position": context.get("position"), "is_elite": bool(context.get("is_elite")), "is_boss": false, "is_normal": not bool(context.get("is_elite")), "max_hp": 0.0, "before": 0.0, "after": 0.0, "unclamped": 0.0, "fraction_after": 0.0, "crit": false, "foreign": true}
	else:
		hit["foreign"] = false
	telemetry["kills"] = int(telemetry["kills"]) + 1
	if hit["family"] == AscensionTags.FAMILY_TREE:
		telemetry["tree_kills"] = int(telemetry["tree_kills"]) + 1
		telemetry["chain_kills"] = int(telemetry["chain_kills"]) + 1
	elif hit["family"] == AscensionTags.FAMILY_NATIVE:
		telemetry["seed_kills"] = int(telemetry["seed_kills"]) + 1
	_charge_revelation(hit)
	kill_resolved.emit(hit, context)
	for engine in engines:
		engine.on_kill(hit, context)
	statuses.erase(handle)
	_last_lethal.erase(handle)


func _charge_revelation(hit: Dictionary) -> void:
	if v_id.is_empty() or AscensionTags.has_flag(hit.get("tags", PackedStringArray()), "v"):
		return
	if _v_charge_actions >= V_CHARGE_ACTIONS_PER_SECOND:
		return
	_v_charge_actions += 1
	var gain := V_CHARGE_NORMAL
	if bool(hit.get("is_boss", false)):
		gain = V_CHARGE_BOSS
	elif bool(hit.get("is_elite", false)):
		gain = V_CHARGE_ELITE
	v_charge = minf(V_CHARGE_MAX, v_charge + gain)
	if _v_slot != null:
		_v_slot.announce(v_cooldown_left, v_cooldown_max)


## Kills caused per seed kill: the review's reproduction number.
func r0() -> float:
	var seeds := int(telemetry["seed_kills"])
	return float(telemetry["chain_kills"]) / float(seeds) if seeds > 0 else 0.0


func _on_weapon_fired(who: Node, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, haste_mul: float) -> void:
	if who != _player:
		return
	for engine in engines:
		engine.on_native_fire(String(style_id), origin, target, power_mul, haste_mul)


func _on_player_dashed(who: Node, from: Vector2, direction: Vector2) -> void:
	if who != _player:
		return
	for engine in engines:
		engine.on_player_dashed(from, direction)


func _on_player_damage_taken(who: Node, amount: float, _position: Vector2) -> void:
	if who != _player:
		return
	for engine in engines:
		engine.on_player_damage_taken(amount)


# ---------------------------------------------------------------- native attack decoration

func apply_to_melee_slash(slash: Node) -> void:
	slash.set_meta(AscensionTags.META_KEY, AscensionTags.native("melee", "slash"))
	for engine in engines:
		engine.decorate_native_slash(slash)


func apply_to_magic_impact(impact: Node) -> void:
	impact.set_meta(AscensionTags.META_KEY, AscensionTags.native("magic", "impact"))
	for engine in engines:
		engine.decorate_native_impact(impact)


func apply_to_managed_hit_profile(profile: HitProfileAdapter, style_id: StringName) -> void:
	profile.set_meta(AscensionTags.META_KEY, AscensionTags.native(String(style_id), "bullet"))
	for engine in engines:
		engine.decorate_native_profile(profile)


func apply_to_ranged_bullet(_bullet: Node, _style_id: StringName) -> void:
	pass


# ---------------------------------------------------------------- generated attacks

func spawn_slash(position: Vector2, direction: Vector2, damage: float, tags: PackedStringArray, arc_degrees: float = -1.0, arc_radius: float = -1.0) -> Node:
	if _player == null or not _player.has_method("spawn_generated_slash"):
		return null
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return _player.call("spawn_generated_slash", position, direction, damage, tags, arc_degrees, arc_radius)


func spawn_impact(position: Vector2, damage: float, tags: PackedStringArray, radius: float = -1.0) -> Node:
	if _player == null or not _player.has_method("spawn_generated_impact"):
		return null
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return _player.call("spawn_generated_impact", position, damage, tags, radius)


func spawn_bullet(origin: Vector2, direction: Vector2, damage: float, tags: PackedStringArray, overrides: Dictionary = {}) -> bool:
	if _player == null or not _player.has_method("spawn_generated_bullet"):
		return false
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return bool(_player.call("spawn_generated_bullet", origin, direction, damage, tags, overrides))


func pay_health(amount: float, reason: StringName) -> float:
	if _player == null or not _player.has_method("pay_health"):
		return 0.0
	return float(_player.call("pay_health", amount, reason))


## The visible world rectangle, from the player's camera when it has one.
func camera_rect() -> Rect2:
	var size := Vector2(1280, 720)
	var center := player_position()
	if _player != null:
		var camera := _player.get_node_or_null("Camera2D") as Camera2D
		var viewport := _player.get_viewport()
		if camera != null and viewport != null and camera.is_current():
			size = viewport.get_visible_rect().size / camera.zoom
			center = camera.get_screen_center_position()
	return Rect2(center - size * 0.5, size)


## A point on the edge of the visible rectangle at `angle` from its centre.
func camera_edge_point(angle: float) -> Vector2:
	var rect := camera_rect()
	var center := rect.get_center()
	var dir := Vector2.from_angle(angle)
	var half := rect.size * 0.5
	var scale := INF
	if absf(dir.x) > 0.0001:
		scale = minf(scale, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		scale = minf(scale, half.y / absf(dir.y))
	return center + dir * (scale * 0.96)


## Fires the native weapon as if the input were pressed (Bottomless).
func fire_native(target: Vector2) -> void:
	if _player != null and _player.has_method("_fire_weapon"):
		_player.call("_fire_weapon", target)


## Blocks native firing for `seconds` (a Jam) using the weapon cooldown.
func block_native_fire(seconds: float) -> void:
	if _player != null:
		var left := float(_player.get("_weapon_cd"))
		_player.set("_weapon_cd", maxf(left, seconds))


func _draw() -> void:
	if _draw_points.is_empty():
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for point in _draw_points:
		draw_circle(point[0], float(point[1]), point[2])


# ---------------------------------------------------------------- multipliers

func get_power_multiplier() -> float:
	var total := 1.0
	for engine in engines:
		total *= engine.power_multiplier(native_core)
	return total


func get_haste_multiplier() -> float:
	var total := 1.0
	for engine in engines:
		total *= engine.haste_multiplier(native_core)
	return total


func get_move_speed_multiplier() -> float:
	var total := 1.0
	for engine in engines:
		total *= engine.move_speed_multiplier()
	return total


func get_damage_taken_multiplier() -> float:
	var total := 1.0
	for engine in engines:
		total *= engine.damage_taken_multiplier()
	return total


# ---------------------------------------------------------------- Q / V

func _process(delta: float) -> void:
	if engines.is_empty() and q_id.is_empty() and v_id.is_empty():
		return
	if q_cooldown_left > 0.0:
		q_cooldown_left = maxf(0.0, q_cooldown_left - delta)
		if _q_slot != null:
			_q_slot.announce(q_cooldown_left, q_cooldown_max)
	if v_cooldown_left > 0.0:
		v_cooldown_left = maxf(0.0, v_cooldown_left - delta)
		if _v_slot != null:
			_v_slot.announce(v_cooldown_left, v_cooldown_max)
	_v_charge_window += delta
	if _v_charge_window >= 1.0:
		_v_charge_window = 0.0
		_v_charge_actions = 0
	for engine in engines:
		engine.tick(delta)
	_draw_points.clear()
	for engine in engines:
		engine.collect_draw_points(_draw_points)
	if not _draw_points.is_empty() or is_visible_in_tree():
		queue_redraw()
	_sweep_accum += delta
	if _sweep_accum >= STATUS_SWEEP_INTERVAL:
		_sweep_accum = 0.0
		_sweep_statuses()
	if _input_allowed():
		if Input.is_action_just_pressed(&"ascension_active"):
			activate_q()
		if Input.is_action_just_pressed(&"ascension_revelation"):
			activate_v()


func _input_allowed() -> bool:
	if get_tree() == null or get_tree().paused:
		return false
	if _player != null and bool(_player.get("is_dead")):
		return false
	if Global != null and Global.has_method("active_augment_input_blocked") and Global.active_augment_input_blocked():
		return false
	return true


func activate_q() -> Dictionary:
	return _activate("q")


func activate_v() -> Dictionary:
	return _activate("v")


func _activate(slot: String) -> Dictionary:
	var id := q_id if slot == "q" else v_id
	var hud := _q_slot if slot == "q" else _v_slot
	if id.is_empty():
		return {"ok": false, "message": "NOTHING EQUIPPED", "cooldown": 0.0}
	var left := q_cooldown_left if slot == "q" else v_cooldown_left
	if left > 0.0:
		if hud != null:
			hud.fail("COOLING")
		return {"ok": false, "message": "COOLING", "cooldown": left}
	if slot == "v" and v_charge < V_CHARGE_MAX:
		if hud != null:
			hud.fail("CHARGING")
		return {"ok": false, "message": "CHARGING", "cooldown": 0.0}
	var engine := engine_for(id)
	if engine == null:
		if hud != null:
			hud.fail("NOT WIRED")
		return {"ok": false, "message": "NOT WIRED", "cooldown": 0.0}
	var result := engine.activate_q(id) if slot == "q" else engine.activate_v(id)
	if not bool(result.get("ok", false)):
		if hud != null:
			hud.fail(String(result.get("message", "FAILED")))
		return result
	var cooldown := float(result.get("cooldown", 0.0))
	if slot == "q":
		q_cooldown_max = cooldown
		q_cooldown_left = cooldown
	else:
		v_cooldown_max = cooldown
		v_cooldown_left = cooldown
		v_charge = 0.0
	if hud != null:
		hud.announce(cooldown, cooldown)
	return result


## What the HUD slot shows; engines add resource lines through hud_state.
func slot_state(slot: String) -> Dictionary:
	var id := q_id if slot == "q" else v_id
	var left := q_cooldown_left if slot == "q" else v_cooldown_left
	var max_cd := q_cooldown_max if slot == "q" else v_cooldown_max
	var state := {
		"ready": not id.is_empty() and left <= 0.0,
		"cooldown_left": left,
		"cooldown_max": max_cd,
		"resource_value": 0.0,
		"resource_max": 0.0,
		"status_text": "READY" if left <= 0.0 else "%.1fs" % left,
		"combat_text": "",
	}
	if slot == "v":
		state["ready"] = state["ready"] and v_charge >= V_CHARGE_MAX
		state["resource_value"] = v_charge
		state["resource_max"] = V_CHARGE_MAX
		if v_charge < V_CHARGE_MAX and left <= 0.0:
			state["status_text"] = "%d%%" % int(v_charge)
	var engine := engine_for(id)
	if engine != null:
		state.merge(engine.hud_state(slot), true)
	return state


func describe() -> Dictionary:
	var out := {"native": native_core, "active": active_ids.keys(), "q": q_id, "v": v_id, "v_charge": v_charge, "r0": r0(), "telemetry": telemetry.duplicate(), "rolls": [rolls_made, rolls_succeeded]}
	for engine in engines:
		out[engine.discipline()] = engine.describe()
	return out
