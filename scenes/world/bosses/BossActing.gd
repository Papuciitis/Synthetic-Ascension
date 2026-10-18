extends Node
## A visual-only follower of accepted attack state. No clocks, colliders,
## combat events, gameplay tweens or damage are owned by this node.
const EQUIPMENT_SHADER := preload("res://scenes/world/bosses/boss_equipment.gdshader")
const DEFEAT := preload("res://scenes/world/bosses/BossDefeatAfterimage.gd")
const FEET := Vector2(0, 42)
const RELEASE_SECONDS := 0.18
var _actor: EnemyActor
var _sprite: Sprite2D
var _brain: Node
var _rest := Transform2D.IDENTITY
var _previous_material: Material
var _equipment: ShaderMaterial
var _phase := 0
var _previous_state: StringName = &"idle"
var _release_left := 0.0
var _angle := 0.0
var _stretch := Vector2.ONE
var _tank := false
var _recoil_left := 0.0
var _recoil_cooldown := 0.0
var _damage_weight := 0.0
var _defeat_spawned := false

func setup(actor: EnemyActor, sprite: Sprite2D) -> void:
	_actor = actor
	_sprite = sprite
	_brain = actor.get_node_or_null("BossBrain")
	_rest = sprite.transform
	_previous_material = sprite.material
	_tank = actor.spec.id == &"boss_bulldozer"
	_equipment = ShaderMaterial.new()
	_equipment.shader = EQUIPMENT_SHADER
	_equipment.set_shader_parameter("arcanist", not _tank)
	sprite.material = _equipment
	RunEvents.enemy_damaged.connect(_on_damaged)
	RunEvents.enemy_defeated.connect(_on_defeated)
	# Observe the controller's completed physics tick (Bulldozer uses 10).
	process_physics_priority = 20
	_physics_process(0.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_actor) or not is_instance_valid(_sprite):
		set_physics_process(false)
		return
	if get_tree().paused:
		return
	_recoil_left = maxf(0.0, _recoil_left - delta)
	_recoil_cooldown = maxf(0.0, _recoil_cooldown - delta)
	if _actor.dead or _actor.is_queued_for_deletion():
		_sprite.transform = _rest
		set_physics_process(false)
		return
	if is_instance_valid(_brain) and _brain.has_method("main_phase"):
		_phase = maxi(_phase, clampi(int(_brain.call("main_phase")), 0, 2))
	_equipment.set_shader_parameter("phase", _phase)
	var state := StringName(_actor.get_meta(&"boss_teaching_state", &"idle"))
	if state not in [&"idle", &"recovery"]:
		_recoil_left = 0.0
		_damage_weight = 0.0
	# The real release has already happened when a committed cast enters its
	# recovery. Hold the follow-through briefly, within that earned opening.
	if state == &"recovery" and _previous_state not in [&"idle", &"recovery", &"phase_shift"]:
		_release_left = RELEASE_SECONDS
	else:
		_release_left = maxf(0.0, _release_left - delta)
	_previous_state = state
	if bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false)):
		_sprite.transform = _rest
		_angle = 0.0
		_stretch = Vector2.ONE
		return
	var releasing := _release_left > 0.0 or state in [&"rush", &"breach_rush"]
	# These sustained attacks retain their cast state through the active part.
	if is_instance_valid(_brain):
		if _tank and state == &"shock":
			releasing = float(_brain.get("_cast_elapsed")) >= float(_brain.get("shockwave_windup"))
		elif not _tank and state in [&"sweep", &"convergence_beam"]:
			releasing = float(_brain.get("_teaching_left")) <= 1.6
	var target_angle := 0.0
	var target_stretch := Vector2.ONE
	if releasing:
		target_angle = 0.13 if _tank else 0.085
		target_stretch = Vector2(1.12, 0.89) if _tank else Vector2(1.07, 0.94)
	elif state == &"recovery":
		target_angle = 0.035 if _tank else 0.025
		target_stretch = Vector2(1.035, 0.955) if _tank else Vector2(0.985, 0.965)
	elif state == &"phase_shift":
		target_stretch = Vector2(1.08, 0.94) if _tank else Vector2(0.94, 1.065)
	elif state != &"idle":
		# The brace becomes deeper as the real accepted tell approaches release.
		# It never introduces a separate clock or moves the combat root.
		var commitment := _commitment_progress()
		target_angle = lerpf(-0.075, -0.12, commitment) if _tank else lerpf(-0.055, -0.08, commitment)
		target_stretch = Vector2(0.96, 1.05).lerp(Vector2(0.92, 1.09), commitment) if _tank else Vector2(0.96, 1.045).lerp(Vector2(0.94, 1.07), commitment)
	if _recoil_left > 0.0 and not releasing:
		var weight := _recoil_left / 0.13
		target_angle -= 0.075 * weight
		target_stretch *= Vector2(1.0 + 0.045 * weight, 1.0 - 0.045 * weight)
	if is_instance_valid(_actor.player) and _actor.player.global_position.x < _actor.global_position.x:
		target_angle = -target_angle
	var blend := minf(1.0, delta * (45.0 if releasing else 18.0))
	_angle = lerpf(_angle, target_angle, blend)
	_stretch = _stretch.lerp(target_stretch, blend)
	_sprite.rotation = _rest.get_rotation() + _angle
	_sprite.scale = _rest.get_scale() * _stretch
	_sprite.position = FEET + ((_rest.origin - FEET) * _stretch).rotated(_angle)

func _commitment_progress() -> float:
	if not is_instance_valid(_brain):
		return 0.0
	if _tank:
		var elapsed := float(_brain.get("_cast_elapsed"))
		var tell := float(_brain.get("_slam_tell"))
		var state := StringName(_actor.get_meta(&"boss_teaching_state", &"idle"))
		if state in [&"rush_tell", &"breach_tell"]:
			tell = float(_brain.get("_rush_tell"))
		elif state == &"shock":
			tell = float(_brain.get("shockwave_windup"))
		return clampf(elapsed / maxf(0.05, tell), 0.0, 1.0)
	return clampf(1.0 - float(_brain.get("_teaching_left")) / maxf(0.05, float(_brain.get("_teaching_duration"))), 0.0, 1.0)

func _on_damaged(handle: int, applied: float, _unclamped: float, _before: float, _source: Node, _payload: Variant) -> void:
	if not is_instance_valid(_actor) or EnemyWorld.actor_for_handle(handle) != _actor or applied <= 0.0:
		return
	if StringName(_actor.get_meta(&"boss_teaching_state", &"idle")) not in [&"idle", &"recovery"]:
		return
	_damage_weight += applied / maxf(_actor.max_hp, 1.0)
	# Aggregate a flurry instead of vibrating once per pellet. This is a
	# visual acknowledgement, never a stagger or a canceled committed tell.
	if _recoil_cooldown <= 0.0 and _damage_weight >= 0.025:
		_recoil_left = 0.13
		_recoil_cooldown = 0.3
		_damage_weight = 0.0

func _on_defeated(context: RefCounted) -> void:
	if context == null or _defeat_spawned or not is_instance_valid(_actor) or EnemyWorld.actor_for_handle(int(context.get("handle"))) != _actor:
		return
	_defeat_spawned = true
	var aftermath := DEFEAT.new()
	aftermath.setup(_sprite, _tank)
	var parent := get_tree().current_scene
	if parent == null:
		parent = _actor.get_parent()
	parent.add_child(aftermath)
	SfxManager.play_2d(&"boss_defeat", _actor.global_position, 0.0, 0.78 if _tank else 1.0)

func _exit_tree() -> void:
	if is_instance_valid(_sprite):
		_sprite.transform = _rest
		if _sprite.material == _equipment:
			_sprite.material = _previous_material
