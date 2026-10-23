"""Root-run scoped parser + bounded native tree retry; --dry-run never launches."""
from pathlib import Path
import argparse, hashlib, json, subprocess, time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
PROJECT = Path('/tmp/sa-wp2-cover')
NATIVE = Path('/var/tmp/sa-city22/cover')
TOOL_SHA = '00f7eba66cffef7961f211e21410ed315244d37280fd8a33bf451c57c196527f'
CASE = 'tree-r6'
RESULT = BASE / 'cover-tree-r6-queue.json'


def command(label, engine_args, native=False):
    cmd = ['python3', str(BASE/'guarded_engine.py'), '--label', label, '--project', str(PROJECT),
           '--start-temperature', '65', '--max-wait', '900', '--timeout', '600' if native else '300']
    if native: cmd += ['--release-marker', '[Game] ready']
    else: cmd += ['--duty-percent', '25']
    return cmd + ['--'] + engine_args


def sample(point):
    out = NATIVE / f'moving-{CASE}-imports-{point}.json'
    cmd = ['python3', '/var/tmp/sa-city22/packets/cover/capture_selected_imports.py', '--project', str(PROJECT),
           '--out', str(out), '--label', f'city22-cover-moving-{CASE}-{point}']
    for path in [BASE/'guarded_engine.py', Path(__file__).resolve(), ROOT/'.superpowers/claude-city-20261021/sa_engine.py',
                 ROOT/'.superpowers/claude-city-20261021/run_engine_slot.py', PROJECT/'tools/dev/WorldCoverMovingVisualProbe.gd']:
        cmd += ['--launcher', str(path)]
    subprocess.run(cmd, check=True)
    return str(out)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--dry-run', action='store_true'); args = parser.parse_args()
    source = PROJECT/'tools/dev/WorldCoverMovingVisualProbe.gd'
    if hashlib.sha256(source.read_bytes()).hexdigest() != TOOL_SHA: raise SystemExit('Frozen r6 tool source differs')
    parse_label = 'city22-cover-tree-r6-parse'; native_label = 'city22-cover-moving-tree-r6'
    parse = command(parse_label, ['--headless', '--audio-driver', 'Dummy', str(BASE/'external_source_parse_probe.tscn'),
                                '--', 'res://tools/dev/WorldCoverMovingVisualProbe.gd'])
    native = command(native_label, ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
        'res://tools/dev/WorldCoverMovingVisualProbe.tscn', '--', '--visible', '--runtime-fps=15', '--phase=tree',
        '--world-seed=16102026', '--target-building-id=944996572', '--target-chunk=0,3', '--review=small',
        '--out='+str(NATIVE/('moving-'+CASE))], native=True)
    plan = {'state':'planned_only', 'tool_sha256':TOOL_SHA, 'parse_command':parse, 'native_command':native,
            'start_gate_c':65, 'runtime_limits_c':[90,85,3], 'native_render_fps':15, 'physics_unchanged':True}
    if args.dry_run: print(json.dumps(plan, indent=2)); return
    occupied = [RESULT, NATIVE/('moving-'+CASE)] + [BASE/(label+'-thermal.json') for label in [parse_label,native_label]]
    occupied += [NATIVE/f'moving-{CASE}-imports-{point}.json' for point in ['before','after']]
    if any(path.exists() for path in occupied): raise SystemExit('Fresh r6 outputs required; refusing to overwrite evidence')
    plan['state'] = 'running_scoped_parse'; RESULT.write_text(json.dumps(plan,indent=2)+'\n')
    plan['parse_returncode'] = subprocess.run(parse).returncode
    if plan['parse_returncode']:
        plan['state']='parse_failed_or_incomplete'; RESULT.write_text(json.dumps(plan,indent=2)+'\n'); raise SystemExit(plan['parse_returncode'])
    time.sleep(3)
    plan['imports_before'] = sample('before')
    try: plan['native_returncode'] = subprocess.run(native).returncode
    finally:
        plan['imports_after'] = sample('after')
        plan['state']='native_finished_not_yet_accepted'
        RESULT.write_text(json.dumps(plan,indent=2)+'\n')
    thermal = json.loads((BASE/(native_label+'-thermal.json')).read_text())
    manifest_path = NATIVE/('moving-'+CASE)/'visual-cover-info.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
    records = sorted((ROOT/'.superpowers/claude-city-20261021/runs').glob(native_label+'-*/run-results.json'))
    record = json.loads(records[-1].read_text()) if records else {}
    clean = plan['native_returncode']==0 and thermal.get('reason')=='completed' and thermal.get('wrapper_exit')==0
    clean = clean and record.get('actual_exit')==0 and record.get('stop_reason')=='completed' and not record.get('diagnostics')
    clean = clean and record.get('source_hashes',{}).get('tools/dev/WorldCoverMovingVisualProbe.gd')==TOOL_SHA
    clean = clean and manifest.get('failures')==0 and manifest.get('save_writes')==0 and manifest.get('engine_max_fps')==15 and manifest.get('physics_ticks_per_second')==60
    plan['state']='clean_execution_requires_image_review' if clean else 'failed_or_incomplete_not_acceptance'
    plan['manifest_failures']=manifest.get('failures'); plan['outer_reason']=thermal.get('reason')
    plan['native_run_record']=str(records[-1]) if records else None; plan['diagnostics']=record.get('diagnostics')
    RESULT.write_text(json.dumps(plan,indent=2)+'\n')
    print('QUEUE_RESULT',native_label,plan['native_returncode'],plan['state'],flush=True)
    if not clean: raise SystemExit(plan['native_returncode'] or 1)


if __name__ == '__main__': main()
