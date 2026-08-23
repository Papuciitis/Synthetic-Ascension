extends Node

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

@warning_ignore("unused_signal")
signal tutorial_tip(text: String, duration: float)

@warning_ignore("unused_signal")
signal objective_changed(title: String, detail: String)

@warning_ignore("unused_signal")
signal secondary_objective_changed(title: String, detail: String)

@warning_ignore("unused_signal")
signal secondary_objective_completed(objective_id: int)

@warning_ignore("unused_signal")
signal segment_phase_changed(phase: StringName, label: String)

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
