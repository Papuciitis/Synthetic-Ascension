"""Host-only preparation contracts; never imports or starts Godot."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('real_household_builder', HERE / 'build_real_household_fixture.py')
builder = None
if spec and Path(spec.origin).exists():
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)


class PreparationContract(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(builder, 'finite household preparation builder is required')

    def test_existing_output_is_refused_without_changes(self):
        with tempfile.TemporaryDirectory(prefix='real-household-prepare-host-', dir=builder.ROOT / builder.PREVIEW) as folder:
            out = Path(folder)
            marker = out / 'evidence'
            marker.write_bytes(b'original')
            with self.assertRaisesRegex((ValueError, FileExistsError), 'exist|overwrite'):
                builder.build(out)
            self.assertEqual(list(out.iterdir()), [marker])
            self.assertEqual(marker.read_bytes(), b'original')

    def test_context_rejects_extra_service_and_exact_attempt_segment(self):
        builder.audit_context(builder.CONTEXT)
        for body in [builder.CONTEXT + b'var save_manager = null\n',
                     builder.CONTEXT.replace(b'= 7', b'= 8')]:
            with self.assertRaisesRegex(ValueError, 'context'):
                builder.audit_context(body)

    def test_unknown_literal_and_singleton_references_stop(self):
        manifest = builder.load_allowlist()
        with self.assertRaisesRegex(ValueError, 'unknown reference'):
            builder.audit_source('probe.gd', b'extends Node\nconst X = preload("res://Game.tscn")\n', manifest)
        for body in [b'extends Node\nvar a = Global.inventory\n',
                     b'extends Node\nvar a = SaveManager.data\n',
                     b'extends Node\nvar a = get_node("/root/RunEvents")\n']:
            with self.assertRaisesRegex(ValueError, 'singleton|context'):
                builder.audit_source('probe.gd', body, manifest)

    def test_prohibited_source_and_autoload_paths_stop(self):
        manifest = builder.load_allowlist()
        for path in ['autoload/Global.gd', 'scenes/Game.tscn',
                     'core/systems/world/chunks/ChunkManager.gd', '../escape.gd']:
            bad = copy.deepcopy(manifest)
            bad['files'].append(dict(path=path, sha256='0'*64, size=1, role='unchanged source'))
            with self.assertRaisesRegex(ValueError, 'prohibited|unsafe'):
                builder.validate_allowlist(bad)

    def test_modified_asset_and_cache_pins_are_rejected(self):
        manifest = builder.load_allowlist()
        for role in ['visual PNG', 'baked ground cache']:
            bad = copy.deepcopy(manifest)
            entry = next(e for e in bad['files'] if e['role'] == role)
            entry['sha256'] = '0'*64
            with self.assertRaisesRegex(ValueError, 'pin mismatch'):
                builder.verify_available_pins(builder.ROOT, bad)

    def test_declared_cache_and_all_fourteen_manifest_inputs_validate(self):
        manifest = builder.load_allowlist()
        report = builder.validate_ground_cache(builder.ROOT, manifest)
        self.assertEqual(report['cache_size'], 10134012)
        self.assertEqual(report['cache_sha256'], '14a57921e0351de7a7ddbe343e783d7341cda75b6a8e774079e866dcb960d8b7')
        self.assertEqual(len(report['sources']), 14)
        self.assertTrue(all(x['source_valid'] for x in report['sources']))
        self.assertTrue(all(x['sidecar_valid'] for x in report['sources']))
        local = manifest['approved_local_import_settings']
        self.assertEqual(len(local), 10)
        entries = {x['path']: x for x in manifest['files']}
        for path in local:
            self.assertEqual(entries[path]['role'], 'current-workspace-untracked import settings')
            self.assertEqual(entries[path]['provenance'], 'current-workspace-untracked import settings; historical equivalence unverified')

    def test_new_profiles_preserve_running_and_full_game_limits(self):
        profiles = builder.PROFILES
        self.assertEqual(profiles['import'], dict(startup_ram_mb=832, startup_commit_mb=1536, private_mb=384, timeout_seconds=180, running_ram_mb=384, running_commit_mb=768))
        self.assertEqual(profiles['parse'], profiles['import'])
        self.assertEqual(profiles['native'], dict(startup_ram_mb=960, startup_commit_mb=1536, private_mb=512, timeout_seconds=120, running_ram_mb=384, running_commit_mb=768))
        self.assertEqual(profiles['full_game_unchanged'], dict(startup_ram_mb=1536, startup_commit_mb=3072, private_mb=1200))

    def test_input_records_are_tracked_durable_and_sha_pinned(self):
        self.assertEqual(len(builder.INPUTS), 4)
        paths = [path for _role, path, _digest in builder.INPUTS]
        tracked = set(subprocess.check_output(
            ['git', 'ls-files', '--', *paths], cwd=builder.ROOT,
            encoding='utf-8').splitlines())
        for role, path, digest in builder.INPUTS:
            with self.subTest(role=role, path=path):
                self.assertIn(path, tracked, 'required INPUTS record must survive scratch cleanup in Git')
                self.assertTrue(path.startswith('docs/'), 'input record must use durable project evidence')
                self.assertNotIn('.superpowers/', path)
                self.assertEqual(builder.sha((builder.ROOT / path).read_bytes()), digest)

    def test_packet_preserves_originals_and_is_never_native_ready(self):
        with tempfile.TemporaryDirectory(prefix='real-household-prepare-host-', dir=builder.ROOT / builder.PREVIEW) as folder:
            out = Path(folder) / 'fresh'
            try:
                builder.build(out)
            except builder.PreparationBlocked:
                pass
            self.assertTrue((out / '.gdignore').is_file())
            status = json.loads((out / 'fixture.json').read_text())
            self.assertFalse(status['native_ready'])
            self.assertIn('runtime harness', ' '.join(status['pending']))
            self.assertFalse((out / 'fixture/tools/tests/RealHouseholdFixture.tscn').exists())
            project = (out / 'fixture/project.godot').read_text()
            self.assertNotIn('run/main_scene', project)
            self.assertEqual(project.count('Global="*res://fixture/SegmentContext.gd"'), 1)
            self.assertNotIn('SaveManager=', project)
            pins = json.loads((out / 'source-pins.json').read_text())
            originals = [p for p in pins if p.get('source_path')]
            self.assertGreater(len(originals), 100)
            for pin in originals:
                copied = (out / pin['path']).read_bytes()
                source = Path(pin['source_path']).read_bytes()
                self.assertEqual(copied, source, pin['path'])
                self.assertEqual(builder.sha(copied), pin['copied_sha256'])
                self.assertEqual(pin['source_sha256_before'], pin['source_sha256_after'])
                self.assertEqual(len(copied), pin['bytes'])
            stage = out / 'import-stage'
            self.assertFalse(any(stage.rglob('*.gd')))
            self.assertFalse(any(stage.rglob('ground_materials*')))


if __name__ == '__main__':
    unittest.main(verbosity=2)
