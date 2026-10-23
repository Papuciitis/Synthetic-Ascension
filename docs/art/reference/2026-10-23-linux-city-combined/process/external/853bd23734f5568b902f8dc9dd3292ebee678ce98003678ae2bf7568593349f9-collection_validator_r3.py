"""Narrow source-corrected ObjectID observation; original R2 stays immutable."""
from __future__ import annotations

import importlib.util
from pathlib import Path

R2_PATH = Path(__file__).resolve().parent.parent / 'street-pickup-r2/street-pickup-r2.py'
SPEC = importlib.util.spec_from_file_location('street_collection_original_r2', R2_PATH)
R2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R2)


def valid_object_id(value) -> bool:
    # Exact ed1daf0bf ObjectID: uint64 high bit marks RefCounted, Variant uses
    # signed int64 conversion, and zero alone is the invalid identifier.
    return type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0


def validate_collection(data: dict) -> dict:
    receipt = data.get('collection_observation_r2', {})
    events = receipt.get('events', [])
    index = receipt.get('accepted_event_index', -1)
    event = events[index] if type(index) is int and 0 <= index < len(events) else {}
    destination_ok = valid_object_id(event.get('destination_instance_id'))
    incoming_ok = valid_object_id(receipt.get('incoming_instance_id'))
    if not destination_ok or not incoming_ok:
        return {'valid': False, 'checks': {'destination_signed_int64_nonzero': destination_ok,
            'incoming_signed_int64_nonzero': incoming_ok}, 'kind': event.get('kind'), 'ground_serial': receipt.get('ground_serial', 0)}
    result = R2.validate_collection(data)
    # Only the erroneous positivity requirement is replaced. Every other R2
    # serial/source/identity/feed/ownership/quantitative gate remains unchanged.
    result['checks']['live_destination'] = event.get('destination_still_owned') is True and event.get('valid_at_event') is True and destination_ok
    result['checks']['incoming_signed_int64_nonzero'] = incoming_ok
    result['valid'] = all(result['checks'].values())
    return result
