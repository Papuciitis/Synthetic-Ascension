extends Node2D

const SPOKES := preload("res://assets/vfx/world/sets/conduit/VFX_SpokesBurst.tscn")
var _passed := 0
var _failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.save_dir = "user://tests/attack_visual_lifecycle/"
	var kit: Script = load("res://core/systems/vfx/VfxKit.gd")
	var shared_glow := kit.has_method("attack_glow_texture")
	_check(shared_glow, "attack light shares one cached texture across effects")
	if shared_glow:
		var first: Texture2D = kit.call("attack_glow_texture")
		_check(first != null and first == kit.call("attack_glow_texture"), "glow draws reuse the same resource")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var burst := PooledVfx.obtain(SPOKES, self) as Node2D
	burst.set_process(false)
	burst.call("_process", 0.03)
	_check(is_zero_approx(burst.rotation), "reduced motion keeps impact spokes steady")
	_check(is_instance_valid(burst) and not bool(burst.get_meta("__in_pool", false)), "reduced motion preserves the impact's lifetime")
	burst.call("_process", 0.2)
	_check(bool(burst.get_meta("__in_pool", false)), "the decorated impact still returns to its pool")
	var again := PooledVfx.obtain(SPOKES, self) as Node2D
	_check(again == burst and is_zero_approx(float(again.get("_t"))), "pooled impact resets for the next attack")
	again.call("_process", 0.3)
	var batch := ImpactBurstRenderer.new()
	add_child(batch)
	batch.set_process(false)
	for i in range(ImpactBurstRenderer.MAX_BURSTS + 20): batch.add_burst(Vector2(i, 0))
	_check(batch.active_count() == ImpactBurstRenderer.MAX_BURSTS, "impact storm stays at its existing batch cap")
	batch._process(ImpactBurstRenderer.DURATION + 0.01)
	_check(batch.active_count() == 0 and not batch.is_processing(), "completed impact batch stops processing")
	batch.add_burst(Vector2.ZERO)
	batch.clear()
	_check(batch.active_count() == 0 and not batch.is_processing(), "run-end clear removes every accent")
	ProjectileManager.set_process(false)
	ProjectileManager.clear_for_run_end()
	var profile := HitProfileAdapter.new()
	profile.damage = 0.0
	profile.speed = 700.0
	profile.max_range = 600.0
	ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, profile, self)
	var instances: Array[MultiMeshInstance2D] = ProjectileManager._identity_instances
	_check(instances.size() == ProjectileSimulationManager.FAMILY_COUNT, "attack light keeps the four existing projectile batches")
	if instances.size() == ProjectileSimulationManager.FAMILY_COUNT:
		for family in range(ProjectileSimulationManager.FAMILY_ENEMY):
			_check(instances[family].material is ShaderMaterial, "player family %d shares one light material" % family)
		_check(instances[ProjectileSimulationManager.FAMILY_ENEMY].material is CanvasItemMaterial, "hostile body keeps its original material")
		_check(ProjectileManager._enemy_halo_instance.material is CanvasItemMaterial, "hostile telegraph halo keeps its original material")
		for level in [&"off", &"reduced", &"full"]:
			SettingsManager.set_value(&"accessibility", &"combat_flash", level, false)
			ProjectileManager._update_renderer()
			var expected := AccessibilityPresentation.flash_alpha(1.0, level)
			var honors_setting := true
			for family in range(ProjectileSimulationManager.FAMILY_ENEMY):
				honors_setting = honors_setting and is_equal_approx(float((instances[family].material as ShaderMaterial).get_shader_parameter(&"accent_strength")), expected)
			_check(honors_setting, "all batched player cores honor combat flash " + String(level))
			_check(is_equal_approx(VfxKit.attack_core(Color.CYAN).a, expected), "native accent honors combat flash " + String(level))
	ProjectileManager.clear_for_run_end()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	print("AttackVisualLifecycleTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)
