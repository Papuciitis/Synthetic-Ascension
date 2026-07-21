extends Node

@warning_ignore("unused_signal")
signal weapon_fired(player: Node, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, haste_mul: float)

@warning_ignore("unused_signal")
signal enemy_killed(player: Node, enemy: Node, pos: Vector2)

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
signal blocking_info_requested(card_id: StringName, title: String, body: String)

@warning_ignore("unused_signal")
signal enemy_archetype_encountered(enemy: Node)

@warning_ignore("unused_signal")
signal tutorial_modal_state_changed(open: bool)
