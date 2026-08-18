class_name EnemyWorldTypes
extends RefCounted

const INVALID_HANDLE: int = 0
const SLOT_MASK: int = 0xFFFFFFFF

enum Representation {
	DATA_ONLY = 0,
	MATERIALIZED = 1,
	DYING = 2,
}

enum Flags {
	NONE = 0,
	ELITE = 1 << 0,
	CRITICAL = 1 << 1,
	OBJECTIVE = 1 << 2,
	TUTORIAL = 1 << 3,
	NEVER_RETIRE = 1 << 4,
	SPECIAL = 1 << 5,
}


static func make_handle(slot: int, generation: int) -> int:
	if slot < 0 or generation <= 0:
		return INVALID_HANDLE
	return (generation << 32) | (slot + 1)


static func slot_from_handle(handle: int) -> int:
	if handle == INVALID_HANDLE:
		return -1
	return int(handle & SLOT_MASK) - 1


static func generation_from_handle(handle: int) -> int:
	if handle == INVALID_HANDLE:
		return 0
	return int(handle >> 32)


static func has_flag(flags: int, flag: int) -> bool:
	return (flags & flag) != 0
