"""Small semantics-only regression receipt fixtures; no engine or project mutation."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bed_r4_fixture', HERE / 'plaza-bed-native-r4.py')
bed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bed)
original = bed.load(HERE / 'plaza-bed-helpers-r4-meta.json')
checks = []

def expect(label, fn, rejects=False):
    try:
        fn()
        if rejects:
            raise AssertionError('bad receipt accepted')
        checks.append({'label': label, 'ok': True})
    except RuntimeError as error:
        if rejects:
            checks.append({'label': label, 'ok': True})
        else:
            checks.append({'label': label, 'ok': False, 'error': str(error)})

expect('actual immutable R3 RED/GREEN and current12 source pins validate', lambda: bed.verify_focused())
with tempfile.TemporaryDirectory(prefix='sa-plaza-r4-byte-') as temp:
    root = Path(temp)
    meta = copy.deepcopy(original)
    case_data = []
    for index, case in enumerate(meta['prior_focused_cases']):
        raw = bed.load(case['raw'])
        raw['source_hashes'] = {key: raw['source_hashes'][key] for key in meta['parent_runtime_sha256']}
        guard = {key: value for key, value in bed.load(case['guard']).items() if key != 'samples'}
        report = bed.load(case['report'])
        stdout = Path(case['stdout']).read_text()
        before_report = case['report']
        for key in ['raw', 'guard', 'report', 'stdout']:
            case[key] = str(root / (str(index) + '-' + key + ('.txt' if key == 'stdout' else '.json')))
        raw['command'] = ['--out=' + case['report'] if arg == '--out=' + before_report else arg for arg in raw['command']]
        case_data.append({'raw': raw, 'guard': guard, 'report': report, 'stdout': stdout})
    baseline = copy.deepcopy(case_data)

    def run(mutator=None):
        data = copy.deepcopy(baseline)
        if mutator:
            mutator(data)
        for case, item in zip(meta['prior_focused_cases'], data):
            for key in ['raw', 'guard', 'report', 'stdout']:
                Path(case[key]).write_text(item[key] if key == 'stdout' else json.dumps(item[key]))
                case[key + '_sha256'] = bed.sha(case[key])
        return bed.verify_focused(meta)

    expect('minimal exact RED/GREEN byte receipts accepted', run)
    for label, mutate in [
        ('wrong RED count rejected', lambda d: d[0]['report'].update(passes=30)),
        ('missing RED diagnostic rejected', lambda d: d[0]['raw']['diagnostics'].pop()),
        ('extra GREEN diagnostic rejected', lambda d: d[1]['raw']['diagnostics'].append('ERROR: unrelated')),
        ('stale raw runtime source rejected', lambda d: d[1]['raw']['source_hashes'].update({'core/systems/world/proc/chunkgen/PlazaPresentation.gd': 'wrong'})),
        ('wrong GREEN state set rejected', lambda d: d[1]['report']['states'][4].update(state=3)),
        ('outside island regression rejected', lambda d: d[1]['report']['states'][2].update(outside_ok=False)),
        ('missing native cause rejected', lambda d: d[1]['report'].update(generator_underlay_matches_native=False)),
        ('terrain fallback rejected', lambda d: d[0]['report'].update(semantic_terrain='dirt')),
        ('save write rejected', lambda d: d[1]['report'].update(save_writes=1)),
        ('cancelled GREEN guard rejected', lambda d: d[1]['guard'].update(reason='external_sigterm', received_signal=15)),
        ('missing original footer rejected', lambda d: d[0].update(stdout='')),
    ]:
        expect(label, lambda change=mutate: run(change), rejects=True)
result = {'status': 'SOURCE_ONLY_TINY_JSON_FIXTURES', 'passed': sum(row['ok'] for row in checks),
          'failed': sum(not row['ok'] for row in checks), 'checks': checks,
          'runtime_writes': 0, 'engines_started': 0, 'regression_reruns': 0}
(HERE / 'resume-source-fixture-result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
assert result['failed'] == 0
