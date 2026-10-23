#!/usr/bin/env python3
"""Source-only prepared adapter; actual build requires all future native/review gates.

Never invokes Godot. Reuses immutable48f88843 packaging/matrix/reward validators;
the only replacement accepts a separately proven ordinary duplicate-feed route.
"""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
CONTROL = HERE.parent
PACKET = Path('/var/tmp/sa-city22/packets/streets')
BUILDER = PACKET / 'build_packet.py'
BUILDER_SHA = '48f888438b6b9ec0807118322f96f31a14513e0df085095ec0f5a83331e84ffd'
R2_DIR = CONTROL / 'street-pickup-r2'
R2_PINS_SHA = '0abd1ed17bd9f9597cb91d20f5c5a1bd3698e0d739aac0a2c3b593f407660559'
ROUTE_QUEUE = Path('/var/tmp/sa-city22/streets/native-routes-r2/queue.json')
REWARD_QUEUE = Path('/var/tmp/sa-city22/streets/native-reward-r1/queue.json')
ROOT_REVIEW = CONTROL / 'street-r2-root-visual-review.json'
HISTORICAL_R1 = Path('/var/tmp/sa-city22/streets/native-s2-r1/queue.json')


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_protocols():
    # Import only after exact frozen-source checks. Original module has no build
    # side effects; both entrypoints are protected by their __main__ guards.
    preparation = json.loads((HERE / 'preparation.json').read_text())
    for name, expected in preparation['frozen_sources'].items():
        if digest(Path(name)) != expected:
            raise ValueError('Reviewed adapter source changed: ' + name)
    if digest(BUILDER) != BUILDER_SHA or digest(HERE / 'original-build_packet-48f88843.py') != BUILDER_SHA:
        raise ValueError('Original reviewed street builder/snapshot changed')
    if digest(R2_DIR / 'source-bindings.json') != R2_PINS_SHA:
        raise ValueError('Reviewed R2 source-binding manifest changed')
    pins = json.loads((R2_DIR / 'source-bindings.json').read_text())
    for name, expected in pins['sources'].items():
        if digest(Path(name)) != expected:
            raise ValueError('Reviewed R2 input changed: ' + name)
    original = load_module(BUILDER, 'street_packet_original_48f88843')
    r2 = load_module(R2_DIR / 'street-pickup-r2.py', 'street_packet_collection_r2')
    return original, r2, pins


def expected_arguments(case: dict, original, r2) -> list[str]:
    key = case['id']
    if key == 'parse':
        return ['--headless', str(CONTROL / 'street-native-source-parse.tscn'), '--',
                str(R2_DIR / 'StreetNativeAcceptanceProbeR2.gd'), str(CONTROL / 'StreetNativeAcceptanceProbe.gd'),
                'res://' + r2.ORIGINAL.PROBE_REL]
    segment, seed, coord = original.ROUTES[key]
    return ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
            str(R2_DIR / 'StreetNativeAcceptanceProbeR2.tscn'), '--', '--visible', '--runtime-fps=20',
            '--review=small', '--segment=' + str(segment), '--world-seed=' + str(seed),
            '--passage-chunk=' + ','.join(map(str, coord)), '--out=' + str(case['out'])]


def r2_case_binding(case: dict, original, r2, pins: dict) -> dict:
    key, label = case['id'], case['label']
    if key not in {'parse', *original.ROUTES} or label != 'city22-street-native-routes-r2-' + key:
        raise ValueError('R2 case ID/label does not belong to the reviewed routes-r2 queue')
    native = r2.ORIGINAL
    checked = native.run_record(label)
    raw_path = Path(checked['path'])
    raw = json.loads(raw_path.read_text())
    outer = json.loads(Path(checked['thermal_path']).read_text())
    if not original.completed_guard(raw, outer) or Path(raw['project_root']).resolve() != original.PROJECT:
        raise ValueError('R2 actual raw/guard/project not clean')
    if (outer.get('start_temperature_c') != 70 or outer.get('runtime_temperature_stop_c') != 90
            or outer.get('sustained_temperature_stop_c') != 85 or outer.get('sustained_temperature_samples') != 3):
        raise ValueError('R2 functional thermal protocol changed')
    if case.get('wrapper_exit') != 0 or case.get('run') != checked:
        raise ValueError('R2 saved run binding differs from actual fresh raw/guard records')
    for name, expected in pins['sources'].items():
        path = Path(name)
        if path.is_relative_to(original.PROJECT):
            relative = str(path.relative_to(original.PROJECT))
            if raw.get('source_hashes', {}).get(relative) != expected:
                raise ValueError('R2 actual launch runtime source mismatch: ' + relative)
    godot_args = expected_arguments(case, original, r2)
    expected_wrapper = native.command(label, godot_args, 240 if key == 'parse' else 1800, key != 'parse')
    if case.get('command') != expected_wrapper or raw.get('command', [])[-len(godot_args):] != godot_args:
        raise ValueError('R2 guard/raw actual command differs from the reviewed source-origin plan')
    result = {'kind': key, 'label': label, 'raw': str(raw_path), 'raw_sha256': checked['sha256'],
              'thermal_path': checked['thermal_path'], 'thermal_sha256': checked['thermal_sha256'],
              'command_origin': str(R2_DIR / 'street-pickup-r2.py'),
              'command_origin_sha256': pins['sources'][str(R2_DIR / 'street-pickup-r2.py')],
              'source_bindings_sha256': R2_PINS_SHA}
    if key == 'parse':
        stdout = (raw_path.parent / 'logs/stdout.log').read_text()
        if 'StreetNativeSourceParse: checked=3 failures=0' not in stdout:
            raise ValueError('R2 actual parser did not check all three required scripts')
        return result
    if outer.get('release_marker') != '[Game] ready' or outer.get('duty_released') is not True:
        raise ValueError('R2 route setup duty did not release normally')
    directory = Path(case['out'])
    if directory != ROUTE_QUEUE.parent / key:
        raise ValueError('R2 actual route output differs from the reviewed queue directory')
    segment, seed, coord = original.ROUTES[key]
    manifest = native.validate_route(directory, segment, seed, coord, 20)
    data_path = directory / 'traversal.json'
    collection = r2.validate_collection(json.loads(data_path.read_text()))
    if manifest.get('valid') is not True or manifest != case.get('manifest'):
        raise ValueError('R2 actual inherited physical route gates do not match the completed queue')
    if collection.get('valid') is not True or collection != case.get('collection_r2'):
        raise ValueError('R2 actual exact-serial collection proof invalid or stale')
    images = native.image_records(directory)
    if not images or images != case.get('images'):
        raise ValueError('R2 actual complete original PNG inventory differs')
    result.update({'manifest': manifest, 'collection_r2': collection, 'images': images, 'out': str(directory),
                   'site_source_sha256': original.CURRENT_SITE_SHA, 'runtime_render_fps_cap': 20,
                   'physics_ticks_per_second': 60})
    return result


def r2_route_evidence(continuity: dict, original, r2, pins: dict) -> dict:
    before = ROUTE_QUEUE.read_bytes()
    report = json.loads(before)
    if report.get('status') != 'checked' or report.get('mode') != 'routes' or Path(report.get('output', '')).resolve() != ROUTE_QUEUE.parent or Path(report.get('project', '')).resolve() != original.PROJECT:
        raise ValueError('Future R2 route queue has not completed all requested physical routes')
    if report.get('source_bindings') != pins or not report.get('started_utc') or not report.get('ended_utc'):
        raise ValueError('R2 source/time provenance does not match its separate frozen command origin')
    prerequisite = report.get('prerequisites', {}).get('complete_dressed_continuity_matrix', {})
    matrix = original.protocol_module(original.MATRIX_DRIVER, 'street_packet_r2_matrix')
    checked_matrix = matrix.validate_aggregate_file(Path(prerequisite['path']))
    if not continuity.get('accepted') or checked_matrix != prerequisite or checked_matrix.get('sha256') != continuity['aggregate']['sha256']:
        raise ValueError('R2 routes lack the same complete fourteen-theme/original-five matrix proof')
    cases = report.get('cases', [])
    if [case.get('id') for case in cases] != ['parse', 's2', 's7', 's6']:
        raise ValueError('R2 exact parser/S2/S7/S6 ordered case set incomplete or duplicated')
    checked = {case['id']: r2_case_binding(case, original, r2, pins) for case in cases}
    if ROUTE_QUEUE.read_bytes() != before:
        raise ValueError('R2 queue receipt changed during validation')
    return {'path': str(ROUTE_QUEUE), 'sha256': original.sha(before), 'accepted': True,
            'cases': list(checked.values()), 'source_origin': 'Separate frozen R2 orchestrator and helper; not the original reward queue program',
            'route_gates': {key: {'queue': str(ROUTE_QUEUE), 'case': checked[key]} for key in original.ROUTES}}


def review_evidence(routes: dict, reward: dict, original, r2) -> dict:
    review_bytes = ROOT_REVIEW.read_bytes()
    review = json.loads(review_bytes)
    if review.get('status') != 'ROOT_VISUAL_ACCEPTED_SELECTED_STREET_ROUTES_AND_REWARD_PAVING' or review.get('broader_ground_topology') != 'OPEN':
        raise ValueError('Actual explicit root image acceptance is absent, or broader topology was overclaimed')
    actual = {key: value['case'] for key, value in routes['route_gates'].items()}
    for key in ('before', 'after'):
        item = reward['reward_pair'][key]
        # The unchanged reward validator returns no image list/thermal fields.
        checked = r2.ORIGINAL.run_record(item['label'])
        actual['reward-' + key] = {**item, 'images': r2.ORIGINAL.image_records(Path(item['out'])),
                                  'thermal_path': checked['thermal_path'], 'thermal_sha256': checked['thermal_sha256']}
    rows = review.get('cases', {})
    if set(rows) != set(actual):
        raise ValueError('Root review must bind exactly three R2 routes and both actual reward sides')
    for key, case in actual.items():
        row = rows[key]
        if not isinstance(row, dict):
            raise ValueError('Root original image review case is still pending: ' + key)
        required = {'label': case['label'], 'raw_path': case['raw'], 'raw_sha256': case['raw_sha256'],
                    'thermal_path': case['thermal_path'], 'thermal_sha256': case['thermal_sha256'],
                    'manifest_path': case['manifest']['path'], 'manifest_sha256': case['manifest']['sha256'],
                    'images': case['images'], 'status': 'ACCEPTED_SELECTED_VIEW'}
        if any(row.get(field) != value for field, value in required.items()):
            raise ValueError('Root original-image/raw/source-manifest/guard review binding stale: ' + key)
    if ROOT_REVIEW.read_bytes() != review_bytes:
        raise ValueError('Root review changed during validation')
    return {'path': str(ROOT_REVIEW), 'sha256': original.sha(review_bytes), 'status': review['status'],
            'cases': sorted(rows), 'broader_ground_topology': 'OPEN'}


def validated_evidence(original, r2, pins):
    # Called before any packet write. Missing future receipts/review fail closed.
    continuity = original.continuity_evidence()
    reward = original.street_native_evidence(continuity, reports=[REWARD_QUEUE])
    if not continuity.get('accepted') or not reward.get('reward_pair_accepted') or reward.get('errors') or not all(row.get('accepted') for row in reward['queues']):
        raise ValueError('Complete matrix and unchanged original reward queue/geometry/source gates are required')
    routes = r2_route_evidence(continuity, original, r2, pins)
    review = review_evidence(routes, reward, original, r2)
    combined = copy.deepcopy(reward)
    combined['route_gates'] = routes['route_gates']
    combined['queues'].append({key: value for key, value in routes.items() if key != 'route_gates'})
    combined['root_visual_review'] = review
    combined['command_program_origins'] = {
        str(REWARD_QUEUE): {'path': str(original.NATIVE_DRIVER), 'sha256': original.PROTOCOL_PINS['street-native-queue.py'],
            'role': 'Original unchanged reward-only orchestrator; both apron source substitutions and all source/geometry gates preserved'},
        str(ROUTE_QUEUE): {'path': str(R2_DIR / 'street-pickup-r2.py'), 'sha256': pins['sources'][str(R2_DIR / 'street-pickup-r2.py')],
            'role': 'Separate R2 route-only orchestrator and exact-serial telemetry helper; no retroactive attribution to original program'},
    }
    combined['r2_collection_protocol'] = {'path': str(R2_DIR / 'source-bindings.json'), 'sha256': R2_PINS_SHA,
        'limits': 'Exact serial scoped retained identity or quantitative ordinary duplicate feed. Original failed R1 remains failed; no retrospective destination proof or broad city/topology/performance claim.'}
    return continuity, combined


def main() -> None:
    original, r2, pins = load_protocols()
    continuity, native = validated_evidence(original, r2, pins)
    if '--check-only' in sys.argv:
        if sys.argv[1:] != ['--check-only']:
            raise ValueError('--check-only must be used alone')
        print(json.dumps({'status': 'all_actual_street_packet_gates_checked', 'routes': sorted(native['route_gates']),
                          'reward_pair_accepted': native['reward_pair_accepted'], 'root_visual_review': native['root_visual_review'],
                          'packet_written': False}))
        return
    def selected_native(current, **_unused):
        if current != continuity:
            raise ValueError('Continuity changed during build')
        return native

    original.street_native_evidence = selected_native
    original_include = original.include_street_protocol
    original_output = original.output

    def include_protocol(current, selected):
        original_include(current, selected)
        paths = [Path(path) for path in pins['sources']] + [R2_DIR / 'source-bindings.json', ROOT_REVIEW,
            HERE / 'original-build_packet-48f88843.py', Path(__file__).resolve(), HERE / 'preparation.json',
            HERE / 'README.md', CONTROL / 'street-pickup-r2-independent-review.json',
            CONTROL / 'street-s2-r1-root-visual-review.json', HISTORICAL_R1]
        for path in dict.fromkeys(paths):
            if path.is_file():
                original.snapshot(path.read_bytes(), path.name, path,
                    'R2 separate exact frozen source/protocol/review or explicitly failed original R1; not a retrospective replacement for earlier unrecorded launch bytes')
        original.output('street-r2-protocol-validation.json', {'native': selected,
            'original_builder': {'path': str(BUILDER), 'sha256': BUILDER_SHA},
            'r2_source_bindings': pins, 'root_visual_review': selected['root_visual_review'],
            'historical_r1': {'queue': str(HISTORICAL_R1), 'accepted': False, 'reason': 'Actual exit1/one identity-only collection diagnostic retained unchanged'},
            'external_source_scope': 'New R2 queue checks these frozen helper/runtime pins before and after every actual case; project source hashes are also matched to actual raw launch maps. External bytes are not invented as raw-map entries.'})

    def output(relative, value):
        if str(relative) == 'evidence-index.json':
            value = copy.deepcopy(value)
            value['street_protocol_r2'] = 'street-r2-protocol-validation.json'
            value['visual_acceptance'] = native['root_visual_review']
            accepted_labels = {row['case']['label'] for row in native['route_gates'].values()}
            accepted_labels.update(native['reward_pair'][key]['label'] for key in ('before', 'after'))
            for row in value.get('native_outputs', []):
                if row['label'] in accepted_labels:
                    row['visual_review'] = {'status': 'ROOT_VISUAL_ACCEPTED_SELECTED_VIEW', **native['root_visual_review']}
        return original_output(relative, value)

    original.include_street_protocol = include_protocol
    original.output = output
    # Existing packaging, exact-source snapshots, failure classifications,
    # historical missing-byte qualifications, compression and manifest unchanged.
    original.main()


if __name__ == '__main__':
    main()
