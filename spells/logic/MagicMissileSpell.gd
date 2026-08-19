extends SpellBase

@export var projectile_scene: PackedScene
@export var projectile_speed := 550.0
@export var base_damage := 6.0
@export var min_cd := 0.12

func _get_cooldown() -> float:
	var haste_mul: float = 1.0
	if caster != null:
		var st: Stats = caster.get("stats") as Stats
		if st != null:
			haste_mul = 1.0 + maxf(st.haste, -0.9)

	var base_cd: float = (data.cooldown if data != null else 0.4)
	var cd: float = base_cd / maxf(haste_mul, 0.05)
	return maxf(min_cd, cd)

func cast() -> bool:
	if caster == null:
		return false
	if projectile_scene == null:
		return false

	var target_handle := _nearest_enemy()
	if target_handle == EnemyWorldTypes.INVALID_HANDLE:
		return false
	var target_position := EnemyCombat.position_for_handle(target_handle)

	var pm := get_node_or_null("/root/PoolManager")
	var p: Node = null
	if pm != null and is_instance_valid(pm) and pm.has_method("obtain"):
		p = pm.call("obtain", projectile_scene, get_tree().current_scene) as Node
	else:
		p = projectile_scene.instantiate()
	if p == null:
		return false

	# only works if your projectile script has `var source`
	p.source = caster

	# position
	if p is Node2D:
		(p as Node2D).global_position = caster.global_position

	# direction
	var dir := (target_position - caster.global_position).normalized()

	# velocity (your projectile seems to use 'velocity')
	if p.has_method("set"):
		p.set("velocity", dir * projectile_speed)

	# damage scaling with power
	var power_mul := 1.0
	var st = caster.get("stats")
	if st != null:
		power_mul = 1.0 + st.power

	if p.has_method("set"):
		p.set("damage", base_damage * power_mul)

	# group for filtering
	p.add_to_group("player_projectile")

	if p.get_parent() == null:
		get_tree().current_scene.add_child(p)
	return true

@export var target_search_radius: float = 1600.0

func _nearest_enemy() -> int:
	if caster == null or not is_instance_valid(caster):
		return EnemyWorldTypes.INVALID_HANDLE
	return EnemyCombat.nearest_enemy(caster.global_position, target_search_radius)
