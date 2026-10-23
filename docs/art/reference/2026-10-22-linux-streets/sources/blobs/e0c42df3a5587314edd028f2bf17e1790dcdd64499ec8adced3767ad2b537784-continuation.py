#!/usr/bin/env python3
"""Validate reused parse/S2 and two root-run manual commands; never starts Godot."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('street_signed_id_r3_protocol', HERE / 'collection_validator_r3.py')
R3 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R3)
NATIVE = R3.R2.ORIGINAL
OLD_QUEUE = Path('/var/tmp/sa-city22/streets/native-routes-r2/queue.json')
COMPLETION = Path('/var/tmp/sa-city22/streets/native-routes-r3/completion.json')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def frozen_protocol():
    bindings = read(HERE / 'source-bindings.json')
    for path, expected in bindings['sources'].items():
        if sha(path) != expected:
            raise ValueError('R3 frozen source/historical receipt changed: ' + path)
    # Root's ordinary reward-before run may temporarily use the old apron.
    # Invoke this ONLY after that queue finishes and restores exact current bytes.
    old_pins = R3.R2.check_pins()
    old = read(OLD_QUEUE)
    if old.get('status') != 'stopped' or [case.get('id') for case in old.get('cases', [])] != ['parse', 's2']:
        raise ValueError('Original R2 failed strict queue was changed or has another completed case set')
    if old.get('source_bindings') != old_pins:
        raise ValueError('Original source-bound R2 evidence changed')
    matrix_spec = importlib.util.spec_from_file_location('street_remaining_matrix_gate', NATIVE.MATRIX_DRIVER)
    matrix = importlib.util.module_from_spec(matrix_spec)
    matrix_spec.loader.exec_module(matrix)
    prerequisite = old['prerequisites']['complete_dressed_continuity_matrix']
    if matrix.validate_aggregate_file(Path(prerequisite['path'])) != prerequisite:
        raise ValueError('Original complete fourteen-theme/five-assertion matrix is stale')
    return bindings, old_pins, old, read(HERE / 'command-plan.json')


def case_evidence(case, pins):
    record = NATIVE.run_record(case['label'])
    raw = read(record['path'])
    outer = read(record['thermal_path'])
    project_state = read(HERE / 'expected-project-state.json')
    if raw.get('git_head') != project_state['git_head'] or raw.get('git_status_porcelain') != '':
        raise ValueError('Actual case is not the exact b298 source with clean tracked state')
    if Path(raw['project_root']).resolve() != NATIVE.PROJECT or outer.get('received_signal') is not None:
        raise ValueError('Actual project/guard cleanup differs')
    if (outer.get('start_temperature_c') != 70 or outer.get('runtime_temperature_stop_c') != 90
            or outer.get('sustained_temperature_stop_c') != 85 or outer.get('sustained_temperature_samples') != 3):
        raise ValueError('Actual functional guard protocol differs')
    args = case['godot_args']
    if raw.get('command', [])[-len(args):] != args:
        raise ValueError('Actual raw command differs from its frozen original/new manual origin')
    for name, expected in pins['sources'].items():
        path = Path(name)
        if path.is_relative_to(NATIVE.PROJECT) and raw.get('source_hashes', {}).get(str(path.relative_to(NATIVE.PROJECT))) != expected:
            raise ValueError('Actual runtime launch source differs: ' + name)
    compact = {key: value for key, value in record.items() if key != 'source_hashes'}
    result = {'id': case['id'], 'label': case['label'], 'origin': case['origin'], 'run': compact,
              'command': case['command'], 'godot_args': args,
              'project_state': {'git_head': raw['git_head'], 'tracked_status': raw['git_status_porcelain'],
                  'source_untracked': raw['source_untracked'], 'qualification': project_state['qualification']}}
    if case['id'] == 'parse':
        if 'StreetNativeSourceParse: checked=3 failures=0' not in (Path(record['path']).parent / 'logs/stdout.log').read_text():
            raise ValueError('Actual reused parser did not check all three scripts')
        return result
    if outer.get('release_marker') != '[Game] ready' or outer.get('duty_released') is not True:
        raise ValueError('Actual native setup duty was not released normally')
    key = case['id']
    expected = {'s2': (2, 16102026, (0, 2)), 's7': (7, 16102028, (-4, 3)), 's6': (6, 16102028, (1, -1))}[key]
    directory = Path(case['out'])
    manifest = NATIVE.validate_route(directory, *expected, 20)
    data = read(directory / 'traversal.json')
    corrected = R3.validate_collection(data)
    strict = R3.R2.validate_collection(data)
    if manifest.get('valid') is not True or corrected.get('valid') is not True:
        raise ValueError('Actual physical or source-corrected collection gate failed: ' + key)
    images = NATIVE.image_records(directory)
    if len(images) != 5:
        raise ValueError('All five unchanged original route images are required')
    result.update({'out': str(directory), 'manifest': manifest, 'images': images,
                   'original_r2_collection_verdict': strict, 'corrected_r3_collection_verdict': corrected})
    return result


def evidence(require_remaining):
    bindings, pins, old, plan = frozen_protocol()
    cases = []
    for case in plan['reused_cases']:
        value = case_evidence(case, pins)
        saved = next(item for item in old['cases'] if item['id'] == case['id'])
        actual_record = NATIVE.run_record(case['label'])
        if saved.get('run') != actual_record or saved.get('command') != case['command']:
            raise ValueError('Original completed raw/command binding changed')
        if case['id'] == 's2':
            if value['manifest'] != saved.get('manifest') or value['images'] != saved.get('images'):
                raise ValueError('Original S2 physical/image proof changed')
            if value['original_r2_collection_verdict'] != saved.get('collection_r2') or [key for key, valid in saved['collection_r2']['checks'].items() if not valid] != ['live_destination']:
                raise ValueError('Original S2 strict failure was not solely the source-proven ID predicate')
        cases.append(value)
    if require_remaining:
        cases += [case_evidence(case, pins) for case in plan['remaining_manual_cases']]
    return {'status': 'checked_corrected_object_id_contract' if require_remaining else 'reused_parse_s2_checked_remaining_native_pending',
        'source_bindings': bindings, 'original_r2_source_bindings': pins,
        'original_r2_queue': {'path': str(OLD_QUEUE), 'sha256': sha(OLD_QUEUE), 'status': 'stopped', 'error': old.get('error')},
        'complete_matrix_prerequisite': old['prerequisites']['complete_dressed_continuity_matrix'], 'cases': cases,
        'remaining_manual_commands': plan['remaining_manual_cases'],
        'limits': 'No engine launched by this validator. Actual completed R2 parser/S2 retain original5e program origin and old stopped verdict. Only S7/S6 use new separately frozen root manual command plan, unchanged b4 GDScript/scene/runtime/physics/route. Corrected signed ObjectID check is a later pure source-based verdict, not a rewritten original queue.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collect', action='store_true', help='Validate all four actual cases and write a fresh completion receipt; otherwise preflight reused cases only.')
    args = parser.parse_args()
    result = evidence(args.collect)
    if args.collect:
        if COMPLETION.exists():
            raise ValueError('Completion receipt already exists; preserve it')
        COMPLETION.parent.mkdir(parents=True, exist_ok=True)
        COMPLETION.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'status': result['status'], 'path': str(COMPLETION), 'cases': [case['id'] for case in result['cases']]}))
    else:
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
