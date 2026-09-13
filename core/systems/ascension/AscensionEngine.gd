extends RefCounted
class_name AscensionEngine
## One discipline's combat rules (Execution, Barrage, Distortion, ...).
##
## The runner owns the shared contract: it parses hits, pairs lethal hits with
## deaths, keeps per-enemy tree statuses, resolves named rolls and spawns
## generated attacks with the player as source. An engine only decides what
## its owned nodes do with those facts. Everything here is a no-op default so
## an engine implements only the hooks it needs.

var runner: AscensionRunner = null
var active: Dictionary = {}   # node id -> true for owned, enabled, equipped-as-needed nodes


func setup(owner: AscensionRunner) -> void:
	runner = owner


## Called on every ledger refresh with the ids this engine may run.
func refresh(active_ids: Dictionary) -> void:
	active = active_ids


func has(id: String) -> bool:
	return active.has(id)


func rank(id: String) -> int:
	return runner.rank(id) if runner != null else 0


## Discipline code this engine serves (EX, BR, DT, ...).
func discipline() -> String:
	return ""


func tick(_delta: float) -> void:
	pass


## A native input fired (RunEvents.weapon_fired), before its hits land.
func on_native_fire(_style: String, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	pass


## Any damage to an enemy from the player; `hit` is the runner's parsed record.
func on_hit(_hit: Dictionary) -> void:
	pass


## An enemy died; `hit` is the lethal hit record (may be untagged).
func on_kill(_hit: Dictionary, _context: RefCounted) -> void:
	pass


## A named combat roll resolved (after modifiers).
func on_roll(_name: StringName, _success: bool, _chance: float) -> void:
	pass


## Chance modifiers for named rolls; return the adjusted chance.
func modify_roll_chance(_name: StringName, chance: float) -> float:
	return chance


## Whether this engine grants a reroll to a failed named roll.
func wants_reroll(_name: StringName) -> bool:
	return false


func on_player_dashed(_from: Vector2, _direction: Vector2) -> void:
	pass


func on_player_damage_taken(_amount: float) -> void:
	pass


func on_enemy_projectile_seen(_position: Vector2, _velocity: Vector2) -> void:
	pass


# ---- attack decoration (native attacks only; generated ones carry their own tags)

func decorate_native_slash(_slash: Node) -> void:
	pass


func decorate_native_impact(_impact: Node) -> void:
	pass


func decorate_native_profile(_profile: HitProfileAdapter) -> void:
	pass


# ---- multipliers polled by the player each attack / frame

func power_multiplier(_core: String) -> float:
	return 1.0


func haste_multiplier(_core: String) -> float:
	return 1.0


func move_speed_multiplier() -> float:
	return 1.0


func damage_taken_multiplier() -> float:
	return 1.0


# ---- Q / V

## Returns {"ok": bool, "message": String, "cooldown": float}.
func activate_q(_id: String) -> Dictionary:
	return {"ok": false, "message": "NOT WIRED", "cooldown": 0.0}


func activate_v(_id: String) -> Dictionary:
	return {"ok": false, "message": "NOT WIRED", "cooldown": 0.0}


## Extra HUD lines for the slot: {"resource_value", "resource_max", "combat_text"}.
func hud_state(_slot: String) -> Dictionary:
	return {}


## Telemetry snapshot for the flight recorder / dev readout.
func describe() -> Dictionary:
	return {}


## Append [position, radius, color] entries for things the engine simulates
## itself (seeking fragments, patches) so the runner can draw them.
func collect_draw_points(_out: Array) -> void:
	pass
