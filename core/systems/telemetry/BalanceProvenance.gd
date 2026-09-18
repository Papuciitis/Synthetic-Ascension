extends RefCounted
class_name BalanceProvenance

## Telemetry-only damage provenance passed as the payload of a damage call
## that carries no HitLedger. It is an object so every existing consumer's
## `payload as HitLedger` cast returns null exactly as it did for a null
## payload (a Dictionary payload would raise); nothing in combat reads it.

var origin_id: String = "unknown"
var emitter_id: String = "unknown"
var family: String = "unknown"
var style: String = ""
var generation: int = 0
var cast_id: String = ""


func _init(origin: String = "unknown", emitter: String = "unknown", kind: String = "unknown", core: String = "", gen: int = 0, cast: String = "") -> void:
	origin_id = origin
	emitter_id = emitter
	family = kind
	style = core
	generation = gen
	cast_id = cast


func to_dictionary() -> Dictionary:
	return {"origin_id": origin_id, "emitter_id": emitter_id, "family": family, "style": style, "generation": generation, "cast_id": cast_id}
