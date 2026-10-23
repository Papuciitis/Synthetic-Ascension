"""Root-only parser -> unchanged native33 -> moving Game; --dry-run never launches.

Does not apply the shader. Root reviews/applies the scratch candidate separately.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
PROJECT = Path('/tmp/sa-wp2-cover')
NATIVE = Path('/var/tmp/sa-city22/cover')
OUT = NATIVE / 'moving-tree-r8'
RESULT = BASE / 'cover-tree-r8-queue.json'
TOOL_SHA = '4ab8a4100dbb99487f88f7965a812762dc29bae165eba96894adb17b23de1b1e'
SHADER_SHA = 'a399f0e37d1cadf82712c9efb668eb8d62bb0866521ded5d415846332318e367'
OLD_SHADER_SHA = '3ede2225821f313419eb87425c99f1eae24b504f4afe6b6d4d2c1345d09f6a87'
SHADER_PATH = 'core/systems/world/visibility/pickup_cover.gdshader'
PINS = {'/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/PickupCoverDensityNative.gd': 'a99056f6250a03384ca8eb429a2bf68c81fc998455bd59ad2f6288eb995dab50',
 '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/PickupCoverDensityNative.tscn': '130fb0879d5da2d55714b1c8bab3ceb4609d5c4ec0d933eaae4b1e8c5a68fa91',
 '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/external_source_parse_probe.gd': '2a9848140bc40f452eb6855405d59b2bd6c09946ff47ea37dfcb44f4e41a5a29',
 '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/external_source_parse_probe.tscn': '703521d388b2ad2fbee83b724af48a8b4586f15c07d7570d81b15feb1bdf4f0f',
 '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/guarded_engine.py': '9f8219f0a9b4ee81e9b797c58f48aa347f16c53cf788dbe5969bf3e2767f7eba',
 '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/pickup-cover-density-r8.gdshader': 'a399f0e37d1cadf82712c9efb668eb8d62bb0866521ded5d415846332318e367',
 '/tmp/sa-wp2-cover/core/systems/world/visibility/pickup_cover.gdshader': 'a399f0e37d1cadf82712c9efb668eb8d62bb0866521ded5d415846332318e367',
 '/tmp/sa-wp2-cover/core/systems/world/visibility/world_cover.gdshaderinc': 'd7f9057717ce97fa41aa3eb7bfe31071aaeb6cbaf59378d82db003aaf976d52a',
 '/tmp/sa-wp2-cover/tools/dev/WorldCoverMovingVisualProbe.gd': '4ab8a4100dbb99487f88f7965a812762dc29bae165eba96894adb17b23de1b1e',
 '/tmp/sa-wp2-cover/tools/dev/WorldCoverMovingVisualProbe.tscn': '88dae1b622468347b76b82a15ff69d4afbdf055b58513f2620db788c07a1bbc2',
 '/tmp/sa-wp2-cover/tools/tests/PickupCoverTest.gd': 'c6cabab7b4b7b2ab6cba7de011478564f991d2237c17f5de2cd0a78e49271d74',
 '/tmp/sa-wp2-cover/tools/tests/PickupCoverTest.tscn': '50327e049b30daf41c4fbf361b77542e281e522d31aa4a328ae0e353f9185146',
 '/var/tmp/sa-city22/packets/cover/capture_selected_imports.py': '3e0631d14b9d3007d927a79a588b2c9a69561ff5e0f8057cc358a983950b5c41'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(dry=False):
    for path, expected in PINS.items():
        actual = sha(Path(path))
        if dry and path == str(PROJECT / SHADER_PATH) and actual == OLD_SHADER_SHA:
            continue
        if actual != expected:
            raise RuntimeError('Reviewed source differs or scratch shader is not applied: ' + path)


def command(label, arguments, moving=False):
    cmd = ['python3', str(BASE/'guarded_engine.py'), '--label', label, '--project', str(PROJECT),
           '--start-temperature', '65', '--max-wait', '900', '--timeout', '600' if moving else '300', '--duty-percent', '25']
    if moving: cmd += ['--release-marker', '[Game] ready']
    return cmd + ['--'] + arguments


def sample(point):
    path = NATIVE / ('moving-tree-r8-imports-' + point + '.json')
    cmd = ['python3', '/var/tmp/sa-city22/packets/cover/capture_selected_imports.py',
           '--project', str(PROJECT), '--out', str(path), '--label', 'city22-cover-moving-tree-r8-' + point,
           '--asset', SHADER_PATH]
    for source in [BASE/'guarded_engine.py', Path(__file__).resolve(), ROOT/'.superpowers/claude-city-20261021/sa_engine.py',
                   ROOT/'.superpowers/claude-city-20261021/run_engine_slot.py']:
        cmd += ['--launcher', str(source)]
    subprocess.run(cmd, check=True)
    return str(path)


def receipt(label):
    paths = list((ROOT/'.superpowers/claude-city-20261021/runs').glob(label+'-*/run-results.json'))
    if len(paths) != 1: raise RuntimeError('One completed raw run required: ' + label)
    raw = json.loads(paths[0].read_text())
    thermal = json.loads((BASE/(label+'-thermal.json')).read_text())
    if (not raw.get('ended_utc') or raw.get('actual_exit') != 0 or raw.get('runner_exit') != 0
            or raw.get('stop_reason') != 'completed' or raw.get('diagnostics') != []
            or Path(raw.get('project_root', '')).resolve() != PROJECT
            or thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed'
            or thermal.get('received_signal') is not None):
        raise RuntimeError('Unclean actual runner/guard: ' + label)
    for path, expected in PINS.items():
        source = Path(path)
        if source.is_relative_to(PROJECT) and raw.get('source_hashes', {}).get(str(source.relative_to(PROJECT))) != expected:
            raise RuntimeError('Actual raw source differs: ' + path)
    stdout = (paths[0].parent/'logs/stdout.log').read_text()
    return raw, thermal, stdout, str(paths[0])


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--dry-run', action='store_true'); args = parser.parse_args()
    verify(dry=args.dry_run)
    cases = [
        ('city22-cover-tree-r8-parse', ['--headless', '--audio-driver', 'Dummy', str(BASE/'external_source_parse_probe.tscn'), '--',
            'res://tools/dev/WorldCoverMovingVisualProbe.gd', 'res://tools/tests/PickupCoverTest.gd', str(BASE/'PickupCoverDensityNative.gd')], False),
        ('city22-cover-pickup-r8-native', ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', str(BASE/'PickupCoverDensityNative.tscn')], False),
        ('city22-cover-moving-tree-r8', ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
            'res://tools/dev/WorldCoverMovingVisualProbe.tscn', '--', '--visible', '--runtime-fps=15', '--phase=tree',
            '--world-seed=16102026', '--target-building-id=944996572', '--target-chunk=0,3', '--review=small', '--out='+str(OUT)], True),
    ]
    plan = {'state':'planned_only', 'project':str(PROJECT), 'tool_sha256':TOOL_SHA, 'shader_sha256':SHADER_SHA,
            'shader_currently_applied':sha(PROJECT/SHADER_PATH)==SHADER_SHA, 'source_pins':PINS,
            'cases':[{'label':label, 'command':command(label, arguments, moving)} for label, arguments, moving in cases],
            'scope':'Camera-only third/fourth hold; same real owners, live AI/physics, unchanged native33 predicates; finite imports, no contrast/performance acceptance.'}
    if args.dry_run: print(json.dumps(plan, indent=2)); return
    occupied = [RESULT, OUT] + [BASE/(label+'-thermal.json') for label, _, _ in cases]
    occupied += [path for label, _, _ in cases for path in (ROOT/'.superpowers/claude-city-20261021/runs').glob(label+'-*')]
    occupied += [NATIVE/('moving-tree-r8-imports-'+point+'.json') for point in ['before','after']]
    if any(path.exists() for path in occupied): raise RuntimeError('Fresh R8 outputs required')
    try:
        for index, (label, arguments, moving) in enumerate(cases):
            verify()
            plan['state'] = label; RESULT.write_text(json.dumps(plan,indent=2)+'\n')
            if moving: plan['imports_before'] = sample('before')
            try: code = subprocess.run(command(label, arguments, moving)).returncode
            finally:
                if moving: plan['imports_after'] = sample('after')
            plan['cases'][index]['wrapper_exit'] = code
            if code != 0: raise RuntimeError('Case runner failed: ' + label)
            verify()
            raw, thermal, stdout, path = receipt(label); plan['cases'][index]['raw_run_record'] = path
            if index == 0 and 'ExternalSourceParseProbe: checked=3 failures=0' not in stdout:
                raise RuntimeError('Scoped three-source parser verdict missing')
            if index == 1 and ('PickupCoverTest passes=33 failures=0' not in stdout
                    or 'PickupCoverDensityNative: driver=opengl3 cap=15 physics=60 original_predicates=33' not in stdout
                    or 'native pixel cases skipped' in stdout):
                raise RuntimeError('Original native33 with actual15FPS/60Hz did not pass')
        manifest = json.loads((OUT/'visual-cover-info.json').read_text()); normal = manifest.get('normal_equipment_comparison', {})
        good = manifest.get('failures')==0 and manifest.get('save_writes')==0 and manifest.get('phase')=='tree'
        good = good and manifest.get('engine_max_fps')==15 and manifest.get('physics_ticks_per_second')==60
        good = good and len(manifest.get('tree_plates', []))==3 and len(normal.get('before', []))==len(normal.get('after', []))==2
        good = good and all(normal.get(key) is True for key in ['passed','same_camera_and_view','comparison_camera_only_held','health_stays_locked','original_locked_counts_preserved'])
        good = good and all((OUT/name).is_file() for name in ['tree-front.png','tree-behind.png','tree-front-restored.png','tree-normal-equipment.png'])
        if not good: raise RuntimeError('Strict original tree/fixed-view/normal-owner comparison gates failed')
        plan['state'] = 'clean_functional_capture_requires_actual_image_review'
    except BaseException as error:
        plan['state']='failed_or_incomplete_not_acceptance'; plan['error']=repr(error)
        raise
    finally:
        RESULT.write_text(json.dumps(plan,indent=2)+'\n')


if __name__ == '__main__': main()
