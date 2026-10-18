extends Node

const Art := preload("res://core/systems/world/WorldArt.gd")
const CACHE := "res://assets/world/ground/baked/ground_materials.res"
const MANIFEST := "res://assets/world/ground/baked/ground_materials.json"
var _passed := 0
var _failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)

func _run() -> void:
	_check(ResourceLoader.exists(CACHE), "the exact ground array is shipped instead of requiring first-entry GPU readback")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	_check(manifest is Dictionary, "the derived ground array carries reproducible source provenance")
	if manifest is Dictionary:
		var valid: bool = int(manifest.get("algorithm_revision", 0)) == Art.GROUND_ARRAY_CACHE_REVISION and int(manifest.get("layer_size", 0)) == Art._GROUND_ARRAY_LAYER_PX
		var sources: Array = manifest.get("sources", [])
		valid = valid and sources.size() == Art.ground_texture_count()
		valid = valid and String(manifest.get("cache_sha256", "")) == FileAccess.get_sha256(CACHE)
		for index in sources.size():
			var entry: Dictionary = sources[index]
			valid = valid and String(entry.path) == Art._GROUND_TEX_PATHS[index] and String(entry.sha256) == FileAccess.get_sha256(String(entry.path)) and String(entry.get("import_sha256", "")) == FileAccess.get_sha256(String(entry.path) + ".import")
		_check(valid, "cached layers match every ordered source and preprocessing revision; art edits require rebaking")
		var array := Art.ground_material_array()
		_check(array != null and array.resource_path == CACHE and array.get_layers() == Art.ground_texture_count(), "world startup actually uses the verified derived array")
	print("GroundMaterialCacheTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)
