extends Node2D
class_name ManifestationRunner

## Runs the Manifestations carried by the eight equipped items.
##
## Mirrors ItemEffectRunner's lifecycle (watch the inventory, sync a keyed set
## of effect nodes) but differs in two ways that matter:
##   * it watches EVERY equipped slot, not just offhand/ring;
##   * it owns the signal wiring. Each shared gameplay hook is connected once
##     here and dispatched to the effects that implement it, so sixteen rules
##     do not each carry their own connect/disconnect boilerplate.

signal manifestations_changed()

const HOOKS: Array[StringName] = [
	&"on_attack",
	&"on_lucky_crit",
	&"on_lucky_crit_failed",
	&"on_hit",
	&"on_kill",
	&"on_damage_taken",
	&"on_evaded",
	&"on_dash",
	&"on_healed",
	&"on_building_entered",
	&"on_secondary_completed",
	&"on_followers_changed",
	&"on_gate_ready",
]

@export var debug_manifestations: bool = false

var state: ManifestationState = null

# key(StringName "<manifestation_id>#<slot>") -> ManifestationEffect
var _active: Dictionary = {}
# hook(StringName) -> Array[ManifestationEffect]
var _hook_lists: Dictionary = {}
# pair id(StringName) -> ManifestationPairEffect, live while its two nouns are lit
var _pairs: Dictionary = {}
## Rules AND pairs, cached. Every passive poll iterates this rather than
## _active - a pair excluded from consume_attack_bonus() would be a silent
## damage change with no visible symptom.
var _all_cache: Array = []
var _bound_inv: Inventory = null
var _gate_ready_announced: bool = false


func _ready() -> void:
	position = Vector2.ZERO
	state = ManifestationState.new()
	state.name = "ManifestationState"
	add_child(state)
	state.bind_player(get_parent() as Node2D)
	_rebuild_hook_lists()
	set_process(true)
	_rebind_if_needed(true)


func _exit_tree() -> void:
	_disconnect_world_hooks()


func _process(_delta: float) -> void:
	_rebind_if_needed(false)


# ---------------------------------------------------------------------------
# Inventory binding
# ---------------------------------------------------------------------------

func _rebind_if_needed(force: bool) -> void:
	var inv: Inventory = (Global.run_inventory as Inventory) if Global != null else null
	if not force and inv == _bound_inv:
		return
	if _bound_inv != null and _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.disconnect(_on_inventory_changed)
	_bound_inv = inv
	if _bound_inv != null and not _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _on_inventory_changed() -> void:
	refresh_effects(_bound_inv)


func refresh_effects(inv: Inventory) -> void:
	if state != null and (state.player == null or not is_instance_valid(state.player)):
		state.bind_player(get_parent() as Node2D)

	if inv == null:
		_clear_all()
		return

	var wanted: Dictionary = {}
	for slot in range(Inventory.SLOT_COUNT):
		var inst: ItemInstance = inv.get_at(slot)
		if inst == null or inst.data == null:
			continue
		var id: StringName = inst.manifestation_id
		if id == &"":
			continue
		var def := ManifestationCatalog.get_def(id)
		if def == null or def.logic == null:
			continue
		# Two items can legitimately carry the same Manifestation; the slot
		# suffix keeps them independent, exactly like ItemEffectRunner.
		wanted[StringName("%s#%d" % [String(id), slot])] = {
			"def": def,
			"slot": slot,
			"inst": inst,
		}

	_sync(wanted)

	if debug_manifestations:
		print("[Manifestations] active: ", _active.keys())


func _sync(wanted: Dictionary) -> void:
	var dirty := false
	# Nouns are claimed from the DEF, here, rather than by each rule in its own
	# _on_manifestation_ready(). Declared and claimed then cannot drift: a rule
	# cannot claim a noun it never declared, nor declare one it never claims.
	var added_nouns: Array[StringName] = []
	var removed_nouns: Array[StringName] = []

	for key in _active.keys():
		if wanted.has(key):
			continue
		var stale: Node = _active[key]
		_active.erase(key)
		if is_instance_valid(stale):
			var stale_effect := stale as ManifestationEffect
			if stale_effect != null and stale_effect.definition != null:
				removed_nouns.append_array(stale_effect.definition.tags)
			if state != null:
				state.clear_contributions((stale as ManifestationEffect).contribution_key())
			stale.queue_free()
		dirty = true

	for key in _active.keys():
		if not is_instance_valid(_active[key]):
			_active.erase(key)
			dirty = true

	for key in wanted.keys():
		var entry: Dictionary = wanted[key]
		var inst: ItemInstance = entry.get("inst", null)
		if _active.has(key) and is_instance_valid(_active[key]):
			(_active[key] as ManifestationEffect).set_item_instance(inst)
			continue
		var def: ManifestationDef = entry.get("def", null)
		if def == null or def.logic == null:
			continue
		var node: Node = def.logic.new()
		var effect := node as ManifestationEffect
		if effect == null:
			push_warning("[Manifestations] %s logic is not a ManifestationEffect" % String(def.id))
			node.free()
			continue
		effect.name = String(def.id)
		add_child(effect)
		added_nouns.append_array(def.tags)
		# Claim BEFORE the effect sets itself up, so a rule that reads its noun
		# during setup sees a live resource rather than a dormant one.
		if state != null:
			for noun in def.tags:
				state.claim(noun)
		effect.setup_manifestation(get_parent(), inst, int(entry.get("slot", -1)), state, def)
		_active[key] = effect
		dirty = true

	# Release LAST. Dropping a noun to zero claimers resets it, so releasing
	# before claiming would wipe the player's bank every time they swapped one
	# momentum ring for another.
	if state != null:
		for noun in removed_nouns:
			state.release(noun)

	# Pairs are synced INSIDE the same dirty pass so manifestations_changed
	# fires exactly once - the notifier that listens for it would otherwise
	# announce twice for a single equip.
	if _sync_pairs():
		dirty = true

	if dirty:
		_rebuild_hook_lists()
		manifestations_changed.emit()


func _clear_all() -> void:
	for id in _pairs.keys():
		var pair := _pairs[id] as ManifestationPairEffect
		_pairs.erase(id)
		if pair != null and is_instance_valid(pair):
			if state != null:
				state.clear_contributions(pair.contribution_key())
				for noun in pair.tags():
					state.release(noun)
			pair.queue_free()
	if _active.is_empty():
		_all_cache.clear()
		return
	for key in _active.keys():
		var node: Node = _active[key]
		if is_instance_valid(node):
			var effect := node as ManifestationEffect
			if state != null and effect != null:
				state.clear_contributions(effect.contribution_key())
				if effect.definition != null:
					for noun in effect.definition.tags:
						state.release(noun)
			node.queue_free()
	_active.clear()
	_rebuild_hook_lists()
	manifestations_changed.emit()


## Which authored pair payoffs the current loadout lights, instantiating and
## freeing them to match. Returns whether anything changed.
func _sync_pairs() -> bool:
	var wanted: Dictionary = {}
	var counts := get_noun_counts()
	for def in ManifestationPairCatalog.active_for_counts(counts):
		wanted[def.id] = def

	var dirty := false
	for id in _pairs.keys():
		if wanted.has(id):
			continue
		var stale: Node = _pairs[id]
		_pairs.erase(id)
		if is_instance_valid(stale):
			var stale_pair := stale as ManifestationPairEffect
			if state != null and stale_pair != null:
				state.clear_contributions(stale_pair.contribution_key())
				for noun in stale_pair.tags():
					state.release(noun)
			stale.queue_free()
		dirty = true

	for id in wanted.keys():
		var def: ManifestationPairDef = wanted[id]
		if _pairs.has(id) and is_instance_valid(_pairs[id]):
			(_pairs[id] as ManifestationPairEffect).set_contributor_rarity(_mean_rarity_for(def))
			continue
		if def.logic == null:
			continue
		var node: Node = def.logic.new()
		var pair := node as ManifestationPairEffect
		if pair == null:
			push_warning("[Manifestations] pair %s logic is not a ManifestationPairEffect" % String(def.id))
			node.free()
			continue
		pair.name = String(def.id)
		add_child(pair)
		if state != null:
			for noun in def.nouns:
				state.claim(noun)
		pair.setup_pair(get_parent(), state, def, _mean_rarity_for(def))
		_pairs[id] = pair
		dirty = true

	return dirty


## A pair has no item of its own, so its scaling is the MEAN rank of the rules
## that formed it: min punishes a mixed loadout, max is farmable with one
## heavily ranked ring.
func _mean_rarity_for(def: ManifestationPairDef) -> float:
	var total := 0.0
	var count := 0
	for node in _active.values():
		var effect := node as ManifestationEffect
		if effect == null or not is_instance_valid(effect) or effect.definition == null:
			continue
		var relevant := false
		for tag in effect.definition.tags:
			if def.involves(tag):
				relevant = true
				break
		if not relevant:
			continue
		total += effect.effective_rarity()
		count += 1
	return total / float(count) if count > 0 else 0.0


## Live pair payoffs, for the HUD and the notifier.
func get_active_pairs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _pairs:
		var pair := _pairs[id] as ManifestationPairEffect
		if pair == null or not is_instance_valid(pair) or pair.pair_definition == null:
			continue
		out.append({
			"id": pair.pair_definition.id,
			"name": pair.pair_definition.display_name,
			"nouns": pair.pair_definition.nouns,
			"rule": pair.describe(),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", "")))
	return out


func _rebuild_hook_lists() -> void:
	_all_cache.clear()
	for node in _active.values():
		if is_instance_valid(node):
			_all_cache.append(node)
	for node in _pairs.values():
		if is_instance_valid(node):
			_all_cache.append(node)

	_hook_lists.clear()
	for hook in HOOKS:
		var listeners: Array[ManifestationEffect] = []
		for node in _all_cache:
			var effect := node as ManifestationEffect
			if effect != null and is_instance_valid(effect) and effect.has_method(hook):
				listeners.append(effect)
		if listeners.is_empty():
			continue
		# Slot order, so producer/consumer contention over a shared resource is
		# stable and explainable instead of depending on dictionary insertion.
		# Momentum's producer sits on Movement (2) and its consumers on Armour
		# (1) / Offhand (6): the armour blast gets first refusal, which is the
		# reading a player would expect from "taking a hit spends it".
		listeners.sort_custom(func(a: ManifestationEffect, b: ManifestationEffect) -> bool:
			return a.slot_index < b.slot_index)
		_hook_lists[hook] = listeners
	_sync_world_hooks()


## Rules and pairs together. Rebuilt only inside _rebuild_hook_lists(), which
## already runs exactly when the set changes.
##
## NOTE the deliberate exceptions: _mean_rarity_for() and get_noun_counts() read
## _active alone. A pair claims the nouns it is built from, so counting pairs
## there would let a lit pair light further pairs - a feedback loop.
func _all_effects() -> Array:
	return _all_cache


func _listeners(hook: StringName) -> Array:
	var found: Variant = _hook_lists.get(hook, null)
	return found if found is Array else []


# ---------------------------------------------------------------------------
# Shared gameplay hooks
# ---------------------------------------------------------------------------

## Every world signal this runner can listen to, and which effect hooks make it
## worth listening to. Connections are DEMAND-DRIVEN: a signal is only connected
## while some equipped rule implements a hook that needs it.
##
## This is not tidiness. `player_hit_landed` fires per pellet per target per
## frame and `player_healed` fires every frame under passive regen; both
## emitters skip their payload when `Signal.has_connections()` is false, and a
## permanently-connected runner would defeat that guard for every player who
## never rolls a Manifestation - which is most of them.
func _signal_wiring() -> Array:
	var wiring: Array = [
		[RunEvents.weapon_fired, _on_weapon_fired, [&"on_attack"], [&"cadence"]],
		[RunEvents.enemy_defeated, _on_enemy_defeated, [&"on_kill"]],
		[RunEvents.player_hit_landed, _on_player_hit_landed, [&"on_hit"]],
		[
			RunEvents.player_lucky_crit,
			_on_player_lucky_crit,
			[&"on_lucky_crit", &"on_lucky_crit_failed"],
			[&"fortune"],
		],
		[RunEvents.player_damage_taken, _on_player_damage_taken, [&"on_damage_taken"], [&"ward"]],
		[RunEvents.player_evaded, _on_player_evaded, [&"on_evaded"]],
		[RunEvents.player_dashed, _on_player_dashed, [&"on_dash"]],
		[RunEvents.player_healed, _on_player_healed, [&"on_healed"]],
		[
			RunEvents.player_entered_building,
			_on_player_entered_building,
			[&"on_building_entered"],
		],
		[
			RunEvents.secondary_objective_completed,
			_on_secondary_completed,
			[&"on_secondary_completed"],
		],
		[RunEvents.gate_checklist_changed, _on_gate_checklist_changed, [&"on_gate_ready"]],
	]
	if Global != null and Global.has_signal("followers_transaction"):
		wiring.append([
			Global.followers_transaction,
			_on_followers_transaction,
			[&"on_followers_changed"],
		])
	return wiring


func _sync_world_hooks() -> void:
	if RunEvents == null:
		return
	for entry_value in _signal_wiring():
		var entry: Array = entry_value
		var sig: Signal = entry[0]
		var callback: Callable = entry[1]
		var wanted := false
		for hook in (entry[2] as Array):
			if _hook_lists.has(hook):
				wanted = true
				break
		# A signal can also be needed by a NOUN rather than by a hook. Once the
		# attack counter lives on the shared state, the rules that read it stop
		# implementing on_attack - and weapon_fired would disconnect, so the
		# counter would silently stop advancing and the whole noun would die.
		if not wanted and entry.size() > 3:
			for noun in (entry[3] as Array):
				if state != null and state.has_source(noun):
					wanted = true
					break
		if wanted:
			_connect(sig, callback)
		else:
			_disconnect(sig, callback)


func _disconnect_world_hooks() -> void:
	if RunEvents == null:
		return
	for entry_value in _signal_wiring():
		var entry: Array = entry_value
		_disconnect(entry[0] as Signal, entry[1] as Callable)


func _connect(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


func _disconnect(sig: Signal, callback: Callable) -> void:
	if sig.is_connected(callback):
		sig.disconnect(callback)


func _is_owner(node: Node) -> bool:
	return node != null and node == get_parent()


func _on_weapon_fired(
	p: Node,
	style_id: StringName,
	origin: Vector2,
	target: Vector2,
	power_mul: float,
	haste_mul: float
) -> void:
	if not _is_owner(p):
		return
	# Advance the shared beat BEFORE dispatching, and never from the
	# consume_attack_bonus path: player.gd reads that bonus before it emits
	# weapon_fired, so a counter bumped there would be one ahead and every
	# "every Nth attack" rule would pay out on the wrong beat.
	if state != null:
		state.note_attack()
	for effect in _listeners(&"on_attack"):
		effect.call(&"on_attack", style_id, origin, target, power_mul, haste_mul)


func _on_enemy_defeated(context: RefCounted) -> void:
	var death := context as EnemyDeathContext
	if death == null or not _is_owner(death.source):
		return
	for effect in _listeners(&"on_kill"):
		effect.call(&"on_kill", death)


func _on_player_hit_landed(
	source: Node,
	handle: int,
	at: Vector2,
	amount: float,
	is_crit: bool,
	is_elite: bool
) -> void:
	if not _is_owner(source):
		return
	for effect in _listeners(&"on_hit"):
		effect.call(&"on_hit", handle, at, amount, is_crit, is_elite)


func _on_player_lucky_crit(p: Node, at: Vector2, succeeded: bool) -> void:
	if not _is_owner(p):
		return
	if state != null:
		state.note_lucky_crit(succeeded)
	var hook: StringName = &"on_lucky_crit" if succeeded else &"on_lucky_crit_failed"
	for effect in _listeners(hook):
		if succeeded:
			effect.call(hook, at)
		else:
			effect.call(hook)


func _on_player_damage_taken(p: Node, amount: float, at: Vector2) -> void:
	if not _is_owner(p):
		return
	if state != null:
		state.note_hit_taken()
	for effect in _listeners(&"on_damage_taken"):
		effect.call(&"on_damage_taken", amount, at)


func _on_player_evaded(p: Node, at: Vector2) -> void:
	if not _is_owner(p):
		return
	for effect in _listeners(&"on_evaded"):
		effect.call(&"on_evaded", at)


func _on_player_dashed(p: Node, from: Vector2, direction: Vector2) -> void:
	if not _is_owner(p):
		return
	for effect in _listeners(&"on_dash"):
		effect.call(&"on_dash", from, direction)


func _on_player_healed(p: Node, amount: float) -> void:
	if not _is_owner(p):
		return
	for effect in _listeners(&"on_healed"):
		effect.call(&"on_healed", amount)


func _on_player_entered_building(_volume: Node, first_visit: bool) -> void:
	for effect in _listeners(&"on_building_entered"):
		effect.call(&"on_building_entered", first_visit)


func _on_secondary_completed(objective_id: int) -> void:
	for effect in _listeners(&"on_secondary_completed"):
		effect.call(&"on_secondary_completed", objective_id)


func _on_gate_checklist_changed(gate_state: StringName, _items: Array, _hint: String) -> void:
	var ready: bool = gate_state == &"ready"
	if ready == _gate_ready_announced:
		return
	_gate_ready_announced = ready
	if not ready:
		return
	for effect in _listeners(&"on_gate_ready"):
		effect.call(&"on_gate_ready")


func _on_followers_transaction(
	_old_value: int,
	change: int,
	_new_value: int,
	reason: StringName,
	_context: Dictionary,
	_show_feedback: bool,
	_allow_aggregate: bool
) -> void:
	if change == 0:
		return
	for effect in _listeners(&"on_followers_changed"):
		effect.call(&"on_followers_changed", change, reason)


# ---------------------------------------------------------------------------
# Passive contributions, polled by the player exactly like ItemEffectRunner's.
# ---------------------------------------------------------------------------

func apply_effects_to_stats(s: Stats) -> void:
	if s == null:
		return
	# The fortune noun's Luck pool. Rules publish into one ledger rather than
	# each writing Stats, so a run carrying several of them reads as one number.
	if state != null:
		s.luck += state.bonus_luck()
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("apply_to_stats"):
			node.call("apply_to_stats", s)


func _multiplier(method: StringName) -> float:
	var total := 1.0
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method(method):
			total *= float(node.call(method))
	return total


func get_power_multiplier() -> float:
	return _multiplier(&"get_power_multiplier")


func get_haste_multiplier() -> float:
	return _multiplier(&"get_haste_multiplier")


func get_move_speed_multiplier() -> float:
	return _multiplier(&"get_move_speed_multiplier")


func get_damage_taken_multiplier() -> float:
	return _multiplier(&"get_damage_taken_multiplier")


## The ward noun owns the evasion budget and its clamp, so the number is one
## shared resource rather than a sum this runner happens to perform.
func get_bonus_evasion_chance() -> float:
	var total := 0.0
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("get_bonus_evasion_chance"):
			total += float(node.call("get_bonus_evasion_chance"))
	if state != null:
		total += state.bonus_evasion()
	return clampf(total, 0.0, ManifestationState.EVASION_CLAMP)


## Projectile-shaping channel, mirroring ItemEffectRunner's. Rules that change
## what an attack IS (piercing while planted, a mutated shot) reach the managed
## profile through here rather than trying to fabricate their own projectiles.
func apply_to_managed_hit_profile(profile: HitProfileAdapter, style_id: StringName) -> void:
	if profile == null:
		return
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("apply_to_hit_profile"):
			node.call("apply_to_hit_profile", profile, style_id)


func apply_to_ranged_bullet(bullet: Node, style_id: StringName) -> void:
	if bullet == null:
		return
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("apply_to_ranged_bullet"):
			node.call("apply_to_ranged_bullet", bullet, style_id)


func apply_to_magic_impact(impact: Node) -> void:
	if impact == null:
		return
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("apply_to_magic_impact"):
			node.call("apply_to_magic_impact", impact)


## One-shot empowerment for the attack that is about to be spawned. Every
## charge/rhythm/tithe rule reports through here, so the player only has to
## ask one question before it fires.
func consume_attack_bonus() -> float:
	var total := 1.0
	for node in _all_effects():
		if is_instance_valid(node) and node.has_method("consume_attack_bonus"):
			total *= maxf(0.0, float(node.call("consume_attack_bonus")))
	return total


# ---------------------------------------------------------------------------
# Readout
# ---------------------------------------------------------------------------

func get_active_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in _active.values():
		var effect := node as ManifestationEffect
		if effect == null or not is_instance_valid(effect) or effect.definition == null:
			continue
		out.append({
			"id": effect.definition.id,
			"name": effect.definition.display_name,
			"tags": effect.definition.tags,
			"slot": effect.slot_index,
			"rule": effect.describe(),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return out


## noun -> how many DISTINCT equipped rules declare it. Distinct, not instances:
## two copies of one rule are a duplicate, not an accidental engine, and
## counting instances would let a doubled ring fake every pair of its noun.
func get_noun_counts() -> Dictionary:
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for node in _active.values():
		var effect := node as ManifestationEffect
		if effect == null or not is_instance_valid(effect) or effect.definition == null:
			continue
		var id := effect.definition.id
		if seen.has(id):
			continue
		seen[id] = true
		for tag in effect.definition.tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


func get_meters() -> Array[Dictionary]:
	return state.get_meters() if state != null else ([] as Array[Dictionary])


func active_count() -> int:
	return _active.size()


func active_pair_count() -> int:
	return _pairs.size()
