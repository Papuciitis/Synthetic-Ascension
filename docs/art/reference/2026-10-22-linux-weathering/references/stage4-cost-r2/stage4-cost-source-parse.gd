extends Node


func _ready() -> void:
	var path: String = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-r2/Stage4StaticCostProbe.gd"
	var script: Script = load(path) as Script
	var good: bool = script != null and script.can_instantiate()
	if not good:
		push_error("Stage4CostSourceParse cannot instantiate external helper")
	print("Stage4CostSourceParse: checked=1 failures=%d" % (0 if good else 1))
	get_tree().quit(0 if good else 1)
