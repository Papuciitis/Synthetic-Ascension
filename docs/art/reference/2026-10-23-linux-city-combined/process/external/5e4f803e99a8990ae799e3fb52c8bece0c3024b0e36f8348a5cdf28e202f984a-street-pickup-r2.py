#!/usr/bin/env python3
"""Root-only R2 route queue; inherits the frozen original guard and all gates."""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import signal
import subprocess
import sys

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
SPEC = importlib.util.spec_from_file_location('street_native_original', BASE / 'street-native-queue.py')
ORIGINAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ORIGINAL)


def validate_collection(data: dict) -> dict:
    """Validate serialized telemetry independently of the helper's booleans."""
    receipt = data.get('collection_observation_r2', {})
    incoming = receipt.get('incoming', {})
    serial = receipt.get('ground_serial', 0)
    events = receipt.get('events', [])
    index = receipt.get('accepted_event_index', -1)
    checks = {
        'original_picked': data.get('pickup', {}).get('picked') is True,
        'original_collected': data.get('collected') is True,
        'receipt_picked': receipt.get('picked') is True,
        'receipt_accepted': receipt.get('accepted') is True,
        'observation_only': receipt.get('observation_only') is True,
        'serial_positive': isinstance(serial, int) and not isinstance(serial, bool) and serial > 0,
        'ordinary_staged_instance': incoming.get('id') == 'ring_crusher' and incoming.get('polarity') == 1 and incoming.get('rarity') == 0 and incoming.get('progress') == 1,
        'one_accepted_event': isinstance(index, int) and not isinstance(index, bool) and 0 <= index < len(events) and sum(event.get('valid_at_event') is True and event.get('destination_still_owned') is True for event in events) == 1,
    }
    event = events[index] if checks['one_accepted_event'] else {}
    payload = event.get('data', {})
    current = event.get('destination_at_acceptance', {})
    checks.update({
        'event_exact_serial': payload.get('ground_serial') == serial and checks['serial_positive'],
        'event_exact_source': payload.get('source') == 'pickup' and payload.get('pickup') == 'drop' and isinstance(payload.get('op'), int) and payload['op'] > 0,
        'live_destination': event.get('destination_still_owned') is True and event.get('valid_at_event') is True and event.get('destination_instance_id', 0) > 0,
        'live_same_item': current.get('id') == incoming.get('id') and current.get('polarity') == incoming.get('polarity'),
    })
    kind = event.get('kind')
    if kind == 'merged':
        before, after = payload.get('dest_before', {}), payload.get('dest_after', {})
        mass = payload.get('mass')
        checks.update({
            'merge_incoming_exact': payload.get('incoming') == incoming,
            'merge_same_item': all(state.get('id') == incoming.get('id') and state.get('polarity') == incoming.get('polarity') for state in (before, after)),
            'merge_no_rank_swap': before.get('rarity', -1) >= incoming.get('rarity', 0),
            'merge_quantitative_progress': after.get('progress', 0) == before.get('progress', 0) + max(1, incoming.get('progress', 0)),
            'merge_positive_finite_mass': isinstance(mass, (float, int)) and not isinstance(mass, bool) and math.isfinite(mass) and mass > 0,
            'merge_progress_still_owned': current.get('progress', 0) >= after.get('progress', 0),
            'merge_consumed_distinct_incoming': event.get('destination_instance_id') != receipt.get('incoming_instance_id'),
        })
    elif kind in ('equipped', 'bagged'):
        checks.update({
            'incoming_identity_retained': receipt.get('incoming_identity_retained') is True and event.get('destination_instance_id') == receipt.get('incoming_instance_id'),
            'retained_progress': current.get('progress', 0) >= incoming.get('progress', 0),
        })
    else:
        checks['supported_collection_event'] = False
    return {'valid': all(checks.values()), 'checks': checks, 'kind': kind, 'ground_serial': serial}


def check_pins() -> dict:
    manifest = ORIGINAL.read_json(HERE / 'source-bindings.json')
    for path, expected in manifest['sources'].items():
        if ORIGINAL.sha(Path(path)) != expected:
            raise RuntimeError('Frozen R2 source changed: ' + path)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--mode', choices=['s2', 's7', 's6', 'routes'], default='s2')
    parser.add_argument('--suffix', required=True)
    parser.add_argument('--continuity-matrix', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9-]+', args.suffix):
        parser.error('suffix must be a fresh lowercase alphanumeric/hyphen label')
    pins = check_pins()
    output = Path('/var/tmp/sa-city22/streets') / ('native-' + args.suffix)
    prefix = 'city22-street-native-' + args.suffix
    parse_args = ['--headless', str(BASE / 'street-native-source-parse.tscn'), '--', str(HERE / 'StreetNativeAcceptanceProbeR2.gd'), str(BASE / 'StreetNativeAcceptanceProbe.gd'), 'res://' + ORIGINAL.PROBE_REL]
    cases = [{'id': 'parse', 'label': prefix + '-parse', 'command': ORIGINAL.command(prefix + '-parse', parse_args, 240, False)}]
    for segment, seed, coord in ((2, 16102026, (0, 2)), (7, 16102028, (-4, 3)), (6, 16102028, (1, -1))):
        if args.mode != 'routes' and args.mode != 's' + str(segment):
            continue
        label, directory = prefix + '-s' + str(segment), output / ('s' + str(segment))
        godot_args = ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', str(HERE / 'StreetNativeAcceptanceProbeR2.tscn'), '--', '--visible', '--runtime-fps=20', '--review=small', '--segment=' + str(segment), '--world-seed=' + str(seed), '--passage-chunk=' + ','.join(map(str, coord)), '--out=' + str(directory)]
        cases.append({'id': 's' + str(segment), 'label': label, 'out': str(directory), 'segment': segment, 'seed': seed, 'coord': coord, 'command': ORIGINAL.command(label, godot_args, 1800)})
    plan = {'created_utc': ORIGINAL.stamp(), 'mode': args.mode, 'project': str(ORIGINAL.PROJECT), 'source_bindings': pins, 'output': str(output), 'commands': cases, 'limits': 'Observation-only collection correction; unchanged original real-physics route, guard70/25% setup released [Game] ready, render20/physics60, ordinary live director/AI/stream and pickup rules, save isolation. R1 remains failed; no timing claim.'}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0
    with (BASE / 'street-native-queue.lock').open('a+') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        if output.exists() or any(list(ORIGINAL.RUNS.glob(case['label'] + '-*')) or (BASE / (case['label'] + '-thermal.json')).exists() for case in cases):
            raise RuntimeError('Existing output/run label; preserve it and choose a fresh suffix')
        prerequisites = {}
        for label in ORIGINAL.FOCUSED:
            record = ORIGINAL.run_record(label)
            for rel in (ORIGINAL.SITE_REL, 'core/systems/world/proc/chunkgen/ChunkGenDistrict.gd'):
                if record['source_hashes'].get(rel) != ORIGINAL.sha(ORIGINAL.PROJECT / rel):
                    raise RuntimeError('Focused source mismatch: ' + rel)
            del record['source_hashes']
            prerequisites[label] = record
        matrix_spec = importlib.util.spec_from_file_location('street_matrix_r2_gate', ORIGINAL.MATRIX_DRIVER)
        matrix = importlib.util.module_from_spec(matrix_spec)
        matrix_spec.loader.exec_module(matrix)
        prerequisites['complete_dressed_continuity_matrix'] = matrix.validate_aggregate_file(args.continuity_matrix.resolve())
        output.mkdir(parents=True)
        (output / '.gdignore').write_text('')
        report_path = output / 'queue.json'
        plan.update({'started_utc': ORIGINAL.stamp(), 'status': 'running', 'prerequisites': prerequisites, 'cases': []})
        ORIGINAL.write_json(report_path, plan)
        signal.signal(signal.SIGINT, ORIGINAL.cancellation)
        signal.signal(signal.SIGTERM, ORIGINAL.cancellation)
        try:
            for case in cases:
                if ORIGINAL.CANCELLED:
                    raise RuntimeError('Queue cancelled between guarded cases')
                check_pins()
                item = {**case, 'started_utc': ORIGINAL.stamp()}
                plan['cases'].append(item)
                ORIGINAL.write_json(report_path, plan)
                print('START', case['label'], flush=True)
                with (BASE / (case['label'] + '-wrapper.log')).open('w') as log:
                    child = subprocess.run(case['command'], stdout=log, stderr=subprocess.STDOUT, check=False)
                item.update({'wrapper_exit': child.returncode, 'ended_utc': ORIGINAL.stamp()})
                check_pins()
                if child.returncode != 0:
                    raise RuntimeError('Actual run failed: ' + case['label'])
                item['run'] = ORIGINAL.run_record(case['label'])
                if 'out' in case:
                    directory = Path(case['out'])
                    item['manifest'] = ORIGINAL.validate_route(directory, case['segment'], case['seed'], tuple(case['coord']), 20)
                    item['collection_r2'] = validate_collection(ORIGINAL.read_json(directory / 'traversal.json'))
                    item['images'] = ORIGINAL.image_records(directory)
                    if not item['manifest']['valid'] or not item['collection_r2']['valid']:
                        raise RuntimeError('Route/collection receipt acceptance failed: ' + case['label'])
                ORIGINAL.write_json(report_path, plan)
            plan['status'] = 'checked'
        except BaseException as error:
            plan['status'], plan['error'] = 'stopped', str(error)
            raise
        finally:
            plan['ended_utc'] = ORIGINAL.stamp()
            ORIGINAL.write_json(report_path, plan)
    print('CHECKED', report_path, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
