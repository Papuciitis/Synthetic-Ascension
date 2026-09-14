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
	"DT": "res://core/systems/ascension/engines/DistortionEngine.gd",
}
## Revelation charge: kills fill it, the equipped V spends all of it. Normals
## give half a point (the review's correction), elites eight, bosses thirty;
## at most four charging kills count per second and V-rooted kills never do.
const V_CHARGE_MAX := 100.0
const V_CHARGE_NORMAL := 0.5
const V_CHARGE_ELITE := 8.0
const V_CHARGE_BOSS := 30.0
const V_CHARGE_ACTIONS_PER_SECOND := 4
## Generated attacks (Cleave, Corpse Bomb, Gavel, Witness, Twice, Hot Rounds)
## are data, not nodes: they queue here and resolve through the handle
## queries a few per frame, so a forty-body chain spreads over a handful of
## frames instead of dropping forty Area2Ds with eight shapes each into one
## physics step (the 22:58 capture: physics 337 ms, 12,000 draw calls).
const ATTACK_BUDGET_PER_FRAME := 12
const ATTACK_FX_SECONDS := 0.16
const SLASH_DEFAULT_ARC := 145.0
const SLASH_DEFAULT_RADIUS := 62.0
const IMPACT_DEFAULT_RADIUS := 48.0
const L := 240.0   # the design's long distance
const R := 80.0    # the design's radius unit
## Witness: a foreign Core strike every second native input (review F12) for
## each Core a Gate opened; two foreign Cores alternate. 0.6D, Proc Power 0.6.
const WITNESS_EVERY := 2
const WITNESS_D := 0.6
const WITNESS_PP := 0.6
## Reaction Q (review F14): opens with the first Gate; 60% damage and Proc
## Power, twice the recovery; casts on a catastrophe or on losing 15% max HP
## to enemies within a second.
const REACTION_SCALE := 0.6
const REACTION_RECOVERY := 2.0
const REACTION_HP_TRIGGER := 0.15
## Ascendant: every native input emits one real strike from each foreign
## Core at 0.45D, Proc Power 0.45, replacing the Witness schedule.
const ASCENDANT_D := 0.45
const ASCENDANT_PP := 0.45
const ECHO_DELAY := 0.3
const SECOND_SKIN_COOLDOWN := 15.0
const TWENTY_BODIES := 20

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
var reaction_id: String = ""
var reaction_cooldown_left: float = 0.0
var reaction_cooldown_max: float = 0.0
var reaction_cast: bool = false
var _recent_damage: float = 0.0
var _recent_damage_window: float = 0.0
var _native_inputs: int = 0
var _witness_turn: int = 0
var witness_strikes: int = 0
var ascendant_strikes: int = 0
var _echoes: Array = []              # {delay, core, origin, target, damage, tags}
var _second_skin_cd: float = 0.0
var _second_skin_double: bool = false
var _twenty_awarded: Dictionary = {} # cast root -> milestones paid
var _twenty_core_turn: int = 0
var v2_id: String = ""
var _v_turn: int = 0
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

var telemetry: Dictionary = {"hits": 0, "kills": 0, "tree_hits": 0, "tree_kills": 0, "generated": 0, "seed_kills": 0, "chain_kills": 0, "longest_chain": 0, "catastrophes": 0, "revelations": 0}
var _chain_counts: Dictionary = {}   # cast root -> distinct victims
var _draw_points: Array = []   # [position, radius, color] gathered from engines each frame
var _attack_queue: Array = []  # {kind, at, dir, damage, tags, radius, arc}
var _attack_fx: Array = []     # resolved attacks still being drawn: {kind, at, dir, radius, arc, ttl, color}
var _sector_scratch: Array[int] = []
var _claimed_nouns: Array[StringName] = []


func _ready() -> void:
	_player = get_parent()
	refresh()


func _exit_tree() -> void:
	_set_wired(false)
	engines.clear()
	_sync_noun_claims()


## Claim before release (the state resets a noun that drops to zero claimers).
func _sync_noun_claims() -> void:
	var wanted: Array[StringName] = []
	for engine in engines:
		for noun in engine.claimed_nouns():
			if not wanted.has(noun):
				wanted.append(noun)
	var state := manifestation_state()
	if state == null:
		return
	for noun in wanted:
		if not _claimed_nouns.has(noun):
			state.call("claim", noun)
	for noun in _claimed_nouns:
		if not wanted.has(noun):
			state.call("release", noun)
	_claimed_nouns = wanted


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
	_sync_noun_claims()
	q_id = ledger.equipped("q") if active_ids.has(ledger.equipped("q")) else ""
	v_id = ledger.equipped("v") if active_ids.has(ledger.equipped("v")) else ""
	reaction_id = ledger.equipped("reaction") if active_ids.has(ledger.equipped("reaction")) else ""
	v2_id = ledger.equipped("v2") if (owns("ASC") and active_ids.has(ledger.equipped("v2"))) else ""
	_q_slot = _sync_slot(_q_slot, "q", q_id)
	_v_slot = _sync_slot(_v_slot, "v", v_id)
	_set_wired(active_ids.size() > 0)
	refreshed.emit()


func _rebuild_engines() -> void:
	var wanted: Dictionary = {}   # discipline -> {id: true}
	for id in active_ids:
		var codes := PackedStringArray()
		var code := ledger.db.discipline_of(id)
		if not code.is_empty():
			codes.append(code)
		elif ledger.db.kind(id) == "fusion":
			# A Fusion belongs to both parents: each engine sees it and runs
			# its half (Kill Feed: Execution finishes, Barrage fragments).
			codes = ledger.db.fusion_disciplines(id)
		for engine_code in codes:
			if not wanted.has(engine_code):
				wanted[engine_code] = {}
			(wanted[engine_code] as Dictionary)[id] = true
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
func roll(roll_name: StringName, chance: float, proc_power: float = 1.0, guaranteed: bool = false) -> bool:
	var effective := chance
	for engine in engines:
		effective = engine.modify_roll_chance(roll_name, effective)
	effective *= proc_power
	if not guaranteed:
		for engine in engines:
			if engine.wants_guarantee(roll_name, proc_power):
				guaranteed = true
				break
	effective = 1.0 if guaranteed else clampf(effective, 0.0, ROLL_CAP)
	last_roll_chance = effective
	rolls_made += 1
	var success := rng().randf() < effective
	if not success and not guaranteed:
		for engine in engines:
			if engine.wants_reroll(roll_name):
				success = rng().randf() < effective
				break
	if success:
		rolls_succeeded += 1
	roll_resolved.emit(roll_name, success, effective)
	for engine in engines:
		engine.on_roll(roll_name, success, effective)
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
	elif owns("ASC2") and _second_skin_cd <= 0.0 and float(hit["max_hp"]) > 0.0 and float(hit["applied"]) >= 0.15 * float(hit["max_hp"]):
		_second_skin()
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
	var cast := AscensionTags.value_of(hit.get("tags", PackedStringArray()), "cast")
	if not cast.is_empty():
		_chain_counts[cast] = int(_chain_counts.get(cast, 0)) + 1
		telemetry["longest_chain"] = maxi(int(telemetry["longest_chain"]), int(_chain_counts[cast]))
		_twenty_bodies(cast, hit.get("position", player_position()))
		if _chain_counts.size() > 512:
			_chain_counts.clear()
			_twenty_awarded.clear()
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
	_native_inputs += 1
	if owns("ASC"):
		for core in foreign_cores():
			_foreign_strike(String(core), origin, target, ASCENDANT_D, ASCENDANT_PP, "ascendant", true)
	elif _native_inputs % WITNESS_EVERY == 0:
		_witness(origin, target)


## Cores a Gate opened, in a stable order.
func foreign_cores() -> Array:
	var out: Array = []
	for core in AscensionTreeDB.CORES:
		if core != native_core and ledger != null and ledger.has_core(core):
			out.append(core)
	return out


func _witness(origin: Vector2, target: Vector2) -> void:
	var foreign := foreign_cores()
	if foreign.is_empty():
		return
	var core := String(foreign[_witness_turn % foreign.size()])
	_witness_turn += 1
	witness_strikes += 1
	_foreign_strike(core, origin, target, WITNESS_D, WITNESS_PP, "witness", true)


## One real strike of a foreign Core with that Core's geometry: a 120-degree
## slash at the player, a projectile along aim, or an R/2 impact at aim. It
## qualifies for the Core's strike rules through the engines' witness tags.
func _foreign_strike(core: String, origin: Vector2, target: Vector2, d_scale: float, pp: float, root: String, may_echo: bool) -> void:
	var flags := PackedStringArray(["core_strike", root])
	var path: String = {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core]
	var tags := AscensionTags.make(core, AscensionTags.FAMILY_TREE, root, path, 1, pp, flags)
	var serial := witness_strikes if root == "witness" else ascendant_strikes
	if root == "ascendant":
		ascendant_strikes += 1
		serial = ascendant_strikes
	tags.append("cast:%s:%d" % [root, serial])
	for engine in engines:
		for extra in engine.witness_tags(core):
			if not tags.has(extra):
				tags.append(extra)
	var damage := d_scale * native_damage_for(core)
	_emit_strike(core, origin, target, damage, tags)
	for engine in engines:
		engine.on_witness_strike(core, origin, target)
	if may_echo and root == "ascendant" and owns("ASC1"):
		_echoes.append({"delay": ECHO_DELAY, "core": core, "origin": origin, "target": target, "damage": damage * 0.5, "tags": _echo_tags(tags)})


func _echo_tags(tags: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for tag in tags:
		if tag.begins_with("pp:"):
			out.append("pp:0.250")
		elif tag == "flag:ascendant":
			out.append("flag:echo")
		else:
			out.append(tag)
	return out


func _emit_strike(core: String, origin: Vector2, target: Vector2, damage: float, tags: PackedStringArray) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	match core:
		"melee":
			spawn_slash(player_position() + dir * 10.0, dir, damage, tags, 120.0, R)
		"ranged":
			spawn_bullet(origin, dir, damage, tags)
		"magic":
			var offset := target - player_position()
			if offset.length() > 3.0 * L:
				offset = offset.normalized() * 3.0 * L
			spawn_impact(player_position() + offset, damage, tags, R * 0.5)


func _tick_echoes(delta: float) -> void:
	if _echoes.is_empty():
		return
	var due: Array = []
	for echo in _echoes:
		echo["delay"] = float(echo["delay"]) - delta
		if float(echo["delay"]) <= 0.0:
			due.append(echo)
	for echo in due:
		_echoes.erase(echo)
		_emit_strike(String(echo["core"]), echo["origin"], echo["target"], float(echo["damage"]), echo["tags"])


## Twenty Bodies (ASC3): a root that has killed twenty distinct enemies
## commands one 2D foreign strike at the nearest survivor, cycling Cores.
func _twenty_bodies(cast: String, at: Vector2) -> void:
	if not owns("ASC3") or foreign_cores().is_empty():
		return
	var bodies := int(_chain_counts.get(cast, 0))
	var milestones := bodies / TWENTY_BODIES
	if milestones <= int(_twenty_awarded.get(cast, 0)):
		return
	_twenty_awarded[cast] = milestones
	var target := nearest_enemy(at, L)
	if target == 0:
		return
	var foreign := foreign_cores()
	var core := String(foreign[_twenty_core_turn % foreign.size()])
	_twenty_core_turn += 1
	var flags := PackedStringArray(["core_strike", "twenty_bodies"])
	var path: String = {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core]
	var tags := AscensionTags.make(core, AscensionTags.FAMILY_TREE, "ASC3", path, 2, ASCENDANT_PP, flags)
	tags.append("cast:" + cast)
	_emit_strike(core, player_position(), enemy_position(target), 2.0 * native_damage_for(core), tags)


## D for any Core: the native hit damage that Core would have.
func native_damage_for(core: String) -> float:
	if _player == null:
		return 12.0
	var base := float(_player.get("base_weapon_damage"))
	var stats: Variant = _player.get("stats")
	var power := 1.0 + (float(stats.get("power")) if stats != null else 0.0)
	return base * CombatStyleTuning.damage_multiplier(StringName(core)) * power


## Engines call this when a catastrophe fires; the Reaction Q answers.
func note_catastrophe(id: String) -> void:
	telemetry["catastrophes"] = int(telemetry["catastrophes"]) + 1
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"ascension", &"catastrophe", {"node": id, "r0": r0(), "longest_chain": int(telemetry["longest_chain"])})
	for engine in engines:
		engine.on_catastrophe(id)
	_try_reaction("catastrophe:" + id)


## Damage scale for Q payloads: 1.0 for a manual cast, 0.6 for a Reaction cast.
func q_scale() -> float:
	return REACTION_SCALE if reaction_cast else 1.0


func _second_skin() -> void:
	if reaction_id.is_empty():
		return
	_second_skin_cd = SECOND_SKIN_COOLDOWN
	reaction_cooldown_left = 0.0
	_second_skin_double = true
	_try_reaction("second_skin")


func _try_reaction(trigger: String) -> Dictionary:
	if reaction_id.is_empty() or reaction_cooldown_left > 0.0:
		return {"ok": false, "message": "NO REACTION", "cooldown": 0.0}
	var engine := engine_for(reaction_id)
	if engine == null:
		return {"ok": false, "message": "NOT WIRED", "cooldown": 0.0}
	reaction_cast = true
	var result := engine.activate_q(reaction_id)
	reaction_cast = false
	if bool(result.get("ok", false)):
		var cooldown := _recovery(float(result.get("cooldown", 0.0))) * REACTION_RECOVERY
		if _second_skin_double:
			_second_skin_double = false
			cooldown *= 2.0
		reaction_cooldown_max = cooldown
		reaction_cooldown_left = cooldown
		result["trigger"] = trigger
		if BattleText != null:
			BattleText.popup(player_position(), "REACTION " + String(result.get("message", "")), Color(0.9, 0.8, 0.4, 1.0), 1.2)
	return result


## Ordinary Q recovery after the Ascendant Recovery sink.
func _recovery(base: float) -> float:
	if ledger != null and ledger.rank("ASC.S2") > 0:
		var r := float(ledger.rank("ASC.S2"))
		return base * (1.0 - 0.20 * r / (r + 100.0))
	return base


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
	_recent_damage += amount
	_recent_damage_window = 1.0
	var max_hp := float(_player.get("max_hp"))
	if max_hp > 0.0 and _recent_damage >= REACTION_HP_TRIGGER * max_hp:
		_recent_damage = 0.0
		_try_reaction("damage")


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

## Queues a slash: a sector of `arc_degrees` and `arc_radius` from `at`
## along `direction`, hitting every enemy in it once. Returns nothing; the
## strike resolves within the next frames (see flush_attacks).
func spawn_slash(at: Vector2, direction: Vector2, damage: float, tags: PackedStringArray, arc_degrees: float = -1.0, arc_radius: float = -1.0) -> Node:
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_attack_queue.append({
		"kind": "slash", "at": at, "dir": dir, "damage": damage, "tags": tags,
		"radius": arc_radius if arc_radius > 0.0 else SLASH_DEFAULT_RADIUS,
		"arc": arc_degrees if arc_degrees > 0.0 else SLASH_DEFAULT_ARC,
	})
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return null


## Queues an impact: every enemy within `radius` of `at` is hit once.
func spawn_impact(at: Vector2, damage: float, tags: PackedStringArray, radius: float = -1.0) -> Node:
	_attack_queue.append({
		"kind": "impact", "at": at, "dir": Vector2.RIGHT, "damage": damage, "tags": tags,
		"radius": radius if radius > 0.0 else IMPACT_DEFAULT_RADIUS, "arc": 360.0,
	})
	telemetry["generated"] = int(telemetry["generated"]) + 1
	return null


## Copies of the attacks still waiting to resolve (tests, telemetry).
func pending_attacks() -> Array:
	return _attack_queue.duplicate(true)


## Resolves queued attacks, at most `max_count` (all when negative). Attacks
## queued by the kills these cause wait for the next call, so a chain never
## recurses inside one resolution. Returns how many resolved.
func flush_attacks(max_count: int = -1) -> int:
	var resolved := 0
	var limit := _attack_queue.size() if max_count < 0 else mini(max_count, _attack_queue.size())
	while resolved < limit and not _attack_queue.is_empty():
		var entry: Dictionary = _attack_queue.pop_front()
		_resolve_attack(entry)
		resolved += 1
	return resolved


func _resolve_attack(entry: Dictionary) -> void:
	var at: Vector2 = entry["at"]
	var radius := float(entry["radius"])
	var damage := float(entry["damage"])
	var tags: PackedStringArray = entry["tags"]
	var targets: Array[int] = []
	if String(entry["kind"]) == "slash":
		EnemyCombat.gather_in_sector(at, entry["dir"], maxf(2.0, radius * 0.95), 0.0, deg_to_rad(clampf(float(entry["arc"]), 5.0, 340.0)) * 0.5, _sector_scratch)
		targets = _sector_scratch.duplicate()
	else:
		EnemyCombat.gather_in_radius(at, radius, targets)
	for handle in targets:
		damage_enemy(handle, damage, tags)
	var color := Color(0.95, 0.85, 0.5, 0.85)
	match AscensionTags.value_of(tags, "core"):
		"melee":
			color = Color(1.0, 0.45, 0.35, 0.85)
		"ranged":
			color = Color(0.5, 0.75, 1.0, 0.85)
		"magic":
			color = Color(0.8, 0.55, 1.0, 0.85)
	_attack_fx.append({"kind": entry["kind"], "at": at, "dir": entry["dir"], "radius": radius, "arc": float(entry["arc"]), "ttl": ATTACK_FX_SECONDS, "color": color})


func _tick_attack_fx(delta: float) -> void:
	for i in range(_attack_fx.size() - 1, -1, -1):
		var fx: Dictionary = _attack_fx[i]
		fx["ttl"] = float(fx["ttl"]) - delta
		if float(fx["ttl"]) <= 0.0:
			_attack_fx.remove_at(i)


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
	var reach := INF
	if absf(dir.x) > 0.0001:
		reach = minf(reach, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		reach = minf(reach, half.y / absf(dir.y))
	return center + dir * (reach * 0.96)


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
	if _draw_points.is_empty() and _attack_fx.is_empty():
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for fx in _attack_fx:
		var fade := clampf(float(fx["ttl"]) / ATTACK_FX_SECONDS, 0.0, 1.0)
		var color: Color = fx["color"]
		color.a *= fade
		var at: Vector2 = fx["at"]
		var radius := float(fx["radius"])
		if String(fx["kind"]) == "slash":
			var facing: float = (fx["dir"] as Vector2).angle()
			var half := deg_to_rad(float(fx["arc"])) * 0.5
			draw_arc(at, radius * (0.75 + 0.25 * (1.0 - fade)), facing - half, facing + half, 24, color, 5.0 * fade + 1.0, true)
		else:
			draw_arc(at, radius * (0.6 + 0.4 * (1.0 - fade)), 0.0, TAU, 32, color, 3.0 * fade + 1.0, true)
			color.a *= 0.15
			draw_circle(at, radius * (0.6 + 0.4 * (1.0 - fade)), color)
	var font := ThemeDB.fallback_font
	for point in _draw_points:
		draw_circle(point[0], float(point[1]), point[2])
		if point.size() > 3 and font != null:
			var text := String(point[3])
			draw_string(font, (point[0] as Vector2) + Vector2(-18.0, -float(point[1]) - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, point[2])


## The shared Misfortune pool lives on the Manifestation layer; the tree only
## adds to it and spends it there, so Broken Providence and the pair rules see
## the same number.
func manifestation_state() -> Object:
	if _player == null:
		return null
	var manifestations := _player.get_node_or_null("ManifestationRunner")
	if manifestations == null:
		return null
	var state: Variant = manifestations.get("state")
	return state as Object


func add_misfortune(amount: int = 1) -> void:
	var state := manifestation_state()
	if state != null and state.has_method("add_misfortune"):
		state.call("add_misfortune", amount)


func misfortune() -> int:
	var state := manifestation_state()
	return int(state.get("misfortune")) if state != null else 0


func spend_misfortune(amount: int) -> bool:
	var state := manifestation_state()
	if state == null or int(state.get("misfortune")) < amount:
		return false
	state.set("misfortune", int(state.get("misfortune")) - amount)
	return true


func heal_player(amount: float, source: StringName) -> void:
	if _player != null and _player.has_method("heal") and amount > 0.0:
		_player.call("heal", amount, source)


# ---------------------------------------------------------------- multipliers

func get_power_multiplier() -> float:
	var total := 1.0
	for engine in engines:
		total *= engine.power_multiplier(native_core)
	if ledger != null and ledger.rank("ASC.S1") > 0:
		total *= 1.0 + 0.005 * sqrt(float(ledger.rank("ASC.S1")))
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
	if engines.is_empty() and q_id.is_empty() and v_id.is_empty() and _attack_queue.is_empty() and _attack_fx.is_empty():
		return
	if q_cooldown_left > 0.0:
		q_cooldown_left = maxf(0.0, q_cooldown_left - delta)
		if _q_slot != null:
			_q_slot.announce(q_cooldown_left, q_cooldown_max)
	if v_cooldown_left > 0.0:
		v_cooldown_left = maxf(0.0, v_cooldown_left - delta)
		if _v_slot != null:
			_v_slot.announce(v_cooldown_left, v_cooldown_max)
	if reaction_cooldown_left > 0.0:
		reaction_cooldown_left = maxf(0.0, reaction_cooldown_left - delta)
	if _second_skin_cd > 0.0:
		_second_skin_cd = maxf(0.0, _second_skin_cd - delta)
	_tick_echoes(delta)
	if _recent_damage_window > 0.0:
		_recent_damage_window -= delta
		if _recent_damage_window <= 0.0:
			_recent_damage = 0.0
	_v_charge_window += delta
	if _v_charge_window >= 1.0:
		_v_charge_window = 0.0
		_v_charge_actions = 0
	for engine in engines:
		engine.tick(delta)
	flush_attacks(ATTACK_BUDGET_PER_FRAME)
	_tick_attack_fx(delta)
	_draw_points.clear()
	for engine in engines:
		engine.collect_draw_points(_draw_points)
	if not _draw_points.is_empty() or not _attack_fx.is_empty():
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
	if not v2_id.is_empty() and (_v_turn % 2 == 1):
		var result := _activate("v2")
		if bool(result.get("ok", false)):
			_v_turn += 1
		return result
	var result := _activate("v")
	if bool(result.get("ok", false)):
		_v_turn += 1
	return result


func _activate(slot: String) -> Dictionary:
	var id := q_id if slot == "q" else (v2_id if slot == "v2" else v_id)
	var hud := _q_slot if slot == "q" else _v_slot
	if slot == "v2":
		slot = "v"
		if id.is_empty():
			return {"ok": false, "message": "NOTHING EQUIPPED", "cooldown": 0.0}
	if id.is_empty():
		return {"ok": false, "message": "NOTHING EQUIPPED", "cooldown": 0.0}
	var left := q_cooldown_left if slot == "q" else v_cooldown_left
	if left > 0.0:
		if hud != null:
			hud.fail("COOLING")
		return {"ok": false, "message": "COOLING", "cooldown": left}
	if slot == "v" and Global != null and not Global.debug_ascension_revelations_enabled:
		if hud != null:
			hud.fail("REVELATIONS OFF")
		return {"ok": false, "message": "REVELATIONS OFF", "cooldown": 0.0}
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
		cooldown = _recovery(cooldown)
		q_cooldown_max = cooldown
		q_cooldown_left = cooldown
	else:
		v_cooldown_max = cooldown
		v_cooldown_left = cooldown
		v_charge = 0.0
		telemetry["revelations"] = int(telemetry["revelations"]) + 1
		if PerformanceFlightRecorder != null:
			PerformanceFlightRecorder.record_event(&"ascension", &"revelation", {"node": id, "r0": r0()})
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
	var out := {"native": native_core, "active": active_ids.keys(), "q": q_id, "v": v_id, "v2": v2_id, "reaction": reaction_id, "witness": witness_strikes, "ascendant": ascendant_strikes, "v_charge": v_charge, "r0": r0(), "queued_attacks": _attack_queue.size(), "telemetry": telemetry.duplicate(), "rolls": [rolls_made, rolls_succeeded]}
	for engine in engines:
		out[engine.discipline()] = engine.describe()
	return out
