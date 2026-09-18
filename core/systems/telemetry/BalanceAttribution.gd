extends RefCounted
class_name BalanceAttribution

## Damage provenance for the balance recorder. Two independent answers per
## hit: what initiated the chain (origin) and what directly dealt it
## (emitter). Existing AscensionTags are read without changing their gameplay
## meaning; paths that carry no tags pass a telemetry-only BalanceProvenance
## object (never a HitLedger, so the tree engines and crit detection see
## exactly what they saw for a null payload). Absence is explicit: "unknown".
## A batched HitLedger whose contributions disagree is "mixed", never
## assigned to one projectile's tags.

const UNKNOWN := "unknown"
const MIXED := "mixed"
## Cast prefixes the tree engines stamp ("cast:blink:3") mapped to the ability
## that initiated the chain. Prefixes not listed keep the payload's own root.
const CAST_ORIGINS := {
	"blink": "ascension:MOV", "lunge": "ascension:MOQ", "deadshot": "ascension:PRQ",
	"judgement": "ascension:PRV", "kneel": "ascension:DOV", "compel": "ascension:DOQ",
	"rupture": "ascension:BAV", "squad": "ascension:PRC", "witness": "witness", "ascendant": "ascendant",
}


## A telemetry-only provenance payload for an emitter that carries no tags.
static func provenance(origin_id: String, emitter_id: String, family: String, style: String = "") -> BalanceProvenance:
	return BalanceProvenance.new(origin_id, emitter_id, family, style, 0 if family == "native" else 1, "")


static func status(kind: StringName) -> BalanceProvenance:
	var id := "status:" + String(kind)
	return provenance(id, id, "status")


static func unknown() -> Dictionary:
	return {"origin_id": UNKNOWN, "emitter_id": UNKNOWN, "family": UNKNOWN, "style": "", "generation": 0, "cast_id": ""}


static func from_tags(tags: PackedStringArray) -> Dictionary:
	if tags.is_empty():
		return unknown()
	var parsed := AscensionTags.parse(tags)
	var family := String(parsed["family"])
	var core := String(parsed["core"])
	var root := String(parsed["root"])
	var path := String(parsed["path"])
	var cast := AscensionTags.value_of(tags, "cast")
	var origin := UNKNOWN
	var emitter := UNKNOWN
	if family == AscensionTags.FAMILY_NATIVE:
		origin = "native:" + core
		emitter = origin + (":" + path if not path.is_empty() else "")
	elif family == AscensionTags.FAMILY_TREE:
		emitter = "ascension:" + root + (":" + path if not path.is_empty() else "")
		origin = "ascension:" + root
		if not cast.is_empty():
			var prefix := cast.get_slice(":", 0)
			if prefix == "native":
				# A tree payload spawned by a native input (Spillover from a
				# native kill): the native attack initiated the chain.
				origin = "native:" + core
			elif CAST_ORIGINS.has(prefix):
				origin = String(CAST_ORIGINS[prefix])
	elif not family.is_empty():
		origin = family + ":" + root
		emitter = origin + (":" + path if not path.is_empty() else "")
	return {"origin_id": origin, "emitter_id": emitter, "family": family if not family.is_empty() else UNKNOWN,
		"style": core, "generation": int(parsed["gen"]), "cast_id": cast}


## Provenance of one resolved damage payload as EnemyCombat emitted it.
static func from_payload(payload: Variant) -> Dictionary:
	if payload is BalanceProvenance:
		return (payload as BalanceProvenance).to_dictionary()
	if not (payload is Object):
		return unknown()
	var ledger := payload as HitLedger
	if ledger == null:
		return unknown()
	if ledger.contributions.size() > 1:
		var first := from_tags(ledger.contributions[0].get("tags", PackedStringArray()))
		var breakdown := {}
		var mixed := false
		for entry in ledger.contributions:
			var part := from_tags(entry.get("tags", PackedStringArray()))
			var key: String = part["origin_id"] + "|" + part["emitter_id"]
			breakdown[key] = float(breakdown.get(key, 0.0)) + float(entry.get("damage", 0.0))
			if part["origin_id"] != first["origin_id"] or part["emitter_id"] != first["emitter_id"]:
				mixed = true
		if mixed:
			var out := unknown()
			out["origin_id"] = MIXED
			out["emitter_id"] = MIXED
			out["family"] = MIXED
			out["raw_breakdown"] = breakdown
			return out
		return first
	return from_tags(ledger.tags)
