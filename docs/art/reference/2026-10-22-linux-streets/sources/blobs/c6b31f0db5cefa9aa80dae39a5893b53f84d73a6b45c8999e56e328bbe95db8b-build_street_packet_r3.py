#!/usr/bin/env python3
"""Thin R3 completion adapter over immutable66/48; never starts an engine."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
CONTROL = HERE.parent
PREVIOUS = CONTROL / 'street-packet-r2-adapter/build_street_packet_r2.py'
PREVIOUS_SHA = '66bcab705c745fd054cb1d29b35e462fa3a97a74ffb3bda146239a026249011f'
R3_DIR = CONTROL / 'street-pickup-r3'
COLLECTOR_SHA = 'e0c42df3a5587314edd028f2bf17e1790dcdd64499ec8adced3767ad2b537784'
R3_PINS_SHA = '9d1bd70e2bb5e9bce75b7f4a139a943e76c1562290e68d35da68ce390c974cdf'
COMPLETION = Path('/var/tmp/sa-city22/streets/native-routes-r3/completion.json')
ROOT_REVIEW = CONTROL / 'street-r3-root-visual-review.json'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def load_protocols():
    preparation = json.loads((HERE / 'preparation.json').read_text())
    for path, expected in preparation['frozen_sources'].items():
        if digest(path) != expected:
            raise ValueError('Frozen R3 packet input changed: ' + path)
    if digest(PREVIOUS) != PREVIOUS_SHA or digest(R3_DIR / 'source-bindings.json') != R3_PINS_SHA or digest(R3_DIR / 'continuation.py') != COLLECTOR_SHA:
        raise ValueError('Frozen preceding adapter or R3 receipt producer changed')
    previous = load_module(PREVIOUS, 'street_packet_immutable_66bc')
    original, r2, pins = previous.load_protocols()
    metadata = json.loads((R3_DIR / 'source-bindings.json').read_text())
    for path, expected in metadata['sources'].items():
        if digest(path) != expected:
            raise ValueError('Frozen R3 source or historical proof changed: ' + path)
    collector = load_module(R3_DIR / 'continuation.py', 'street_packet_readonly_r3_collector')
    return previous, original, r2, pins, collector


def route_evidence(continuity, original, collector):
    before = COMPLETION.read_bytes()
    report = json.loads(before)
    if report.get('status') != 'checked_corrected_object_id_contract' or [row.get('id') for row in report.get('cases', [])] != ['parse', 's2', 's7', 's6']:
        raise ValueError('R3 completion is partial, reordered or not the checked four-case receipt')
    # This frozen read-only producer independently rechecks all actual raw,
    # source, guard, matrix, physical/collection/image and separate-origin gates.
    actual = collector.evidence(True)
    if report != actual:
        raise ValueError('Saved R3 completion differs from freshly rebuilt actual evidence')
    if not continuity.get('accepted') or report['complete_matrix_prerequisite'].get('sha256') != continuity.get('aggregate', {}).get('sha256'):
        raise ValueError('R3 completion and packet require the same complete fourteen-theme/five-assertion matrix')
    if report['original_r2_queue'].get('status') != 'stopped':
        raise ValueError('Original failed R2 queue must remain stopped')
    cases = []
    for case in report['cases']:
        run, origin = case['run'], case['origin']
        source = origin['program']
        source_sha = origin.get('sha256') or report['source_bindings']['sources'].get(source) or report['original_r2_source_bindings']['sources'].get(source)
        if not source_sha:
            raise ValueError('Actual execution origin has no frozen source pin: ' + source)
        row = {'kind': case['id'], 'label': case['label'], 'raw': run['path'], 'raw_sha256': run['sha256'],
               'thermal_path': run['thermal_path'], 'thermal_sha256': run['thermal_sha256'],
               'origin': origin, 'command_origin': source, 'command_origin_sha256': source_sha,
               'source_bindings_sha256': R3_PINS_SHA, 'command': case['command'], 'project_state': case['project_state']}
        if case['id'] != 'parse':
            row.update({key: case[key] for key in ('out', 'manifest', 'images', 'original_r2_collection_verdict', 'corrected_r3_collection_verdict')})
            row.update(site_source_sha256=original.CURRENT_SITE_SHA, runtime_render_fps_cap=20, physics_ticks_per_second=60)
        cases.append(row)
    if COMPLETION.read_bytes() != before:
        raise ValueError('R3 completion changed during validation')
    return {'path': str(COMPLETION), 'sha256': original.sha(before), 'accepted': True, 'cases': cases,
            'historical_r2': {**report['original_r2_queue'], 'accepted_as_original_queue': False},
            'source_origin': 'Reused original5e parser/S2 and two frozen7936 root manual commands; later853/e0 corrected verdict remains separate',
            'route_gates': {row['kind']: {'queue': str(COMPLETION), 'case': row} for row in cases if row['kind'] != 'parse'}}


def corrected_evidence(base_validation, original, r2, pins):
    # base_validation is the unchanged66 function. Its matrix, original reward,
    # five-case root image and composition checks are all retained.
    continuity, native = base_validation(original, r2, pins)
    native.pop('r2_collection_protocol', None)
    native['r3_collection_protocol'] = {'path': str(R3_DIR / 'source-bindings.json'), 'sha256': R3_PINS_SHA,
        'collector_sha256': COLLECTOR_SHA, 'limits': 'Nonbool signed-int64/nonzero ObjectIDs; every original exact-serial/ordinary-feed/identity/ownership/route gate remains. R1 failed and original R2 queue stopped.'}
    native['command_program_origins'] = {
        str(CONTROL / 'street-native-queue.py'): {'sha256': original.PROTOCOL_PINS['street-native-queue.py'], 'role': 'Unchanged original reward-only execution program'},
        str(CONTROL / 'street-pickup-r2/street-pickup-r2.py'): {'sha256': pins['sources'][str(CONTROL / 'street-pickup-r2/street-pickup-r2.py')], 'role': 'Only reused actual parser/S2 origins; original strict queue remains stopped'},
        str(R3_DIR / 'command-plan.json'): {'sha256': '7936c9172b52a5e9662c75c8bea9c95606af2a526cd1ef2b1c16a466ed4d7875', 'role': 'Only new S7/S6 root manual execution origins; no new GDScript or queue runner'},
        str(COMPLETION): {'path': str(R3_DIR / 'continuation.py'), 'sha256': COLLECTOR_SHA, 'role': 'Later read-only corrected evidence producer, not a native execution program'}}
    return continuity, native


def rewritten_output(relative, value):
    if str(relative) == 'street-r2-protocol-validation.json':
        value = copy.deepcopy(value)
        value['r3_collection_protocol'] = value['native']['r3_collection_protocol']
        value['adapter_chain'] = {'unchanged_r2_adapter': str(PREVIOUS), 'sha256': PREVIOUS_SHA}
        value['external_source_scope'] = 'Reused parser/S2 retain original5e launch origins; S7/S6 use pinned7936 root manual guard commands. Frozen e0/853 read-only producer rebuilds actual sources/raw/guards/routes/images and preserves the stopped old queue. No claim that original5e orchestrated the new cases.'
        return 'street-r3-protocol-validation.json', value
    if str(relative) == 'evidence-index.json':
        value = copy.deepcopy(value)
        value.pop('street_protocol_r2', None)
        value['street_protocol_r3'] = 'street-r3-protocol-validation.json'
    return relative, value


def main():
    previous, original, r2, pins, collector = load_protocols()
    base_validation = previous.validated_evidence
    previous.ROOT_REVIEW, previous.ROUTE_QUEUE = ROOT_REVIEW, COMPLETION
    previous.r2_route_evidence = lambda continuity, current, _r2, _pins: route_evidence(continuity, current, collector)
    previous.validated_evidence = lambda current, inherited_r2, inherited_pins: corrected_evidence(base_validation, current, inherited_r2, inherited_pins)
    previous.load_protocols = lambda: (original, r2, pins)
    continuity, native = previous.validated_evidence(original, r2, pins)
    output, include = original.output, original.include_street_protocol

    def include_protocol(current, selected):
        include(current, selected)
        metadata = json.loads((R3_DIR / 'source-bindings.json').read_text())
        paths = [Path(path) for path in metadata['sources']] + [R3_DIR / 'source-bindings.json', COMPLETION,
            Path(__file__).resolve(), HERE / 'preparation.json', HERE / 'README.md', HERE / 'root-review-template.json',
            CONTROL / 'street-s2-r2-root-visual-review.json']
        for path in dict.fromkeys(paths):
            original.snapshot(path.read_bytes(), path.name, path,
                'Separate R3 signed-ObjectID protocol/source/completion or supporting S2 review; original stoppedR2/R1 evidence remains unchanged')

    def emit(relative, value):
        return output(*rewritten_output(relative, value))

    original.include_street_protocol, original.output = include_protocol, emit
    if '--check-only' not in sys.argv:
        selected = [row['case'] for row in native['route_gates'].values()] + [native['reward_pair'][key] for key in ('before', 'after')]
        # Use the original packager's existing image-input mechanism after all
        # actual five-case proof/review gates; original PNG bytes stay unchanged.
        for case in selected:
            sys.argv += ['--native', case['label'] + '=' + case['out']]
    previous.main()


if __name__ == '__main__':
    main()
