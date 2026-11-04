extends SceneTree
## Parse-only: load native fixture scripts/baseline bindings, never instantiate
## a renderer/viewport or request any native material/texture asset.
const NATIVE_TEST = preload("res://tools/tests/YardSupportNativeTest.gd")

func _initialize() -> void:
	if NATIVE_TEST.can_instantiate():
		print("YardSupportNativeParseTest: 1 passed, 0 failed")
		quit(0)
	else:
		print("YardSupportNativeParseTest: 0 passed, 1 failed")
		quit(1)
