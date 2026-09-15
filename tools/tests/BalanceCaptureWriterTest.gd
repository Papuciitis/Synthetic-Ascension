extends Node

var _passes := 0
var _failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var path := "res://core/systems/telemetry/BalanceCaptureWriter.gd"
	_check(ResourceLoader.exists(path), "capture writer is available")
	if ResourceLoader.exists(path):
		var writer = load(path)
		var dir := "user://balance_writer_test_%s" % Time.get_ticks_usec()
		var huge: int = 9007199254740993
		var fixture := {"schema_version": 1, "metadata": {"capture_id": "test"}, "outcome": "suspended", "totals": {"followers_close": huge}, "segments": [], "dropped_records": 0, "wallet_discontinuities": 0}
		var result: Dictionary = writer.write_batch({"records": [{"seq": 1, "kind": "transaction", "data": {"after": huge}}], "summary": fixture}, dir)
		_check(result.get("ok", false), "writer creates capture directory and report")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("summary.json")))
		_check(parsed is Dictionary and str(parsed.totals.followers_close) == "9007199254740993", "large wallet integers survive JSON round trip exactly")
		writer.write_batch({"records": [{"seq": 2, "kind": "end"}]}, dir)
		var lines := FileAccess.get_file_as_string(dir.path_join("events.jsonl")).strip_edges().split("\n")
		_check(lines.size() == 2 and JSON.parse_string(lines[1]).seq == 2, "successive batches append without overwriting history")
		_check(FileAccess.file_exists(dir.path_join("report.md")) and FileAccess.file_exists(dir.path_join("segments.csv")), "human report and segment CSV are generated")
		var blocker := dir.path_join("file-not-directory")
		var f := FileAccess.open(blocker, FileAccess.WRITE)
		f.store_string("fixture")
		f.close()
		result = writer.write_batch({"records": [{"seq": 3}]}, blocker.path_join("child"))
		_check(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "I/O failure is reported instead of claiming success")
		for name in ["events.jsonl", "summary.json", "report.md", "segments.csv", "file-not-directory"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("BalanceCaptureWriterTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
