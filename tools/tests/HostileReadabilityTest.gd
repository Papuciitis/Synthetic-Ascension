extends Node

# Hostile readability (audit 2026-10-04, change 7): a Spitter holds every shot
# for 0.25 s behind a visible tell; hostile bolts draw 1.3x a player bolt over
# a halo in their shooter's colour; the Charger's tell builds instead of
# fading and flashes on release; a Bomber burns a 0.35 s fuse inside its
# trigger distance; and a sniper aiming from off-screen gets an edge pip.
# Each actor's own AI is switched off and its module driven by hand.

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const SPITTER := preload("res://core/actors/enemy/EnemySpec_Spitter.tres")
const BOMBER := preload("res://core/actors/enemy/EnemySpec_Bomber.tres")
const SNIPER := preload("res://core/actors/enemy/EnemySpec_Sniper.tres")
const OverlayScript := preload("res://ui/controllers/HudDangerOverlay.gd")

var _passes := 0
var _failures := 0
var _player: CharacterBody2D = null


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn(spec: EnemySpec, at: Vector2) -> EnemyActor:
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	enemy.spec = spec
	enemy.global_position = at
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.player = _player
	# Its own AI ran for two frames before it was stopped: start every module
	# from rest.
	(enemy.get("_bomber") as EnemyBomber).setup(enemy)
	(enemy.get("_sniper") as EnemySniper).setup(enemy)
	(enemy.get("_shooter") as EnemyShooter).setup(enemy)
	return enemy


func _run() -> void:
	Global.start_new_attempt()
	_player = CharacterBody2D.new()
	_player.add_to_group(&"player")
	add_child(_player)
	await _test_spitter_windup()
	_test_bolt_render()
	await _test_charger_tell()
	await _test_bomber_fuse()
	await _test_sniper_pips()
	ProjectileManager.call("_clear_all")
	_player.queue_free()
	await get_tree().process_frame
	print("HostileReadabilityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_spitter_windup() -> void:
	ProjectileManager.call("_clear_all")
	var spitter := await _spawn(SPITTER, Vector2(300, 0))
	var shooter: EnemyShooter = spitter.get("_shooter")
	shooter.setup(spitter)
	var base := int(ProjectileManager.call("active_count"))
	var to_player := _player.global_position - spitter.global_position
	shooter.brain(to_player, to_player.length(), 100.0, SPITTER.preferred_range, SPITTER.range_tolerance, SPITTER.strafe_strength)
	_check(shooter.is_winding_up(), "a ready Spitter in sight starts a wind-up")
	_check(int(ProjectileManager.call("active_count")) == base, "instead of firing at once")
	var tell := spitter.get_node_or_null("ShotWindupTell") as VFX_EnemyShotWindup
	_check(tell != null and tell.visible, "and shows its tell")
	for i in range(10):
		shooter.tick(0.02)
	_check(shooter.is_winding_up() and int(ProjectileManager.call("active_count")) == base, "0.2 s in it is still holding the shot")
	_check(tell != null and tell.progress() > 0.7, "with the tell nearly closed (%.2f)" % (tell.progress() if tell != null else -1.0))
	for i in range(3):
		shooter.tick(0.02)
	_check(not shooter.is_winding_up(), "after 0.25 s the wind-up is over")
	_check(int(ProjectileManager.call("active_count")) == base + 1, "and the bolt flies")
	_check(tell != null and not tell.visible, "the tell hides at release")
	_check(is_equal_approx(float(shooter.get("_cd")), maxf(SPITTER.shoot_every, 0.05)), "the cooldown starts at release")
	var visuals: PackedInt32Array = ProjectileManager.get("_visuals")
	_check(visuals.size() > base and visuals[base] == ProjectileSimulationManager.Visual.ENEMY_GREEN, "a Spitter bolt carries the Spitter visual")
	shooter.brain(to_player, to_player.length(), 100.0, SPITTER.preferred_range, SPITTER.range_tolerance, SPITTER.strafe_strength)
	_check(not shooter.is_winding_up(), "a Spitter on cooldown does not wind up")
	# Plinks (Herald, Tactical) share the tell.
	shooter.set("_cd", 0.0)
	shooter.shoot_if_ready(to_player)
	_check(shooter.is_winding_up() and int(ProjectileManager.call("active_count")) == base + 1, "shoot_if_ready winds up too")
	# A pooled body forgets a half-finished wind-up.
	shooter.setup(spitter)
	_check(not shooter.is_winding_up() and (tell == null or not tell.visible), "setup clears a wind-up and its tell")
	spitter.queue_free()
	await get_tree().process_frame


func _test_bolt_render() -> void:
	ProjectileManager.call("_clear_all")
	ProjectileManager.call("spawn_enemy", Vector2(0, 0), Vector2.RIGHT, 300.0, 5.0, 3.0, null, &"enemy_spitter")
	ProjectileManager.call("spawn_enemy", Vector2(0, 50), Vector2.RIGHT, 300.0, 5.0, 3.0, null, &"enemy_herald")
	ProjectileManager.call("spawn_player", Vector2(0, 100), Vector2.RIGHT, HitProfileAdapter.new(), null)
	ProjectileManager.call("_update_renderer")
	var meshes: Array = ProjectileManager.get("_identity_meshes")
	if meshes.size() != int(ProjectileManager.get("FAMILY_COUNT")):
		_check(true, "legacy single-family renderer: the halo is not built (no body art)")
		return
	var enemy_buffer: PackedFloat32Array = ProjectileManager.get("_buffer_enemy")
	var player_buffer: PackedFloat32Array = ProjectileManager.get("_buffer_shared")
	_check(absf(enemy_buffer[0] / player_buffer[0] - ProjectileSimulationManager.ENEMY_BODY_SCALE) < 0.001, "a hostile bolt draws 1.3x a player bolt (%.2f vs %.2f)" % [enemy_buffer[0], player_buffer[0]])
	var halo_mesh: MultiMesh = ProjectileManager.get("_enemy_halo_mesh")
	var halo: PackedFloat32Array = ProjectileManager.get("_buffer_enemy_halo")
	_check(halo_mesh != null and halo_mesh.visible_instance_count == 2, "every hostile bolt gets a halo, and only those (%d)" % (halo_mesh.visible_instance_count if halo_mesh != null else -1))
	var first := Color(halo[8], halo[9], halo[10])
	var second := Color(halo[20], halo[21], halo[22])
	_check(first.g > first.r and first.g > first.b, "the Spitter's halo is green (%s)" % first)
	_check(second.r > second.g and second.g > second.b, "the Herald's is orange (%s)" % second)
	_check(not first.is_equal_approx(second), "so the two shooters' bolts no longer look alike")
	ProjectileManager.call("_clear_all")
	ProjectileManager.call("_update_renderer")
	_check(halo_mesh.visible_instance_count == 0, "clearing the bolts clears the halos")


func _test_charger_tell() -> void:
	var tell := VFX_ChargeWindup.new()
	add_child(tell)
	tell.setup(Vector2.RIGHT, 0.4)
	_check(is_equal_approx(tell.windup_alpha(0.0), 0.35) and is_equal_approx(tell.windup_alpha(1.0), 1.0), "the Charger tell builds from 0.35 to full")
	_check(tell.windup_alpha(0.9) > tell.windup_alpha(0.5), "and is brightest just before the dash, not gone")
	tell.call("_process", 0.42)
	_check(is_instance_valid(tell) and not tell.is_queued_for_deletion(), "past the wind-up it stays for the release flash")
	tell.call("_process", tell.release_flash)
	_check(tell.is_queued_for_deletion(), "then frees itself")
	await get_tree().process_frame


func _test_bomber_fuse() -> void:
	var bomber := await _spawn(BOMBER, Vector2(60, 0))
	var module: EnemyBomber = bomber.get("_bomber")
	var to_player := _player.global_position - bomber.global_position
	var move := module.brain(to_player.normalized(), to_player.length(), 100.0)
	_check(module.is_fuse_lit() and not bomber.dead, "inside the trigger distance the fuse lights instead of an instant blast")
	_check(absf(move.length() - 100.0 * EnemyBomber.FUSE_MOVE_MUL) < 0.01, "the bomber keeps closing, slowed (%.1f)" % move.length())
	var calls := 1
	while not bomber.dead and calls < 120:
		module.brain(to_player.normalized(), to_player.length(), 100.0)
		calls += 1
	var burned := float(calls) * bomber.get_physics_process_delta_time()
	_check(bomber.dead, "the fuse goes off")
	_check(absf(burned - EnemyBomber.FUSE_TIME) <= bomber.get_physics_process_delta_time() + 0.001, "after about 0.35 s (%.3f s)" % burned)
	await get_tree().process_frame


func _test_sniper_pips() -> void:
	var overlay: Control = OverlayScript.new()
	overlay.size = Vector2(1920, 1080)
	add_child(overlay)
	await get_tree().process_frame
	var far := await _spawn(SNIPER, Vector2(2600, 540))
	var near := await _spawn(SNIPER, Vector2(900, 500))
	overlay.call("_process", 0.11)
	_check(overlay.sniper_pips().is_empty(), "no pip while no sniper aims")
	var far_module: EnemySniper = far.get("_sniper")
	var near_module: EnemySniper = near.get("_sniper")
	far_module.call("_start_windup", _player.global_position - far.global_position)
	near_module.call("_start_windup", _player.global_position - near.global_position)
	_check(far.is_in_group(EnemySniper.AIMING_GROUP), "a sniper in its wind-up joins the aiming group")
	overlay.call("_process", 0.11)
	var pips: PackedVector2Array = overlay.sniper_pips()
	_check(pips.size() == 1, "only the off-screen one gets a pip (%d)" % pips.size())
	if pips.size() == 1:
		_check(absf(pips[0].x - (1920.0 - OverlayScript.PIP_INSET)) < 1.0 and absf(pips[0].y - 540.0) < 1.0, "on the screen edge toward it (%s)" % pips[0])
	far_module.call("_free_telegraph")
	near_module.call("_free_telegraph")
	_check(not far.is_in_group(EnemySniper.AIMING_GROUP), "shot, cancelled or freed, it leaves the group")
	overlay.call("_process", 0.016)
	_check(overlay.sniper_pips().is_empty(), "and its pip goes")
	var crowd: Array[EnemyActor] = []
	for i in range(6):
		var s := await _spawn(SNIPER, Vector2(-1500 - i * 50, 200 + i * 40))
		(s.get("_sniper") as EnemySniper).call("_start_windup", _player.global_position - s.global_position)
		crowd.append(s)
	# No pip showed a moment ago, so the overlay is on its 0.1 s idle poll.
	overlay.call("_process", 0.11)
	_check(overlay.sniper_pips().size() == OverlayScript.MAX_SNIPER_PIPS, "at most %d pips at once (%d)" % [OverlayScript.MAX_SNIPER_PIPS, overlay.sniper_pips().size()])
	for s in crowd:
		s.queue_free()
	far.queue_free()
	near.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	overlay.call("_process", 0.016)
	_check(overlay.sniper_pips().is_empty(), "freed snipers leave no pip behind")
	overlay.queue_free()
