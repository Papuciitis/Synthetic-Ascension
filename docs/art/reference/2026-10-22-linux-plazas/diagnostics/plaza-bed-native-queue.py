#!/usr/bin/env python3
"""Root-invoked native bed acceptance queue; importing/preparing starts no engine."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import signal
import subprocess
import sys
import time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = Path(__file__).resolve().parent
PROJECT = Path('/tmp/sa-wp2-plazas')
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
EXPECTED = {6: ('industrial_cutthrough', 1), 7: ('canal_services', 3), 8: ('military_staging', 4)}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


def clean_records(label):
    thermal_path = BASE / (label + '-thermal.json')
    require(thermal_path.is_file(), 'Final guard record missing: ' + label)
    thermal = load(thermal_path)
    require(thermal.get('reason') == 'completed' and thermal.get('wrapper_exit') == 0
            and thermal.get('received_signal') is None, 'Guard not clean: ' + label)
    matches = [p / 'run-results.json' for p in RUNS.glob(label + '-*')
               if p.is_dir() and re.fullmatch(re.escape(label) + r'-\d+', p.name)
               and (p / 'run-results.json').is_file()]
    require(len(matches) == 1, 'Need one exact final raw run: ' + label)
    path = matches[0]
    raw = load(path)
    require(raw.get('ended_utc') and raw.get('actual_exit') == 0 and raw.get('runner_exit') == 0
            and raw.get('stop_reason') == 'completed' and raw.get('diagnostics') == [],
            'Raw engine run not clean: ' + label)
    require(Path(raw['project_root']).resolve() == PROJECT, 'Wrong source checkout: ' + label)
    return raw, {'raw': str(path), 'raw_sha256': sha(path),
                 'guard': str(thermal_path), 'guard_sha256': sha(thermal_path)}


def validate(discovery_path):
    meta = load(BASE / 'plaza-bed-helpers-meta.json')
    for helper in meta['helpers'].values():
        require(sha(helper['gd']) == helper['sha256'], 'Frozen helper changed: ' + helper['gd'])
        require(sha(helper['scene']) == helper['scene_sha256'], 'Frozen helper scene changed.')
    raw_parse, parse_binding = clean_records('city22-plaza-bed-tools-parse')
    for helper in meta['helpers'].values():
        require(helper['gd'] in raw_parse['command'], 'Scoped parser omitted a bed helper.')
    discovery_raw, discovery_binding = clean_records('city22-plaza-bed-discovery')
    require(str(BASE / 'PlazaBedDiscovery.tscn') in discovery_raw['command']
            and '--headless' in discovery_raw['command']
            and '--out=' + str(discovery_path) in discovery_raw['command'],
            'Discovery command does not bind this JSON.')
    data = load(discovery_path)
    require(data.get('failures') == 0 and data.get('save_writes') == 0, 'Discovery report not clean.')
    require(data.get('source_sha256', {}).get(str(BASE / 'PlazaBedDiscovery.gd'))
            == meta['helpers']['PlazaBedDiscovery']['sha256'], 'Discovery helper SHA mismatch.')
    source_hashes = dict(meta['parent_runtime_sha256'])
    overlay = load(BASE / 'plaza-parse-baseline-overlay/city22-plaza-parse-overlay-baseline-result.json')
    require(overlay.get('restored_exactly') and not overlay.get('restore_errors'), 'Candidate overlay not restored.')
    source_hashes.update(overlay['source_restored'])
    for relative, digest in source_hashes.items():
        require(sha(PROJECT / relative) == digest, 'Current source changed: ' + relative)
        require(discovery_raw['source_hashes'].get(relative) == digest,
                'Discovery launch source mismatch: ' + relative)
    entries = data.get('results', [])
    require(len(entries) == 3, 'Discovery must return exactly three distinct family candidates.')
    by_segment = {}
    for item in entries:
        segment = item.get('segment')
        require(segment in EXPECTED and segment not in by_segment, 'Unexpected/duplicate discovery segment.')
        family, state = EXPECTED[segment]
        require(item.get('family') == family and item.get('state') == state, 'Discovery family/state mismatch.')
        require(1 <= item.get('attempt_seed', 0) <= 400 and 1 <= item.get('matching_seed_number', 0) <= 8,
                'Discovery exceeds bounded natural seed search.')
        require(len(item.get('coord', [])) == 2 and bool(item.get('role')), 'Discovery coordinate/role missing.')
        bed = item.get('bed_rect_cells', {})
        require(len(bed.get('position', [])) == 2 and len(bed.get('size', [])) == 2
                and min(bed['size']) > 0, 'Discovery planned bed rectangle missing.')
        focus = item.get('camera_world_px', [])
        require(len(focus) == 2 and all(math.isfinite(v) for v in focus)
                and item.get('actual_fixture_bed_nodes'), 'Discovery real-node bounds/focus missing.')
        by_segment[segment] = item
    require(set(by_segment) == set(EXPECTED), 'Discovery lacks a required family.')
    require(all(1 <= row.get('matching_seed_number', 0) <= 8 for row in data.get('attempts', [])),
            'Attempt log exceeds matching-seed bound.')
    return meta, by_segment, source_hashes, {'discovery': str(discovery_path),
            'discovery_sha256': sha(discovery_path), 'discovery_records': discovery_binding,
            'scoped_parse_records': parse_binding}


def native_acceptance(segment, expected, output, label, source_hashes, meta):
    raw, binding = clean_records(label)
    for relative, digest in source_hashes.items():
        require(raw['source_hashes'].get(relative) == digest and sha(PROJECT / relative) == digest,
                'Native/current source differs from discovery: ' + relative)
    actual = load(output / 'bed-validation.json')
    capture = load(output / 'capture-info.json')
    family, state = EXPECTED[segment]
    require(actual.get('matches_expected') is True and actual.get('failures') == 0
            and actual.get('save_writes') == 0, 'Actual Game bed validation failed.')
    require(actual.get('expected') == expected and actual.get('actual_family') == family
            and actual.get('actual_state') == state and actual.get('actual_role') == expected['role'],
            'Actual family/state/role/expected binding differs.')
    require(expected['bed_rect_cells'] in actual.get('actual_plan_island_beds', []), 'Expected plan bed is absent.')
    focus = expected['camera_world_px']
    def contains(node):
        bounds = node['world_aabb']; position = bounds['position']; size = bounds['size']
        return all(position[i] <= focus[i] < position[i] + size[i] for i in [0, 1])
    require(any(contains(node) for node in actual.get('actual_bed_nodes', [])), 'No real bed covers focal camera.')
    require(actual['source_sha256'].get(str(BASE / 'PlazaBedGamePreview.gd'))
            == meta['helpers']['PlazaBedGamePreview']['sha256'], 'Native helper runtime SHA differs.')
    require(capture.get('failures') == 0 and capture.get('save_writes') == 0
            and capture.get('normal_hud') is True and capture.get('optional_details_hidden') is False,
            'Parent native fixture/save/HUD checks failed.')
    require(capture.get('seed') == expected['attempt_seed'] and capture.get('theme') == family
            and capture.get('segment') == segment and capture.get('bed_render_fps_cap') == 20
            and capture.get('physics_ticks_per_second') == 60, 'Native actual seed/theme/timing settings differ.')
    require(any(row.get('event') == 'ground_context_streamed_reload' and row.get('equal') is True
                and row.get('care_equal') is True for row in capture.get('route', [])),
            'Actual unload/reload equality is not demonstrated.')
    image = output / 'ground-before.png'
    require(image.is_file() and image.stat().st_size > 0, 'Native PNG missing.')
    return {'records': binding, 'bed_validation_sha256': sha(output / 'bed-validation.json'),
            'capture_info_sha256': sha(output / 'capture-info.json'), 'image': str(image),
            'image_sha256': sha(image), 'actual_node_count': len(actual['actual_bed_nodes']),
            'acceptance': 'native plan/node/reload checks clean; visual review of original PNG still required'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--discovery', type=Path, default=BASE / 'plaza-bed-discovery.json')
    parser.add_argument('--segments', type=int, nargs='+', choices=sorted(EXPECTED), default=sorted(EXPECTED))
    parser.add_argument('--label-prefix', default='city22-plaza-bed-native')
    parser.add_argument('--duty-percent', type=int, choices=[10, 25], default=10)
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    require(re.fullmatch('city22-plaza-bed-native(?:-[a-z0-9-]+)?', args.label_prefix) is not None,
            'Use a stage-specific fresh bed-native label prefix.')
    meta, entries, hashes, prerequisite = validate(args.discovery.resolve())
    cases = []
    for segment in args.segments:
        label = args.label_prefix + '-s' + str(segment)
        output = Path('/var/tmp/sa-city22/plaza-beds/s' + str(segment))
        require(not (BASE / (label + '-thermal.json')).exists()
                and not list(RUNS.glob(label + '-*')), 'Native label already used: ' + label)
        require(not output.exists() or not any(output.iterdir()), 'Native output is not fresh: ' + str(output))
        command = [sys.executable, str(BASE / 'guarded_engine.py'), '--label', label,
                   '--project', str(PROJECT), '--start-temperature', '70', '--max-wait', '900',
                   '--timeout', '600', '--duty-percent', str(args.duty_percent), '--',
                   '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
                   str(BASE / 'PlazaBedGamePreview.tscn'), '--', '--visible', '--review=normal',
                   '--render-fps=20', '--discovery=' + str(args.discovery.resolve()),
                   '--family=' + EXPECTED[segment][0], '--out=' + str(output)]
        cases.append({'segment': segment, 'label': label, 'output': str(output), 'command': command,
                      'expected': entries[segment]})
    if args.validate_only:
        print(json.dumps({'validated': True, 'prerequisite': prerequisite, 'cases': cases,
                          'engines_started': 0}, indent=2), flush=True)
        return 0
    summary_path = BASE / 'plaza-bed-native-queue.json'
    summary = {'prerequisite': prerequisite, 'cases': [], 'scope': 'Native frozen actual-Game bed/reload evidence; render20/physics60, functional duty only. No live/performance claim; original unsorted audit diagnostics remain unresolved.'}
    child = None
    interrupted = None
    def stop(signum, _frame):
        nonlocal interrupted
        interrupted = signum
        if child is not None and child.poll() is None:
            child.send_signal(signum)
    previous = {sig: signal.signal(sig, stop) for sig in [signal.SIGINT, signal.SIGTERM]}
    try:
        for case in cases:
            require(interrupted is None, 'Queue interrupted before next native launch.')
            row = dict(case, state='running')
            summary['cases'].append(row)
            summary_path.write_text(json.dumps(summary, indent=2) + '\n')
            child = subprocess.Popen(case['command'], cwd=ROOT, start_new_session=True)
            rc = child.wait()
            row.update(returncode=rc, state='guard_finished')
            summary_path.write_text(json.dumps(summary, indent=2) + '\n')
            require(rc == 0 and interrupted is None, 'Guarded native run failed/interrupted: ' + case['label'])
            row['validation'] = native_acceptance(case['segment'], case['expected'], Path(case['output']),
                                                  case['label'], hashes, meta)
            row['state'] = 'native_checks_clean_pending_visual_review'
            summary_path.write_text(json.dumps(summary, indent=2) + '\n')
            print('BED_NATIVE_CHECKED', case['label'], json.dumps(row['validation']), flush=True)
            time.sleep(3)
    finally:
        if child is not None and child.poll() is None:
            child.send_signal(signal.SIGTERM)
            child.wait()
        for sig, handler in previous.items(): signal.signal(sig, handler)
        summary['interrupted_signal'] = interrupted
        summary_path.write_text(json.dumps(summary, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
