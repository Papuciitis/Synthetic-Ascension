extends AscensionEngine
class_name ExecutionEngine
## Execution: the execute line, Marks, overkill Spillover, Corpse Bombs,
## Cleaves, Gavel, Red Mist and DECIMATION.
##
## Definition (review F1): an execution is a normal killed by an
## execution-enabled hit, by damage or by the line. Finish makes native Melee
## Core hits execution-enabled; Chain Sentence extends that to Spillover,
## Corpse Bomb and Cleave payloads; Gavel and DECIMATION always are. A hit
## that leaves a normal at or below the line finishes it on the spot.
##
## Every native input and every Gavel cast is a root ("cast:" tag) that the
## chain inherits, so Red Mist can count deaths per root and Blood can grow
## Spillover per fresh victim. Boss loop (review F13): Melee hits on a boss
## below half HP stack Bloodletting; a Gavel on a boss cracks it for +15% on
## your next five hits.

const BASE_LINE := 0.10
const BLOODLETTING_STEP := 0.02
const BLOODLETTING_CAP := 0.10
const BLOODLETTING_DURATION := 4.0
const MARK_DURATION := 3.0
const BOLT_SPEED := 600.0
const RED_MIST_DEATHS := 12
const CRACKED_HITS := 5

var _volley: int = 0
var _bloodletting_stacks: int = 0
var _bloodletting_left: float = 0.0
var _five_down_left: float = 0.0
var _five_down_count: int = 0
var _marks: Array[int] = []                 # handles, oldest first
var _mark_dirs: Dictionary = {}             # handle -> approach direction
var _root_deaths: Dictionary = {}           # cast id -> real deaths
var _root_victims: Dictionary = {}          # cast id -> fresh Spillover victims
var _root_spilled: Dictionary = {}          # cast id -> true once Spillover travelled (Meat)
var _root_gavel_targets: Dictionary = {}    # cast id -> {handle: true} chain Gavels delivered
var _bolts: Array = []                      # {pos, target, damage, tags, root}
var _reservoir: float = 0.0
var _reservoir_left: float = 0.0
var _pending_gavels: Array = []             # {delay, point, damage, radius, cast, kind}
var _gavel_casts: int = 0
var _gavel_windup: float = -1.0
var _gavel_scale: float = 1.0
var _gavel_point: Vector2 = Vector2.ZERO
var _gavel_cast_id: String = ""
var _gavel_executed: Dictionary = {}        # cast id -> executions
var _second_swing_left: float = -1.0
var _red_mist_recovery: float = 0.0
var _decimation_tell: float = -1.0
var _decimation_casts: int = 0
var _boss_sentence_cd: float = 0.0
var _clock: float = 0.0

var counters: Dictionary = {"executions": 0, "line_finishes": 0, "spillovers": 0, "bolt_hits": 0, "corpse_bombs": 0, "cleaves": 0, "marks": 0, "mark_consumed": 0, "first_cuts": 0, "last_words": 0, "reservoir_releases": 0, "gavels": 0, "gavel_executions": 0, "public_executions": 0, "chain_gavels": 0, "lesser_gavels": 0, "second_swings": 0, "red_mists": 0, "decimations": 0, "elite_sentences": 0, "boss_sentences": 0, "cracks": 0}


func discipline() -> String:
	return "EX"


func D() -> float:
	return runner.native_damage()


# ---------------------------------------------------------------- the line

## The normal execute line right now.
func line() -> float:
	var value := BASE_LINE
	if has("EXS2"):
		value += 0.0015 * float(mini(rank("EXS2"), 30))
	if has("EXK1"):
		value += 0.12
	if has("EX04"):
		value += BLOODLETTING_STEP * float(_bloodletting_stacks)
	if has("EXQ7") and _five_down_left > 0.0:
		value += 0.10
	return value


func gavel_line() -> float:
	if not has("EX01"):
		return 0.20
	return minf(0.60, 2.0 * line())


func _hit_line(hit: Dictionary, handle: int) -> float:
	var tags: PackedStringArray = hit["tags"]
	var value := line()
	if hit["path"] == "fragment":
		value *= 0.5
	elif hit["path"] == "gavel":
		value = gavel_line()
		if AscensionTags.has_flag(tags, "second_swing"):
			value += 0.10
	elif hit["path"] == "sweep" and has("EXV3"):
		value = maxf(0.0, value - 0.10)
	if has("EX08") and runner.has_status(handle, "wound") and AscensionTags.has_flag(tags, "core_strike"):
		value += 0.20
		runner.clear_status(handle, "wound")
	return value


func _execution_enabled(hit: Dictionary) -> bool:
	if hit["core"] == "melee" and AscensionTags.has_flag(hit["tags"], "execute_enabled"):
		return true
	# Kill Feed (MR2): fragments may apply Finish at half the line.
	return has("MR2") and hit["path"] == "fragment"


func _cast_of(tags: PackedStringArray) -> String:
	var cast := AscensionTags.value_of(tags, "cast")
	return cast if not cast.is_empty() else "native:%d" % _volley


func _payload_tags(root: String, path: String, hit: Dictionary, pp: float, extra_flags: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var flags := PackedStringArray()
	if has("EX10"):
		flags.append("execute_enabled")
	if AscensionTags.has_flag(hit["tags"], "v"):
		flags.append("v")
	flags.append_array(extra_flags)
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, root, path, int(hit["gen"]) + 1, pp, flags)
	tags.append("cast:" + _cast_of(hit["tags"]))
	return tags


# ---------------------------------------------------------------- native decoration

func witness_tags(core: String) -> PackedStringArray:
	if core != "melee":
		return PackedStringArray()
	return PackedStringArray(["flag:execute_enabled"]) if has("EX01") else PackedStringArray()


func decorate_native_slash(slash: Node) -> void:
	var tags: PackedStringArray = slash.get_meta(AscensionTags.META_KEY, PackedStringArray())
	tags = AscensionTags.with_flag(tags, "core_strike")
	if has("EX01"):
		tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:%d" % (_volley + 1))
	slash.set_meta(AscensionTags.META_KEY, tags)


func on_native_fire(style: String, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	if style == "melee":
		_volley += 1


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	if _bloodletting_left > 0.0:
		_bloodletting_left = maxf(0.0, _bloodletting_left - delta)
		if _bloodletting_left <= 0.0:
			_bloodletting_stacks = 0
	if _five_down_left > 0.0:
		_five_down_left = maxf(0.0, _five_down_left - delta)
	if _reservoir_left > 0.0:
		_reservoir_left = maxf(0.0, _reservoir_left - delta)
		if _reservoir_left <= 0.0:
			_reservoir = 0.0
	if _red_mist_recovery > 0.0:
		_red_mist_recovery = maxf(0.0, _red_mist_recovery - delta)
	if _boss_sentence_cd > 0.0:
		_boss_sentence_cd = maxf(0.0, _boss_sentence_cd - delta)
	_expire_marks()
	_tick_bolts(delta)
	_tick_gavel(delta)
	_tick_pending_gavels(delta)
	_tick_decimation(delta)


func _expire_marks() -> void:
	for i in range(_marks.size() - 1, -1, -1):
		var handle := _marks[i]
		var record: Dictionary = runner.statuses.get(handle, {})
		if not runner.enemy_alive(handle) or float(record.get("mark", 0.0)) <= _clock:
			_marks.remove_at(i)
			_mark_dirs.erase(handle)
			runner.clear_status(handle, "mark")


# ---------------------------------------------------------------- hits

func on_hit(hit: Dictionary) -> void:
	if hit["core"] != "melee" and not (has("MR2") and hit["path"] == "fragment"):
		return
	var handle := int(hit["handle"])
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	if bool(hit["lethal"]):
		return  # deaths are handled in on_kill
	if core_strike:
		_core_strike_hit(hit, handle)
	if bool(hit["is_boss"]):
		_boss_hit(hit, handle)
		return
	if not _execution_enabled(hit):
		return
	var fraction := float(hit["fraction_after"])
	if bool(hit["is_normal"]):
		if fraction <= _hit_line(hit, handle):
			_finish(hit, handle)
	elif bool(hit["is_elite"]) and (has("EX09") or (has("EXK2") and runner.has_status(handle, "mark"))):
		var elite_line := minf(0.15, 0.5 * line())
		if has("EXK2") and runner.has_status(handle, "mark"):
			elite_line = minf(0.20, line())
		if fraction <= elite_line:
			counters["elite_sentences"] = int(counters["elite_sentences"]) + 1
			_finish(hit, handle)


## Mark, First Cut, Reservoir release, Cracked and keystone modifiers on a Core hit.
func _core_strike_hit(hit: Dictionary, handle: int) -> void:
	var applied := float(hit["applied"])
	var bonus := 0.0
	if has("EX02") and runner.has_status(handle, "mark") and not runner.has_status(handle, "mark_fresh"):
		runner.clear_status(handle, "mark")
		_marks.erase(handle)
		bonus += 0.5 * D()
		counters["mark_consumed"] = int(counters["mark_consumed"]) + 1
	if has("EX02") and not runner.has_status(handle, "mark"):
		_mark(handle, hit)
	if has("EX08") and is_equal_approx(float(hit["before"]), float(hit["max_hp"])) and float(hit["max_hp"]) > 0.0:
		bonus += D()
		runner.status_of(handle)["wound"] = _clock + 2.0
		counters["first_cuts"] = int(counters["first_cuts"]) + 1
	if has("EX07") and _reservoir > 0.0:
		bonus += _reservoir
		_release_reservoir_line(hit, handle)
		_reservoir = 0.0
		_reservoir_left = 0.0
	if runner.has_status(handle, "cracked"):
		var record := runner.status_of(handle)
		bonus += 0.15 * applied
		record["cracked"] = int(record["cracked"]) - 1
		if int(record["cracked"]) <= 0:
			runner.clear_status(handle, "cracked")
	if has("EXK2"):
		if runner.has_status(handle, "mark"):
			bonus += 0.5 * applied
		else:
			EnemyCombat.heal(handle, 0.3 * applied)
	elif has("EXK1") and float(hit["before"]) > 0.5 * float(hit["max_hp"]):
		EnemyCombat.heal(handle, 0.25 * applied)
	runner.clear_status(handle, "mark_fresh")
	if bonus > 0.0 and runner.enemy_alive(handle):
		runner.damage_enemy(handle, bonus, _payload_tags("EX02", "bonus", hit, 0.0))


func _mark(handle: int, hit: Dictionary) -> void:
	var capacity := 8 if has("EXK2") else 1
	while _marks.size() >= capacity and not _marks.is_empty():
		var old: int = _marks.pop_front()
		runner.clear_status(old, "mark")
		_mark_dirs.erase(old)
	_marks.append(handle)
	var record := runner.status_of(handle)
	record["mark"] = _clock + MARK_DURATION
	record["mark_fresh"] = true
	_mark_dirs[handle] = ((hit["position"] as Vector2) - runner.player_position()).normalized()
	counters["marks"] = int(counters["marks"]) + 1


func _release_reservoir_line(hit: Dictionary, handle: int) -> void:
	counters["reservoir_releases"] = int(counters["reservoir_releases"]) + 1
	var origin: Vector2 = hit["position"]
	var forward := (origin - runner.player_position()).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var out: Array[int] = []
	EnemyCombat.gather_in_sector(origin, forward, 2.0 * AscensionRunner.R, 0.0, 0.2, out)
	for other in out:
		if other != handle:
			runner.damage_enemy(other, _reservoir, _payload_tags("EX07", "line", hit, 0.5))


func _boss_hit(hit: Dictionary, handle: int) -> void:
	if not AscensionTags.has_flag(hit["tags"], "core_strike"):
		return
	if has("EX04") and float(hit["fraction_after"]) < 0.5:
		_stack_bloodletting()
	if has("EX09") and float(hit["fraction_after"]) < 0.25 and _boss_sentence_cd <= 0.0:
		_boss_sentence_cd = 1.0
		counters["boss_sentences"] = int(counters["boss_sentences"]) + 1
		runner.damage_enemy(handle, D(), _payload_tags("EX09", "bonus", hit, 0.0))


func _stack_bloodletting() -> void:
	_bloodletting_stacks = mini(_bloodletting_stacks + 1, int(round(BLOODLETTING_CAP / BLOODLETTING_STEP)))
	_bloodletting_left = BLOODLETTING_DURATION


## The line finishes a survivor: one more hit with the same provenance.
func _finish(hit: Dictionary, handle: int) -> void:
	counters["line_finishes"] = int(counters["line_finishes"]) + 1
	var tags: PackedStringArray = (hit["tags"] as PackedStringArray).duplicate()
	tags = AscensionTags.with_flag(tags, "execute")
	tags = AscensionTags.with_flag(tags, "line_kill")
	runner.damage_enemy(handle, runner.enemy_hp(handle) + 0.01, tags)


# ---------------------------------------------------------------- kills

func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var melee_kill: bool = hit["core"] == "melee"
	if not melee_kill and not (has("MR2") and hit["path"] == "fragment"):
		return
	var handle := int(hit["handle"])
	var tags: PackedStringArray = hit["tags"]
	var cast := _cast_of(tags)
	var by_line := AscensionTags.has_flag(tags, "line_kill")
	var executed := _execution_enabled(hit) and (bool(hit["is_normal"]) or by_line)
	var overkill := float(hit["overkill"])
	if by_line:
		overkill = 0.5 * D()  # the seed: a threshold kill never starts an empty chain
	if executed:
		_on_execution(hit, handle, cast, overkill)
	if not melee_kill:
		return  # a fragment execution runs the execution families only
	_root_deaths[cast] = int(_root_deaths.get(cast, 0)) + 1
	if has("EX03") and not (has("EXF1") and _root_spilled.get(cast, false)):
		_spillover(hit, handle, cast, overkill)
	if has("EX06"):
		_cleave(hit, handle)
	if has("EX11") and runner.has_status(handle, "mark"):
		_last_word(hit, handle)
	_marks.erase(handle)
	_mark_dirs.erase(handle)
	if has("EXC") and _red_mist_recovery <= 0.0 and int(_root_deaths[cast]) >= RED_MIST_DEATHS:
		_red_mist(hit)


func _on_execution(hit: Dictionary, handle: int, cast: String, overkill: float) -> void:
	counters["executions"] = int(counters["executions"]) + 1
	if has("EX04"):
		_stack_bloodletting()
	var path := String(hit["path"])
	var from_gavel: bool = path == "gavel" or path == "chain_gavel" or path == "lesser_gavel"
	if from_gavel:
		counters["gavel_executions"] = int(counters["gavel_executions"]) + 1
		_gavel_executed[cast] = int(_gavel_executed.get(cast, 0)) + 1
		if has("EXQ7"):
			_five_down_count += 1
			if _five_down_count >= 5:
				_five_down_count = 0
				_five_down_left = 5.0
		if has("EXQ3") and hit["path"] == "gavel" and overkill > 0.0:
			_public_execution(hit, handle, overkill)
		if has("EXE2") and hit["path"] != "lesser_gavel":
			_queue_chain_gavel(hit, handle, cast)
		if has("EXE1") and hit["path"] == "gavel":
			_queue_lesser_gavel(hit, cast)
	var body_count: bool = path == "sweep" and has("EXV2")
	if has("EX05") or body_count:
		_corpse_bomb(hit, handle, overkill, body_count and not has("EX05"))
	# Kill Feed (MR2): a fragment execution grants one extra fragment.
	if path == "fragment" and has("MR2"):
		var barrage := runner.engine_for("BR05") as BarrageEngine
		if barrage != null:
			counters["kill_feed"] = int(counters.get("kill_feed", 0)) + 1
			barrage.extra_fragment(hit["position"], handle)
	# Death Debt (MM2): the victim's unpaid Debt explodes as a Magic payload.
	if has("MM2"):
		var distortion := runner.engine_for("DT06") as DistortionEngine
		if distortion != null:
			var owed := distortion.collect_for_death_debt(handle)
			counters["death_debts"] = int(counters.get("death_debts", 0)) + 1
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "MM2", "impact", int(hit["gen"]) + 1, 0.4)
			runner.spawn_impact(hit["position"], maxf(owed, 0.5 * D()), tags, 1.5 * AscensionRunner.R)


func _spillover(hit: Dictionary, handle: int, cast: String, overkill: float) -> void:
	var damage := overkill if overkill > 0.0 else 0.5 * D()
	var range := 2.0 * AscensionRunner.R
	if has("EXF2"):
		range += AscensionRunner.R
		# The victim that just died is the root's first fresh victim.
		var victims := int(_root_victims.get(cast, 0)) + 1
		_root_victims[cast] = victims
		damage += minf(3.0 * D(), 0.25 * D() * float(victims))
	var target := runner.nearest_enemy(hit["position"], range, handle)
	if target == 0 or not runner.enemy_alive(target):
		if has("EX07"):
			_reservoir = minf(8.0 * D(), _reservoir + damage)
			_reservoir_left = 4.0
		return
	counters["spillovers"] = int(counters["spillovers"]) + 1
	_root_spilled[cast] = true
	_bolts.append({"pos": hit["position"], "target": target, "damage": damage, "tags": _payload_tags("EX03", "bolt", hit, 0.7), "root": cast})


func _tick_bolts(delta: float) -> void:
	if _bolts.is_empty():
		return
	var arrived: Array = []
	for bolt in _bolts:
		var target := int(bolt["target"])
		if not runner.enemy_alive(target):
			arrived.append(bolt)
			continue
		var pos: Vector2 = bolt["pos"]
		var to_target := runner.enemy_position(target) - pos
		var step := BOLT_SPEED * delta
		if to_target.length() <= step + EnemyWorld.get_collision_radius(target):
			arrived.append(bolt)
			counters["bolt_hits"] = int(counters["bolt_hits"]) + 1
			runner.damage_enemy(target, float(bolt["damage"]), bolt["tags"])
		else:
			bolt["pos"] = pos + to_target.normalized() * step
	for bolt in arrived:
		_bolts.erase(bolt)


func _corpse_bomb(hit: Dictionary, handle: int, overkill: float, baseline: bool) -> void:
	counters["corpse_bombs"] = int(counters["corpse_bombs"]) + 1
	var radius := AscensionRunner.R
	var damage := 0.0
	if baseline:
		damage = D()
	else:
		var hp_part := 0.15 * float(hit["max_hp"])
		if not bool(hit["is_normal"]):
			hp_part = D()
		if has("EXF1"):
			hp_part *= 2.0
			radius *= 1.5
		if has("EXF2"):
			hp_part = 0.0
		damage = hp_part + 0.5 * D() + overkill
	var pp := 0.35 if hit["path"] == "sweep" else 0.5
	runner.spawn_impact(hit["position"], damage, _payload_tags("EX05", "impact", hit, pp), radius)


func _cleave(hit: Dictionary, _handle: int) -> void:
	counters["cleaves"] = int(counters["cleaves"]) + 1
	var body: Vector2 = hit["position"]
	var dir := (runner.aim_target() - runner.player_position()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	runner.spawn_slash(body, dir, 0.8 * D(), _payload_tags("EX06", "slash", hit, 0.5), 120.0, 1.5 * AscensionRunner.R)


func _last_word(hit: Dictionary, handle: int) -> void:
	counters["last_words"] = int(counters["last_words"]) + 1
	var dir: Vector2 = _mark_dirs.get(handle, Vector2.RIGHT)
	runner.spawn_bullet(hit["position"], dir, 2.0 * D(), _payload_tags("EX11", "blade", hit, 0.6), {"pierce": 4, "speed": 800.0, "max_range": 480.0, "collision_radius": 10.0})


func _public_execution(hit: Dictionary, victim: int, overkill: float) -> void:
	counters["public_executions"] = int(counters["public_executions"]) + 1
	var radius := _gavel_radius()
	for other in runner.enemies_in_radius(_gavel_point, radius, victim):
		runner.damage_enemy(other, overkill, _payload_tags("EXQ3", "bonus", hit, 0.5))


func _red_mist(hit: Dictionary) -> void:
	counters["red_mists"] = int(counters["red_mists"]) + 1
	_red_mist_recovery = 8.0
	runner.note_catastrophe("EXC")
	var damage := 5.0 * D() + _reservoir
	_reservoir = 0.0
	if BattleText != null:
		BattleText.popup(runner.player_position(), "RED MIST", Color(0.9, 0.1, 0.1, 1.0), 1.6)
	var rect := runner.camera_rect()
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXC", "sweep", int(hit["gen"]) + 1, 0.2, PackedStringArray(["execute_enabled"]))
	tags.append("cast:mist:%d" % int(counters["red_mists"]))
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if rect.has_point(runner.enemy_position(handle)):
			runner.damage_enemy(handle, damage, tags)


# ---------------------------------------------------------------- Gavel (Q)

func _gavel_radius() -> float:
	if has("EXE1") or has("EXQ1"):
		return 2.0 * AscensionRunner.R
	if has("EXQ2"):
		return AscensionRunner.R
	return 1.25 * AscensionRunner.R


func _gavel_damage() -> float:
	var scale := _gavel_scale
	if has("EXE1"):
		return 5.0 * D() * scale
	if has("EXQ1"):
		return 2.5 * D() * scale
	return 3.0 * D() * scale


func activate_q(id: String) -> Dictionary:
	if id != "EXQ":
		return {"ok": false, "message": "NOT EXECUTION", "cooldown": 0.0}
	if _gavel_windup >= 0.0:
		return {"ok": false, "message": "WINDING UP", "cooldown": 0.0}
	var origin := runner.player_position()
	var aim := runner.aim_target()
	if has("EXQ4"):
		var rect := runner.camera_rect()
		_gavel_point = Vector2(clampf(aim.x, rect.position.x, rect.end.x), clampf(aim.y, rect.position.y, rect.end.y))
	else:
		var offset := aim - origin
		if offset.length() > AscensionRunner.L:
			offset = offset.normalized() * AscensionRunner.L
		_gavel_point = origin + offset
	var windup := 0.35
	if has("EXE1"):
		windup = 0.8
	elif has("EXQ4"):
		windup = 0.35 if has("EXQ2") else 0.7
	elif has("EXQ2"):
		windup = 0.1
	_gavel_windup = windup
	_gavel_scale = runner.q_scale()
	_gavel_casts += 1
	_gavel_cast_id = "EXQ:%d" % _gavel_casts
	_gavel_executed[_gavel_cast_id] = 0
	counters["gavels"] = int(counters["gavels"]) + 1
	return {"ok": true, "message": "GAVEL", "cooldown": 5.0 if has("EXQ2") else 7.0}


func _tick_gavel(delta: float) -> void:
	if _gavel_windup >= 0.0:
		if has("EXQ6"):
			_gather(delta)
		_gavel_windup -= delta
		if _gavel_windup <= 0.0:
			_gavel_windup = -1.0
			_strike(_gavel_point, _gavel_damage(), _gavel_radius(), _gavel_cast_id, "gavel", PackedStringArray())
			if has("EXQ5"):
				_second_swing_left = 0.35
	if _second_swing_left >= 0.0:
		_second_swing_left -= delta
		if _second_swing_left <= 0.0:
			_second_swing_left = -1.0
			if int(_gavel_executed.get(_gavel_cast_id, 0)) == 0:
				counters["second_swings"] = int(counters["second_swings"]) + 1
				_strike(_gavel_point, 2.0 * D(), _gavel_radius(), _gavel_cast_id, "gavel", PackedStringArray(["second_swing"]))


func _gather(delta: float) -> void:
	for handle in runner.enemies_in_radius(_gavel_point, 2.0 * AscensionRunner.R):
		var to_point := _gavel_point - runner.enemy_position(handle)
		if to_point.length() < 8.0:
			continue
		var pull := 1.0
		if runner.is_boss(handle):
			continue
		if runner.is_elite(handle):
			pull = 0.5
		EnemyCombat.apply_knockback(handle, to_point.normalized() * (AscensionRunner.R / maxf(_gavel_windup, 0.05)) * pull * delta * 60.0)


func _strike(point: Vector2, damage: float, radius: float, cast: String, path: String, extra_flags: PackedStringArray) -> void:
	var flags := PackedStringArray(["execute_enabled", "core_strike"])
	flags.append_array(extra_flags)
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXQ", path, 1, 1.0, flags)
	tags.append("cast:" + cast)
	runner.spawn_impact(point, damage, tags, radius)
	for handle in runner.enemies_in_radius(point, radius):
		if runner.is_boss(handle):
			runner.status_of(handle)["cracked"] = CRACKED_HITS
			counters["cracks"] = int(counters["cracks"]) + 1


func _queue_chain_gavel(hit: Dictionary, victim: int, cast: String) -> void:
	var delivered: Dictionary = _root_gavel_targets.get(cast, {})
	_root_gavel_targets[cast] = delivered
	var previous_radius := float(hit.get("gavel_radius", _gavel_radius()))
	var radius := maxf(0.35 * AscensionRunner.R, previous_radius * 0.92)
	var target := runner.nearest_enemy(hit["position"], AscensionRunner.L, victim)
	if target == 0 or delivered.has(target):
		return
	delivered[target] = true
	_pending_gavels.append({"delay": 0.12, "target": target, "point": runner.enemy_position(target), "damage": 1.5 * D(), "radius": radius, "cast": cast, "kind": "chain_gavel"})


func _queue_lesser_gavel(hit: Dictionary, cast: String) -> void:
	var best := 0
	var best_distance := INF
	for handle in _marks:
		if not runner.enemy_alive(handle):
			continue
		var distance := (hit["position"] as Vector2).distance_to(runner.enemy_position(handle))
		if distance < best_distance:
			best_distance = distance
			best = handle
	if best == 0:
		return
	_pending_gavels.append({"delay": 0.12, "target": best, "point": runner.enemy_position(best), "damage": 1.5 * D(), "radius": AscensionRunner.R, "cast": cast, "kind": "lesser_gavel"})


func _tick_pending_gavels(delta: float) -> void:
	if _pending_gavels.is_empty():
		return
	var due: Array = []
	for gavel in _pending_gavels:
		gavel["delay"] = float(gavel["delay"]) - delta
		if float(gavel["delay"]) <= 0.0:
			due.append(gavel)
	for gavel in due:
		_pending_gavels.erase(gavel)
		var target := int(gavel["target"])
		var point: Vector2 = runner.enemy_position(target) if runner.enemy_alive(target) else gavel["point"]
		if String(gavel["kind"]) == "chain_gavel":
			counters["chain_gavels"] = int(counters["chain_gavels"]) + 1
		else:
			counters["lesser_gavels"] = int(counters["lesser_gavels"]) + 1
		var flags := PackedStringArray(["execute_enabled"])
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXQ", String(gavel["kind"]), 2, 1.0, flags)
		tags.append("cast:" + String(gavel["cast"]))
		tags.append("radius:%.1f" % float(gavel["radius"]))
		runner.spawn_impact(point, float(gavel["damage"]), tags, float(gavel["radius"]))


# ---------------------------------------------------------------- DECIMATION (V)

func activate_v(id: String) -> Dictionary:
	if id != "EXV":
		return {"ok": false, "message": "NOT EXECUTION", "cooldown": 0.0}
	if _decimation_tell >= 0.0:
		return {"ok": false, "message": "CASTING", "cooldown": 0.0}
	_decimation_casts += 1
	if has("EXV3"):
		_decimate()
	else:
		_decimation_tell = 0.4
	return {"ok": true, "message": "DECIMATION", "cooldown": 0.0}


func _tick_decimation(delta: float) -> void:
	if _decimation_tell < 0.0:
		return
	_decimation_tell -= delta
	if _decimation_tell <= 0.0:
		_decimation_tell = -1.0
		_decimate()


func _decimate() -> void:
	counters["decimations"] = int(counters["decimations"]) + 1
	if BattleText != null:
		BattleText.popup(runner.player_position(), "DECIMATION", Color(0.9, 0.1, 0.1, 1.0), 1.8)
	var rect := runner.camera_rect()
	var normal_damage := (5.0 if has("EXV1") else 3.0) * D()
	var extra := _reservoir if has("EXV3") else 0.0
	_reservoir = 0.0 if has("EXV3") else _reservoir
	var cast := "EXV:%d" % _decimation_casts
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if not rect.has_point(runner.enemy_position(handle)):
			continue
		var damage := normal_damage + extra
		if runner.is_boss(handle):
			damage = 5.0 * D() + extra
			EnemyCombat.apply_stun(handle, 0.5)
		elif runner.is_elite(handle):
			damage = 4.0 * D() + extra
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXV", "sweep", 1, 0.0, PackedStringArray(["execute_enabled", "v"]))
		tags.append("cast:" + cast)
		runner.damage_enemy(handle, damage, tags)


# ---------------------------------------------------------------- multipliers and HUD

func power_multiplier(core: String) -> float:
	if core == "melee" and has("EXS1"):
		return 1.0 + 0.01 * sqrt(float(rank("EXS1")))
	return 1.0


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		state["combat_text"] = "LINE %d%%" % int(round(line() * 100.0))
		if _bloodletting_stacks > 0:
			state["combat_text"] += " +%d" % _bloodletting_stacks
		if _gavel_windup >= 0.0:
			state["combat_text"] = "GAVEL"
	elif slot == "v" and _decimation_tell >= 0.0:
		state["combat_text"] = "DECIMATION"
	return state


func collect_draw_points(out: Array) -> void:
	for bolt in _bolts:
		out.append([bolt["pos"], 4.0, Color(0.95, 0.15, 0.15, 0.95)])
	if _gavel_windup >= 0.0:
		out.append([_gavel_point, _gavel_radius(), Color(0.9, 0.2, 0.2, 0.18)])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["line"] = line()
	out["bloodletting"] = _bloodletting_stacks
	out["marks"] = _marks.size()
	out["reservoir"] = _reservoir
	out["bolts_live"] = _bolts.size()
	return out
