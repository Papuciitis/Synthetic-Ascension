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


## Whether a guarantee state (Heads, REWRITE, five Misfortune) makes this
## roll succeed without rolling.
func wants_guarantee(_name: StringName, _proc_power: float) -> bool:
	return false


func on_player_dashed(_from: Vector2, _direction: Vector2) -> void:
	pass


func on_player_damage_taken(_amount: float) -> void:
	pass


## Enemy damage that reached the player: pre-mitigation `raw`, `applied`
## HP lost, and its source (Undo, Fixed Coin, Force).
func on_player_damage_resolved(_source: Node, _raw: float, _applied: float, _kind: StringName) -> void:
	pass


## A dash the player started (from RunEvents) and one that just ended.
func on_dash_ended(_from: Vector2, _to: Vector2, _direction: Vector2) -> void:
	pass


## Hold-to-use Qs (Guard): the runner starts them with activate_q, feeds the
## hold each frame, and releases them when the key lifts.
func q_is_hold(_id: String) -> bool:
	return false


func hold_q(_id: String, _delta: float) -> void:
	pass


func release_q(_id: String) -> Dictionary:
	return {"ok": false, "message": "", "cooldown": 0.0}


## A killing blow the engine may refuse (Last Hit). Return true to leave the
## player at 1 HP instead.
func intercept_lethal_hit(_damage: float) -> bool:
	return false


## Width multiplier for native Melee arcs (Stride, Slash Width).
func arc_multiplier() -> float:
	return 1.0


## Multiplier on incoming damage from one source; 0 makes it miss.
func damage_taken_multiplier_for(_source: Node, _kind: StringName) -> float:
	return damage_taken_multiplier()


## Outgoing damage adjustment for one player hit, before mitigation.
## `preview` = {handle, raw, tags, core, core_strike, family}. Return the
## damage to apply (raw for no change).
func modify_outgoing_damage(_preview: Dictionary, raw: float) -> float:
	return raw


## Lifetime multiplier for friendly projectiles and fragments.
func projectile_life_multiplier() -> float:
	return 1.0


## Where an automatic cast of this engine's Q aims (V4 automation table).
func auto_target(_id: String) -> Vector2:
	return runner.nearest_enemy_position(AscensionRunner.L) if runner != null else Vector2.ZERO


## Whether the engine wants the runner to keep each enemy's last hits (Replay).
func wants_hit_history() -> bool:
	return false


## A tagged player projectile ended (range, life, pierce, world, consumed):
## see ProjectileSimulationManager.projectile_ended for the report's keys.
func on_projectile_ended(_info: Dictionary) -> void:
	pass


## Multiplier on direct Q damage (the Q Damage sink); applies to every Q.
func q_damage_multiplier() -> float:
	return 1.0


## Any Q (including a Reaction or automatic cast) was activated: `verdict`
## is the casting engine's result. Fuse (axiom) hangs on it.
func on_q_activated(_id: String, _verdict: Dictionary) -> void:
	pass


## Multiplier on healing the player receives (Blood Rune).
func heal_multiplier() -> float:
	return 1.0


func on_enemy_projectile_seen(_position: Vector2, _velocity: Vector2) -> void:
	pass


## Extra tags for a Witness strike of `core` (flags such as execute_enabled,
## or a volley id), so the strike qualifies for that Core's strike rules.
func witness_tags(_core: String) -> PackedStringArray:
	return PackedStringArray()


## A Witness strike of `core` was just emitted (counters, Heat, ...).
func on_witness_strike(_core: String, _origin: Vector2, _target: Vector2) -> void:
	pass


## A catastrophe (Overload, Red Mist, Payday) began; Reaction Q listens.
func on_catastrophe(_id: String) -> void:
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


## Whether this Q is in a running state (Burst, beam, a held Guard) that a
## second press cancels or releases; the runner then routes the press to
## activate_q even while the recovery is counting.
func q_active(_id: String) -> bool:
	return false


## Extra HUD lines for the slot: {"resource_value", "resource_max", "combat_text"}.
func hud_state(_slot: String) -> Dictionary:
	return {}


## Manifestation nouns this engine produces into (e.g. &"fortune" for Bad
## Luck's Misfortune). The runner claims them on the shared state so the
## pool accepts deposits even when no Manifestation rule owns the noun.
func claimed_nouns() -> Array[StringName]:
	return []


## Telemetry snapshot for the flight recorder / dev readout.
func describe() -> Dictionary:
	return {}


## Per-frame cost counters (microseconds and counts) for the recorder;
## empty when the engine has nothing worth attributing.
func frame_cost() -> Dictionary:
	return {}


## Append [position, radius, color] entries for things the engine simulates
## itself (seeking fragments, patches) so the runner can draw them.
func collect_draw_points(_out: Array) -> void:
	pass


## Observational report for the balance recorder: conditional guards and
## resources a sample should show without evaluating a hit. The per-source
## incoming-damage rule (damage_taken_multiplier_for) consumes state (Plate)
## and is never called from a sample; the plain multiplier getters read
## fields only and the runner reports them directly.
func balance_snapshot() -> Dictionary:
	return {}
