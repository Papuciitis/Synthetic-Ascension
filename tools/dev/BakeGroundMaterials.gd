extends SceneTree
## Run with a real renderer, --path . --script res://tools/dev/BakeGroundMaterials.gd.
## Uses the original imported-texture algorithm; no source artwork is changed.
const Art := preload("res://core/systems/world/WorldArt.gd")
const DIRECTORY := "res://assets/world/ground/baked/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ground material baking requires real texture readback, not the Dummy renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var images: Array[Image] = []
	var sources: Array[Dictionary] = []
	for index in Art.ground_texture_count():
		var image := Art.prepare_ground_material_layer(index)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		images.append(image)
		var path: String = Art._GROUND_TEX_PATHS[index]
		sources.append({"path": path, "sha256": FileAccess.get_sha256(path), "import_sha256": FileAccess.get_sha256(path + ".import"), "layer_sha256": hash.finish().hex_encode()})
		await RenderingServer.frame_post_draw
		await process_frame
	var array := Texture2DArray.new()
	var result := array.create_from_images(images)
	if result == OK:
		result = ResourceSaver.save(array, DIRECTORY + "ground_materials.res", ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Ground material bake failed: " + error_string(result))
		quit(1)
		return
	var manifest := {"algorithm_revision": Art.GROUND_ARRAY_CACHE_REVISION, "layer_size": Art._GROUND_ARRAY_LAYER_PX, "format": "RGB8 with generated mipmaps", "cache_sha256": FileAccess.get_sha256(DIRECTORY + "ground_materials.res"), "sources": sources}
	var file := FileAccess.open(DIRECTORY + "ground_materials.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot save ground bake provenance")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	print("BakeGroundMaterials: saved %d original-algorithm layers" % images.size())
	quit(0)
