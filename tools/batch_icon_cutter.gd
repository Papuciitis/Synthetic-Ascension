@tool
extends Node

# Batch-cuts 16x16 tiles from a sprite sheet into your project as standalone PNGs.
# This project uses those PNGs as ItemData.icon textures.
#
# Assign a sheet Texture2D, then tick "run" once.
#
# Coordinates are (row, col) in the sheet grid.

@export var sheet: Texture2D
@export var cell_size: int = 16
@export var scale: int = 8 # nearest-neighbor upscale (16*8 = 128px output)
@export var output_root: String = "res://assets/textures/items/"

@export var run: bool = false:
	set(v):
		run = false
		if v:
			_cut_all()

func _cut_all() -> void:
	if sheet == null:
		push_error("BatchIconCutter: sheet missing")
		return

	var jobs := [
		# ---- Lattice Index (medium set) ----
		{ "rc": Vector2i(34, 43), "out": output_root + "lattice/lattice_pulsecoil.png" },
		{ "rc": Vector2i(37, 4),  "out": output_root + "lattice/lattice_shellplate.png" },
		{ "rc": Vector2i(4, 10),  "out": output_root + "lattice/lattice_strideframe.png" },
		{ "rc": Vector2i(43, 28), "out": output_root + "lattice/lattice_focusnode.png" },
		{ "rc": Vector2i(37, 37), "out": output_root + "lattice/lattice_tickspurs.png" },
		{ "rc": Vector2i(34, 13), "out": output_root + "lattice/lattice_fingerprint.png" },

		# ---- Gravemarch Protocol (heavy set) ----
		{ "rc": Vector2i(7, 37),  "out": output_root + "gravemarch/gravemarch_vessel.png" },
		{ "rc": Vector2i(46, 7),  "out": output_root + "gravemarch/gravemarch_carapace.png" },
		{ "rc": Vector2i(46, 46), "out": output_root + "gravemarch/gravemarch_stompers.png" },
		{ "rc": Vector2i(34, 1),  "out": output_root + "gravemarch/gravemarch_censer.png" },
		{ "rc": Vector2i(4, 31),  "out": output_root + "gravemarch/gravemarch_clockjaw.png" },
		{ "rc": Vector2i(31, 37), "out": output_root + "gravemarch/gravemarch_bonekey.png" },
	]

	for j in jobs:
		_cut(j.rc, j.out)

	print("BatchIconCutter: done. Wrote ", jobs.size(), " icons.")

func _cut(rc: Vector2i, out_path: String) -> void:
	var img := sheet.get_image()
	if img == null or img.is_empty():
		push_error("BatchIconCutter: sheet image empty")
		return

	var x := rc.y * cell_size
	var y := rc.x * cell_size
	var sub := img.get_region(Rect2i(x, y, cell_size, cell_size))

	# nearest-neighbor upscale
	if scale > 1:
		sub.resize(cell_size * scale, cell_size * scale, Image.INTERPOLATE_NEAREST)

	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())

	var err := sub.save_png(out_path)
	if err != OK:
		push_error("BatchIconCutter: failed save_png: %s (err=%s)" % [out_path, str(err)])
