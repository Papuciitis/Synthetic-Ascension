extends Node

# Observational balance events. They do not replace gameplay hooks: the
# recorder needs clamped HP loss, sources and lifecycle without changing what
# item/Manifestation listeners currently receive.
@warning_ignore("unused_signal")
signal player_damage_resolved(player: Node, raw: float, after_defenses: float, applied: float, source: Node, kind: StringName, outcome: StringName)
@warning_ignore("unused_signal")
signal player_heal_resolved(player: Node, requested: float, modified: float, applied: float, source: StringName, blocked: bool)
@warning_ignore("unused_signal")
signal player_stats_recomputed(player: Node)
@warning_ignore("unused_signal")
signal player_life_event(player: Node, kind: StringName)

@warning_ignore("unused_signal")
signal weapon_fired(player: Node, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, haste_mul: float)

@warning_ignore("unused_signal")
signal enemy_killed(player: Node, enemy: Node, pos: Vector2)

@warning_ignore("unused_signal")
signal enemy_defeated(context: RefCounted)

@warning_ignore("unused_signal")
signal boss_spawned(boss: Node, tier: int, portrait: Texture2D, title: String)

@warning_ignore("unused_signal")
signal boss_cleared(boss: Node, tier: int)


@warning_ignore("unused_signal")
signal damage_dealt(player: Node, amount: float)

# --- Manifestation hooks -----------------------------------------------------
# The shared gameplay events curated item Manifestations listen to. They are
# deliberately generic (any listener may use them) and each emitter guards on
# has_connections() so nothing is paid for while nothing is listening.

# One resolved player hit on one enemy. `handle` is the EnemyWorld handle so
# listeners can re-target or re-damage the same enemy.
@warning_ignore("unused_signal")
signal player_hit_landed(source: Node, handle: int, position: Vector2, amount: float, is_crit: bool, is_elite: bool)

# The per-attack Luck roll, reported whether it succeeded or failed - failure
# is buildable material (Misfortune), not just a non-event.
@warning_ignore("unused_signal")
signal player_lucky_crit(player: Node, position: Vector2, succeeded: bool)

@warning_ignore("unused_signal")
signal player_damage_taken(player: Node, amount: float, position: Vector2)

@warning_ignore("unused_signal")
signal player_evaded(player: Node, position: Vector2)

@warning_ignore("unused_signal")
signal player_healed(player: Node, amount: float)

# Healing sealed on the player - the Cursed Vault's price, a Sacrifice, a
# ritual interference. Emitted when a lock starts, when a longer one extends
# it, and once with 0.0 when it lifts. Per lock, never per refused heal.
@warning_ignore("unused_signal")
signal healing_lock_changed(seconds_left: float, reason: StringName)

# The dash. Emitted at the START of the dash, not the end: `from` is where the
# orbit was when it left, the direction is locked at that instant, and a halo
# leaving WITH the player is the authored fantasy. A rule that wants landing
# behaviour can delay itself.
@warning_ignore("unused_signal")
signal player_dashed(player: Node, from: Vector2, direction: Vector2)

# Emitted when the player walks into an interior volume. `first_visit` is false
# for re-entry, so exploration rules cannot be farmed by pacing a doorway.
@warning_ignore("unused_signal")
signal player_entered_building(volume: Node, first_visit: bool)

@warning_ignore("unused_signal")
signal pickup_fly_to_equip(start_global: Vector2, equip_slot: int, inst: ItemInstance, upgraded: bool)

@warning_ignore("unused_signal")
signal resonance_changed(value: float)

# Exit Rite climax (plan 2.8): how far the world has warped, 0..1. The rite
# emits it as the hold climbs past its distortion_start_fraction - a static
# ramp that only moves with the channel - and emits 0 when the channel resets,
# lapses, the player dies or the rite clears. The VisionRig tints to it.
@warning_ignore("unused_signal")
signal rite_distortion_changed(level: float)

@warning_ignore("unused_signal")
signal tutorial_tip(text: String, duration: float)

@warning_ignore("unused_signal")
signal objective_changed(title: String, detail: String)

@warning_ignore("unused_signal")
signal secondary_objective_changed(title: String, detail: String)

@warning_ignore("unused_signal")
signal secondary_objective_completed(objective_id: int)
## One of a "take one" group of pickups was taken; the others sealed away.
signal choice_pickup_taken(group: int, inst: ItemInstance)
## A merge dissolved a Manifestation; it is kept as an imprint for the Hub.
signal imprint_stored(imprint_id: StringName)
## The imprinter put a held rule onto an item (replaced may be empty).
signal imprint_applied(inst: ItemInstance, imprint_id: StringName, replaced: StringName)

@warning_ignore("unused_signal")
signal segment_phase_changed(phase: StringName, label: String)

## The player's build crossed a visible power threshold (third / fifth
## Manifestation, ...). The ThreatDirector opens a power-contrast window so
## old threats crumble before the next one arrives (roadmap §11).
@warning_ignore("unused_signal")
signal power_threshold_crossed(id: StringName, label: String)

@warning_ignore("unused_signal")
signal doctrine_event_recorded(event_id: StringName, label: String)

# Structured Exit Rite state for the HUD checklist. state is &"locked",
# &"located" or &"ready"; items are {id: StringName, label: String,
# done: bool}. Never derive READY from resonance_changed - that channel is
# deliberately clamped to 0.998 while the gate is blocked.
@warning_ignore("unused_signal")
signal gate_checklist_changed(state: StringName, items: Array, next_hint: String)

@warning_ignore("unused_signal")
signal blocking_info_requested(card_id: StringName, title: String, body: String)

@warning_ignore("unused_signal")
signal enemy_archetype_encountered(enemy: Node)

@warning_ignore("unused_signal")
signal tutorial_modal_state_changed(open: bool)

@warning_ignore("unused_signal")
signal opening_sequence_state_changed(active: bool, phase: int, mode: StringName)

## Every point of enemy health lost to `source`, with the health it had before
## the hit and the damage before clamping, so a listener can read execute
## bands and overkill. `payload` is the HitLedger (or null) the hit arrived
## with; its tags carry attack provenance for the advancement tree. Guarded by
## has_connections at the emitter: it fires per hit at horde scale.
@warning_ignore("unused_signal")
signal enemy_damaged(handle: int, applied: float, unclamped: float, health_before: float, source: Node, payload: Variant)

## The player spent health on purpose (a tree cost), bypassing evasion, armour
## and i-frames and never below 1 HP. Not a hit: HitFeel and the on-damage
## rules do not hear it.
@warning_ignore("unused_signal")
signal player_paid_health(player: Node, amount: float, reason: StringName)

## One canonical record per actual player HP mutation, emitted by the owner of
## the mutation right after the assignment (and before callbacks that could
## mutate again), so the balance recorder can reconcile every health change:
## hits, heals, intentional costs, takebacks and developer adjustments,
## rescues and reconstruction. Telemetry only; nothing may react to it.
## change: {category, source_id, source_node, hp_before, hp_after,
##          max_hp_before, max_hp_after, requested, reason}
@warning_ignore("unused_signal")
signal balance_health_changed(player: Node, change: Dictionary)

## An advancement-tree ability went off (slot q, v or v2) with the recovery it
## charged. Telemetry only, emitted after the engine accepted the activation.
@warning_ignore("unused_signal")
signal player_ability_activated(player: Node, slot: StringName, id: String, cooldown: float)

## Exit diagnostics (balance recorder). Emitted by the owners of the state:
## nothing may react to these; they describe what the runtime actually did.
## ExitRite: unlocked/locked/revealed, rejected, channel_entered/left,
## lapse_drain_started/ended, progress_lost (death), seal, wave, last_chance,
## safeguard_granted/used/drained, completed. `data` carries hold/progress.
@warning_ignore("unused_signal")
signal exit_rite_event(rite: Node, kind: StringName, data: Dictionary)
## One resolved spawn request: source (ambient, burst, burst_at, beat,
## interior, authored, forced), outcome (spawned or a rejection reason) and
## how many enemies it produced.
@warning_ignore("unused_signal")
signal spawn_request_resolved(source: StringName, outcome: StringName, count: int, data: Dictionary)
## EncounterDirector lifecycle: beat_started/ended/aborted, escalation,
## specialist_response.
@warning_ignore("unused_signal")
signal encounter_event(kind: StringName, data: Dictionary)
## ThreatDirector accepted extra unseal seconds from a contributor (an
## Overtime Gospel instance); the unseal clock and overtime after it.
@warning_ignore("unused_signal")
signal overtime_pressure_injected(contributor: String, seconds: float, unseal_seconds: float, overtime: float)

## Upgrade diagnostics (balance recorder), telemetry only. An item was
## generated by ItemGenerator for `source` (enemy, vendor, vault, indoor,
## exploration): a vendor item is an offer, not an acquisition.
@warning_ignore("unused_signal")
signal item_generated(inst: ItemInstance, source: StringName, context: Dictionary)
## One successful item operation reported by its owner after the fact, with
## the operation scope (BalanceItemContext) it belongs to: merged (from
## ItemInstance.merge_from with exact before/after), equipped/unequipped,
## bagged/unbagged, stashed/unstashed, dropped_to_world, purchased/sold/undo.
@warning_ignore("unused_signal")
signal item_operation(kind: StringName, inst: ItemInstance, data: Dictionary)
