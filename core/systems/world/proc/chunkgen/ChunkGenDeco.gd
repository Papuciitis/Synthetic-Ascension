extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _add_environment_deco(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator, archetype: StringName, conn_mask: int) -> void:
	if gen.cm != null:
		gen.cm._add_environment_deco(chunk, rng, archetype, conn_mask)
