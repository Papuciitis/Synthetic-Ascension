import collections
import hashlib
import json
import statistics
from pathlib import Path

directory = Path(__file__).resolve().parent
base = directory.parents[3]
rows = collections.defaultdict(lambda: {'before_usec': [], 'after_usec': [], 'before_forms': [], 'after_forms': []})
for phase in ('before', 'after'):
    for path in sorted(directory.glob(f'boss-spawn-{phase}-[0-9].log')):
        for line in path.read_text(encoding='utf-8').splitlines():
            if not line.startswith('SPAWN_PRESENTATION '):
                continue
            data = json.loads(line.removeprefix('SPAWN_PRESENTATION '))
            entry = rows[(data['boss'], data['tier'])]
            entry[f'{phase}_usec'].append(data['spawn_usec'])
            entry[f'{phase}_forms'].append(len(data['initialized_forms']))
output = {'method': 'Native Godot 4.7.1 Windows, headless, audio Dummy. Fresh process per run; three baseline runs and one fixed run; fixed S10 Mage/Tank then S5 Mage/Tank order. Actual arena _spawn measured, with real signal listeners/autoloads but no Game/HUD. OS file cache not cleared. No FPS claim or elimination of remaining cold texture load.', 'results': []}
for (boss, tier), data in rows.items():
    output['results'].append({'boss': boss, 'tier': tier, **data,
        'before_median_ms': statistics.median(data['before_usec']) / 1000,
        'after_observed_ms': [value / 1000 for value in data['after_usec']]})
output['source_sha256'] = {name: hashlib.sha256((base / name).read_bytes()).hexdigest() for name in (
    'scenes/world/events/BossArena.gd', 'scenes/world/events/MiniBossArena.gd',
    'tools/tests/BossSpawnPresentationTest.gd')}
directory.joinpath('boss-spawn-comparison.json').write_text(json.dumps(output, indent=2), encoding='utf-8')
print(json.dumps(output, indent=2))
