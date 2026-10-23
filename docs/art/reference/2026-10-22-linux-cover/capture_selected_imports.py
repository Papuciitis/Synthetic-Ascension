#!/usr/bin/env python3
"""Read-only finite import/launcher sample. Root invokes before/after a run.

This does not claim a full Game dependency closure or reconstruct old launch
state. No output is written in the project; choose a fresh absolute JSON path.
Pass the actual current guarded_engine.py path with --launcher; do not use an
older renamed wrapper snapshot as a substitute for the launch implementation.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re

SEEDS = [
    'assets/world/city_block/clay.png',
    'assets/world/city_block/slate.png',
    'assets/world/city_block/temperate_tree.png',
    'assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png',
    'assets/textures/characters/baked/grunt_frames.tres',
    'assets/textures/characters/baked/spitter_frames.tres',
    'assets/textures/characters/baked/human_frames.tres',
    'assets/textures/characters/baked/dragonborn_frames.tres',
    'assets/textures/characters/baked/elf_frames.tres',
    'assets/textures/characters/baked/warforged_frames.tres',
    'core/actors/enemy/EnemySpec_Brute.tres',
    'scenes/world/pickups/ItemPickup.tscn',
    'scenes/world/pickups/HealthPickup.tscn',
]
TEXT = {'.tres', '.tscn', '.import'}
MAX_FILE = 32 * 1024 * 1024
MAX_TOTAL = 256 * 1024 * 1024


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--label', required=True)
    parser.add_argument('--launcher', action='append', type=Path, default=[])
    parser.add_argument('--asset', action='append', default=[])
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.out.resolve()
    if output.exists():
        raise SystemExit('Refusing to overwrite a recorded sample: ' + str(output))
    if output.is_relative_to(project):
        raise SystemExit('Output must be outside the active project')
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    pending = [(path, 'selected source seed') for path in SEEDS + args.asset]
    for launcher in args.launcher:
        pending.append((str(launcher.resolve()), 'explicit launcher sample'))
    records, seen, total = [], set(), 0
    while pending:
        name, reason = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        path = Path(name) if Path(name).is_absolute() else project / name
        entry = {'path': name, 'reason': reason}
        if not path.is_file():
            entry['status'] = 'missing_at_sample'
            records.append(entry)
            continue
        size = path.stat().st_size
        if size > MAX_FILE or total + size > MAX_TOTAL:
            entry.update(status='omitted_size_bound', bytes=size)
            records.append(entry)
            continue
        data = path.read_bytes()
        total += len(data)
        entry.update(status='sampled', bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        records.append(entry)
        if not Path(name).is_absolute() and not name.endswith('.import') and (project / (name + '.import')).is_file():
            pending.append((name + '.import', 'import sidecar for ' + name))
        if path.suffix in TEXT:
            for ref in re.findall(r'res://[^"\s\)\],;]+', data.decode(errors='replace')):
                relative = ref[6:]
                if '%' in relative or '{' in relative:
                    continue
                if Path(relative).suffix in ['.tres', '.png', '.jpg', '.webp', '.svg', '.ctex', '.md5']:
                    pending.append((relative, 'literal resource reference from ' + name))
                    if relative.startswith('.godot/imported/') and relative.endswith('.ctex'):
                        pending.append((str(Path(relative).with_suffix('.md5')), 'existing import metadata companion for ' + relative))
    finished = datetime.datetime.now(datetime.timezone.utc).isoformat()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'schema': 1, 'label': args.label, 'project': str(project),
        'started_utc': started, 'ended_utc': finished, 'sampled_bytes': total,
        'per_file_limit': MAX_FILE, 'total_limit': MAX_TOTAL,
        'scope': 'Finite selected cover canopy/roof/actor/pickup resources and their literal texture/import references, plus explicit launcher paths. Not full Game closure or load telemetry.',
        'seeds': SEEDS + args.asset, 'entries': sorted(records, key=lambda item: item['path'])}, indent=2) + '\n')
    print(json.dumps({'out': str(output), 'entries': len(records), 'sampled_bytes': total,
                      'omitted_or_missing': sum(item['status'] != 'sampled' for item in records)}))


if __name__ == '__main__':
    main()
