#!/usr/bin/env python3
"""Dry-run by default. Root alone opts into two short guarded headless cases."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
META = BASE / 'prop-shadow-acceptance-source.json'


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(project: Path) -> dict:
    meta = json.loads(META.read_text())
    observed = {}
    for relative, expected in meta['project_bindings'].items():
        path = project / relative
        observed[str(path)] = sha(path)
        if observed[str(path)] != expected:
            raise RuntimeError('Bound project bytes changed: ' + str(path))
    for absolute, expected in meta['external_bindings'].items():
        path = Path(absolute)
        observed[absolute] = sha(path)
        if observed[absolute] != expected:
            raise RuntimeError('Bound external bytes changed: ' + absolute)
    return observed


def clean_run(label: str) -> dict:
    paths = list(RUNS.glob(label + '-*/run-results.json'))
    if len(paths) != 1:
        raise RuntimeError(f'{label}: expected one raw run result, found {len(paths)}')
    result = json.loads(paths[0].read_text())
    thermal_path = BASE / (label + '-thermal.json')
    thermal = json.loads(thermal_path.read_text())
    if not result.get('ended_utc') or result.get('actual_exit') != 0 or result.get('runner_exit') != 0 or result.get('stop_reason') != 'completed' or result.get('diagnostics') or not result.get('source_hashes'):
        raise RuntimeError('Unclean engine result: ' + str(paths[0]))
    if thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed':
        raise RuntimeError('Unclean thermal wrapper: ' + str(thermal_path))
    return {'path': str(paths[0]), 'sha256': sha(paths[0]), 'thermal_path': str(thermal_path), 'thermal_sha256': sha(thermal_path)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suffix', required=True)
    parser.add_argument('--project', type=Path, default=Path('/tmp/sa-c22-props'))
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--duty-percent', type=int, choices=[10, 25], default=10)
    parser.add_argument('--start-temperature', type=int, choices=[65, 70], default=70)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,55}', args.suffix):
        raise SystemExit('Use a fresh lowercase alphanumeric/hyphen suffix.')
    project = args.project.resolve()
    observed = verify(project)
    directory = Path('/var/tmp/sa-city22/prop-shadow-acceptance') / args.suffix
    meta = json.loads(META.read_text())
    parser_args = ['--headless', str(BASE / 'street-native-source-parse.tscn'), '--', *meta['scoped_parser_paths']]
    fixture_args = ['--headless', str(BASE / 'CityPropShadowAcceptance.tscn'), '--', '--out=' + str(directory / 'acceptance.json')]
    cases = []
    for role, tail in [('parse', parser_args), ('fixture', fixture_args)]:
        label = 'city22-prop-shadow-' + role + '-' + args.suffix
        if (BASE / (label + '-thermal.json')).exists() or list(RUNS.glob(label + '-*')):
            raise RuntimeError('Fresh label required: ' + label)
        command = [sys.executable, str(BASE / 'guarded_engine.py'), '--label', label, '--project', str(project), '--start-temperature', str(args.start_temperature), '--max-wait', '900', '--timeout', str(args.timeout), '--duty-percent', str(args.duty_percent), '--', *tail]
        cases.append({'role': role, 'label': label, 'command': command})
    if not args.execute:
        print(json.dumps({'execute': False, 'project': str(project), 'reported_revision': meta['reported_revision'], 'source_count': len(observed), 'cases': cases}, indent=2))
        return
    print('PROP_ACCEPTANCE_START', args.suffix, 'bound_sources', len(observed), 'cases', len(cases), flush=True)
    directory.mkdir(parents=True, exist_ok=False)
    record = {'source_before': observed, 'cases': cases, 'passed': False}
    try:
        for index, case in enumerate(cases):
            if index:
                time.sleep(3)
            verify(project)
            case['wrapper_exit'] = subprocess.run(case['command'], check=False).returncode
            if case['wrapper_exit'] != 0:
                raise RuntimeError('Guarded case failed: ' + case['label'])
            case['raw_result'] = clean_run(case['label'])
            if case['role'] == 'parse':
                stdout = Path(case['raw_result']['path']).parent / 'logs/stdout.log'
                if 'StreetNativeSourceParse: checked=6 failures=0' not in stdout.read_text():
                    raise RuntimeError('Missing six-source scoped parser verdict')
            record['source_after'] = verify(project)
        acceptance = json.loads((directory / 'acceptance.json').read_text())
        if acceptance.get('suite') != 'CityPropShadowAcceptance' or acceptance.get('passes') != 48 or acceptance.get('failures') != 0 or len(acceptance.get('checks', [])) != 48 or not all(check.get('ok') is True for check in acceptance['checks']):
            raise RuntimeError('Incomplete or failing 48-check acceptance manifest')
        record['acceptance_sha256'] = sha(directory / 'acceptance.json')
        record['passed'] = True
    except BaseException as exc:
        record['error'] = repr(exc)
        raise
    finally:
        (directory / 'queue.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
