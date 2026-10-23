extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/StreetNativeAcceptanceProbe.gd"
## Observation only: ordinary duplicates can feed an existing equipped/bag
## instance, so the incoming Resource need not survive collection. Bind the
## unchanged runtime telemetry to this exact pickup's monotonic ground serial.

var _collection_serial: int = 0
var _collection_incoming: Dictionary = {}
var _collection_events: Array[Dictionary] = []
var _collection_destinations: Array[ItemInstance] = []
var _collection_receipt: Dictionary = {}


func _stage_pickup(desired: Vector2) -> void:
	super._stage_pickup(desired)
	var pickup := _pickup_ref.get_ref() as ItemPickup if _pickup_ref != null else null
	if pickup == null or _pickup_instance == null:
		return
	_collection_serial = pickup.ground_serial
	_collection_incoming = _pickup_instance._balance_state().duplicate(true)
	_collection_receipt = {"ground_serial": _collection_serial,
		"incoming_instance_id": _pickup_instance.get_instance_id(),
		"incoming": _collection_incoming, "observation_only": true}
	RunEvents.item_operation.connect(_observe_collection_operation)


func _observe_collection_operation(kind: StringName, destination: ItemInstance, data: Dictionary) -> void:
	if _collection_serial <= 0 or int(data.get("ground_serial", 0)) != _collection_serial:
		return
	if kind not in [&"equipped", &"bagged", &"merged"]:
		return
	var same_kind := String(data.get("source", "")) == "pickup" and String(data.get("pickup", "")) == "drop"
	var scoped := same_kind and int(data.get("op", 0)) > 0
	var same_item := destination != null and destination.data != null \
		and String(destination.data.id) == String(_collection_incoming.get("id", "")) \
		and int(destination.polarity) == int(_collection_incoming.get("polarity", 0))
	var valid := scoped and same_item
	if kind == &"merged":
		var before: Dictionary = data.get("dest_before", {})
		var after: Dictionary = data.get("dest_after", {})
		var incoming: Dictionary = data.get("incoming", {})
		var mass := float(data.get("mass", 0.0))
		valid = valid and incoming == _collection_incoming \
			and after == destination._balance_state() \
			and String(before.get("id", "")) == String(incoming.get("id", "")) \
			and int(before.get("polarity", 0)) == int(incoming.get("polarity", 0)) \
			and int(before.get("rarity", -1)) >= int(incoming.get("rarity", 0)) \
			and int(after.get("progress", 0)) == int(before.get("progress", 0)) + maxi(1, int(incoming.get("progress", 0))) \
			and is_finite(mass) and mass > 0.0
	else:
		valid = valid and destination == _pickup_instance
	_collection_events.append({"kind": String(kind), "destination_instance_id": destination.get_instance_id() if destination != null else 0,
		"data": data.duplicate(true), "valid_at_event": valid})
	_collection_destinations.append(destination)


func _inventory_has(instance: ItemInstance) -> bool:
	if instance != _pickup_instance or instance == null:
		return super._inventory_has(instance)
	var retained_incoming := super._inventory_has(instance)
	var accepted: int = -1
	for index: int in range(_collection_events.size()):
		var event: Dictionary = _collection_events[index]
		var destination: ItemInstance = _collection_destinations[index]
		var retained := destination != null and super._inventory_has(destination)
		event["destination_still_owned"] = retained
		if retained:
			event["destination_at_acceptance"] = destination._balance_state().duplicate(true)
		if not bool(event.valid_at_event) or not retained:
			continue
		if String(event.kind) == "merged" or (retained_incoming and destination == instance):
			if accepted != -1:
				# One staged instance must not have two successful acquisitions.
				accepted = -2
				break
			accepted = index
	_collection_receipt["events"] = _collection_events
	_collection_receipt["incoming_identity_retained"] = retained_incoming
	_collection_receipt["accepted_event_index"] = accepted
	_collection_receipt["accepted"] = accepted >= 0
	_collection_receipt["picked"] = bool(_pickup_state.get("picked", false))
	_collection_receipt["scope"] = "Exact staged pickup ground_serial/source operation; incoming identity or quantitatively observed ordinary duplicate feed into a still-owned destination. No pickup, inventory, route, AI or physics mutation."
	return accepted >= 0


func _shutdown() -> void:
	if RunEvents.item_operation.is_connected(_observe_collection_operation):
		RunEvents.item_operation.disconnect(_observe_collection_operation)
	if not _report.is_empty():
		_report["collection_observation_r2"] = _collection_receipt
		_report["collection_acceptance_entrypoint_r2"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/street-pickup-r2/StreetNativeAcceptanceProbeR2.tscn"
	await super._shutdown()
