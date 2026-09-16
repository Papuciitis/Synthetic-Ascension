extends AscensionEngine
class_name UnionEngine
## The three Unions: INCARNATE (Melee+Magic), TOTAL OFFENSIVE (Melee+Ranged)
## and ARCANE BALLISTICS (Ranged+Magic). Each borrows the parent
## disciplines' engines through the runner; a missing engine simply skips
## that family.

const EFFECTS: Dictionary = {"UMM": &"incarnate", "UMR": &"total_offensive", "URM": &"arcane_ballistics"}

var _volley: int = 0
var _incarnate_volley: int = -1
var _incarnate_damage: float = 0.0
var rack: int = 0
var _executions_per_cast: Dictionary = {}
var _ranged_inputs: int = 0
var _spell_cycle: int = 0
var _loaded_rule: String = ""
var _loaded_volley: int = -1
var _rule_pid: int = 0

var counters: Dictionary = {"incarnate_commands": 0, "rack_loaded": 0, "rack_fired": 0, "rack_volleys": 0, "rack_dumps": 0, "spell_shots": 0, "spell_rules": 0, "magic_shots": 0}


func discipline() -> String:
	return "UN"


func _inv() -> InvocationEngine:
	return runner.engine_of_discipline("IN") as InvocationEngine


func _dom() -> DominionEngine:
	return runner.engine_of_discipline("DO") as DominionEngine


func _dt() -> DistortionEngine:
	return runner.engine_of_discipline("DT") as DistortionEngine


# ---------------------------------------------------------------- INCARNATE

## The newest Sigil and Well ride within R of the player.
func tick(_delta: float) -> void:
	if not has("UMM"):
		return
	var at := runner.player_position()
	var inv := _inv()
	if inv != null and not inv.sigils.is_empty():
		var carried: Dictionary = inv.sigils[inv.sigils.size() - 1]
		if not bool(carried.get("follow_cursor", false)) and (carried["at"] as Vector2).distance_to(at) > AscensionRunner.R:
			carried["at"] = at + ((carried["at"] as Vector2) - at).normalized() * AscensionRunner.R
	var dom := _dom()
	if dom != null and not dom.wells.is_empty():
		var well: Dictionary = dom.wells[dom.wells.size() - 1]
		if (well["at"] as Vector2).distance_to(at) > AscensionRunner.R:
			well["at"] = at + ((well["at"] as Vector2) - at).normalized() * AscensionRunner.R


func _command_carried() -> void:
	counters["incarnate_commands"] = int(counters["incarnate_commands"]) + 1
	var inv := _inv()
	if inv != null and not inv.sigils.is_empty():
		var carried: Dictionary = inv.sigils[inv.sigils.size() - 1]
		var echoes: Array = carried["echoes"]
		if not echoes.is_empty():
			inv._release_echo(carried, echoes.pop_front())
	var dom := _dom()
	if dom != null and not dom.wells.is_empty():
		var well: Dictionary = dom.wells[dom.wells.size() - 1]
		well["budget"] = {}
		well["life"] = maxf(float(well["life"]), 0.5)


func on_player_damage_resolved(_source: Node, _raw: float, applied: float, _kind: StringName) -> void:
	if not has("UMM"):
		return
	_incarnate_damage += applied
	var threshold := 0.1 * runner.player_max_hp()
	while _incarnate_damage >= threshold and threshold > 0.0:
		_incarnate_damage -= threshold
		_command_carried()


# ---------------------------------------------------------------- native inputs

func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	if has("UMR") and style == "melee" and rack >= 6:
		_fire_rack(origin, target, true)
	if has("URM"):
		if style == "ranged":
			_ranged_inputs += 1
			if _ranged_inputs % 4 == 0:
				_loaded_rule = _next_rule()
				_loaded_volley = _volley
		elif style == "magic":
			var dir := (target - origin).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			counters["magic_shots"] = int(counters["magic_shots"]) + 1
			runner.spawn_bullet(origin, dir, runner.native_damage_for("ranged"), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "URM", "bullet", 1, 0.5, PackedStringArray(["core_strike", "union"])), {"pierce": 3})


func _next_rule() -> String:
	var families: Array[String] = []
	if _inv() != null:
		families.append("sigil")
	if _dt() != null:
		families.append("debt")
	if _dom() != null:
		families.append("well")
	if families.is_empty():
		return ""
	var rule: String = families[_spell_cycle % families.size()]
	_spell_cycle += 1
	counters["spell_rules"] = int(counters["spell_rules"]) + 1
	return rule


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var native: bool = hit["family"] == AscensionTags.FAMILY_NATIVE
	var core_strike := native or AscensionTags.has_flag(hit["tags"], "core_strike")
	if has("UMM") and native and hit["core"] == "melee" and _incarnate_volley != _volley:
		var inv := _inv()
		var dom := _dom()
		var through_sigil := inv != null and not inv._containing(hit["position"]).is_empty()
		var through_well := false
		if dom != null:
			for well in dom.wells:
				if (well["at"] as Vector2).distance_to(hit["position"]) <= dom._well_radius(well):
					through_well = true
		if through_sigil or through_well:
			_incarnate_volley = _volley
			_command_carried()
	if has("UMR") and core_strike:
		if hit["core"] == "melee" and native and rack < 6:
			rack += 1
			counters["rack_loaded"] = int(counters["rack_loaded"]) + 1
		elif hit["core"] == "ranged" and rack > 0 and not AscensionTags.has_flag(hit["tags"], "rack"):
			rack -= 1
			_rack_round(runner.player_position(), (runner.aim_target() - runner.player_position()).normalized())
	if has("URM") and native and hit["core"] == "ranged" and not _loaded_rule.is_empty() and _loaded_volley == _volley:
		var rule := _loaded_rule
		_loaded_rule = ""
		counters["spell_shots"] = int(counters["spell_shots"]) + 1
		match rule:
			"sigil":
				var inv := _inv()
				if inv != null:
					inv.place_sigil(hit["position"])
			"debt":
				var dt := _dt()
				if dt != null:
					dt.deposit(handle, runner.native_damage_for("magic"), "union", false)
			"well":
				var dom := _dom()
				if dom != null:
					dom.place_well(hit["position"])


func _rack_round(origin: Vector2, dir: Vector2) -> void:
	counters["rack_fired"] = int(counters["rack_fired"]) + 1
	runner.spawn_bullet(origin, dir if dir != Vector2.ZERO else Vector2.RIGHT, 0.7 * runner.native_damage_for("ranged"), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "UMR", "bullet", 1, 0.4, PackedStringArray(["rack"])))


func _fire_rack(origin: Vector2, target: Vector2, across_arc: bool) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var count := rack
	rack = 0
	counters["rack_volleys"] = int(counters["rack_volleys"]) + 1
	for i in range(count):
		var spread := deg_to_rad(-60.0 + 120.0 * float(i) / float(maxi(1, count - 1))) if across_arc else deg_to_rad(-8.0 + 16.0 * float(i) / float(maxi(1, count - 1)))
		_rack_round(origin, dir.rotated(spread))


## A Jam, a full Force discharge or an execution chain of six victims dumps
## the rack toward aim and loads three.
func note_trigger(kind: String, cast: String = "") -> void:
	if not has("UMR"):
		return
	if kind == "execution":
		_executions_per_cast[cast] = int(_executions_per_cast.get(cast, 0)) + 1
		if int(_executions_per_cast[cast]) != 6:
			return
	counters["rack_dumps"] = int(counters["rack_dumps"]) + 1
	if rack > 0:
		_fire_rack(runner.player_position(), runner.aim_target(), false)
	rack = 3
	counters["rack_loaded"] = int(counters["rack_loaded"]) + 3


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	if has("UMR") and AscensionTags.has_flag(hit["tags"], "execute"):
		note_trigger("execution", AscensionTags.value_of(hit["tags"], "cast"))


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q" and has("UMR"):
		state["combat_text"] = "RACK %d/6" % rack
	return state


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["rack"] = rack
	return out
