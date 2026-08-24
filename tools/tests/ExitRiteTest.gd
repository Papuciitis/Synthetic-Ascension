extends Node

## The Rite is the one fight the player cannot walk away from, so its failure
## behaviour has to be exactly as forgiving as it claims and no more.

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")

var _passes: int = 0
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	_check(rite != null, "the Exit Rite scene instantiates")
	if rite == null:
		_finish()
		return
	add_child(rite)
	await get_tree().process_frame

	_check(rite.hold_time >= 10.0, "the rite is a siege, not a button (%.0fs)" % rite.hold_time)
	_check(
		rite.death_progress_kept > 0.0 and rite.death_progress_kept < 1.0,
		"a death costs something but not everything (%.2f)" % rite.death_progress_kept
	)
	_check(rite.lapse_drain_rate > 0.0, "stepping out costs progress")
	_check(
		rite.lapse_drain_rate < 1.0,
		"stepping out costs LESS than standing in it gains - otherwise dodging is never worth it"
	)
	_check(rite.lapse_grace > 0.0, "a moment out of the circle is free")
	_check(
		rite.channel_regen_per_sec > 0.0 or rite.channel_regen_max_hp_pct > 0.0,
		"holding the circle mends you"
	)

	# After a death the wave schedule must rewind with the channel, or every
	# stage is already spent and the rest of the rite is silent.
	rite.set("_hold", rite.hold_time * 0.9)
	rite.call("_resync_burst_stage")
	var late_stage: int = int(rite.get("_burst_stage"))
	rite.set("_hold", rite.hold_time * 0.1)
	rite.call("_resync_burst_stage")
	var early_stage: int = int(rite.get("_burst_stage"))
	_check(
		early_stage < late_stage,
		"the waves rewind with the channel (%d < %d)" % [early_stage, late_stage]
	)
	rite.set("_hold", 0.0)
	rite.call("_resync_burst_stage")
	_check(int(rite.get("_burst_stage")) == 0, "an empty channel has spent no waves")

	# The stages themselves must escalate and be spread across the whole rite,
	# not stacked at the end where nothing can reach the player in time.
	var stages: Array = ExitRite.BURST_STAGES
	_check(stages.size() >= 4, "the rite has several waves (%d)" % stages.size())
	_check(float(stages[0].x) <= 0.25, "the first wave arrives early (%.2f)" % float(stages[0].x))
	for index in range(1, stages.size()):
		_check(float(stages[index].x) > float(stages[index - 1].x), "wave %d is later" % index)
		_check(float(stages[index].y) >= float(stages[index - 1].y), "wave %d is no smaller" % index)

	rite.queue_free()
	_finish()


func _finish() -> void:
	print("ExitRiteTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
