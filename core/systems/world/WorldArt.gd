extends Object
class_name WorldArt
# Centralized texture lists for ChunkManager + procedural generators.

const TEX_TILE_PX: int = 1024

const GROUND_TEX: Array[Texture2D] = [
	preload("res://assets/world/ground/ground_grass_01.png"),
	preload("res://assets/world/ground/ground_dirt_01.png"),
	preload("res://assets/world/ground/ground_cobble_01.png"),
	preload("res://assets/world/ground/ground_stone_tiles_01.png"),
	preload("res://assets/world/ground/ground_dirt_path_01.png"),
	preload("res://assets/world/ground/ground_mud_wet_01.png"),
]

const DECAL_TEX: Array[Texture2D] = [
	preload("res://assets/world/decals/decal_cracks_01.png"),
	preload("res://assets/world/decals/decal_stain_01.png"),
	preload("res://assets/world/decals/decal_sigil_01.png"),
]

const VEG_TEX: Array[Texture2D] = [
	preload("res://assets/world/vegetation/veg_bush_cluster_01.png"),
	preload("res://assets/world/vegetation/veg_overgrowth_island_01.png"),
	preload("res://assets/world/vegetation/veg_dead_tree_01.png"),
]

const LANDMARK_TEX: Array[Texture2D] = [
	preload("res://assets/world/landmarks/landmark_obelisk_01.png"),
	preload("res://assets/world/landmarks/landmark_shrine_piece_01.png"),
	preload("res://assets/world/landmarks/landmark_big_statue_01.png"),
]
