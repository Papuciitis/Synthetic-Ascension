extends RefCounted
class_name RitePulseResolver


static func apply(
	combat: Node,
	origin: Vector2,
	radius: float,
	force: float,
	stun_seconds: float,
	player: Node,
	missing_hp_fraction: float,
	invulnerability_seconds: float = 0.0
) -> Dictionary:
	var handles: Array[int] = []
	if combat != null and combat.has_method("gather_in_radius"):
		combat.call("gather_in_radius", origin, maxf(radius, 0.0), handles)
	for handle in handles:
		var target_position: Vector2 = combat.call("position_for_handle", handle)
		var offset := target_position - origin
		var direction := Vector2.RIGHT if offset.length_squared() <= 0.000001 else offset.normalized()
		combat.call("apply_knockback", handle, direction * maxf(force, 0.0))
		if stun_seconds > 0.0:
			combat.call("apply_stun", handle, stun_seconds)
	var healed := _heal_missing(player, missing_hp_fraction)
	var protected := invulnerability_seconds > 0.0 and player != null and player.has_method("grant_invulnerability")
	if protected:
		player.call("grant_invulnerability", invulnerability_seconds)
	return {"targets": handles.size(), "healed": healed, "protected": protected}


static func _heal_missing(player: Node, missing_hp_fraction: float) -> float:
	if player == null or not is_instance_valid(player) or not player.has_method("heal"):
		return 0.0
	var max_value: Variant = player.get("max_hp")
	var current_value: Variant = player.get("hp")
	if not (current_value is float or current_value is int):
		current_value = player.get("health")
	if not (max_value is float or max_value is int) or not (current_value is float or current_value is int):
		return 0.0
	var amount := maxf(0.0, float(max_value) - float(current_value)) * clampf(missing_hp_fraction, 0.0, 1.0)
	if amount > 0.0:
		player.call("heal", amount, &"exit_rite")
	return amount
