extends "res://tools/tests/DistrictGroundPolicyTest.gd"
## Reuse the unchanged catalogue assertions without regenerating fourteen districts.


func _run() -> void:
	_test_policy_catalogue()
	print("GroundPolicyCatalogue: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
