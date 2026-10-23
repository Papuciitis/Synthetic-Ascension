#!/usr/bin/env python3
"""Read-only comparison correction and ten-case continuation; dry run by default."""
from pathlib import Path
import argparse
import fcntl
import hashlib
import importlib.util
import json
import math
import re
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
BASE = HERE.parent
PROTOCOL = HERE / 'protocol.json'
PROTOCOL_SHA = '1939eb80399153253515ab1597f23fe9174cf86e2b0f59599c9061fcea819c32'
R3_PATH = BASE / 'stage4-cost-r3/stage4-static-cost-queue.py'
R3_SHA = 'a8ea1573fea86c4f6a01bd202a5821e64238c1b8d1facc479ae46df0dc424af2'


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


require(sha(R3_PATH) == R3_SHA, 'Frozen R3 validator changed')
spec = importlib.util.spec_from_file_location('unchanged_stage4_r3', R3_PATH)
r3 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r3)


def point(value):
    require(isinstance(value, list) and len(value) == 2
            and all(type(v) in (int, float) and math.isfinite(v) for v in value), 'Invalid parking point')
    return value


def parking_basis(report):
    data = report['data']
    require(report.get('valid') is True and data.get('helper_sha256') == r3.HELPER_SHA,
            'Original per-run R3 validator/helper is mandatory')
    require('/root/Game/Player' in data.get('hidden_non_scenery', [])
            and data.get('physics_nodes_disabled_after_settle', 0) > 0, 'Player hiding/freeze observation absent')
    first, last = data['fixture_initial'], data['fixture_final']
    require(first['exterior_state'] == last['exterior_state']
            and bool(first.get('exterior_state_sha256'))
            and first['exterior_state_sha256'] == last['exterior_state_sha256'], 'Within-run state/SHA changed')
    points = []
    for fixture in (first, last):
        require(r3.exterior_state_valid(fixture), 'Original opaque/outside/clearance gates failed')
        parking = fixture['player_parking']
        selected, actual = point(parking['selected_world']), point(parking['after_settle_world'])
        cell = r3.parse_vector(parking['selected_cell'])
        require(all(value.is_integer() for value in cell)
                and selected == [cell[0]*64+32, cell[1]*64+32]
                and [math.floor(value/64) for value in actual] == list(cell), 'Parking left its exact selected 64px cell')
        require(math.dist(selected, actual) <= 1.0
                and actual == fixture['exterior_state']['player_world']
                and parking.get('clearance_px') == 64.0
                and parking.get('static_capsule_checked') is True
                and parking.get('outside_and_opaque_before_freeze') is True
                and parking.get('ordinary_physics_frames_after_stream_settle', 0) >= 4,
                'Hidden parking exceeds existing 1px bound or loses observed outside proof')
        points.append((selected, actual, cell))
    require(points[0] == points[1], 'Parking moved within the sampled run')
    return points[0]


def compare_pair(before, after):
    """Ignore only a bounded hidden actor's coordinates for cross-run scenery comparison."""
    strict = r3.compare_pair(before, after)
    left, right = before['data'], after['data']
    ls, lp, lc = parking_basis(before)
    rs, rp, rc = parking_basis(after)
    a = {key: value for key, value in left['fixture_initial']['exterior_state'].items() if key != 'player_world'}
    b = {key: value for key, value in right['fixture_initial']['exterior_state'].items() if key != 'player_world'}
    omitted = {'exterior_state', 'exterior_state_sha256', 'parking_after_settle_world'}
    checks = {key: value for key, value in strict['checks'].items() if key not in omitted}
    checks.update(exterior_except_hidden_player_exact=a == b, selected_parking_exact=ls == rs and lc == rc,
                  each_run_parking_stable_hidden_and_bounded=True, cross_run_hidden_drift_at_most_1px=math.dist(lp, rp) <= 1.0)
    comparable = all(checks.values())
    observations = []
    if comparable:
        for index, (old, new) in enumerate(zip(left['rounds'], right['rounds'])):
            observations.append({'round': index, **{metric: {'baseline': old['summary'][metric],
                'candidate': new['summary'][metric], 'p50_delta_ms': new['summary'][metric]['p50']-old['summary'][metric]['p50']}
                for metric in ('gpu_ms', 'viewport_cpu_ms', 'setup_cpu_ms', 'process_ms')}})
    return {'checks': checks, 'comparable_geometry_and_protocol': comparable,
        'round_observations': observations, 'strict_original_comparison': strict,
        'normalization_applied': not all(strict['checks'].get(key) for key in omitted),
        'cross_run_hidden_player_drift_px': math.dist(lp, rp),
        'python_normalized_exterior_sha256': hashlib.sha256(json.dumps(a, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest(),
        'raw_godot_exterior_sha256': {'baseline': left['fixture_initial']['exterior_state_sha256'], 'candidate': right['fixture_initial']['exterior_state_sha256']},
        'baseline_material_inventory': strict['baseline_material_inventory'], 'candidate_material_inventory': strict['candidate_material_inventory'],
        'limits': strict['limits'] + ' Cross-run comparison excludes only the hidden, disabled, stable player coordinates within the existing 1px parking bound. Original files, within-run Godot SHA and failed strict verdict are unchanged; normalized Python SHA is separate.'}


def positive_samples(data):
    require(len(data.get('rounds', [])) == 3, 'Expected three original rounds')
    for index, item in enumerate(data['rounds']):
        rows = item.get('samples', [])
        require(item.get('round') == index and len(rows) == item.get('requested_frames') == item.get('gpu_positive_samples') == 120, 'Incomplete timer samples')
        for metric in ('gpu_ms', 'viewport_cpu_ms', 'setup_cpu_ms', 'process_ms'):
            values = [row.get(metric) for row in rows]
            require(all(type(v) in (int, float) and math.isfinite(v) for v in values)
                    and (metric != 'gpu_ms' or min(values) > 0), 'Nonfinite/nonpositive timing observation')
            values.sort()
            require(item['summary'][metric] == {'count':120, 'min':values[0], 'p50':values[59], 'p95':values[math.ceil(119*.95)], 'max':values[-1]}, 'Recorded timer summary differs')


def input_bindings(protocol):
    actual = r3.external_bindings()
    require(actual == protocol['original_fourteen_bindings'] and len(actual) == 14, 'Original fourteen R3 inputs changed')
    return actual, {str(p): {'sha256':sha(p), 'bytes':p.stat().st_size} for p in (Path(__file__).resolve(), PROTOCOL)}


def validated_case(case, source_maps, expected_head, saved=None):
    record = r3.run_record(case['label'])
    raw, outer = record['data'], record['thermal']
    require(outer.get('received_signal') is None, 'Case received a signal')
    if saved is not None:
        for key in ('path', 'sha256', 'thermal_path', 'thermal_sha256'):
            require(record[key] == saved['run'][key], 'Original raw/guard receipt changed: ' + case['id'])
    arguments = case['command'][case['command'].index('--')+1:]
    require(raw.get('command', [])[-len(arguments):] == arguments and raw.get('git_head') == expected_head
            and not raw.get('git_status_porcelain') and Path(raw['project_root']) == Path(case['project'])
            and all(raw.get('source_hashes', {}).get(key) == digest for key, digest in source_maps[case['side']].items()),
            'Actual case command/project/source binding differs')
    report = None
    if case['native']:
        require(outer.get('duty_released') is True and outer.get('release_marker') == 'TOOL_COST_READY', 'Sampling setup duty was not released')
        report = r3.validate_report(Path(case['json']), r3.CONTEXTS[case['key']], tuple(case['size']), False, False)
        require(report['valid'], 'Original R3 native report rejected')
        positive_samples(report['data'])
        parking_basis(report)
        if saved is not None:
            require(report == saved['report'], 'Original report bytes/validation changed')
    else:
        require(outer.get('duty_released') is False and outer.get('release_marker') is None
                and 'Stage4CostSourceParse: checked=2 failures=0' in (Path(record['path']).parent/'logs/stdout.log').read_text(), 'Reused parser was incomplete')
    return {'path':record['path'], 'sha256':record['sha256'], 'thermal_path':record['thermal_path'], 'thermal_sha256':record['thermal_sha256']}, report, raw['source_hashes']


def prior_evidence(protocol):
    require(sha(protocol['origin_queue']) == protocol['origin_queue_sha256'], 'Original failed R3 queue changed')
    origin = load(protocol['origin_queue'])
    require(origin.get('ended_utc') and origin.get('status') == protocol['origin_expected_status']
            and origin.get('error') == protocol['origin_expected_error'] and len(origin['planned_cases']) == 18
            and [case['id'] for case in origin['cases']] == protocol['reused_case_ids'] and len(origin['cases']) == 8,
            'Original failed queue is not the exact 2-parser/6-native prefix')
    require(origin['smoke_only'] is False and origin['reduced_motion'] is False
            and origin['timing_window_attestation'] is True, 'Original measurement scope differs')
    input_bindings(protocol)
    for path, entry in protocol['original_fourteen_bindings'].items():
        snapshot = Path(protocol['origin_queue']).parent/'external-sources'/(entry['sha256']+'-'+Path(path).name)
        require(sha(snapshot) == entry['sha256'], 'Original advertised fourteen-input snapshot changed')
    reused, reports, sources = [], {}, {}
    for planned, saved in zip(origin['planned_cases'], origin['cases']):
        require(all(saved.get(key) == value for key, value in planned.items()) and saved.get('wrapper_exit') == 0
                and saved.get('ended_utc'), 'Original case differs from its frozen plan')
        receipt, report, source = validated_case(planned, origin['source_maps_initial'], protocol[planned['side']], saved)
        reused.append({'id':planned['id'], 'label':planned['label'], 'origin_queue':protocol['origin_queue'], 'run':receipt, 'json':planned.get('json'), 'report_sha256':report['sha256'] if report else None})
        if report:
            reports.setdefault(planned['pair'], {})[planned['side']] = report
            sources.setdefault(planned['pair'], {})[planned['side']] = source
    pairs = comparisons(reports, sources)
    require(set(pairs) == {'s2-960', 's6-960', 's7-960'} and all(row['comparable_geometry_and_protocol'] for row in pairs.values()), 'Prior native pairs fail the bounded corrected comparison')
    for key in pairs:
        strict = dict(pairs[key]['strict_original_comparison'])
        strict['launched_changed_source_keys'] = pairs[key]['launched_changed_source_keys']
        strict['launched_source_scope_valid'] = pairs[key]['launched_source_scope_valid']
        require(strict == origin['pairs'][key], 'Original strict comparison was not reproduced')
    require({key for key, value in origin['pairs']['s7-960']['checks'].items() if not value}
            == {'exterior_state', 'exterior_state_sha256', 'parking_after_settle_world'}, 'Original S7 mismatch is broader than hidden parking')
    return origin, reused, reports, sources, pairs


def comparisons(reports, sources):
    result = {}
    for pair, sides in reports.items():
        if set(sides) != {'baseline', 'candidate'}:
            continue
        comparison = compare_pair(sides['baseline'], sides['candidate'])
        delta = r3.changed_keys(sources[pair]['baseline'], sources[pair]['candidate'])
        comparison.update(launched_changed_source_keys=delta, launched_source_scope_valid=all(r3.allowed(row['path']) for row in delta))
        require(comparison['comparable_geometry_and_protocol'] and comparison['launched_source_scope_valid'], 'Pair failed corrected geometry/source comparison: ' + pair)
        result[pair] = comparison
    return result


def remaining_plan(origin, protocol, suffix):
    output = Path('/var/tmp/sa-city22/stage4')/('static-'+suffix)
    cases = []
    for original in origin['planned_cases'][8:]:
        require(original['native'] is True, 'Resume may launch only remaining native cases')
        case = dict(original)
        case['label'] = 'city22-stage4-cost-'+suffix+'-'+case['id']
        case['json'] = str(output/(case['id']+'.json'))
        arguments = original['command'][original['command'].index('--')+1:]
        arguments = [('--json='+case['json'] if value == '--json='+original['json'] else value) for value in arguments]
        case['command'] = r3.guard_command(case['label'], Path(case['project']), arguments, True)
        cases.append(case)
    require(len(cases) == 10 and [case['id'] for case in cases] == protocol['remaining_case_ids'], 'Resume scope changed')
    return output, cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--timing-window-open', action='store_true')
    parser.add_argument('--suffix', default='ecb-resume-r4')
    args = parser.parse_args()
    require(re.fullmatch('[a-z0-9-]+', args.suffix), 'Use a fresh lowercase alphanumeric/hyphen suffix')
    require(not args.execute or args.timing_window_open, 'Root must attest a fresh OPEN quiet timing window/Claude ACK')
    require(sha(PROTOCOL) == PROTOCOL_SHA, 'Frozen resume protocol changed')
    protocol = load(PROTOCOL)
    origin, reused, reports, sources, pairs = prior_evidence(protocol)
    original_bindings, resume_bindings = input_bindings(protocol)
    output, cases = remaining_plan(origin, protocol, args.suffix)
    plan = {'protocol_revision':protocol['revision'], 'output':str(output), 'origin_queue':protocol['origin_queue'],
        'origin_queue_sha256':protocol['origin_queue_sha256'], 'original_failed_queue_unchanged':True,
        'original_fourteen_bindings':original_bindings, 'resume_bindings':resume_bindings, 'reused_cases':reused,
        'planned_remaining_cases':cases, 'cases':[], 'pairs':pairs, 'status':'prepared',
        'timing_window_attestation':args.timing_window_open, 'scope':protocol['mixed_origin_limit']}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0
    lock = (BASE/'stage4-static-cost-queue.lock').open('a+')
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    for side, project in (('baseline', r3.BASELINE), ('candidate', r3.CANDIDATE)):
        r3.project_state(project, protocol[side])
        require(r3.source_keys(project) == origin['source_maps_initial'][side], 'Current project source changed since original queue')
    require(not output.exists() and all(not list(r3.RUNS.glob(case['label']+'-*'))
            and not (BASE/(case['label']+'-thermal.json')).exists() for case in cases), 'Resume labels/output already used')
    output.mkdir(parents=True)
    (output/'.gdignore').write_text('')
    snapshots = output/'external-sources'
    snapshots.mkdir()
    for path, entry in {**original_bindings, **resume_bindings}.items():
        (snapshots/(entry['sha256']+'-'+Path(path).name)).write_bytes(Path(path).read_bytes())
    cancelled = []
    def cancel(signum, _frame):
        cancelled.append(signum)
        print('Cancellation requested; wait for the owned guarded case to finish cleanup.', flush=True)
    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    plan.update(status='running', started_utc=r3.stamp())
    queue_path = output/'queue.json'
    r3.json_write(queue_path, plan)
    try:
        for case in cases:
            require(not cancelled, 'Resume cancelled between owned guarded cases')
            require(input_bindings(protocol) == (original_bindings, resume_bindings), 'Original/resume program bytes changed')
            project = Path(case['project'])
            r3.project_state(project, protocol[case['side']])
            require(r3.source_keys(project) == origin['source_maps_initial'][case['side']], 'Project source changed before native case')
            item = {**case, 'started_utc':r3.stamp(), 'mask_imports_before':r3.finite_mask_imports(project)}
            plan['cases'].append(item)
            r3.json_write(queue_path, plan)
            child = subprocess.Popen(case['command'], cwd=r3.ROOT)
            while child.poll() is None:
                time.sleep(.25)
            item.update(wrapper_exit=child.returncode, ended_utc=r3.stamp(), mask_imports_after=r3.finite_mask_imports(project))
            r3.json_write(queue_path, plan)
            require(child.returncode == 0, 'Native guard failed; retain original attempt and stop')
            receipt, report, source = validated_case(case, origin['source_maps_initial'], protocol[case['side']])
            item.update(run=receipt, report=report, origin='new resume driver; original fourteen R3 helper/program inputs')
            reports.setdefault(case['pair'], {})[case['side']] = report
            sources.setdefault(case['pair'], {})[case['side']] = source
            plan['pairs'] = comparisons(reports, sources)
            require(r3.source_keys(project) == origin['source_maps_initial'][case['side']]
                    and input_bindings(protocol) == (original_bindings, resume_bindings), 'Source/program changed during native case')
            r3.json_write(queue_path, plan)
            time.sleep(3)
        require(set(plan['pairs']) == {key+'-'+size for key in ('s2','s6','s7','s9') for size in ('960','1080')}
                and len(plan['cases']) == 10, 'Full mixed-origin matrix incomplete')
        plan['status'] = 'mixed_origin_paired_observations_checked'
    except BaseException as error:
        plan.update(status='stopped', error=repr(error))
        raise
    finally:
        plan.update(ended_utc=r3.stamp(), received_signals=cancelled)
        r3.json_write(queue_path, plan)
        lock.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
