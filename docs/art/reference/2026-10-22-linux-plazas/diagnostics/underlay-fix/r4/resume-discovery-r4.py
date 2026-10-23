#!/usr/bin/env python3
"""Root-only continuation: revalidate completed R3 regression, then fresh tools/discovery.
Default is a read-only plan. Never writes project/runtime files or reruns RED/GREEN.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import signal
import subprocess
import sys
import time

FIX = Path(__file__).resolve().parent
BASE = FIX.parent.parent
PROJECT = Path('/tmp/sa-wp2-plazas')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    manifest = load(FIX / 'manifest-r4.json')
    for name, digest in manifest['files'].items():
        if sha(FIX / name) != digest:
            raise RuntimeError('Frozen R4 package changed: ' + name)
    spec = importlib.util.spec_from_file_location('plaza_bed_r4', FIX / 'plaza-bed-native-r4.py')
    bed = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bed)
    prior = bed.verify_focused()
    meta = load(FIX / 'plaza-bed-helpers-r4-meta.json')
    helpers = meta['helpers']
    discovery = FIX / 'plaza-bed-discovery-r4.json'
    parse_paths = [helpers[name]['gd'] for name in ['PlazaBedDiscovery', 'PlazaBedDiscoveryTerrain', 'PlazaBedGamePreview', 'PlazaBedUnderlayGamePreview']]
    scenes = [( 'city22-plaza-bed-tools-parse-r4', str(BASE / 'external_source_parse_probe.tscn'), parse_paths, 300),
              ( 'city22-plaza-bed-discovery-r4', helpers['PlazaBedDiscoveryTerrain']['scene'], ['--out=' + str(discovery)], 900)]
    cases = []
    for label, scene, extra, timeout in scenes:
        bed.require(not (BASE / (label + '-thermal.json')).exists() and not list(bed.RUNS.glob(label + '-*')), 'Fresh R4 label required: ' + label)
        command = [sys.executable, str(BASE / 'guarded_engine.py'), '--label', label, '--project', str(PROJECT), '--start-temperature', '65', '--max-wait', '900', '--timeout', str(timeout), '--duty-percent', '25', '--', '--headless', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', scene, '--', *extra]
        cases.append({'label': label, 'command': command, 'scene': scene, 'extra': extra})
    summary_path = FIX / 'resume-discovery-execution-r4.json'
    bed.require(not discovery.exists() and not summary_path.exists(), 'R4 output already exists; preserve it and review a fresh suffix')
    if not args.execute:
        print(json.dumps({'execute': False, 'engines_started': 0, 'runtime_writes': 0, 'regression_reruns': 0,
                          'verified_completed_r3_regression': prior, 'cases': cases, 'discovery': str(discovery)}, indent=2))
        return 0
    summary = {'cases': [], 'completed_discovery': False, 'runtime_writes': 0, 'regression_reruns': 0,
               'verified_completed_r3_regression': prior, 'scope': 'Continuation only; native and explicit visual acceptance remain separate.'}
    child = None
    interrupted = None

    def save():
        summary_path.write_text(json.dumps(summary, indent=2) + '\n')

    def stop(signum, _frame):
        nonlocal interrupted
        interrupted = signum
        if child is not None and child.poll() is None:
            child.send_signal(signum)

    previous = {sig: signal.signal(sig, stop) for sig in [signal.SIGINT, signal.SIGTERM]}
    try:
        save()
        for index, case in enumerate(cases):
            bed.require(interrupted is None, 'Resume interrupted before next launch')
            bed.verify_focused()
            row = dict(case, state='running', guard_started_unix_ns=time.time_ns(), guard_source_sha256=sha(BASE / 'guarded_engine.py'))
            summary['cases'].append(row)
            save()
            child = subprocess.Popen(case['command'], cwd=PROJECT, start_new_session=True)
            row['wrapper_exit'] = child.wait()
            row['state'] = 'guard_finished'
            save()
            bed.require(row['wrapper_exit'] == 0 and interrupted is None, 'Fresh guarded R4 case failed/interrupted: ' + case['label'])
            raw, binding = bed.clean_records(case['label'])
            bed.require(case['scene'] in raw['command'] and '--headless' in raw['command'] and all(arg in raw['command'] for arg in case['extra']), 'R4 actual command differs')
            for relative, digest in meta['parent_runtime_sha256'].items():
                bed.require(raw['source_hashes'].get(relative) == digest, 'R4 launch source changed: ' + relative)
            if index == 0:
                stdout = Path(binding['raw']).parent / 'logs/stdout.log'
                bed.require('ExternalSourceParseProbe: checked=4 failures=0' in stdout.read_text(), 'Exact four-helper parse footer absent')
            bed.verify_focused()
            row.update(state='clean', records=binding)
            save()
            if index == 0:
                time.sleep(3)
        _, _, _, prerequisite = bed.validate(discovery)
        summary.update(completed_discovery=True, validated_discovery=prerequisite)
    except BaseException as error:
        summary['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        if child is not None and child.poll() is None:
            child.send_signal(signal.SIGTERM)
            child.wait()
        summary['interrupted_signal'] = interrupted
        summary['final_runtime_sha256'] = sha(PROJECT / 'core/systems/world/proc/chunkgen/PlazaPresentation.gd')
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        save()
    print(json.dumps({'completed_discovery': True, 'runtime_writes': 0, 'regression_reruns': 0,
                      'native_acceptance_pending': True, 'summary': str(summary_path)}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
