extends "res://tools/tests/WorldGroundSplatTest.gd"
## SAME retained existing data assertions, with queue_free processed between
## independent cases. This bounds memory without relaxing the 64MB guard.
## The three ChunkManager integration assertions are explicitly out of scope.

const DATA_CASES := [
	"_test_base_and_stamps", "_test_z_order", "_test_authored_stamps_survive_bases",
	"_test_stains", "_test_wrap_reclaims_block", "_test_slots",
	"_test_domestic_care_data_contract", "_test_district_policy_presentation",
	"_test_district_care_eligibility", "_test_ground_occlusion",
	"_test_occlusion_seams", "_test_planting", "_test_base_margin_rects",
]

func _ready() -> void:
	call_deferred("_run_bounded_subset")

func _run_bounded_subset() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for method: String in DATA_CASES:
		var started := Time.get_ticks_msec()
		print("DATA CASE START: ",method," ms=",started)
		call(method)
		print("DATA CASE DONE: ",method," elapsed_ms=",Time.get_ticks_msec()-started)
		await get_tree().process_frame
	await get_tree().process_frame
	print("WorldGroundSplatDataSubset: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures else 0)
