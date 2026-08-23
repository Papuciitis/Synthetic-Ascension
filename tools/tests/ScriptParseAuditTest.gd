extends Node

# Loads every .gd under the gameplay roots and asserts it compiles in a
# real game context (autoloads present). Catches parse/compile errors in
# scripts that no headless test happens to load — UI screens especially.

const ROOTS: Array[String] = [
	"res://core",
	"res://ui",
	"res://autoload",
	"res://scenes",
	"res://effects",
	"res://data",
]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	for root in ROOTS:
		_scan(root)
	print("ScriptParseAuditTest: %d passed, %d failed (checked %d scripts)" % [
		_checked - _failures, _failures, _checked,
	])
	get_tree().quit(1 if _failures > 0 else 0)


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(full)
		elif entry.ends_with(".gd"):
			_checked += 1
			var script: Script = load(full) as Script
			if script == null or not script.can_instantiate():
				_failures += 1
				push_error("FAIL: script does not compile: " + full)
		entry = dir.get_next()
	dir.list_dir_end()
