"""Prepare a finite original-art one-house packet. HOST ONLY: no engine launch.

The JSON allowlist is frozen input, never a dependency resolver. Missing imports
are a declared future qualification; this preparation has no runnable harness.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = Path(__file__).with_name('real_household_fixture_allowlist.json')
CONTEXT = b'extends Node\nvar attempt_segment: int = 7\n'
CACHE_SHA = '14a57921e0351de7a7ddbe343e783d7341cda75b6a8e774079e866dcb960d8b7'
DERIVED_SHA = 'd114555c681e5bd770ce7ecddf3fff72afc2715fe88b0f4455f5a61f0f394ec4'
GUARD_SHA = 'dfe25730c5e24ac0e4ed6031af387c5fa2038ef30c37c1c7ac087856c19e7382'
PROFILES = {
    'import': dict(startup_ram_mb=832, startup_commit_mb=1536, private_mb=384, timeout_seconds=180, running_ram_mb=384, running_commit_mb=768),
    'parse': dict(startup_ram_mb=832, startup_commit_mb=1536, private_mb=384, timeout_seconds=180, running_ram_mb=384, running_commit_mb=768),
    'native': dict(startup_ram_mb=960, startup_commit_mb=1536, private_mb=512, timeout_seconds=120, running_ram_mb=384, running_commit_mb=768),
    'full_game_unchanged': dict(startup_ram_mb=1536, startup_commit_mb=3072, private_mb=1200),
}
TEXT_SOURCE_SUFFIXES = {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres'}
PREVIEW = '.superpowers/sdd/2026-11-04-trailer-yard-preview/'
INPUTS = [
    ('historical sample', 'docs/art/reference/2026-10-22-linux-streets/sources/blobs/43938c18fa45cbc8ca3248d4bdbcf3bf22922c23789e5bcd10ff5a193c60390b-city22-street-continuity-part-08-part08-v1.json', '43938c18fa45cbc8ca3248d4bdbcf3bf22922c23789e5bcd10ff5a193c60390b'),
    ('historical run binding', 'docs/art/reference/2026-10-22-linux-streets/sources/run-bindings/city22-street-continuity-part-08-part08-v1-1.json', 'f2abbe70c7e2e34a8ce7b373052c4b78ee614558253127574513ab89cd23c179'),
    ('historical run result', 'docs/art/reference/2026-10-22-linux-streets/runs/city22-street-continuity-part-08-part08-v1-1/run-results.json.gz', '73769e1806a46ee5ae27292e3851211814854b7d5e5d84fd53ce2a937dd80c3f'),
    ('actual Godot derived geometry', 'docs/audits/evidence/2026-11-04-real-yard-candidates/fix1/fixture/derived-results.json', DERIVED_SHA),
]


class PreparationBlocked(ValueError):
    """Preparation evidence exists, but a required original input is invalid."""


def sha(body):
    return hashlib.sha256(body).hexdigest()


def load_allowlist():
    return json.loads(ALLOWLIST.read_text(encoding='utf-8'))


def audit_context(body):
    if body != CONTEXT:
        raise ValueError('fixture segment-context must contain only extends Node and attempt_segment = 7')


def safe_source_path(path):
    parts = PurePosixPath(path).parts
    if not path or '\\' in path or PurePosixPath(path).is_absolute() or '..' in parts or ':' in path:
        raise ValueError('unsafe source path: '+path)
    if path.startswith(('autoload/', 'ui/', 'core/systems/enemy_world/')) or any('manager' in p.lower() for p in parts) or any(p.lower() in ('game.gd', 'game.tscn') for p in parts):
        raise ValueError('prohibited production source: '+path)
    if path.startswith('.godot/') and not path.startswith('.godot/imported/'):
        raise ValueError('prohibited main cache source: '+path)


def validate_allowlist(manifest):
    seen = set()
    for entry in manifest['files']:
        path = entry['path']
        safe_source_path(path)
        if path in seen:
            raise ValueError('duplicate source path: '+path)
        seen.add(path)
        if entry.get('missing_at_freeze'):
            if entry['role'] != 'original imported artifact' or entry['sha256'] is not None or entry['size'] is not None:
                raise ValueError('invalid absent artifact declaration: '+path)
        elif not re.fullmatch(r'[0-9a-f]{64}', entry.get('sha256', '')) or not isinstance(entry['size'], int):
            raise ValueError('invalid pin: '+path)
    for path in manifest['roots']:
        if path not in seen:
            raise ValueError('missing root: '+path)


def verify_available_pins(root, manifest):
    """Reject changed, newly appeared, or unexpectedly absent frozen inputs."""
    validate_allowlist(manifest)
    for entry in manifest['files']:
        path = root / entry['path']
        if entry.get('missing_at_freeze'):
            if path.exists():
                raise ValueError('pin mismatch; frozen absent artifact appeared: '+entry['path'])
            continue
        if not path.is_file():
            raise ValueError('pin mismatch; missing source: '+entry['path'])
        body = path.read_bytes()
        if len(body) != entry['size'] or sha(body) != entry['sha256']:
            raise ValueError('pin mismatch: '+entry['path'])


def audit_source(path, body, manifest):
    text = body.decode('utf-8-sig')
    refs = re.findall(r'["\']res://([^"\'\n]+)["\']', text)
    allowed = set(manifest['allowed_references'].get(path, []))
    for ref in refs:
        if ref not in allowed:
            raise ValueError('unknown reference in '+path+': '+ref)
    # Strip comments for property reads; no source rewrites are performed.
    code = '\n'.join(line.split('#', 1)[0] for line in text.splitlines())
    for prop in re.findall(r'\bGlobal\s*\.\s*([A-Za-z_]\w*)', code):
        if prop != 'attempt_segment':
            raise ValueError('undeclared Global context property: '+prop)
    for singleton in manifest['singleton_names']:
        if singleton != 'Global' and re.search(r'\b'+re.escape(singleton)+r'\b', code):
            raise ValueError('prohibited singleton: '+singleton+' in '+path)
    if re.search(r'/root/|\bGlobal\s*\[|\bGlobal\s*\.\s*(?:get|call)\s*\(', code):
        raise ValueError('undeclared singleton/context lookup in '+path)


def validate_ground_cache(root, manifest):
    cache = root / manifest['ground_cache']['path']
    body = cache.read_bytes() if cache.is_file() else b''
    if len(body) != 10134012 or sha(body) != CACHE_SHA:
        raise ValueError('actual WorldArt cache pin mismatch; no leaf or rebuild fallback')
    data = json.loads((root / manifest['ground_cache']['manifest']).read_text(encoding='utf-8-sig'))
    if data.get('cache_sha256') != CACHE_SHA or data.get('algorithm_revision') != 1 or data.get('layer_size') != 512 or data.get('format') != 'RGB8 with generated mipmaps' or len(data.get('sources', [])) != 14:
        raise ValueError('actual WorldArt manifest prerequisites invalid')
    records = []
    for source in data['sources']:
        path = source['path'].removeprefix('res://')
        safe_source_path(path)
        record = dict(path=path, source_valid=False, sidecar_valid=False)
        for suffix, key, field in [('', 'sha256', 'source_valid'), ('.import', 'import_sha256', 'sidecar_valid')]:
            file = root / (path+suffix)
            record[field] = file.is_file() and sha(file.read_bytes()) == source[key]
        records.append(record)
    invalid = [x for x in records if not x['source_valid'] or not x['sidecar_valid']]
    if invalid:
        raise ValueError('actual WorldArt manifest source/sidecar pin mismatch: '+json.dumps(invalid))
    return dict(cache_size=len(body), cache_sha256=sha(body), sources=records, valid=True)


def source_audit(manifest):
    result = dict(time_references=[], animation_references=[], uid_references=[], classes=[])
    files = {e['path'] for e in manifest['files']}
    uid_values = {}
    for path in files:
        if path.endswith('.gd.uid'):
            uid_values[(ROOT / path).read_text().strip()] = path
        elif path.endswith('.import'):
            uid = re.search(r'^uid="([^"]+)"', (ROOT / path).read_text(encoding='utf-8-sig'), re.M)
            if uid:
                uid_values[uid.group(1)] = path
    for entry in manifest['files']:
        path = entry['path']
        if Path(path).suffix not in TEXT_SOURCE_SUFFIXES:
            continue
        body = (ROOT / path).read_bytes()
        audit_source(path, body, manifest)
        text = body.decode('utf-8-sig')
        for number, line in enumerate(text.splitlines(), 1):
            if re.search(r'\bTIME\b', line):
                result['time_references'].append(dict(path=path,line=number,text=line.strip()))
            if re.search(r'create_tween|tween_method|AnimationPlayer|AnimatedSprite|func _process', line):
                result['animation_references'].append(dict(path=path,line=number,text=line.strip()))
            if '[ext_resource ' in line and 'uid=' in line:
                uid = re.search(r'uid="([^"]+)"',line).group(1)
                result['uid_references'].append(dict(path=path,line=number,uid=uid,source_metadata=uid_values.get(uid),present=uid in uid_values))
        name = re.search(r'^class_name\s+(\w+)',text,re.M)
        base = re.search(r'^extends\s+(\w+)',text,re.M)
        if name and base:
            result['classes'].append(dict(name=name.group(1),base=base.group(1),path=path))
    return result


def _project_settings(original):
    # Keep the exact six authored shader globals; retain their source snapshot.
    globals_match = re.search(r'\[shader_globals\](.*?)(?=\n\[|\Z)', original, re.S)
    if not globals_match or sorted(re.findall(r'^(sa_weather_\w+)=', globals_match.group(1), re.M)) != sorted(['sa_weather_damp','sa_weather_damp_tint','sa_weather_damp_mask','sa_weather_lichen','sa_weather_lichen_tint','sa_weather_lichen_mask']):
        raise ValueError('shader globals no longer contain exactly the expected six inputs')
    return ('config_version=5\n[application]\nconfig/name="Real household PREPARATION ONLY"\n'
            '[autoload]\nGlobal="*res://fixture/SegmentContext.gd"\n'
            '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/mode=0\nwindow/stretch/mode="canvas_items"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/canvas_textures/default_texture_filter=2\n2d/snap/snap_2d_transforms_to_pixel=true\n'
            '[shader_globals]'+globals_match.group(1)).encode('utf-8')


def build(out: Path) -> None:
    out = Path(out).resolve()
    if out.exists():
        raise FileExistsError('Refusing to overwrite existing fixture evidence: '+str(out))
    out.mkdir(parents=True)
    (out / '.gdignore').write_bytes(b'')  # FIRST artifact in every fresh packet.
    for directory in ['fixture', 'import-stage', 'launcher-sources', 'source-inputs']:
        (out / directory).mkdir()
    pins = []
    inventory = {}
    status = dict(identity='real-household-prepare-only-v1', native_ready=False, full_game=False,
                  prepared=False, engine_launched=False, profiles=PROFILES,
                  profile_qualification='parent-accepted finite experiment; unmeasured',
                  pending=['runtime harness and scene', 'new guarded runner', 'asset-only import qualification', 'finite closure parse qualification', 'native qualification at each output size'],
                  limitations=['isolated recovered-lot replay; no complete city', 'no private-memory or GPU fit claim from PNG dimensions', 'later phases must use a fresh root; this packet is immutable evidence'])

    def put(relative, body, role, source=None, expected=None):
        destination = out / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        before = sha(body)
        if expected is not None and before != expected:
            raise ValueError('pin mismatch: '+str(source))
        destination.write_bytes(body)
        copied = destination.read_bytes()
        after = sha(source.read_bytes()) if source else None
        if copied != body or (source and after != before):
            raise ValueError('source/copy changed during snapshot: '+relative)
        pins.append(dict(path=relative, role=role, bytes=len(copied), source_path=str(source.resolve()) if source else None, source_sha256_before=before if source else None, source_sha256_after=after, copied_sha256=sha(copied)))

    def copy_file(source, relative, role, expected=None):
        put(relative, source.read_bytes(), role, source, expected)

    def write_json(relative, value):
        (out / relative).write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')

    try:
        manifest = load_allowlist()
        validate_allowlist(manifest)
        verify_available_pins(ROOT, manifest)
        inventory['ground_cache_validation'] = validate_ground_cache(ROOT, manifest)
        inventory['source_audit'] = source_audit(manifest)
        inventory['assets'] = []
        missing_imports = []
        missing_settings = []
        entries = {e['path']: e for e in manifest['files']}
        approved = set(manifest.get('approved_local_import_settings', []))
        for asset in manifest['assets']:
            path = asset['path']
            body = (ROOT / path).read_bytes()
            if body[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError('PNG header mismatch: '+path)
            width, height = struct.unpack('>II', body[16:24])
            absent = [p for p in asset['imported_artifacts'] if entries[p].get('missing_at_freeze')]
            item = dict(asset, width=width, height=height, compressed_disk_bytes=len(body), base_rgba8_storage_bytes=width*height*4, missing_imported_artifacts=absent)
            inventory['assets'].append(item)
            if asset['import_required'] and absent:
                missing_imports.append(dict(path=path,artifacts=absent))
            if asset['import_required'] and not asset['original_settings_verified'] and asset['sidecar'] not in approved:
                missing_settings.append(asset['sidecar'])
        inventory['missing_visual_imports'] = missing_imports
        inventory['missing_original_import_settings'] = missing_settings
        inventory['approved_local_import_settings'] = sorted(approved)
        inventory['uncalled_dynamic_branches'] = manifest.get('uncalled_dynamic_branches', [])
        inventory['storage_estimates_are_not_process_or_gpu_measurements'] = True
        inventory['counts'] = dict(files=len(entries), available_files=sum(not e.get('missing_at_freeze',False) for e in entries.values()), absent_import_artifacts=sum(e.get('missing_at_freeze',False) for e in entries.values()), pngs=len(inventory['assets']), png_disk_bytes=sum(x['compressed_disk_bytes'] for x in inventory['assets']), base_rgba8_storage_bytes=sum(x['base_rgba8_storage_bytes'] for x in inventory['assets']), original_settings_missing=len(missing_settings), approved_local_settings=len(approved), missing_visual_imports=len(missing_imports))
        for entry in manifest['files']:
            if not entry.get('missing_at_freeze'):
                copy_file(ROOT / entry['path'], 'fixture/'+entry['path'], entry['role'], entry['sha256'])
        if missing_settings:
            raise PreparationBlocked('specific new-import decision needed for original settings: '+', '.join(missing_settings))
        # Import stage has only missing REQUIRED visual PNGs and their byte-exact
        # declared settings. Ground-manifest inputs never enter this project.
        for item in missing_imports:
            for path in [item['path'], item['path']+'.import']:
                copy_file(ROOT / path, 'import-stage/'+path, entries[path]['role'], entries[path]['sha256'])
        put('import-stage/project.godot', b'config_version=5\n[application]\nconfig/name="Finite visual import stage"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', 'asset-only staging configuration; no scripts/autoload/main scene')
        audit_context(CONTEXT)
        put('fixture/fixture/SegmentContext.gd', CONTEXT, 'fixture segment-context double')
        copy_file(ROOT / 'project.godot', 'source-inputs/project-original.godot', 'production configuration snapshot, never runnable')
        put('fixture/project.godot', _project_settings((ROOT / 'project.godot').read_text(encoding='utf-8-sig')), 'preparation-only project configuration; no runnable main scene')
        classes=[]
        for entry in inventory['source_audit']['classes']:
            classes.append('{\n"base": &'+json.dumps(entry['base'])+',\n"class": &'+json.dumps(entry['name'])+',\n"icon": "",\n"is_abstract": false,\n"is_tool": false,\n"language": &"GDScript",\n"path": '+json.dumps('res://'+entry['path'])+'\n}')
        put('fixture/.godot/global_script_class_cache.cfg', ('list=['+', '.join(classes)+']\n').encode(), 'minimal generated class metadata from actual declarations; no main cache copy')
        bindings = dict(observed=dict(chunk=[-8,-4],plan_seed=1208827904,attempt_seed=16102028,segment=7,family='canal_services',generation_attempt=1,rect=[21,7,8,7],door_position=[25,13],door_direction=[0,1],building_usage='row_house',civic=False,irregular=False,infill=False), derived=dict(visual_seed=1910440753,variant=1,door_width=2,chunk_origin_pixels=[-16384,-8192],geometry_source_sha256=DERIVED_SHA), unknown=['historical garden contact','historical party edges/extra reach','neighbours/props/semantics/occlusion','physical volumes/furnishing'], fixture_choices=dict(party_edges=0,party_extra_pixels=[0,0],neighbours=[],volume=None), source_records=[])
        for index, (role, path, digest) in enumerate(INPUTS):
            # Evidence roots are already deep on Windows. Keep short packet
            # names; exact original filenames remain in bindings and pins.
            target = 'source-inputs/'+str(index).zfill(2)+'-input'+''.join(Path(path).suffixes)
            copy_file(ROOT / path, target, role, digest)
            bindings['source_records'].append(dict(role=role,path=path,packet_path=target,sha256=digest))
        actual = json.loads((ROOT / INPUTS[3][1]).read_text(encoding='utf-8-sig'))
        bindings['derived']['actual_result'] = actual['derived_verified'][0]
        put('input-bindings.json', (json.dumps(bindings,indent=2,ensure_ascii=False)+'\n').encode('utf-8'), 'observed/derived/unknown input binding record')
        for path in ['tools/tests/build_real_household_fixture.py','tools/tests/real_household_fixture_allowlist.json','tools/tests/test_real_household_fixture_contract.py','tools/capture/city_resource_guard.ps1']:
            copy_file(ROOT / path,'launcher-sources/'+Path(path).name,'exact preparation tool/guard snapshot',GUARD_SHA if path.endswith('city_resource_guard.ps1') else None)
        status['prepared'] = True
        status['runner_snapshot'] = 'pending; runner does not yet exist'
        status['harness_snapshot'] = 'pending; harness does not yet exist'
        verify_available_pins(ROOT, manifest)
    except Exception as error:
        status['failure'] = str(error)
        (out / 'build-failure.txt').write_text(str(error)+'\n',encoding='utf-8')
        raise
    finally:
        write_json('source-pins.json', pins)
        write_json('asset-inventory.json', inventory)
        write_json('fixture.json', status)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    build(args.out)
    print(json.dumps(dict(out=str(args.out.resolve()), native_ready=False, engine_launched=False)))
