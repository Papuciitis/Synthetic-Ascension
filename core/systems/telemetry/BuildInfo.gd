extends RefCounted
class_name BuildInfo

## One source of truth for "which build produced this" (roadmap 5.8).
##
## The version lives in project settings (application/config/version); the
## packaging script reads it from there, so the exe name, the menu and every
## telemetry report agree. Git identity is read from the checkout in
## development and from res://build_info.json in exported builds (written by
## tools/package_release.ps1 before export).

const BUILD_INFO_PATH := "res://build_info.json"

static var _git_commit := ""
static var _git_branch := ""
static var _git_resolved := false


static func version() -> String:
	var value := String(ProjectSettings.get_setting("application/config/version", ""))
	return value if not value.is_empty() else "unknown"


static func godot_version() -> String:
	return String(Engine.get_version_info().get("string", ""))


static func git_commit() -> String:
	_resolve_git()
	return _git_commit


static func git_branch() -> String:
	_resolve_git()
	return _git_branch


static func describe(world_seed: int = 0) -> Dictionary:
	return {
		"game_version": version(),
		"git_commit": git_commit(),
		"git_branch": git_branch(),
		"world_seed": world_seed,
		"godot_version": godot_version(),
	}


static func _resolve_git() -> void:
	if _git_resolved:
		return
	_git_resolved = true
	_git_commit = "unknown"
	_git_branch = "unknown"
	if FileAccess.file_exists(BUILD_INFO_PATH):
		var baked: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO_PATH))
		if baked is Dictionary:
			_git_commit = String((baked as Dictionary).get("git_commit", _git_commit))
			_git_branch = String((baked as Dictionary).get("git_branch", _git_branch))
			return
	# Linked worktrees and submodules use a .git FILE pointing at their own
	# HEAD directory. Branch refs may live in the shared commondir instead.
	var git_dir := ProjectSettings.globalize_path("res://.git")
	if FileAccess.file_exists(git_dir):
		var link := _read_trimmed(git_dir)
		if not link.begins_with("gitdir: "):
			return
		git_dir = _resolve_relative(git_dir.get_base_dir(), link.substr(8))
	var common_dir := git_dir
	var common_link := _read_trimmed(git_dir.path_join("commondir"))
	if not common_link.is_empty():
		common_dir = _resolve_relative(git_dir, common_link)
	var head := _read_trimmed(git_dir.path_join("HEAD"))
	if head.is_empty():
		return
	if head.begins_with("ref: "):
		var ref := head.substr(5)
		_git_branch = ref.trim_prefix("refs/heads/")
		var commit := _read_trimmed(common_dir.path_join(ref))
		if commit.is_empty():
			# Packed refs after a gc: "<sha> refs/heads/<branch>" lines.
			for line in _read_trimmed(common_dir.path_join("packed-refs")).split("\n"):
				if line.ends_with(" " + ref):
					commit = line.get_slice(" ", 0)
					break
		_git_commit = commit.substr(0, 12) if not commit.is_empty() else "unknown"
	else:
		_git_branch = "detached"
		_git_commit = head.substr(0, 12)


static func _resolve_relative(base: String, target: String) -> String:
	return target.simplify_path() if target.is_absolute_path() else base.path_join(target).simplify_path()


static func _read_trimmed(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()
