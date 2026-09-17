extends Node

# Loads every .gd under the gameplay roots and asserts it compiles in a
# real game context (autoloads present). Catches parse/compile errors in
# scripts that no headless test happens to load — UI screens especially.
#
# ROOTS is every directory outside tools/ that holds a .gd at all: a script
# living nowhere in this list is a script nothing in the suite ever parses.
const ROOTS: Array[String] = [
	"res://core",
	"res://ui",
	"res://autoload",
	"res://scenes",
	"res://effects",
	"res://data",
	"res://assets",
	"res://spells",
]

## A scan that finds nothing passes for free, and a renamed or moved directory
## is exactly how it would come to find nothing. Every root must resolve and
## contribute at least one script, and the whole sweep must stay near the
## tree's real size.
## Floor under the 372 scripts the eight roots hold at 127d4be, with room for
## ordinary deletions.
const MINIMUM_SCRIPTS: int = 340

var _failures: int = 0
var _checked: int = 0
var _coverage_failures: int = 0


func _ready() -> void:
	for root in ROOTS:
		var before := _checked
		_scan(root)
		_check_coverage(_checked > before, "%s resolves and holds scripts to parse" % root)
	_check_coverage(
		_checked >= MINIMUM_SCRIPTS,
		"the sweep still covers the tree (%d scripts, floor %d)" % [_checked, MINIMUM_SCRIPTS]
	)
	print("ScriptParseAuditTest: %d passed, %d failed (checked %d scripts across %d roots)" % [
		_checked - _failures, _failures, _checked, ROOTS.size(),
	])
	get_tree().quit(1 if _failures + _coverage_failures > 0 else 0)


func _check_coverage(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_coverage_failures += 1
		push_error("FAIL: " + message)


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
