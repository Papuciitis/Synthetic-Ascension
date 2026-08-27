extends RefCounted
class_name BuildIdentity

## "What am I?" - the one-sentence behavioural reading of a run's build
## (roadmap §14/§15). Pure: takes the readings the Run Sheet already gathers
## and composes an identity, so the HUD, the run archive and playtest logs all
## describe a build the same way, in behaviour rather than percentages.
##
## Input dictionary (every key optional):
##   burden          BurdenSnapshot
##   augment_ids     Array of StringName
##   manifestations  Array[Dictionary] {id, name, tags}   (runner summaries)
##   noun_counts     Dictionary noun -> distinct rules declaring it
##   pairs           Array[Dictionary] {id, name, nouns}  (connected pairs)
##   set_counts      Dictionary set_id -> equipped pieces
##   luck            float

const MIN_DOCTRINE_CURSES := 3
const MIN_CORRUPTION_SEVERITY := 0.50
const MIN_ENGINE_NOUNS := 2


static func compose(input: Dictionary) -> Dictionary:
	var burden: BurdenSnapshot = input.get("burden") as BurdenSnapshot
	var augment_ids: Array = input.get("augment_ids", []) as Array
	var manifestations: Array = input.get("manifestations", []) as Array
	var noun_counts: Dictionary = input.get("noun_counts", {}) as Dictionary
	var pairs: Array = input.get("pairs", []) as Array
	var set_counts: Dictionary = input.get("set_counts", {}) as Dictionary
	var luck := float(input.get("luck", 0.0))

	var neg_count := burden.neg_count if burden != null else 0
	var active_pct := int(round(burden.total_active * 100.0)) if burden != null else 0
	var inverted := burden != null and burden.suppressed_slot >= 0
	var qualifying := burden.qualifying_count if burden != null else 0

	var primary := ""
	var primary_clause := ""
	if inverted and augment_ids.has(&"augment_inversion_lens"):
		primary = "Inversion Lens"
		primary_clause = "one %d%% curse inverted into a strength" % int(round(burden.suppressed_severity * 100.0))
	elif augment_ids.has(&"augment_corruption_engine") and burden != null and burden.heaviest(2) >= MIN_CORRUPTION_SEVERITY:
		primary = "Corruption Engine"
		primary_clause = "two catastrophic curses (%d%%) feed Power" % int(round(burden.heaviest(2) * 100.0))
	elif augment_ids.has(&"augment_doctrine_of_burden") and qualifying >= MIN_DOCTRINE_CURSES:
		primary = "Doctrine of Burden"
		primary_clause = "%d mild curses (%d%% active burden) keep you standing" % [qualifying, active_pct]

	var dominant_noun := _dominant_noun(noun_counts)
	var engine := _engine_clause(pairs, noun_counts)
	if primary.is_empty() and not dominant_noun.is_empty():
		primary = "%s engine" % dominant_noun
		primary_clause = engine if not engine.is_empty() else "%s drives combat" % dominant_noun
	var largest_set := _largest_set(set_counts)
	if primary.is_empty() and not largest_set.is_empty():
		primary = largest_set
		primary_clause = "a %s set carries the run" % largest_set

	var secondary := engine if not primary.begins_with(dominant_noun) or dominant_noun.is_empty() else ""
	if secondary.is_empty() and not largest_set.is_empty() and primary != largest_set:
		secondary = "%s x%d" % [largest_set, int(set_counts.get(StringName(largest_set), 0))]

	var sentence := ""
	if primary.is_empty():
		sentence = "Unformed: %d equipped rules, no engine yet." % manifestations.size()
	else:
		sentence = "%s build: %s" % [primary, primary_clause]
		if not secondary.is_empty() and secondary != primary_clause:
			sentence += "; %s" % secondary
		if neg_count > 0 and not primary.contains("Curse") and not primary.begins_with("Doctrine") and not primary.begins_with("Corruption") and not primary.begins_with("Inversion"):
			sentence += "; %d NEG pieces" % neg_count
		if luck >= 20.0:
			sentence += "; Luck +%d" % int(round(luck))
		sentence += "."

	return {
		"primary": primary if not primary.is_empty() else "Unformed",
		"secondary": secondary,
		"sets": _set_labels(set_counts),
		"neg_count": neg_count,
		"active_burden_pct": active_pct,
		"inverted": inverted,
		"luck": luck,
		"manifestation_count": manifestations.size(),
		"connected_pairs": pairs.size(),
		"sentence": sentence,
	}


static func _dominant_noun(noun_counts: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for noun in noun_counts:
		var count := int(noun_counts[noun])
		if count > best_count or (count == best_count and String(noun) < best):
			best = String(noun)
			best_count = count
	return best if best_count >= MIN_ENGINE_NOUNS else ""


static func _engine_clause(pairs: Array, noun_counts: Dictionary) -> String:
	# A connected pair is the clearest behavioural chain: "Momentum -> Shard".
	if not pairs.is_empty():
		var pair := pairs[0] as Dictionary
		var nouns: Array = pair.get("nouns", []) as Array
		if nouns.size() >= 2:
			return "%s -> %s chain drives combat" % [String(nouns[0]), String(nouns[1])]
		return "%s drives combat" % String(pair.get("name", "a pair"))
	# Otherwise the two strongest nouns, if two exist.
	var ranked: Array = noun_counts.keys()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca := int(noun_counts[a])
		var cb := int(noun_counts[b])
		return ca > cb if ca != cb else String(a) < String(b))
	if ranked.size() >= 2 and int(noun_counts[ranked[1]]) >= MIN_ENGINE_NOUNS:
		return "%s and %s both in play, not yet connected" % [String(ranked[0]), String(ranked[1])]
	return ""


static func _largest_set(set_counts: Dictionary) -> String:
	var best := ""
	var best_count := 1
	for set_id in set_counts:
		var count := int(set_counts[set_id])
		if count > best_count or (count == best_count and String(set_id) < best):
			best = String(set_id)
			best_count = count
	return best


static func _set_labels(set_counts: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	for set_id in set_counts:
		labels.append("%s x%d" % [String(set_id), int(set_counts[set_id])])
	labels.sort()
	return labels
