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

# External diagnostic only; the original repository audit remains unchanged.
const ORIGINAL_AUDIT_SHA256 := "0a1a538b70404fdf68e27678cbcaf0c7137d07ff1bdf8b3b701eae8b5fd32736"
const PREPARED_SCRIPT_SET_SHA256 := "239780686c5da9fe5bb2ece59294dbf512d698c7ee667cce347dd44cb3381403"
var _explicit_audit_load_order: Array[String] = []
var _root_counts: Dictionary = {}



func _ready() -> void:
	for root in ROOTS:
		var before := _checked
		_scan(root)
		_root_counts[root] = _checked - before
		_check_coverage(_checked > before, "%s resolves and holds scripts to parse" % root)
	_check_coverage(
		_checked >= MINIMUM_SCRIPTS,
		"the sweep still covers the tree (%d scripts, floor %d)" % [_checked, MINIMUM_SCRIPTS]
	)
	print("ScriptParseAuditTest: %d passed, %d failed (checked %d scripts across %d roots)" % [
		_checked - _failures, _failures, _checked, ROOTS.size(),
	])
	if not _write_sorted_trace():
		_coverage_failures += 1
		push_error("FAIL: sorted parse diagnostic trace is missing or does not match prepared source")
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
	var entries: Array[String] = []
	var directories: Dictionary = {}
	var entry := dir.get_next()
	while entry != "":
		entries.append(entry)
		directories[entry] = dir.current_is_dir()
		entry = dir.get_next()
	# Diagnostic change: one explicit lexical order before any recursion/load.
	entries.sort()
	for ordered_entry: String in entries:
		var full := path.path_join(ordered_entry)
		if bool(directories[ordered_entry]):
			if not ordered_entry.begins_with("."):
				_scan(full)
		elif ordered_entry.ends_with(".gd"):
			_checked += 1
			_explicit_audit_load_order.append(full)
			var script: Script = load(full) as Script
			if script == null or not script.can_instantiate():
				_failures += 1
				push_error("FAIL: script does not compile: " + full)
	dir.list_dir_end()


func _write_sorted_trace() -> bool:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace-out="):
			output = argument.substr(12)
	if output.is_empty() or not output.is_absolute_path() or FileAccess.file_exists(output):
		push_error("FAIL: sorted diagnostic requires --trace-out=<fresh absolute JSON path>")
		return false
	var sorted_set: Array[String] = _explicit_audit_load_order.duplicate()
	sorted_set.sort()
	var path_set: Dictionary = {}
	for path: String in _explicit_audit_load_order:
		path_set[path] = true
	var order_hash: String = "\n".join(_explicit_audit_load_order).sha256_text()
	var set_hash: String = "\n".join(sorted_set).sha256_text()
	var original_hash: String = FileAccess.get_sha256("res://tools/tests/ScriptParseAuditTest.gd")
	var same_set: bool = set_hash == PREPARED_SCRIPT_SET_SHA256 and path_set.size() == _checked
	var diagnostic_path: String = get_script().resource_path
	var trace: Dictionary = {
		"scope": "Explicit audit load(full) calls only; nested dependency loads are not traced.",
		"project_root": ProjectSettings.globalize_path("res://"),
		"diagnostic_script": diagnostic_path,
		"diagnostic_script_sha256": FileAccess.get_sha256(diagnostic_path),
		"original_audit": "res://tools/tests/ScriptParseAuditTest.gd",
		"original_audit_sha256": original_hash,
		"original_audit_unchanged": original_hash == ORIGINAL_AUDIT_SHA256,
		"roots": ROOTS,
		"minimum_scripts": MINIMUM_SCRIPTS,
		"root_counts": _root_counts,
		"checked": _checked,
		"parse_failures": _failures,
		"coverage_failures": _coverage_failures,
		"unique_script_paths": path_set.size(),
		"prepared_script_set_sha256": PREPARED_SCRIPT_SET_SHA256,
		"script_set_sha256": set_hash,
		"same_script_set_as_prepared": same_set,
		"lexical_entries_before_recursion": true,
		"explicit_audit_load_order_sha256": order_hash,
		"explicit_audit_load_order": _explicit_audit_load_order,
	}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("FAIL: cannot create sorted diagnostic trace: " + output)
		return false
	file.store_string(JSON.stringify(trace, "\t") + "\n")
	file.close()
	print("SORTED_PARSE_TRACE checked=%d unique=%d same_set=%s set_sha256=%s order_sha256=%s json=%s" % [
		_checked, path_set.size(), str(same_set), set_hash, order_hash, output,
	])
	return same_set and original_hash == ORIGINAL_AUDIT_SHA256
