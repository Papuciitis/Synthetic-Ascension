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
