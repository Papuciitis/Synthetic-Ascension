extends Node

const BUILDER_SCRIPT: Script = preload("res://core/systems/world/SegmentProcBuilder.gd")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")

var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	var builder: Node = BUILDER_SCRIPT.new()
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	await get_tree().process_frame
	builder.set("_exit_rite", rite)
	_check(int(builder.call("register_rite_safeguard_source", &"wardstone:0")) == 1, "wardstone source grants")
	_check(int(builder.call("register_rite_safeguard_source", &"wardstone:0")) == 0, "wardstone source deduplicates")
	_check(int(builder.call("register_rite_safeguard_source", &"secondary:77")) == 1, "secondary source grants")
	_check(rite.safeguard_count() == 2, "two unique exploration sources produce two charges")

	var pending_builder: Node = BUILDER_SCRIPT.new()
	_check(int(pending_builder.call("register_rite_safeguard_source", &"secondary:88")) == 0, "source waits when Rite is not spawned")
	var later_rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(later_rite)
	await get_tree().process_frame
	pending_builder.set("_exit_rite", later_rite)
	pending_builder.call("_replay_rite_safeguard_sources")
	_check(later_rite.safeguard_count() == 1, "pending source replays once into later Rite")
	pending_builder.call("_replay_rite_safeguard_sources")
	_check(later_rite.safeguard_count() == 1, "replay stays deduplicated")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("RiteSafeguardIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
