extends Node
const BuildInfoScript = preload("res://core/systems/telemetry/BuildInfo.gd")

# Roadmap 5.8: one source of truth for the game version, and telemetry that
# can say exactly what build produced it.

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var version := BuildInfoScript.version()
	_check(not version.is_empty() and version != "unknown", "the game version comes from project settings (%s)" % version)
	_check(
		version == String(ProjectSettings.get_setting("application/config/version", "")),
		"and is the single source of truth"
	)
	var commit := BuildInfoScript.git_commit()
	_check(commit.length() >= 7 and commit.is_valid_hex_number(), "the git commit is resolved from the checkout (%s)" % commit)
	var branch := BuildInfoScript.git_branch()
	_check(not branch.is_empty() and branch != "unknown", "the git branch is resolved (%s)" % branch)
	_check(BuildInfoScript.godot_version().begins_with("4."), "the engine version is recorded (%s)" % BuildInfoScript.godot_version())
	var described := BuildInfoScript.describe(1337)
	for key in ["game_version", "git_commit", "git_branch", "world_seed", "godot_version"]:
		_check(described.has(key), "describe() carries %s" % key)
	_check(int(described.get("world_seed", 0)) == 1337, "describe() stamps the seed it is given")
	print("BuildInfoTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
