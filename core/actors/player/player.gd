extends CharacterBody2D

const AimState := preload("res://core/actors/player/PlayerAimState.gd")
const AimReticle := preload("res://core/actors/player/PlayerAimReticle.gd")

signal hp_changed(current: float, max_hp: float)

@export var speed: float = 300.0
@export var max_hp: float = 100.0

@export var contact_damage: float = 10.0
@export var contact_tick: float = 0.5

@export var base_stats: Stats

@export var melee_slash_scene: PackedScene
@export var ranged_bullet_scene: PackedScene
@export var magic_impact_scene: PackedScene
@export var vfx_pulse_ring_scene: PackedScene   # assign PulseRing.tscn
@export var vfx_spokes_scene: PackedScene       # assign SpokesBurst.tscn

@export var base_weapon_damage: float = 12.0
@export var melee_cooldown: float = 0.0
@export var ranged_cooldown: float = 0.22
@export var magic_cooldown: float = 0.55


# Melee keeps its passive regeneration identity. Lifesteal itself is universal,
# style-weighted and capped per second so fast multi-hit builds cannot bypass danger.
@export_group("Melee Sustain")
@export var melee_regen_flat_per_sec: float = 0.35
@export var melee_regen_bonus_hp_pct_per_sec: float = 0.004
@export var melee_regen_delay_after_damage: float = 1.25

@export_group("Style Lifesteal")
@export_range(0.0, 0.20, 0.001) var melee_lifesteal_pct: float = 0.020
@export_range(0.0, 0.20, 0.001) var ranged_lifesteal_pct: float = 0.008
@export_range(0.0, 0.20, 0.001) var magic_lifesteal_pct: float = 0.006
@export_range(0.0, 0.50, 0.005) var melee_lifesteal_cap_max_hp_per_sec: float = 0.060
@export_range(0.0, 0.50, 0.005) var ranged_lifesteal_cap_max_hp_per_sec: float = 0.030
@export_range(0.0, 0.50, 0.005) var magic_lifesteal_cap_max_hp_per_sec: float = 0.025

@export var death_follower_cost: int = 10
@export var respawn_invuln_time: float = 2.0
@export var respawn_phase_time: float = 2.0
@export var respawn_speed_mul: float = 1.35

var stats: Stats = null
var hp: float = 100.0
var spawn_pos: Vector2

var _weapon_cd: float = 0.0

# sustain runtime
var _melee_regen_block_left: float = 0.0
var _style_damage_cb: Callable = Callable()
var _lifesteal_window_left: float = 1.0
var _lifesteal_healed_this_window: float = 0.0
var _touching_enemies: int = 0
var _damage_loop_running: bool = false
var _contact_sources: Dictionary = {} # enemy instance id -> {node, overlap_count}
var is_dead: bool = false
var _cinematic_move_locked: bool = false
var _cinematic_attack_locked: bool = false
var _aim_state: RefCounted = AimState.new()
var _aim_reticle: Node2D

var invulnerable_time: float = 0.0

var respawn_phase_left: float = 0.0
var _base_collision_mask: int = 0
var _base_collision_layer: int = 0
const ENEMY_BODY_LAYER_BIT: int = 1 << 1  # physics layer 2
var _bound_inv: Inventory = null
var _managed_hit_profile: HitProfileAdapter = HitProfileAdapter.new()

@onready var hurtbox: Area2D = $Hurtbox
@onready var aim_pivot: Node2D = $AimPivot
@onready var spell_caster: SpellCaster = $SpellCaster as SpellCaster


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	# ✅ so enemy projectiles can identify it without guessing layers
	if hurtbox != null:
		hurtbox.add_to_group("player_hurtbox")

	_base_collision_mask = collision_mask
	_base_collision_layer = collision_layer

	# HP init
	hp = max_hp
	spawn_pos = global_position
	hp_changed.emit(hp, max_hp)

	# Hurtbox signal wiring
	if hurtbox != null:
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		if not hurtbox.area_exited.is_connected(_on_hurtbox_area_exited):
			hurtbox.area_exited.connect(_on_hurtbox_area_exited)

		if not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)
		if not hurtbox.body_exited.is_connected(_on_hurtbox_body_exited):
			hurtbox.body_exited.connect(_on_hurtbox_body_exited)
	else:
		push_warning("Player Hurtbox node missing!")

	# SpellCaster setup
	if spell_caster == null:
		push_error("SpellCaster missing or not typed. In player.tscn set SpellCaster node correctly.")
	else:
		spell_caster.setup(self)
		sync_spells_from_global()

	# Make sure inventory binding is active immediately
	# (regen/lifesteal tick happens in _process(delta))
	_ensure_inventory_binding()

	# listen for permanent augment changes so stats refresh immediately
	if not Global.permanent_augments_changed.is_connected(_on_permanent_augments_changed):
		Global.permanent_augments_changed.connect(_on_permanent_augments_changed)

	# If you have AugmentRunner, refresh once
	if has_node("AugmentRunner"):
		$AugmentRunner.call("refresh")

	_connect_style_sustain_signals()
	_aim_reticle = AimReticle.new()
	add_child(_aim_reticle)


func _exit_tree() -> void:
	if Global.permanent_augments_changed.is_connected(_on_permanent_augments_changed):
		Global.permanent_augments_changed.disconnect(_on_permanent_augments_changed)

	if _bound_inv != null and _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.disconnect(_on_inventory_changed)

	# Style lifesteal signal cleanup
	if _style_damage_cb.is_valid() and RunEvents != null and RunEvents.has_signal("damage_dealt"):
		if RunEvents.damage_dealt.is_connected(_style_damage_cb):
			RunEvents.damage_dealt.disconnect(_style_damage_cb)


func _on_permanent_augments_changed(ids: Array[StringName]) -> void:
	print("[AUG] Player received permanent_augments_changed:", ids)
	refresh_run_state()


func _process(delta: float) -> void:
	if is_dead:
		return
	if _weapon_cd > 0.0:
		_weapon_cd = max(_weapon_cd - delta, 0.0)

	if invulnerable_time > 0.0:
		invulnerable_time = max(invulnerable_time - delta, 0.0)

	if respawn_phase_left > 0.0:
		respawn_phase_left = max(respawn_phase_left - delta, 0.0)
		if respawn_phase_left <= 0.0:
			# restore collisions after phasing
			collision_mask = _base_collision_mask

	_ensure_inventory_binding()

	if Input.is_action_just_pressed("debug_print_sets"):
		if Global.run_inventory == null:
			print("[SETS] run_inventory is null")
		else:
			print("[SETS] counts = ", Global.run_inventory.get_set_counts())

	if not _cinematic_attack_locked and Input.is_action_just_pressed("attack"):
		_fire_weapon(_current_aim_target())

	if not _cinematic_attack_locked and Input.is_action_just_pressed("alt_attack"):
		if spell_caster != null:
			spell_caster.cast_all_manual()
			
	_update_lifesteal_budget(delta)
	_update_melee_sustain(delta)

func _unhandled_input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		_debug_dump_sets()
	if event is InputEventMouseMotion:
		_aim_state.note_mouse_motion()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	var dir := Vector2.ZERO if _cinematic_move_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = dir * get_effective_move_speed()
	move_and_slide()

	if dir != Vector2.ZERO:
		rotation = dir.angle()

	var deadzone := 0.2 if SettingsManager == null else float(SettingsManager.get_value(&"controls", &"controller_deadzone", 0.2))
	var stick_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	_aim_state.update_stick(stick_aim, deadzone)
	var aim_direction: Vector2 = _aim_state.direction() if _aim_state.using_controller() else (get_global_mouse_position() - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	if aim_pivot != null:
		aim_pivot.global_rotation = aim_direction.angle()
	if _aim_reticle != null:
		_aim_reticle.set_aim(global_position, aim_direction, _aim_state.using_controller())


func _current_aim_target() -> Vector2:
	return _aim_state.resolve_target(_attack_origin(), get_global_mouse_position(), 900.0)


func get_effective_move_speed() -> float:
	# One authoritative value for movement and stat-sheet display. The stored
	# speed already contains race, style, augment, equipment and set stat deltas;
	# runtime effects are multiplicative and must be applied only once here.
	var eff_speed: float = speed
	if respawn_phase_left > 0.0:
		eff_speed *= respawn_speed_mul

	var sr: SetRunner = get_node_or_null("SetRunner") as SetRunner
	if sr != null:
		eff_speed *= sr.get_move_speed_multiplier()

	var ier: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier != null:
		eff_speed *= ier.get_move_speed_multiplier()

	return maxf(0.0, eff_speed)


func set_cinematic_input(move_locked: bool, attack_locked: bool) -> void:
	_cinematic_move_locked = move_locked
	_cinematic_attack_locked = attack_locked
	if move_locked:
		velocity = Vector2.ZERO


func clear_cinematic_input() -> void:
	set_cinematic_input(false, false)


func _ensure_inventory_binding() -> void:
	if Global.run_inventory == _bound_inv:
		return

	if _bound_inv != null and _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.disconnect(_on_inventory_changed)

	_bound_inv = Global.run_inventory

	if _bound_inv != null and not _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.connect(_on_inventory_changed)

	_on_inventory_changed()


func _on_inventory_changed() -> void:
	var race: RaceData = Global.race_db.get(Global.selected_race_id, null) as RaceData
	var style: StyleData = Global.style_db.get(Global.selected_style_id, null) as StyleData
	recompute_run_stats(race, style)


func apply_run_stats(new_stats: Stats, emit_hp_signal: bool = true) -> void:
	var old_max: float = max_hp
	var was_full: bool = is_equal_approx(hp, old_max) or hp >= (old_max - 0.001)

	stats = new_stats
	speed = stats.move_speed
	max_hp = stats.max_hp

	if was_full:
		hp = max_hp
	else:
		hp = min(hp, max_hp)

	if emit_hp_signal:
		hp_changed.emit(hp, max_hp)



func sync_spells_from_global() -> void:
	if spell_caster == null:
		return

	if Global.equipped_spell_ids.size() < 3:
		Global.equipped_spell_ids.resize(3)

	for i in range(SpellCaster.SLOT_COUNT):
		var sid: String = str(Global.equipped_spell_ids[i])
		var sd: SpellData = Global.spell_db.get(sid, null) as SpellData
		spell_caster.set_slot(i, sd)


func refresh_run_state() -> void:
	var race: RaceData = Global.race_db.get(Global.selected_race_id, null) as RaceData
	var style: StyleData = Global.style_db.get(Global.selected_style_id, null) as StyleData
	recompute_run_stats(race, style)
	sync_spells_from_global()
	if has_node("AugmentRunner"):
		$AugmentRunner.call("refresh")


func recompute_run_stats(race: RaceData, style: StyleData, emit_hp_signal: bool = true) -> void:
	if base_stats == null:
		push_warning("Player.base_stats is null!")
		return

	var s: Stats = base_stats.copy()

	if race != null:
		race.apply_to(s)
	if style != null:
		style.apply_to(s)

	if Global.has_method("apply_permanent_augments_to_stats"):
		Global.call("apply_permanent_augments_to_stats", s)

	if Global.has_method("apply_attempt_modifiers_to_stats"):
		Global.call("apply_attempt_modifiers_to_stats", s)

	if Global.run_inventory != null:
		var inv_mods: StatDelta = Global.run_inventory.sum_mods()
		if inv_mods != null:
			inv_mods.apply_to(s)

	var sr: SetRunner = get_node_or_null("SetRunner") as SetRunner
	if sr != null:
		sr.apply_sets_to_stats(s, Global.run_inventory)

	var ier: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier != null:
		ier.refresh_effects(Global.run_inventory)
		ier.apply_effects_to_stats(s)

	if Global.run_inventory != null:
		var items: Array[ItemInstance] = Global.run_inventory.items
		for i in range(min(items.size(), Inventory.STAT_SLOT_COUNT)):
			var it: ItemInstance = items[i]
			if it == null or it.data == null:
				continue

			var pct := it.active_pct()
			if i == 5:
				pct = clampf(pct, -0.9999, 0.9999)
			else:
				pct = clampf(pct, -0.95, 0.95)

			match i:
				0: s.max_hp *= (1.0 + pct)
				1: s.armor *= (1.0 + pct)
				2: s.move_speed *= (1.0 + pct)
				3: s.power += pct
				4: s.haste += pct
				5: s.luck += pct

	Global.run_luck = s.luck

	apply_run_stats(s, emit_hp_signal)


func _fire_weapon(mouse_pos: Vector2) -> void:
	var style_id: String = str(Global.selected_style_id)

	var haste_mul: float = 1.0
	var power_mul: float = 1.0
	if stats != null:
		haste_mul = 1.0 + max(stats.haste, -0.9)
		power_mul = 1.0 + stats.power

	var sr: SetRunner = get_node_or_null("SetRunner") as SetRunner
	if sr != null:
		haste_mul *= sr.get_haste_multiplier()

	var ier3: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier3 != null:
		haste_mul *= ier3.get_haste_multiplier()
		power_mul *= ier3.get_power_multiplier()

	var cd: float = 0.0
	if style_id == "melee":
		cd = melee_cooldown
	elif style_id == "magic":
		cd = magic_cooldown
	else:
		cd = ranged_cooldown

	if cd > 0.0 and _weapon_cd > 0.0:
		return

	if cd > 0.0:
		_weapon_cd = cd / max(haste_mul, 0.05)

	if style_id == "melee":
		_spawn_melee(mouse_pos, base_weapon_damage * 1.25 * power_mul)
	elif style_id == "magic":
		_spawn_magic(mouse_pos, base_weapon_damage * 1.15 * power_mul)
	else:
		_spawn_ranged(mouse_pos, base_weapon_damage * power_mul)

	RunEvents.weapon_fired.emit(self, StringName(style_id), global_position, mouse_pos, power_mul, haste_mul)


func _spawn_melee(mouse_pos: Vector2, dmg: float) -> void:
	dmg = _consume_hex_mark_bonus(dmg)
	var origin := _attack_origin()
	var dir := (mouse_pos - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# Major-choice style mutation: double slash
	var dual: bool = (Global != null and Global.has_method("has_mutation") and Global.has_mutation(&"mut_melee_dual_slash"))
	if dual:
		var ang := deg_to_rad(18.0)
		_spawn_melee_slash(origin, dir.rotated(-ang), dmg * 0.75)
		_spawn_melee_slash(origin, dir.rotated( ang), dmg * 0.75)
		return

	_spawn_melee_slash(origin, dir, dmg)


func _spawn_melee_slash(origin: Vector2, dir: Vector2, dmg: float) -> void:
	var forward := 10.0
	var attack_pos := origin + dir * forward

	var inst := melee_slash_scene.instantiate()
	var slash := inst as MeleeSlash
	if slash == null:
		push_error("MeleeSlash scene root is not MeleeSlash (script/class_name missing on scene root).")
		inst.queue_free()
		return

	slash.global_position = attack_pos
	slash.rotation = dir.angle()
	slash.damage = dmg
	slash.set("source", self)

	if hurtbox != null:
		slash.collision_mask = hurtbox.collision_mask
		slash.collision_layer = hurtbox.collision_layer

	slash.add_to_group("player_projectile")
	get_tree().current_scene.add_child(slash)


func _consume_hex_mark_bonus(dmg: float) -> float:
	# Hex Blink's mark charges apply to the next attacks of ANY style —
	# consuming them only in the ranged path made half the augment a no-op
	# for melee and magic builds. Applies once per attack (then distributed
	# if multi-shot).
	var shots_left: int = 0
	if has_meta("hex_mark_shots_left"):
		var sv: Variant = get_meta("hex_mark_shots_left")
		if typeof(sv) == TYPE_INT:
			shots_left = int(sv)
	if shots_left <= 0:
		return dmg

	var d8_count: int = 2
	var power_scale: float = 0.0
	var flat: float = 0.0

	if has_meta("hex_mark_d8_count"):
		var dv: Variant = get_meta("hex_mark_d8_count")
		if typeof(dv) == TYPE_INT:
			d8_count = int(dv)

	if has_meta("hex_mark_power_scale"):
		var pv: Variant = get_meta("hex_mark_power_scale")
		if typeof(pv) == TYPE_FLOAT or typeof(pv) == TYPE_INT:
			power_scale = float(pv)

	if has_meta("hex_mark_flat"):
		var fv: Variant = get_meta("hex_mark_flat")
		if typeof(fv) == TYPE_FLOAT or typeof(fv) == TYPE_INT:
			flat = float(fv)

	var extra: int = 0
	for i in range(max(1, d8_count)):
		extra += randi_range(1, 8)

	var pwr: float = 0.0
	if stats != null:
		pwr = stats.power

	dmg += float(extra) + flat + (pwr * power_scale)

	shots_left -= 1
	if shots_left <= 0:
		remove_meta("hex_mark_shots_left")
		if has_meta("hex_mark_d8_count"): remove_meta("hex_mark_d8_count")
		if has_meta("hex_mark_power_scale"): remove_meta("hex_mark_power_scale")
		if has_meta("hex_mark_flat"): remove_meta("hex_mark_flat")
	else:
		set_meta("hex_mark_shots_left", shots_left)
	return dmg


func _spawn_ranged(mouse_pos: Vector2, dmg: float) -> void:
	var origin := _attack_origin()
	var dir := (mouse_pos - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	dmg = _consume_hex_mark_bonus(dmg)

	# Major-choice style mutation: shotgun spread
	var shotgun: bool = (Global != null and Global.has_method("has_mutation") and Global.has_mutation(&"mut_ranged_shotgun"))
	if shotgun:
		var pellet_count := 3
		var spread_deg := 12.0
		var pellet_dmg := dmg * 0.70
		if pellet_count <= 1:
			_spawn_ranged_bullet(origin, dir, dmg)
			return

		for n in range(pellet_count):
			var t := float(n) / float(pellet_count - 1) - 0.5 # -0.5..0.5
			var a := deg_to_rad(spread_deg) * t
			_spawn_ranged_bullet(origin, dir.rotated(a), pellet_dmg)
		return

	_spawn_ranged_bullet(origin, dir, dmg)


func _spawn_ranged_bullet(origin: Vector2, dir: Vector2, dmg: float) -> void:
	var projectile_manager := get_node_or_null("/root/ProjectileManager") as ProjectileSimulationManager
	if projectile_manager != null:
		_managed_hit_profile.reset(dmg)
		var managed_effects := get_node_or_null("ItemEffectRunner") as ItemEffectRunner
		if managed_effects != null:
			managed_effects.apply_to_managed_hit_profile(_managed_hit_profile, &"ranged")
		projectile_manager.spawn_player(origin, dir, _managed_hit_profile, self)
		return

	# Compatibility fallback for projects that deliberately remove the manager.
	var inst := ranged_bullet_scene.instantiate()
	var bullet := inst as RangedBullet
	if bullet == null:
		push_error("RangedBullet scene root is not RangedBullet (script/class_name missing on scene root).")
		inst.queue_free()
		return

	bullet.source = self
	bullet.global_position = origin
	bullet.velocity = dir * bullet.speed
	bullet.damage = dmg

	if hurtbox != null:
		bullet.collision_mask = hurtbox.collision_mask
		bullet.collision_layer = hurtbox.collision_layer

	bullet.add_to_group("player_projectile")
	var ier_r: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier_r != null:
		ier_r.apply_to_ranged_bullet(bullet, &"ranged")

	get_tree().current_scene.add_child(bullet)


func _spawn_magic(mouse_pos: Vector2, dmg: float) -> void:
	dmg = _consume_hex_mark_bonus(dmg)
	var origin := _attack_origin()

	# Major-choice style mutation: tri-sigil burst
	var tri: bool = (Global != null and Global.has_method("has_mutation") and Global.has_mutation(&"mut_magic_trisigil"))
	if tri:
		var dir := (mouse_pos - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		var off := 38.0

		_vfx_spawn_spokes(origin, 0.10, 44.0)
		_vfx_spawn_pulse(mouse_pos, 22.0, 0.14, 5.0)

		_spawn_magic_impact(mouse_pos, dmg * 0.72)
		_spawn_magic_impact(mouse_pos + perp * off, dmg * 0.64)
		_spawn_magic_impact(mouse_pos - perp * off, dmg * 0.64)
		return

	_vfx_spawn_spokes(origin, 0.10, 44.0)
	_vfx_spawn_pulse(mouse_pos, 22.0, 0.14, 5.0)
	_spawn_magic_impact(mouse_pos, dmg)


func _spawn_magic_impact(pos: Vector2, dmg: float) -> void:
	var inst := magic_impact_scene.instantiate()
	var impact := inst as MagicImpact
	if impact == null:
		push_error("MagicImpact scene root is not MagicImpact (script/class_name missing on scene root).")
		inst.queue_free()
		return

	impact.global_position = pos
	impact.damage = dmg
	impact.set("source", self)

	if hurtbox != null:
		impact.collision_mask = hurtbox.collision_mask
		impact.collision_layer = hurtbox.collision_layer

	var ier_g: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier_g != null:
		ier_g.apply_to_magic_impact(impact)

	get_tree().current_scene.add_child(impact)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		_register_contact_source(_enemy_from_contact(area))


func _on_hurtbox_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		_unregister_contact_source(_enemy_from_contact(area))


func _on_hurtbox_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		_register_contact_source(body)


func _on_hurtbox_body_exited(body: Node) -> void:
	if body.is_in_group("enemies"):
		_unregister_contact_source(body)

func _enemy_from_contact(node: Node) -> Node:
	var cur := node
	for _i in range(4):
		if cur == null:
			break
		if cur.is_in_group(&"enemies"):
			return cur
		cur = cur.get_parent()
	return null

func _register_contact_source(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_meta(&"opening_non_hostile") and bool(enemy.get_meta(&"opening_non_hostile")):
		return
	var id := enemy.get_instance_id()
	var record: Dictionary = _contact_sources.get(id, {}) as Dictionary
	if record.is_empty():
		record = {"node": enemy, "overlap_count": 0}
	record["overlap_count"] = int(record.get("overlap_count", 0)) + 1
	_contact_sources[id] = record
	_touching_enemies = _contact_sources.size()
	_start_contact_loop()

func _unregister_contact_source(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if not _contact_sources.has(id):
		return
	var record: Dictionary = _contact_sources[id] as Dictionary
	var remaining := int(record.get("overlap_count", 1)) - 1
	if remaining <= 0:
		_contact_sources.erase(id)
	else:
		record["overlap_count"] = remaining
		_contact_sources[id] = record
	_touching_enemies = _contact_sources.size()

func _prune_contact_sources() -> void:
	for id in _contact_sources.keys():
		var record: Dictionary = _contact_sources[id] as Dictionary
		var enemy: Node = record.get("node", null) as Node
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
			_contact_sources.erase(id)
	_touching_enemies = _contact_sources.size()


func _threat_enemy_damage_mul() -> float:
	var td := get_node_or_null("/root/ThreatDirector") as ThreatDirectorSingleton
	return (td.enemy_damage_mul if td != null else 1.0)

func _start_contact_loop() -> void:
	if _damage_loop_running:
		return

	_damage_loop_running = true
	while hp > 0:
		_prune_contact_sources()
		if _touching_enemies <= 0:
			break
		# One deterministic tick per interval. A single enemy's Area and Body are
		# one source; extra unique enemies increase pressure with a capped curve.
		var swarm_mul := minf(2.25, 1.0 + float(_touching_enemies - 1) * 0.35)
		_take_damage(contact_damage * swarm_mul * _threat_enemy_damage_mul())
		await get_tree().create_timer(maxf(contact_tick, 0.05), false).timeout

	_damage_loop_running = false


# ✅ NEW: public wrapper so enemies/projectiles can damage you
func take_damage(amount: float, _source: Node = null) -> void:
	_take_damage(amount)



func _take_damage(amount: float) -> void:
	if Global.debug_player_god_mode:
		return
	if invulnerable_time > 0.0:
		return
	if is_dead:
		return

	var ier4: ItemEffectRunner = get_node_or_null("ItemEffectRunner") as ItemEffectRunner
	if ier4 != null:
		amount *= ier4.get_damage_taken_multiplier()

	var armor_val: float = 0.0
	if stats != null:
		armor_val = stats.armor

	var reduced: float = amount * (100.0 / (100.0 + max(armor_val, 0.0)))
	hp = max(hp - reduced, 0.0)

	# Melee passive regen pauses briefly after taking damage (LoL-style).
	if _is_melee_style_active():
		_melee_regen_block_left = maxf(_melee_regen_block_left, melee_regen_delay_after_damage)

	hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true

	var cost: int = death_follower_cost
	if Global != null and Global.has_method("consume_respawn_cost"):
		cost = Global.consume_respawn_cost()
	elif Global != null:
		Global.transaction_followers(-death_follower_cost, &"reconstruction", {}, false, false)

	var game: Node = get_parent()
	var remaining: int = Global.followers if Global != null else 0
	if game != null and game.has_method("present_reconstruction"):
		await game.call("present_reconstruction", cost, remaining)

	# The modal can outlive the scene if the player exits during it.
	if not is_inside_tree():
		return
	if Global != null and Global.followers > 0:
		respawn()
	elif game != null and is_instance_valid(game) and game.has_method("end_run"):
		game.call_deferred("end_run")

func respawn() -> void:
	# Rebuild the complete loadout snapshot before restoring HP. This prevents the
	# first reconstruction from using a stale base speed/max-HP value when effects
	# or inventory bindings finished refreshing while the death card was open.
	is_dead = false
	velocity = Vector2.ZERO

	var race: RaceData = Global.race_db.get(Global.selected_race_id, null) as RaceData
	var style: StyleData = Global.style_db.get(Global.selected_style_id, null) as StyleData
	recompute_run_stats(race, style, false)

	# Hard reset to checkpoint using the final rebuilt maximum. Emit one coherent
	# HP snapshot after both current and maximum HP are settled.
	hp = max_hp
	global_position = spawn_pos
	_contact_sources.clear()
	_touching_enemies = 0
	hp_changed.emit(hp, max_hp)

	# Spawn protection: invulnerability + phasing through enemy bodies
	grant_invulnerability(respawn_invuln_time)
	start_respawn_phase(respawn_phase_time)


func start_respawn_phase(duration: float) -> void:
	respawn_phase_left = max(respawn_phase_left, duration)
	# remove enemy-body collisions during the phase, keep world/cover collisions
	collision_mask = _base_collision_mask & ~ENEMY_BODY_LAYER_BIT

func set_checkpoint(pos: Vector2, move_player: bool = false) -> void:
	spawn_pos = pos
	if move_player:
		global_position = pos
	if Global != null and Global.has_method("set_attempt_checkpoint"):
		Global.set_attempt_checkpoint(pos)

func wardstone_full_restore() -> void:
	# used on wardstone capture (one-time)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_weapon_cd = 0.0
	if spell_caster != null and spell_caster.has_method("reset_all_cooldowns"):
		spell_caster.call("reset_all_cooldowns")
	if has_node("AugmentRunner") and $AugmentRunner.has_method("reset_all_cooldowns"):
		$AugmentRunner.call("reset_all_cooldowns")

func grant_invulnerability(duration: float) -> void:
	invulnerable_time = max(invulnerable_time, duration)



func _is_melee_style_active() -> bool:
	return str(Global.selected_style_id) == "melee"

func _connect_style_sustain_signals() -> void:
	if RunEvents == null or not RunEvents.has_signal("damage_dealt"):
		return

	# Connect defensively so extra signal arguments in future patches are ignored.
	var argc := 2
	for signal_info in RunEvents.get_signal_list():
		if StringName(signal_info.get("name", "")) == &"damage_dealt":
			var args: Array = signal_info.get("args", [])
			argc = maxi(2, args.size())
			break

	var callback := Callable(self, "_on_style_damage_dealt")
	if argc > 2:
		callback = callback.unbind(argc - 2)
	_style_damage_cb = callback
	if not RunEvents.damage_dealt.is_connected(_style_damage_cb):
		RunEvents.damage_dealt.connect(_style_damage_cb)

func _active_lifesteal_profile() -> Vector2:
	var style_id: String = str(Global.selected_style_id) if Global != null else "ranged"
	match style_id:
		"melee":
			return Vector2(melee_lifesteal_pct, melee_lifesteal_cap_max_hp_per_sec)
		"magic":
			return Vector2(magic_lifesteal_pct, magic_lifesteal_cap_max_hp_per_sec)
		_:
			return Vector2(ranged_lifesteal_pct, ranged_lifesteal_cap_max_hp_per_sec)

func _update_lifesteal_budget(dt: float) -> void:
	_lifesteal_window_left -= maxf(0.0, dt)
	if _lifesteal_window_left <= 0.0:
		_lifesteal_window_left = 1.0
		_lifesteal_healed_this_window = 0.0

func _on_style_damage_dealt(a, b) -> void:
	if is_dead or hp >= max_hp - 0.001:
		return

	var source: Node = null
	var damage_amount: float = 0.0
	if a is Node:
		source = a
		damage_amount = float(b)
	elif b is Node:
		source = b
		damage_amount = float(a)
	else:
		return
	if source != self or damage_amount <= 0.0:
		return

	var profile: Vector2 = _active_lifesteal_profile()
	var lifesteal_pct: float = maxf(0.0, profile.x)
	var cap_this_second: float = maxf(0.0, max_hp * profile.y)
	var remaining_cap: float = maxf(0.0, cap_this_second - _lifesteal_healed_this_window)
	if lifesteal_pct <= 0.0 or remaining_cap <= 0.0:
		return

	var healing: float = minf(damage_amount * lifesteal_pct, remaining_cap)
	healing = minf(healing, maxf(0.0, max_hp - hp))
	if healing <= 0.0:
		return
	_lifesteal_healed_this_window += healing
	heal(healing)

func _update_melee_sustain(dt: float) -> void:
	# Passive regen that scales with BONUS HP (max_hp - base_stats.max_hp), LoL-style.
	if is_dead:
		return

	if not _is_melee_style_active():
		_melee_regen_block_left = 0.0
		return

	if _melee_regen_block_left > 0.0:
		_melee_regen_block_left = maxf(_melee_regen_block_left - dt, 0.0)
		return

	if hp >= (max_hp - 0.001):
		return

	var base_hp: float = max_hp
	if base_stats != null:
		base_hp = base_stats.max_hp

	var bonus_hp := maxf(0.0, max_hp - base_hp)
	var per_sec := melee_regen_flat_per_sec + bonus_hp * melee_regen_bonus_hp_pct_per_sec
	if per_sec > 0.0:
		heal(per_sec * dt)



func _attack_origin() -> Vector2:
	if hurtbox != null:
		return hurtbox.global_position
	return global_position


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	hp = min(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func _debug_dump_sets() -> void:
	print("----- SET DEBUG DUMP -----")
	print("Global.set_db keys:", Global.set_db.keys())
	print("Has conduit set?:", Global.set_db.has(&"conduit"))

	if Global.run_inventory == null:
		print("run_inventory = null")
		return

	for i in range(Inventory.SLOT_COUNT):
		var it: ItemInstance = Global.run_inventory.get_at(i)
		if it == null or it.data == null:
			print("slot", i, ": (empty)")
		else:
			print("slot", i, ":", it.data.id, " set_id=", StringName(it.data.set_id))

	print("get_set_counts():", Global.run_inventory.get_set_counts())

	var sr: SetRunner = get_node_or_null("SetRunner") as SetRunner
	if sr == null:
		print("Player has no SetRunner node")
	else:
		print("SetRunner children:", sr.get_children())

	print("----- END SET DEBUG DUMP -----")


func _vfx_spawn_pulse(pos: Vector2, radius: float, dur: float = -1.0, lw: float = -1.0) -> void:
	if vfx_pulse_ring_scene == null:
		return
	var n: Node = vfx_pulse_ring_scene.instantiate()
	if dur > 0.0:
		n.set("duration", dur)
	if lw > 0.0:
		n.set("line_width", lw)

	get_tree().current_scene.add_child(n)
	if n.has_method("setup"):
		n.call("setup", pos, radius)
	elif n is Node2D:
		(n as Node2D).global_position = pos


func _vfx_spawn_spokes(pos: Vector2, dur: float = -1.0, outer: float = -1.0, core: Color = Color(), glow: Color = Color()) -> void:
	if vfx_spokes_scene == null:
		return
	var n: Node = vfx_spokes_scene.instantiate()

	if dur > 0.0: n.set("duration", dur)
	if outer > 0.0: n.set("outer", outer)

	if core != Color():
		n.set("color_core", core)
	if glow != Color():
		n.set("color_glow", glow)
		n.set("glow_mul", 0.45)

	get_tree().current_scene.add_child(n)
	if n.has_method("setup"):
		n.call("setup", pos)
	elif n is Node2D:
		(n as Node2D).global_position = pos
