#!/usr/bin/env python3
"""Build a source-bound prop evidence packet from completed records; never runs Godot.

Root invokes after the fresh independent parser/48-check fixture is complete.
Only writes inside --out (default this scratch packet); no source/Git mutations.
"""
from pathlib import Path
import argparse
import gzip
import hashlib
import importlib.util
import json
import re
import subprocess

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
CONTROL = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
PROJECT = Path('/tmp/sa-c22-props')
META = CONTROL / 'prop-shadow-acceptance-source.json'
META_SHA = '34a1c6af13108bcf63f10aefb1d5f96197dda7b9b48bbe24ce9a651b6f1b3561'
PREP = CONTROL / 'prop-shadow-final-9b7-prep'

NATIVE_PREP = CONTROL / 'prop-shadow-native-r2'
NATIVE_META_SHA = '2696f6a53f5fe7cdfc5e38cece5bd584bf70aba8c4eed11313a46f7da5a81760'
NATIVE_DRIVER_SHA = '917c62cdadd94e5469a901075e4f1a7ae971cd74ed124b0dde150fa845e81878'
NATIVE_PROOF_SHA = '5fb708becc0b5c878efb7b75fb8946109ea9b0ef6e6f594e93d59fc49d49a566'
NATIVE_PACKET_PREP = CONTROL / 'prop-packet-native-r2-prep'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_text())


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def clean(raw_path):
    raw = load(raw_path)
    label = re.sub(r'-\d+$', '', raw_path.parent.name)
    thermal_path = CONTROL / (label + '-thermal.json')
    thermal = load(thermal_path)
    require(raw.get('ended_utc') and raw.get('actual_exit') == 0
            and raw.get('runner_exit') == 0 and raw.get('stop_reason') == 'completed'
            and not raw.get('diagnostics') and raw.get('source_hashes'), 'Unclean raw: ' + str(raw_path))
    require(thermal.get('reason') == 'completed' and thermal.get('wrapper_exit') == 0,
            'Unclean guard: ' + str(thermal_path))
    return raw, thermal_path


def bind(raw, expected):
    require(all(raw['source_hashes'].get(path) == digest for path, digest in expected.items()),
            'Raw source mismatch in ' + str(raw.get('run_root')))


def validate_objective_ground_review(review, expected_source, before, after):
    require(review.get('current_objective_source_sha256') == expected_source,
            'Objective ground-control review source changed')
    require(review.get('ground_control_bytes_identical') is True,
            'Objective ground-control review is missing a positive identity verdict')
    for side, directory in [('before', before), ('after', after)]:
        recorded = review.get('sources', {}).get(side, {})
        for name in ['objectives.png', 'provenance.json']:
            require(recorded.get(name) == sha((directory / name).read_bytes()),
                    'Objective ground-control review is stale: ' + side + '/' + name)


def independent_48_clean(acceptance):
    return (acceptance.get('suite') == 'CityPropShadowAcceptance'
            and acceptance.get('passes') == 48 and acceptance.get('failures') == 0
            and len(acceptance.get('checks', [])) == 48
            and all(row.get('ok') is True for row in acceptance['checks']))


def native_fixture_evidence(suffix, expected_all, acceptance_root=Path('/var/tmp/sa-city22/prop-shadow-acceptance')):
    require(sha((NATIVE_PREP / 'source.json').read_bytes()) == NATIVE_META_SHA
            and sha((NATIVE_PREP / 'queue.py').read_bytes()) == NATIVE_DRIVER_SHA
            and sha((NATIVE_PREP / 'README.md').read_bytes()) == NATIVE_PROOF_SHA,
            'Reviewed native execution/proof sources changed')
    spec = importlib.util.spec_from_file_location('prop_packet_native_r2', NATIVE_PREP / 'queue.py')
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    observed, meta = native.verify()
    require(observed == expected_all, 'Native execution changed the original57 source expectations')
    prerequisite = native.parser_receipt(observed)
    directory = acceptance_root / suffix
    queue, acceptance = load(directory / 'queue.json'), load(directory / 'acceptance.json')
    require(queue.get('passed') is True and independent_48_clean(acceptance), 'Native unchanged48 fixture incomplete')
    require(queue.get('source_before') == observed and queue.get('source_after') == observed
            and queue.get('source_metadata_path') == str(NATIVE_PREP / 'source.json')
            and queue.get('source_metadata_sha256') == NATIVE_META_SHA
            and queue.get('baseline_metadata_sha256') == META_SHA
            and queue.get('native_execution_bindings') == meta['native_execution_bindings']
            and queue.get('execution_protocol') == meta['execution_protocol'], 'Native queue source/protocol receipt changed')
    require(queue.get('prerequisite_parser') == prerequisite, 'Reused six-source parser receipt differs')
    cases = queue.get('cases', [])
    label = 'city22-prop-shadow-fixture-' + suffix
    require(len(cases) == 1 and cases[0].get('role') == 'fixture' and cases[0].get('label') == label
            and cases[0].get('wrapper_exit') == 0, 'Exactly one new native fixture required')
    raw, receipt = native.clean_run(label)
    require(cases[0].get('raw_result') == receipt, 'Actual native raw/guard receipt changed')
    banner = native.validate_native(raw, receipt, directory / 'acceptance.json')
    require(queue.get('actual_renderer_banner') == banner
            and queue.get('native_state_sha256') == sha((directory / 'native-state.json').read_bytes())
            and queue.get('acceptance_sha256') == sha((directory / 'acceptance.json').read_bytes()),
            'Actual hardware banner/state/48-check output binding changed')
    old = meta['failed_headless_attempt']
    for row in old.values():
        require(sha(Path(row['path']).read_bytes()) == row['sha256'], 'Original headless failure evidence changed')
    old_raw, old_guard, old_acceptance = [load(Path(old[key]['path'])) for key in ['raw', 'guard', 'acceptance']]
    require(old_raw.get('actual_exit') == 1 and old_raw.get('runner_exit') == 1
            and old_raw.get('stop_reason') == 'nonzero_exit' and '--headless' in old_raw.get('command', [])
            and old_raw.get('diagnostics') == list(dict.fromkeys('ERROR: FAIL: ' + row['label'] for row in old_acceptance.get('checks', []) if row.get('ok') is False)) and old_guard.get('wrapper_exit') == 1
            and old_acceptance.get('passes') == 25 and old_acceptance.get('failures') == 15
            and len(old_acceptance.get('checks', [])) == 40, 'Original headless25/15 result no longer matches preserved actual failure')
    parser_raw = Path(prerequisite['path']); native_raw = Path(receipt['path'])
    records = [('parse-reused', parser_raw, Path(prerequisite['thermal_path']), load(parser_raw)),
               ('fixture-native', native_raw, Path(receipt['thermal_path']), raw)]
    return directory, records, meta, old


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suffix', default='9b7-native-r2')
    parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    require(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,55}', args.suffix), 'Invalid suffix')
    require(sha(META.read_bytes()) == META_SHA, 'Reviewed final metadata changed')
    meta = load(META)
    for relative, digest in meta['project_bindings'].items():
        require(sha((PROJECT / relative).read_bytes()) == digest, 'Current project changed: ' + relative)
    for path, digest in meta['external_bindings'].items():
        require(sha(Path(path).read_bytes()) == digest, 'Current helper changed: ' + path)
    expected_all = {str(PROJECT / p): h for p, h in meta['project_bindings'].items()} | meta['external_bindings']
    acceptance_dir, records, native_meta, headless_failure = native_fixture_evidence(args.suffix, expected_all)
    owner = meta['existing_owner_33_check']
    owner_raw = Path(owner['raw_path'])
    raw, thermal_path = clean(owner_raw)
    require(sha(owner_raw.read_bytes()) == owner['raw_sha256']
            and sha(thermal_path.read_bytes()) == owner['thermal_sha256']
            and sha(Path(owner['stdout_path']).read_bytes()) == owner['stdout_sha256'], 'Owner33 evidence changed')
    bind(raw, owner['source_bindings'])
    require('ChunkBlockRendererTest: 33 passed, 0 failed' in Path(owner['stdout_path']).read_text(), 'Owner33 footer absent')
    records.append(('owner33', owner_raw, thermal_path, raw))
    visual_path = CONTROL / 'prop-final-native-visual-review.json'
    visual = load(visual_path)
    require(visual.get('status') == 'ROOT_VISUAL_ACCEPTED_SELECTED_PROP_AND_OBJECTIVE_SHADOWS', 'Root visual review missing')
    for row in visual['runtime_binding']:
        require(meta['project_bindings'].get(row['path']) == row['sha256'], 'Visual review is stale')
    for row in visual['images']:
        require(sha(Path(row['path']).read_bytes()) == row['sha256'], 'Reviewed native image changed')
    natives = []
    for family, base in [('props', Path('/var/tmp/sa-c22/props/s6a')), ('objectives', Path('/var/tmp/sa-c22/objectives'))]:
        for side in ['before', 'after']:
            directory = base / side
            provenance = load(directory / 'provenance.json')
            raw_path = Path(provenance['run_result']['run_root']) / 'run-results.json'
            raw, thermal_path = clean(raw_path)
            bind(raw, provenance['scoped_sha256'])
            for name, digest in provenance['outputs_sha256'].items():
                require(sha((directory / name).read_bytes()) == digest, 'Native output changed: ' + name)
            if side == 'after':
                bind(raw, meta['project_bindings'] if family == 'props' else {
                    key: meta['project_bindings'][key] for key in provenance['scoped_sha256']})
            natives.append((family, side, directory, provenance))
            records.append((family + '-' + side, raw_path, thermal_path, raw))
    objective_review_path = CONTROL / 'prop-objective-visual-review.json'
    validate_objective_ground_review(load(objective_review_path),
        meta['project_bindings']['core/systems/world/objectives/ObjectiveWorldArt.gd'],
        Path('/var/tmp/sa-c22/objectives/before'), Path('/var/tmp/sa-c22/objectives/after'))
    # No writes until every completed acceptance/native/owner input passes above.
    out = args.out.resolve()
    require(out != ROOT and ROOT not in out.parents and out != PROJECT and PROJECT not in out.parents,
            'Packet output must be outside active checkouts')
    out.mkdir(parents=True, exist_ok=True)
    files = []

    def put(data, relative, origin, role):
        compressed = len(data) > 128 * 1024 and not str(relative).endswith('.png')
        relative = str(relative) + ('.gz' if compressed else '')
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        payload = gzip.compress(data, mtime=0) if compressed else data
        target.write_bytes(payload)
        files.append({'path': relative, 'source_path': str(origin), 'role': role,
                      'raw_sha256': sha(data), 'raw_bytes': len(data),
                      'delivered_sha256': sha(payload), 'delivered_bytes': len(payload), 'gzip': compressed})

    def copy(path, relative, role):
        put(path.read_bytes(), relative, path, role)

    copy(META, 'source-binding.json', 'reviewed final source inventory')
    copy(NATIVE_PREP / 'source.json', 'native-execution/source.json', 'reviewed native-only execution/source binding')
    copy(Path(__file__).resolve(), 'sources/helpers/build_packet.py', 'exact packet builder source')
    for path in sorted(NATIVE_PREP.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc':
            copy(path, 'native-execution/preparation/' + str(path.relative_to(NATIVE_PREP)), 'frozen native envelope, original failed headless source/evidence and official backend proof')
    for absolute in native_meta['native_execution_bindings']:
        path = Path(absolute)
        copy(path, 'sources/native-execution/' + path.name, 'exact native execution/guard/post-autoload settings source')
    for path in sorted(NATIVE_PACKET_PREP.rglob('*')):
        if path.is_file() and path.suffix != '.pyc':
            copy(path, 'preparation/native-packet/' + str(path.relative_to(NATIVE_PACKET_PREP)), 'preserved builder adaptation/review source evidence')
    for path, digest in meta['project_bindings'].items():
        copy(PROJECT / path, 'sources/current/' + path, 'exact final project source')
    for path in meta['external_bindings']:
        copy(Path(path), 'sources/helpers/' + Path(path).name, 'exact external helper')
    for path in sorted(PREP.rglob('*')):
        if path.is_file() and path.suffix != '.pyc':
            copy(path, 'preparation/' + str(path.relative_to(PREP)), 'preserved former binding/source-only rebind proof')
    copy(visual_path, 'reviews/prop-final-native-visual-review.json', 'root selected native visual review')
    copy(objective_review_path, 'reviews/prop-objective-visual-review.json', 'root source/image-bound positive objective ground-strip control')
    for path in acceptance_dir.glob('*.json'):
        copy(path, 'acceptance/' + path.name, 'actual independent48 queue/manifest')
    for role, raw_path, thermal_path, raw in records:
        copy(thermal_path, 'runs/' + role + '/thermal.json', 'original completed outer guard record')
        for path in sorted(raw_path.parent.rglob('*')):
            if path.is_file():
                copy(path, 'runs/' + role + '/' + str(path.relative_to(raw_path.parent)), 'original completed engine evidence')
    for family, side, directory, provenance in natives:
        for name in ['provenance.json', *provenance['outputs_sha256']]:
            copy(directory / name, 'native/' + family + '/' + side + '/' + name, 'original source-bound native image/record')
    failed_raw = Path(headless_failure['raw']['path'])
    for path in sorted(failed_raw.parent.rglob('*')):
        if path.is_file():
            copy(path, 'earlier/headless-9b7-r1/' + str(path.relative_to(failed_raw.parent)), 'actual failed25/15 headless result; dummy uploaded-transform getter backend is inapplicable, not a pass')
    copy(Path(headless_failure['guard']['path']), 'earlier/headless-9b7-r1/thermal.json', 'original failed headless guard')
    for name in ['acceptance.json', 'queue.json']:
        path = Path('/var/tmp/sa-city22/prop-shadow-acceptance/9b7-r1') / name
        copy(path, 'earlier/headless-9b7-r1/' + name, 'original failed headless fixture receipt, retained unchanged')
    old = [{'label': 'city22-prop-shadow-fixture-9b7-r1', 'classification': 'actual_failed25passed15failed_40executed_dummy_GPU_readback_backend_inapplicable_no_pass', 'official_engine_commit': 'ed1daf0bf', 'proof': 'native-execution/preparation/README.md'}]
    for suffix, classification in [('f0fe-r1', 'parser_timeout_no_logical_verdict'), ('f0fe-r2', 'queued_cancelled_after_owner_source_revision_no_logical_verdict')]:
        label = 'city22-prop-shadow-parse-' + suffix
        thermal_path = CONTROL / (label + '-thermal.json')
        if thermal_path.exists():
            copy(thermal_path, 'earlier/' + label + '-thermal.json', classification)
            old.append({'label': label, 'classification': classification})
        for raw_path in RUNS.glob(label + '-*/run-results.json'):
            for path in sorted(raw_path.parent.rglob('*')):
                if path.is_file():
                    copy(path, 'earlier/' + raw_path.parent.name + '/' + str(path.relative_to(raw_path.parent)), classification)
    for name in ['prop-shadow-frozen-source-cancellation.json']:
        copy(CONTROL / name, 'earlier/' + name, 'original cancellation reason')
    summary = {'status': 'INDEPENDENT48_CLEAN_AND_SELECTED_NATIVE_VISUAL_ACCEPTED',
               'reported_revision': meta['reported_revision'], 'metadata_sha256': META_SHA,
               'independent_fixture': {'passes': 48, 'failures': 0, 'parser_sources_reused': 6, 'execution': 'native OpenGL gl_compatibility,20FPS/windowed640x360/physics60; predicates unchanged'},
               'owner_fixture': {'passes': 33, 'failures': 0}, 'earlier_attempts': old,
               'limits': visual['limits'] + ['Still/frozen native props and objective forms; not moving combat or added-cost evidence.',
                                            'Other city continuation stages and main integration are outside this packet.'],
               'files': files}
    (out / 'manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
    (out / 'README.md').write_text('# Prop shadows evidence\n\nFinal9b7 source-bound independent48/0 plus six-source parser and owner33/0; selected native prop/objective views accepted by root. The exact clean six-source parser is reused. Original9b7-r1 headless failed25/15 (40 executed) is preserved as a failed/inapplicable dummy uploaded-transform readback backend, with exacted1d engine-source proof; it is never relabelled as a pass. Earlier f0fe parser timeout and queued cancellation remain without a logical verdict. Exact sources, raw runs, guard records and native PNGs are indexed in manifest.json; larger text records use lossless gzip. This packet does not establish moving combat or performance, other city stages, or main integration.\n')
    print(json.dumps({'packet': str(out), 'files': len(files), 'manifest_sha256': sha((out / 'manifest.json').read_bytes())}))


if __name__ == '__main__':
    main()
