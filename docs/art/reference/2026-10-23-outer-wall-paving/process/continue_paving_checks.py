"""Remaining finite checks; stop scheduling on an actual incomplete run."""
import json
from pathlib import Path
import subprocess

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261023-ground'
GUARD = ROOT / '.superpowers/continuation-20261022/guarded_engine.py'
OUTPUT = BASE / 'paving-queue-r3.json'


def clean(label):
    thermal = json.loads((GUARD.parent / (label + '-thermal.json')).read_text())
    raw = json.loads((ROOT / '.superpowers/claude-city-20261021/runs' / (label + '-1') / 'run-results.json').read_text())
    return (thermal['reason'] == 'completed' and thermal['wrapper_exit'] == 0
            and raw['actual_exit'] == 0 and raw['runner_exit'] == 0
            and raw['diagnostics'] == [] and raw['stop_reason'] == 'completed')


assert not OUTPUT.exists(), OUTPUT
assert clean('city23-ground-after-s9-r3')
record = {'status': 'RUNNING', 'source_head': '6905e7ea5a768f4edd2c279f0b5add4aa6283ccd',
          'reused_normal': 'city23-ground-after-s9-r3',
          'preserved_interrupted_small': 'city23-ground-after-s9-small-r1',
          'thermal_protocol': 'Optional 98 C instantaneous stop; 85 C x3 sustained and 65 C launch unchanged. No performance/safety claim.',
          'cases': []}


def save():
    OUTPUT.write_text(json.dumps(record, indent=2) + '\n')


save()
cases = [
    ('city23-ground-after-s9-small-r2', [
        '--max-fps', '20', '--resolution', '960x540', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
        str(BASE / 'GroundPavingPreview.tscn'), '--', '--visible', '--segment=9', '--world-seed=16102026',
        '--ground-context=-3104,-1384', '--review=small', '--out=/var/tmp/sa-city23-ground/after-s9-small-r2']),
    ('city23-ground-owner-care-r4', ['--headless', '--max-fps', '20', 'res://tools/tests/CityGroundCareTest.tscn']),
    ('city23-ground-owner-splat-r1', ['--headless', '--max-fps', '20', 'res://tools/tests/WorldGroundSplatTest.tscn']),
]
for label, args in cases:
    command = ['python3', str(GUARD), '--label', label, '--project', '/tmp/sa-c23-ground',
               '--cpu-count', '1', '--start-temperature', '65', '--burst-temperature', '98',
               '--max-wait', '900', '--timeout', '900', '--duty-percent', '10', '--', *args]
    print('START', label, flush=True)
    item = {'label': label, 'command': command, 'status': 'RUNNING'}
    record['cases'].append(item)
    save()
    result = subprocess.run(command, cwd=ROOT)
    item.update({'guard_exit': result.returncode,
                 'status': 'PASSED' if result.returncode == 0 and clean(label) else 'INCOMPLETE_OR_FAILED'})
    save()
    if item['status'] != 'PASSED':
        record['status'] = 'STOPPED'
        save()
        raise SystemExit(1)
record['status'] = 'ALL_COMPLETED'
save()
print('QUEUE ALL_COMPLETED', flush=True)
