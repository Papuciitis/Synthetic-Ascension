extends RefCounted

## The last gameplay seconds before an incident: a bounded ring of compact
## event records and cheap state samples.
##
## Ages by the gameplay clock each record carries in `t`, so a pause never
## expires the last fight; wall time travels separately in `wall`. The event
## and sample caps apply independently. Whatever a cap discards is counted as
## overwritten (lost context); whatever aged out is counted as expired. The
## buffer takes ownership of pushed dictionaries; `snapshot()` returns a deep
## copy that no later push can change, which is what the worker receives.

const RETAIN_SECONDS := 5.0
const EVENT_CAP := 2048
const SAMPLE_CAP := 32
## Fields summed when identical same-step records coalesce; the rest keep the
## newest value. Only records carrying a `key` may coalesce, and only into the
## record immediately before them, so ordering around damage is preserved.
const SUMMED_FIELDS := ["delta", "requested", "applied", "raw", "adjusted", "amount"]

var retain_seconds := RETAIN_SECONDS
var event_cap := EVENT_CAP
var sample_cap := SAMPLE_CAP

var _events: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _sequence := 0
var _life_id := 0
var _reset_t := 0.0
var _events_pushed := 0
var _samples_pushed := 0
var _events_overwritten := 0
var _samples_overwritten := 0
var _events_expired := 0
var _samples_expired := 0
var _coalesced := 0


func reset(life_id: int = 0, now: float = 0.0) -> void:
	_events = []
	_samples = []
	_sequence = 0
	_life_id = life_id
	_reset_t = now
	_events_pushed = 0
	_samples_pushed = 0
	_events_overwritten = 0
	_samples_overwritten = 0
	_events_expired = 0
	_samples_expired = 0
	_coalesced = 0


func life_id() -> int:
	return _life_id


func event_count() -> int:
	return _events.size()


func sample_count() -> int:
	return _samples.size()


## `record` needs `kind` and `t` (gameplay seconds); the buffer numbers it.
func push_event(record: Dictionary) -> void:
	var t := float(record.get("t", 0.0))
	_expire(t)
	_events_pushed += 1
	if _try_coalesce(record):
		return
	_sequence += 1
	record["seq"] = _sequence
	if _events.size() >= event_cap:
		_events.pop_front()
		_events_overwritten += 1
	_events.append(record)


func push_sample(sample: Dictionary) -> void:
	_expire(float(sample.get("t", 0.0)))
	_samples_pushed += 1
	if _samples.size() >= sample_cap:
		_samples.pop_front()
		_samples_overwritten += 1
	_samples.append(sample)


## The last event of `kind` (any kind when empty) that satisfies `predicate`,
## or an empty dictionary. Returns the live record; callers must not keep it.
func find_last(kind: String, predicate: Callable = Callable()) -> Dictionary:
	for index in range(_events.size() - 1, -1, -1):
		var record: Dictionary = _events[index]
		if not kind.is_empty() and String(record.get("kind", "")) != kind:
			continue
		if predicate.is_valid() and not bool(predicate.call(record)):
			continue
		return record
	return {}


func event_after(seq: int) -> Dictionary:
	for record in _events:
		if int(record.get("seq", 0)) > seq:
			return record
	return {}


func stats() -> Dictionary:
	return {"life_id": _life_id, "events": _events.size(), "samples": _samples.size(),
		"events_pushed": _events_pushed, "events_overwritten": _events_overwritten, "events_expired": _events_expired,
		"samples_pushed": _samples_pushed, "samples_overwritten": _samples_overwritten, "samples_expired": _samples_expired,
		"coalesced": _coalesced, "complete": _events_overwritten == 0 and _samples_overwritten == 0}


## An immutable copy of everything retained at gameplay time `now`.
func snapshot(now: float) -> Dictionary:
	_expire(now)
	var result := stats()
	result["now"] = now
	result["retain_seconds"] = retain_seconds
	var oldest := now
	if not _events.is_empty():
		oldest = minf(oldest, float(_events[0].get("t", now)))
	if not _samples.is_empty():
		oldest = minf(oldest, float(_samples[0].get("t", now)))
	# A young buffer has less than the window to retain: report what exists.
	result["retained_seconds"] = clampf(now - maxf(oldest, _reset_t), 0.0, retain_seconds) if (not _events.is_empty() or not _samples.is_empty()) else 0.0
	var wall_first := INF
	var wall_last := -INF
	for record in _events:
		if record.has("wall"):
			wall_first = minf(wall_first, float(record["wall"]))
			wall_last = maxf(wall_last, float(record["wall"]))
	result["wall_span_seconds"] = (wall_last - wall_first) if wall_first <= wall_last else 0.0
	result["events"] = _events.duplicate(true)
	result["samples"] = _samples.duplicate(true)
	result["trimmed_events"] = 0
	result["trimmed_samples"] = 0
	return result


## Shrinks a serialized incident under `ceiling` bytes by dropping the oldest
## history first (events, then samples, never the last sample), leaving the
## terminal event and the state outside `history` untouched. Reports the trim
## in the context and returns it.
static func fit_to_bytes(context: Dictionary, ceiling: int) -> Dictionary:
	var history: Dictionary = context.get("history", {})
	var events: Array = history.get("events", [])
	var samples: Array = history.get("samples", [])
	# Measured with the report keys in place so the number is the payload's.
	context["serialized_bytes"] = 0
	context["over_ceiling"] = false
	var bytes := _measure(context)
	var report := {"ceiling": ceiling, "bytes_before": bytes, "bytes": bytes, "events": 0, "samples": 0}
	var per_event := 0.0
	var per_sample := 0.0
	var attempts := 0
	while bytes > ceiling and attempts < 24:
		attempts += 1
		var over := bytes - ceiling
		if not events.is_empty():
			if per_event <= 0.0:
				per_event = maxf(1.0, float(_measure(events)) / events.size())
			var drop := mini(events.size(), int(ceil(over / per_event)) + 1)
			events = events.slice(drop)
			history["events"] = events
			report["events"] = int(report["events"]) + drop
		elif samples.size() > 1:
			if per_sample <= 0.0:
				per_sample = maxf(1.0, float(_measure(samples)) / samples.size())
			var drop := mini(samples.size() - 1, int(ceil(over / per_sample)) + 1)
			samples = samples.slice(drop)
			history["samples"] = samples
			report["samples"] = int(report["samples"]) + drop
		else:
			break
		bytes = _measure(context)
	report["bytes"] = bytes
	history["trimmed_events"] = int(history.get("trimmed_events", 0)) + int(report["events"])
	history["trimmed_samples"] = int(history.get("trimmed_samples", 0)) + int(report["samples"])
	context["serialized_bytes"] = bytes
	context["over_ceiling"] = bytes > ceiling
	return report


static func _measure(value: Variant) -> int:
	return JSON.stringify(value).to_utf8_buffer().size()


func _expire(now: float) -> void:
	var cutoff := now - retain_seconds
	while not _events.is_empty() and float(_events[0].get("t", 0.0)) < cutoff:
		_events.pop_front()
		_events_expired += 1
	while not _samples.is_empty() and float(_samples[0].get("t", 0.0)) < cutoff:
		_samples.pop_front()
		_samples_expired += 1


func _try_coalesce(record: Dictionary) -> bool:
	if not record.has("key") or _events.is_empty():
		return false
	var last: Dictionary = _events[-1]
	if String(last.get("kind", "")) != String(record.get("kind", "")) or str(last.get("key", "")) != str(record.get("key", "")):
		return false
	if float(last.get("t", -1.0)) != float(record.get("t", 0.0)):
		return false
	for field in SUMMED_FIELDS:
		if record.has(field):
			last[field] = float(last.get(field, 0.0)) + float(record[field])
	for field in record:
		if field in SUMMED_FIELDS or field == "seq":
			continue
		last[field] = record[field]
	last["n"] = int(last.get("n", 1)) + 1
	_coalesced += 1
	return true
