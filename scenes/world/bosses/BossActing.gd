extends Node
## A visual-only follower of accepted attack state. No clocks, colliders,
## combat events, gameplay tweens or damage are owned by this node.
const EQUIPMENT_SHADER := preload("res://scenes/world/bosses/boss_equipment.gdshader")
const FEET := Vector2(0, 42)
const RELEASE_SECONDS := 0.14
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
	# Observe the controller's completed physics tick (Bulldozer uses 10).
	process_physics_priority = 20
	_physics_process(0.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_actor) or not is_instance_valid(_sprite):
		set_physics_process(false)
		return
	if get_tree().paused:
		return
	if _actor.dead or _actor.is_queued_for_deletion():
		_sprite.transform = _rest
		set_physics_process(false)
		return
	if is_instance_valid(_brain) and _brain.has_method("main_phase"):
		_phase = maxi(_phase, clampi(int(_brain.call("main_phase")), 0, 2))
	_equipment.set_shader_parameter("phase", _phase)
	var state := StringName(_actor.get_meta(&"boss_teaching_state", &"idle"))
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
		target_angle = 0.045 if _tank else 0.03
		target_stretch = Vector2(1.06, 0.95) if _tank else Vector2(1.025, 0.985)
	elif state == &"recovery":
		target_angle = 0.015 if _tank else 0.012
		target_stretch = Vector2(1.015, 0.985) if _tank else Vector2(0.995, 0.985)
	elif state == &"phase_shift":
		target_stretch = Vector2(1.045, 0.97) if _tank else Vector2(0.98, 1.025)
	elif state != &"idle":
		target_angle = -0.035 if _tank else -0.02
		target_stretch = Vector2(0.98, 1.025) if _tank else Vector2(0.985, 1.02)
	if is_instance_valid(_actor.player) and _actor.player.global_position.x < _actor.global_position.x:
		target_angle = -target_angle
	var blend := minf(1.0, delta * (45.0 if releasing else 18.0))
	_angle = lerpf(_angle, target_angle, blend)
	_stretch = _stretch.lerp(target_stretch, blend)
	_sprite.rotation = _rest.get_rotation() + _angle
	_sprite.scale = _rest.get_scale() * _stretch
	_sprite.position = FEET + ((_rest.origin - FEET) * _stretch).rotated(_angle)

func _exit_tree() -> void:
	if is_instance_valid(_sprite):
		_sprite.transform = _rest
		if _sprite.material == _equipment:
			_sprite.material = _previous_material
