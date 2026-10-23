#!/usr/bin/env python3
"""Small tamper-negative tests of the actual R2 JSON acceptance gate, no engine."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('street_pickup_r2', Path(__file__).with_name('street-pickup-r2.py'))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

incoming = {'id': 'ring_crusher', 'polarity': 1, 'rarity': 0, 'progress': 1, 'pct': 0.25, 'meter': 0.0, 'manifestation': '', 'locked': False, 'flat': {}}
before = {**incoming, 'progress': 1, 'pct': 0.12}
after = {**incoming, 'progress': 2, 'meter': 0.31}
event = {'kind': 'merged', 'destination_instance_id': 300, 'valid_at_event': True, 'destination_still_owned': True, 'destination_at_acceptance': after,
         'data': {'ground_serial': 73, 'source': 'pickup', 'pickup': 'drop', 'op': 8, 'incoming': incoming, 'dest_before': before, 'dest_after': after, 'mass': 0.31}}
valid = {'pickup': {'picked': True}, 'collected': True, 'collection_observation_r2': {'ground_serial': 73, 'incoming_instance_id': 200, 'incoming': incoming, 'events': [event], 'accepted_event_index': 0, 'picked': True, 'accepted': True, 'observation_only': True, 'incoming_identity_retained': False}}
valid = json.loads(json.dumps(valid))  # Actual manifests have independent JSON values.

checks = []


def check(name, value, expected):
    actual = MODULE.validate_collection(value)['valid']
    assert actual is expected, (name, MODULE.validate_collection(value))
    checks.append(name)


def negative(name, mutate):
    candidate = deepcopy(valid)
    mutate(candidate, candidate['collection_observation_r2'], candidate['collection_observation_r2']['events'][0])
    check(name, candidate, False)


check('scoped ordinary merge with consumed incoming and owned destination', valid, True)
negative('same-id unrelated nearby pickup cannot qualify', lambda d, r, e: e['data'].update(ground_serial=74))
negative('player drop operation cannot qualify', lambda d, r, e: e['data'].update(source='player'))
negative('reward operation cannot qualify', lambda d, r, e: e['data'].update(source='reward'))
negative('wrong pickup kind', lambda d, r, e: e['data'].update(pickup='ground'))
negative('missing operation scope', lambda d, r, e: e['data'].update(op=0))
negative('incoming snapshot changed', lambda d, r, e: e['data']['incoming'].update(pct=0.34))
negative('same-id opposite polarity', lambda d, r, e: e['data']['dest_before'].update(polarity=-1))
negative('no quantitative progress change', lambda d, r, e: e['data']['dest_after'].update(progress=1))
negative('no consumed merge mass', lambda d, r, e: e['data'].update(mass=0.0))
negative('nonfinite merge mass', lambda d, r, e: e['data'].update(mass=float('nan')))
negative('destination no longer owned', lambda d, r, e: e.update(destination_still_owned=False))
negative('destination progression no longer present', lambda d, r, e: e['destination_at_acceptance'].update(progress=1))
negative('unpicked despawn cannot qualify', lambda d, r, e: d['pickup'].update(picked=False))
negative('original route collection failure remains failure', lambda d, r, e: d.update(collected=False))
negative('receipt cannot override unpicked', lambda d, r, e: r.update(picked=False))
negative('duplicate successful operations rejected', lambda d, r, e: r['events'].append(deepcopy(e)))
negative('boolean serial rejected', lambda d, r, e: r.update(ground_serial=True))
negative('zero serial rejected', lambda d, r, e: r.update(ground_serial=0))
negative('consumed incoming cannot also be merge destination', lambda d, r, e: e.update(destination_instance_id=200))
negative('failed helper event does not qualify', lambda d, r, e: e.update(valid_at_event=False))
negative('unsupported event does not qualify', lambda d, r, e: e.update(kind='unequipped'))

identity = deepcopy(valid)
receipt = identity['collection_observation_r2']
receipt.update(incoming_identity_retained=True)
receipt['events'][0].update(kind='equipped', destination_instance_id=200, destination_at_acceptance=deepcopy(incoming))
check('same incoming Resource equipped through ordinary scoped pickup', identity, True)
identity['collection_observation_r2']['events'][0]['kind'] = 'bagged'
check('same incoming Resource bagged through ordinary scoped pickup', identity, True)
identity['collection_observation_r2']['events'][0]['destination_instance_id'] = 301
check('different Resource cannot pretend to be retained incoming', identity, False)

historical = MODULE.ORIGINAL.read_json(Path('/var/tmp/sa-city22/streets/native-s2-r1/s2/traversal.json'))
check('actual failed R1 lacking proof stays failed', historical, False)
assert historical['pickup']['picked'] is True and historical['collected'] is False and historical['failures'] == 1

print(f'R2 collection receipt offline checks={len(checks)} failures=0; no Godot execution or native pass implied')
