from copy import deepcopy
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('street_signed_id_r3', HERE / 'collection_validator_r3.py')
R3 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R3)
actual_path = Path('/var/tmp/sa-city22/streets/native-routes-r2/s2/traversal.json')
actual = json.loads(actual_path.read_text())
old = R3.R2.validate_collection(actual)
assert old['valid'] is False and [key for key, valid in old['checks'].items() if not valid] == ['live_destination']
assert actual['collection_observation_r2']['incoming_instance_id'] == -9223370948063769565
assert R3.validate_collection(actual)['valid'] is True
checks = 2
for field in ('incoming_instance_id', 'destination_instance_id'):
    for value in (0, True, False, 1.5, '123', None, 1 << 63, -(1 << 63) - 1):
        data = deepcopy(actual)
        target = data['collection_observation_r2'] if field == 'incoming_instance_id' else data['collection_observation_r2']['events'][0]
        target[field] = value
        assert R3.validate_collection(data)['valid'] is False, (field, value)
        checks += 1
data = deepcopy(actual); data['collection_observation_r2']['events'][0]['destination_instance_id'] += 1
assert R3.validate_collection(data)['valid'] is False; checks += 1
for value in (1, (1 << 63) - 1, -(1 << 63)):
    data = deepcopy(actual); data['collection_observation_r2']['incoming_instance_id'] = value; data['collection_observation_r2']['events'][0]['destination_instance_id'] = value
    assert R3.validate_collection(data)['valid'] is True; checks += 1
for field, value in (('ground_serial', 999999), ('source', 'player')):
    data = deepcopy(actual); data['collection_observation_r2']['events'][0]['data'][field] = value
    assert R3.validate_collection(data)['valid'] is False; checks += 1
data = deepcopy(actual); data['pickup']['picked'] = False
assert R3.validate_collection(data)['valid'] is False; checks += 1
data = deepcopy(actual); data['collection_observation_r2']['events'][0]['destination_still_owned'] = False
assert R3.validate_collection(data)['valid'] is False; checks += 1
print(json.dumps({'status': 'passed', 'checks': checks, 'actual_negative_id_regression': str(actual_path),
    'old_strict_verdict': old, 'corrected_verdict': R3.validate_collection(actual), 'engine_run': False,
    'scope': 'Pure signed-ID schema correction and actual unchanged S2 receipt; original stopped R2 queue remains stopped.'}))
