extends Node

# Augment output in D per second (docs/design/2026-10-03-bindings-and-theses.md
# §4): each combat augment is stepped by hand for PROBE_SECONDS against a
# fixed crowd of immortal dummies, with perfect play for the actives (cast
# the moment it is ready), at several levels, plain and Transcended. Prints
# a markdown table; D = the native hit (ranged, Power 0: 12).
#
# Reference: the native weapon is about 4.5 D/s on one target (ranged),
# 3.3 D/s per enemy in its arc (melee), 2.5 D/s per enemy in its blast
# (magic).
#
# Run: <godot> --headless --fixed-fps 60 --path . res://tools/tests/AugmentPowerProbe.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const SCENES := {
	"Magic Missile": preload("res://effects/augments/scenes/MagicMissileEffect.tscn"),
	"Tesla Aura": preload("res://effects/augments/scenes/TeslaAuraEffect.tscn"),
	"Spirit Slash": preload("res://effects/augments/scenes/SpiritSlashEffect.tscn"),
	"Summon Spiderlings": preload("res://effects/augments/scenes/SpiderlingSummonEffect.tscn"),
}
## Large enough that nothing dies in the window, small enough that a 32-bit
## health record still shows a single hit.
const HP := 1.0e6
const STEP := 1.0 / 60.0
const PROBE_SECONDS := 10.0
const CROWD := 40
const CROWD_RADIUS := 260.0
const LEVELS := [1, 5, 10]


class ProbePlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats: Stats = Stats.new()
	var hp: float = 100.0
	var max_hp: float = 100.0

	func heal(_amount: float, _source: StringName = &"generic") -> void:
		pass

	func grant_invulnerability(_seconds: float) -> void:
		pass


var _crowd: Array[int] = []


func _ready() -> void:
	call_deferred(&"_run")


func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(CROWD):
		var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * CROWD_RADIUS
		_crowd.append(EnemyWorld.create_enemy(SpawnState.new(&"probe_dummy", "res://probe_dummy.tscn", at, HP, 0.0, 4.0, 0)))


func _crowd_damage() -> float:
	var total := 0.0
	for handle in _crowd:
		if EnemyWorld.is_valid_handle(handle):
			total += HP - EnemyWorld.get_health(handle)
	return total


func _reset_crowd() -> void:
	for handle in _crowd:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"power_probe")
	_crowd.clear()
	_spawn_crowd()


func _run() -> void:
	Global.selected_style_id = &"ranged"
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	var player := ProbePlayer.new()
	add_child(player)
	var d := AugmentScaling.native_d(player)
	var lines: Array[String] = []
	lines.append("| Augment | Lv | Plain D/s | Transcended D/s |")
	lines.append("|---|---|---|---|")
	for augment_name in SCENES:
		for level in LEVELS:
			var started := Time.get_ticks_msec()
			var plain: float = (await _measure(SCENES[augment_name], player, level, false)) / d
			var turned: float = (await _measure(SCENES[augment_name], player, level, true)) / d
			print("measured %s Lv.%d in %d ms" % [augment_name, level, Time.get_ticks_msec() - started])
			lines.append("| %s | %d | %.1f | %.1f |" % [augment_name, level, plain, turned])
	# Blink Hex adds to the native attacks: its D/s is the marks it can lay.
	for level in LEVELS:
		var t := AugmentScaling.count_steps(level)
		var cooldown := maxf(2.5, 6.0 * pow(0.92, float(t)))
		var marks := 1 + int(floor(float(t) / 2.0))
		var per_mark := 3.0 * AugmentScaling.potency(level)
		lines.append("| Blink Hex (marks, analytic) | %d | %.1f | %.1f (+ rifts 2 x 2.5 x %.2f = %.1f D per blink) |" % [
			level, per_mark * marks / cooldown, per_mark * (marks + 1) / cooldown, AugmentScaling.potency(level), 5.0 * AugmentScaling.potency(level),
		])
	print("\n".join(lines))
	for handle in _crowd:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"power_probe")
	get_tree().quit(0)


## Total damage dealt to the crowd in PROBE_SECONDS, per second. The engine
## runs the effect, its missiles and spiderlings and their VFX; the probe
## only presses the active key the moment it is ready. Run with
## --fixed-fps 60 so every frame is exactly STEP.
func _measure(scene: PackedScene, player: ProbePlayer, level: int, transcended: bool) -> float:
	_reset_crowd()
	var effect := scene.instantiate()
	effect.call("setup", player)
	add_child(effect)
	effect.call("set_level", level)
	effect.call("set_transcended", transcended)
	var steps := int(PROBE_SECONDS / STEP)
	for i in range(steps):
		if effect is SpiritSlashEffect and not transcended and float(effect.get("_cd")) <= 0.0:
			effect.call("_try_cast", true)
		elif effect is SpiderlingSummonEffect and float(effect.get("_cd")) <= 0.0:
			effect.call("_try_spawn")
		await get_tree().physics_frame
	var dealt := _crowd_damage()
	effect.queue_free()
	for spider in get_tree().get_nodes_in_group("spiderlings"):
		spider.queue_free()
	await get_tree().process_frame
	return dealt / PROBE_SECONDS
