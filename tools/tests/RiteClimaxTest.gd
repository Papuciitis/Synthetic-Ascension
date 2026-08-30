extends Node

# Plan 2.8, the two parts §27 recorded as not built. The 50% cue: the ExitRite
# reports a distortion level that is 0 below its start fraction, climbs with
# the hold, and falls back to 0 on lapse, death, reset and clear; the
# VisionRig tints the screen to it and lets go under reduced motion without a
# fade. The 85% last chance: exactly one Cursed Vault per channel, at the
# rite's edge on the far side from the player, configured to take every
# safeguard; a reset or a clear takes the vault with it.
#
# Run: <godot> --headless --path . res://tools/tests/RiteClimaxTest.tscn

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const VISION_RIG_SCENE: PackedScene = preload("res://scenes/vision/VisionRig.tscn")

class FakePlayer:
	extends Node2D
	var is_dead := false
	var max_hp := 100.0
	var hp := 60.0

	func heal(amount: float, _source: StringName = &"generic") -> void:
		hp = minf(max_hp, hp + amount)

var _passes := 0
var _failures := 0
var _levels: Array[float] = []
var _tips: Array[String] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_level(level: float) -> void:
	_levels.append(level)


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _last_level() -> float:
	return _levels.back() if not _levels.is_empty() else -1.0


func _tip_containing(needle: String) -> bool:
	for tip in _tips:
		if tip.contains(needle):
			return true
	return false


func _vaults_under(rite: Node) -> Array[CursedVault]:
	var found: Array[CursedVault] = []
	for child in rite.get_children():
		if child is CursedVault and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _run() -> void:
	var saved_rules: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	var saved_hold_mul: float = Global.attempt_exit_hold_mul
	Global.attempt_doctrine_rules = {}
	Global.attempt_exit_hold_mul = 1.0
	RunEvents.rite_distortion_changed.connect(_on_level)
	RunEvents.tutorial_tip.connect(_on_tip)

	await _test_rite()
	await _test_vision_rig()

	RunEvents.rite_distortion_changed.disconnect(_on_level)
	RunEvents.tutorial_tip.disconnect(_on_tip)
	Global.attempt_doctrine_rules = saved_rules
	Global.attempt_exit_hold_mul = saved_hold_mul
	print("RiteClimaxTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_rite() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	player.position = Vector2(100.0, 0.0)
	add_child(player)
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	rite.position = Vector2.ZERO
	add_child(rite)
	await get_tree().process_frame
	# Driven by hand from here: the engine's own frames would move the hold.
	rite.set_process(false)
	var hold := rite.hold_time

	_check(rite.distortion_start_fraction > 0.0 and rite.distortion_start_fraction < rite.last_chance_fraction, "the cue starts before the last chance (%.2f < %.2f)" % [rite.distortion_start_fraction, rite.last_chance_fraction])
	_check(rite.last_chance_fraction < 1.0, "the last chance comes before the clear")

	rite.set_locked(false)
	rite.set("_player_inside", true)
	rite.grant_safeguard(&"test:a")
	rite.grant_safeguard(&"test:b")
	_check(rite.safeguard_count() == 2, "two safeguards to lose")

	# --- 50%: nothing below, a ramp above ---
	rite._process(hold * 0.30)
	_check(rite.distortion_level() == 0.0 and _levels.is_empty(), "no distortion at 30%% (level %.2f, %d signals)" % [rite.distortion_level(), _levels.size()])
	rite._process(hold * 0.20)
	_check(rite.distortion_level() == 0.0, "none at exactly 50%% (level %.2f)" % rite.distortion_level())
	rite._process(hold * 0.10)
	var at_60 := rite.distortion_level()
	_check(at_60 > 0.0 and _last_level() == at_60, "the world warps past 50%% (level %.2f, reported %.2f)" % [at_60, _last_level()])
	_check(_tip_containing("warps"), "the cue is taught (%s)" % [_tips])
	rite._process(hold * 0.10)
	var at_70 := rite.distortion_level()
	_check(at_70 > at_60 and at_70 < 1.0, "and climbs with the hold (%.2f -> %.2f)" % [at_60, at_70])
	_check(_vaults_under(rite).is_empty(), "no vault before 85%")

	# --- lapse: the ramp lets go once the grace runs out ---
	rite.set("_player_inside", false)
	rite._process(rite.lapse_grace * 0.5)
	_check(rite.distortion_level() == at_70, "a short dodge keeps the cue (%.2f)" % rite.distortion_level())
	rite._process(rite.lapse_grace * 0.5 + 0.2)
	_check(rite.distortion_level() == 0.0 and _last_level() == 0.0, "past the grace the cue is gone (level %.2f, reported %.2f)" % [rite.distortion_level(), _last_level()])
	rite.set("_player_inside", true)
	rite._process(0.01)
	_check(rite.distortion_level() > 0.0, "stepping back in restores it from the kept progress (%.2f)" % rite.distortion_level())

	# --- death ---
	player.is_dead = true
	rite._process(0.1)
	_check(rite.distortion_level() == 0.0 and _last_level() == 0.0, "a dead body in the circle does not warp the world")
	player.is_dead = false

	# --- 85%: one vault, at the edge, on the far side ---
	var tips_before := _tips.size()
	rite._process(hold * 0.25)
	var vaults := _vaults_under(rite)
	_check(vaults.size() == 1, "crossing 85%% spawns exactly one vault (%d)" % vaults.size())
	rite._process(hold * 0.02)
	_check(_vaults_under(rite).size() == 1, "and only one per channel")
	if vaults.size() != 1:
		rite.queue_free()
		player.queue_free()
		await get_tree().process_frame
		return
	var vault: CursedVault = vaults[0]
	_check(rite.last_chance_vault() == vault, "the rite knows its vault")
	var distance := vault.position.length()
	_check(distance >= rite.radius - vault.open_radius and distance <= rite.radius + vault.open_radius, "the vault's opening disc overlaps the rite's edge (%.0f for radius %.0f)" % [distance, rite.radius])
	_check(vault.position.x < 0.0 and absf(vault.position.y) < 1.0, "on the far side from the player (%s)" % [vault.position])
	_check(vault.cost_all_safeguards and vault.cost_beats.is_empty() and vault.guarantee_manifestation, "configured to take the safeguards, send no beat, and guarantee a Manifestation")
	_check(_tips.size() > tips_before and _tip_containing("LAST CHANCE"), "announced once (%s)" % [_tips.slice(tips_before)])

	# --- opening it takes the safeguards, from outside the circle ---
	player.global_position = vault.global_position
	vault._process(0.5)
	_check(_tip_containing("every safeguard"), "the vault's own sign names the safeguard cost")
	vault._process(vault.open_time + 0.1)
	_check(vault.is_opened(), "standing in it opens it")
	_check(rite.safeguard_count() == 0, "and the rite's safeguards are gone (%d)" % rite.safeguard_count())
	_check(not rite.can_invoke_safeguard(), "nothing left to invoke")
	var reward := vault.reward()

	# --- reset takes the vault and the cue ---
	rite.set_locked(true)
	_check(rite.distortion_level() == 0.0 and _last_level() == 0.0, "a channel reset reports level 0")
	_check(vault.is_queued_for_deletion() and rite.last_chance_vault() == null, "and despawns the vault")
	await get_tree().process_frame
	_check(rite.get_node_or_null(ExitRite.LAST_CHANCE_VAULT_NAME) == null, "the vault is gone next frame")

	# --- a second channel re-arms the last chance; the clear takes it ---
	rite.set_locked(false)
	rite.set("_player_inside", true)
	rite._process(hold * 0.90)
	_check(_vaults_under(rite).size() == 1, "the next channel spawns its own vault")
	_check(rite.distortion_level() > 0.0, "and warps again (%.2f)" % rite.distortion_level())
	rite._process(hold)
	_check(bool(rite.get("_completed")), "the rite clears")
	_check(rite.distortion_level() == 0.0 and _last_level() == 0.0, "the clear reports level 0")
	_check(_vaults_under(rite).is_empty(), "and takes the vault with it")

	if reward != null and is_instance_valid(reward):
		reward.queue_free()
	rite.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _test_vision_rig() -> void:
	var rig := VISION_RIG_SCENE.instantiate() as VisionRig
	add_child(rig)
	await get_tree().process_frame
	var rect := rig.vignette_rect
	_check(rect != null, "the rig has its vignette rect")
	if rect == null:
		rig.queue_free()
		return
	var mat := rect.material as ShaderMaterial
	_check(mat != null, "with the vignette shader")
	if mat == null:
		rig.queue_free()
		return
	var base_inner := float(mat.get_shader_parameter("inner_radius"))
	_check(not rect.visible, "nothing shows outdoors at level 0")
	var initial_tint: Variant = mat.get_shader_parameter("tint")
	var initial_wash: Variant = mat.get_shader_parameter("wash")
	_check((initial_tint == null or initial_tint == Color.BLACK) and (initial_wash == null or float(initial_wash) == 0.0), "the shader's tint defaults render the plain vignette (%s, %s)" % [initial_tint, initial_wash])

	var previous_reduced: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)

	RunEvents.rite_distortion_changed.emit(0.5)
	_check(rect.visible, "level 0.5 shows the vignette")
	var strength_half := float(mat.get_shader_parameter("strength"))
	var inner_half := float(mat.get_shader_parameter("inner_radius"))
	var tint_half: Color = mat.get_shader_parameter("tint")
	_check(strength_half > 0.0 and inner_half < base_inner and tint_half != Color.BLACK, "with strength, a tighter centre and a colour (%.2f, %.2f, %s)" % [strength_half, inner_half, tint_half])
	RunEvents.rite_distortion_changed.emit(1.0)
	_check(float(mat.get_shader_parameter("strength")) > strength_half and float(mat.get_shader_parameter("inner_radius")) < inner_half, "level 1 goes further than 0.5")
	_check(is_equal_approx(float(mat.get_shader_parameter("strength")), rig.distortion_strength_max), "full distortion is the exported ceiling")
	RunEvents.rite_distortion_changed.emit(0.7)
	_check(float(mat.get_shader_parameter("strength")) < rig.distortion_strength_max and rect.visible, "a drain lowers it without letting go")

	# Release with motion allowed: a fade, not a cut.
	RunEvents.rite_distortion_changed.emit(0.0)
	_check(rect.visible and rig.distortion_level() > 0.0, "the release fades rather than cuts (%.2f)" % rig.distortion_level())
	await get_tree().create_timer(rig.distortion_release_time + 0.3).timeout
	_check(not rect.visible and rig.distortion_level() == 0.0, "and ends hidden (%.2f)" % rig.distortion_level())
	_check(mat.get_shader_parameter("tint") == Color.BLACK and float(mat.get_shader_parameter("wash")) == 0.0 and is_equal_approx(float(mat.get_shader_parameter("inner_radius")), base_inner), "with the shader back to its defaults")

	# Reduced motion: the ramp still shows; the release is immediate.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	RunEvents.rite_distortion_changed.emit(0.8)
	_check(rect.visible, "reduced motion still shows the static ramp")
	RunEvents.rite_distortion_changed.emit(0.0)
	_check(not rect.visible and rig.distortion_level() == 0.0, "and lets go at once under reduced motion")

	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_reduced, false)
	rig.queue_free()
	await get_tree().process_frame
