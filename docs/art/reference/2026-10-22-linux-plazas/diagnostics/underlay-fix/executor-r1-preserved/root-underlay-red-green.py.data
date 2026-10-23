#!/usr/bin/env python3
"""Root-only reviewed executor. Default prints planned commands; no engines or edits."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import signal
import subprocess
import sys
import time

FIX = Path(__file__).resolve().parent
BASE = FIX.parent
PROJECT = Path('/tmp/sa-wp2-plazas')
RUNS = BASE.parent / 'claude-city-20261021/runs'
RUNTIME = 'core/systems/world/proc/chunkgen/PlazaPresentation.gd'

def need(ok, message):
    if not ok: raise RuntimeError(message)

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def load(path): return json.loads(Path(path).read_text())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    manifest = load(FIX / 'manifest.json')
    assertions = load(FIX / 'assertion-manifest.json')
    for name, digest in manifest['files'].items(): need(sha(FIX / name) == digest, 'Frozen package changed: ' + name)
    before, after = FIX / 'PlazaPresentation.before.gd.data', FIX / 'PlazaPresentation.after.gd.data'
    need(sha(before) == manifest['original_runtime_sha256'] and sha(after) == manifest['proposed_runtime_sha256'], 'Frozen runtime bytes changed')
    overlay = load(BASE / 'plaza-parse-baseline-overlay/manifest.json')
    original = {row['runtime_path']: row['candidate']['sha256'] for row in overlay['files']}
    fixed = dict(original, **{RUNTIME: manifest['proposed_runtime_sha256']})
    test_paths = {'tools/tests/PlazaBedUnderlayTest.gd': manifest['files']['PlazaBedUnderlayTest.gd'], 'tools/tests/PlazaBedUnderlayTest.tscn': manifest['files']['PlazaBedUnderlayTest.repo.tscn']}
    def source(expected):
        for relative, digest in dict(expected, **test_paths).items(): need(sha(PROJECT / relative) == digest, 'Pinned project source changed/missing: ' + relative)
    source(original)
    spec = importlib.util.spec_from_file_location('bed_r2', FIX / 'plaza-bed-native-r2.py')
    bed = importlib.util.module_from_spec(spec); spec.loader.exec_module(bed)
    red_out, green_out = FIX / 'underlay-red.json', FIX / 'underlay-green.json'
    discovery = FIX / 'plaza-bed-discovery-r2.json'
    cases = [
        ('city22-plaza-underlay-red', 'res://tools/tests/PlazaBedUnderlayTest.tscn', ['--out=' + str(red_out)], 600),
        ('city22-plaza-underlay-green', 'res://tools/tests/PlazaBedUnderlayTest.tscn', ['--out=' + str(green_out)], 600),
        ('city22-plaza-bed-tools-parse-r2', str(BASE / 'external_source_parse_probe.tscn'), [str(BASE / 'PlazaBedDiscovery.gd'), str(BASE / 'PlazaBedGamePreview.gd'), str(FIX / 'PlazaBedUnderlayGamePreview.gd')], 300),
        ('city22-plaza-bed-discovery-r2', str(BASE / 'PlazaBedDiscovery.tscn'), ['--out=' + str(discovery)], 900)]
    commands = []
    for label, scene, extra, timeout in cases:
        need(not (BASE / (label + '-thermal.json')).exists() and not list(RUNS.glob(label + '-*')), 'Label already used: ' + label)
        commands.append([sys.executable, str(BASE / 'guarded_engine.py'), '--label', label, '--project', str(PROJECT), '--start-temperature', '65', '--max-wait', '900', '--timeout', str(timeout), '--duty-percent', '25', '--', '--headless', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', scene, '--'] + extra)
    for path in (red_out, green_out, discovery): need(not path.exists(), 'Output already exists: ' + str(path))
    if not args.execute:
        print(json.dumps({'engines_started': 0, 'runtime_edits': 0, 'commands': commands, 'runtime_change_after_strict_red_only': str(after), 'expected': assertions}, indent=2))
        return 0
    summary_path = FIX / 'root-underlay-execution.json'
    need(not summary_path.exists(), 'Execution record already exists')
    summary = {'cases': [], 'runtime_applied': False, 'green_clean': False, 'completed_discovery': False, 'scope': 'Focused causal regression and fresh discovery only; no native visual acceptance/full-audit claim.'}
    child = None
    interrupted = None
    def save(): summary_path.write_text(json.dumps(summary, indent=2) + '\n')
    def stop(signum, _frame):
        nonlocal interrupted
        interrupted = signum
        if child is not None and child.poll() is None: child.send_signal(signum)
    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    def run(index, expected, red=False):
        nonlocal child
        need(interrupted is None, 'Executor interrupted before next action')
        source(expected)
        label, scene, extra, _ = cases[index]
        row = {'label': label, 'command': commands[index], 'state': 'running'}
        summary['cases'].append(row); save()
        child = subprocess.Popen(commands[index], cwd=PROJECT, start_new_session=True)
        rc = child.wait(); row['wrapper_exit'] = rc; save()
        need(interrupted is None and rc == (1 if red else 0), 'Unexpected guard exit: ' + label)
        thermal_path = BASE / (label + '-thermal.json'); thermal = load(thermal_path)
        paths = [p / 'run-results.json' for p in RUNS.glob(label + '-*') if p.is_dir() and re.fullmatch(re.escape(label) + r'-\d+', p.name) and (p / 'run-results.json').exists()]
        need(len(paths) == 1, 'Need one exact final raw record: ' + label)
        raw_path = paths[0]; raw = load(raw_path)
        row.update(raw=str(raw_path), raw_sha256=sha(raw_path), guard=str(thermal_path), guard_sha256=sha(thermal_path))
        need(thermal.get('reason') == 'completed' and thermal.get('wrapper_exit') == rc and thermal.get('received_signal') is None, 'Guard did not complete normally')
        need(raw.get('ended_utc') and raw.get('actual_exit') == rc and raw.get('runner_exit') == rc and raw.get('stop_reason') == ('nonzero_exit' if red else 'completed'), 'Raw engine exit does not match expected result')
        need(Path(raw['project_root']).resolve() == PROJECT and scene in raw['command'] and '--headless' in raw['command'] and all(arg in raw['command'] for arg in extra), 'Raw command/source scope differs')
        for relative, digest in expected.items(): need(raw['source_hashes'].get(relative) == digest, 'Raw launch source hash differs: ' + relative)
        diagnostics = assertions['red_diagnostics'] if red else []
        need(raw.get('diagnostics') == diagnostics, 'Unexpected/missing diagnostics: ' + label)
        source(expected)
        row['state'] = 'expected_red' if red else 'clean'; save()
        return raw_path
    try:
        save()
        raw = run(0, original, True)
        report = load(red_out)
        need(report['passes'] == 29 and report['failures'] == 8 and report['save_writes'] == 0, 'RED footer JSON differs')
        need(assertions['red_footer'] in (raw.parent / 'logs/stdout.log').read_text(), 'Expected RED footer absent')
        for row in report['states']:
            need(row['state'] in range(5) and row['outside_ok'] and row['material_ok'] == (row['state'] == 0) and row['care_ok'] == (row['state'] == 0), 'RED failed outside the exact intended state checks')
        need(len(report['states']) == 5 and {row['state'] for row in report['states']} == set(range(5)), 'RED state matrix incomplete')
        source(original); need(interrupted is None, 'Interrupted before runtime fix')
        (PROJECT / RUNTIME).write_bytes(after.read_bytes())
        summary['runtime_applied'] = True; save(); source(fixed)
        time.sleep(3)
        raw = run(1, fixed)
        report = load(green_out)
        need(report['passes'] == 37 and report['failures'] == 0 and report['save_writes'] == 0 and len(report['states']) == 5, 'GREEN count/state/save report differs')
        need(assertions['green_footer'] in (raw.parent / 'logs/stdout.log').read_text() and all(row['material_ok'] and row['care_ok'] and row['outside_ok'] for row in report['states']), 'GREEN underlay matrix not clean')
        summary['green_clean'] = True; save()
        time.sleep(3); run(2, fixed)
        time.sleep(3); run(3, fixed)
        bed.validate(discovery)
        summary['completed_discovery'] = True; save()
    except BaseException as error:
        summary['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        try:
            if child is not None and child.poll() is None:
                child.send_signal(signal.SIGTERM); child.wait(timeout=30)
            if summary['runtime_applied'] and not summary['green_clean']:
                need(sha(PROJECT / RUNTIME) == manifest['proposed_runtime_sha256'], 'Runtime changed; refuse automatic rollback')
                (PROJECT / RUNTIME).write_bytes(before.read_bytes()); summary['runtime_rolled_back_after_unclean_green'] = True
        except BaseException as error: summary['cleanup_error'] = str(error)
        summary['interrupted_signal'] = interrupted
        summary['final_runtime_sha256'] = sha(PROJECT / RUNTIME)
        for sig, handler in previous.items(): signal.signal(sig, handler)
        save()
    print(json.dumps({'focused_green': True, 'fresh_discovery': True, 'native_acceptance_pending': True, 'summary': str(summary_path)}))
    return 0

if __name__ == '__main__': raise SystemExit(main())
