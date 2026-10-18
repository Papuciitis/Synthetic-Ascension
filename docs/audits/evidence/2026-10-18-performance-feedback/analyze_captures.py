import bisect
import collections
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[4]
unique = {}
events = {}
files = sorted((BASE / 'performance_results/2026-10-18').glob('*.json'))
for path in files:
    capture = json.loads(path.read_text(encoding='utf-8'))
    for sample in capture.get('samples', []):
        unique.setdefault(sample['t_usec'], (path.name, sample))
    for event in capture.get('events', []):
        events.setdefault((event['t_usec'], event.get('category'), event.get('name')), event)
ordered = sorted(unique.values(), key=lambda row: row[1]['t_usec'])
ordered_events = sorted(events.values(), key=lambda event: event['t_usec'])
times = [event['t_usec'] for event in ordered_events]

def percentile(values, fraction):
    return sorted(values)[min(int((len(values) - 1) * fraction), len(values) - 1)] if values else None

def stats(rows):
    values = [sample.get('wall_ms', sample['frame_ms']) for _, sample in rows]
    return {'samples': len(rows), 'p50_wall_ms': percentile(values, .5),
            'p95_wall_ms': percentile(values, .95), 'p99_wall_ms': percentile(values, .99),
            'max_wall_ms': max(values, default=0), 'over_28_ms': sum(value > 28 for value in values)}

worst = []
for filename, sample in sorted(ordered, key=lambda row: row[1].get('wall_ms', 0), reverse=True)[:40]:
    end = sample['t_usec']
    start = end - int(sample['wall_ms'] * 1000)
    nearby = ordered_events[bisect.bisect_left(times, start):bisect.bisect_right(times, end)]
    worst.append({'file': filename, 't_usec': end, 'wall_ms': sample['wall_ms'],
                  'physics_frame_ms': sample.get('physics_frame_ms'), 'physics_ticks': sample.get('physics_ticks'),
                  'enemies': sample.get('enemies'), 'frame_phases': sample.get('frame_phases'),
                  'scene_change': sample.get('scene_change'), 'events_in_interval': nearby})
boss_events = []
for event in ordered_events:
    if event.get('category') == 'encounter' and event.get('name') in ('boss_started', 'miniboss_started'):
        following = [(filename, sample) for filename, sample in ordered
                     if sample['t_usec'] - sample.get('wall_ms', 0) * 1000 <= event['t_usec'] <= sample['t_usec']]
        boss_events.append({'event': event, 'containing_samples': [
            {'file': filename, 't_usec': sample['t_usec'], 'wall_ms': sample.get('wall_ms'),
             'physics_frame_ms': sample.get('physics_frame_ms'), 'frame_phases': sample.get('frame_phases')}
            for filename, sample in following]})
out = {'files': len(files), 'dedup_key': 'sample t_usec; event (t_usec, category, name)',
       'unique_events': len(events), 'all_captured': stats(ordered),
       'combat_without_scene_change': stats([row for row in ordered if row[1].get('enemies', 0) > 0 and not row[1].get('scene_change')]),
       'no_enemies_without_scene_change': stats([row for row in ordered if not row[1].get('enemies', 0) and not row[1].get('scene_change')]),
       'boss_entrances': boss_events, 'worst': worst,
       'limits': 'Rolling incident windows, not a complete session timeline. Entity counts and nested scheduler/chunk/flow data are cached up to 0.5 seconds. Physics is the whole scene interval, not enemy self time. Correlation does not prove causation.'}
destination = Path(__file__).with_name('deduplicated-captures.json')
destination.write_text(json.dumps(out, indent=2), encoding='utf-8')
print(json.dumps({key: out[key] for key in ('files', 'unique_events', 'all_captured', 'combat_without_scene_change', 'no_enemies_without_scene_change', 'boss_entrances')}, indent=2))
