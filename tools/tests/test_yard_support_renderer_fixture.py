"""Source/provenance contracts for the bounded yard preview; no engine launch."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
GROUND = ROOT / 'core/systems/world/ground'
spec = importlib.util.spec_from_file_location('yard_builder', Path(__file__).with_name('build_yard_support_renderer_fixture.py'))
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
EVIDENCE = None


class YardSupportSourceContracts(unittest.TestCase):
    def test_original_shader_unchanged(self):
        original = subprocess.check_output(['git', 'show', 'd7cfb52f:core/systems/world/ground/ground_splat.gdshader'], cwd=ROOT)
        self.assertEqual((GROUND / 'ground_splat.gdshader').read_bytes(), original)

    def test_manager_is_explicit_once_and_after_care(self):
        source = (ROOT / 'core/systems/world/ChunkManager.gd').read_text(encoding='utf-8-sig')
        ensure = source.split('func _ensure_ground_splat() -> GroundSplatRenderer:', 1)[1].split('\nfunc ', 1)[0]
        self.assertEqual(source.count('SA_YARD_SUPPORT_PREVIEW'), 1)
        self.assertEqual(source.count('SA_YARD_SUPPORT_TARGET'), 1)
        self.assertLess(ensure.index('if _ground_splat == null'), ensure.index('SA_YARD_SUPPORT_PREVIEW'))
        self.assertLess(ensure.index('SA_YARD_SUPPORT_PREVIEW'), ensure.index('add_child(_ground_splat)'))
        self.assertIn('OS.get_environment("SA_YARD_SUPPORT_PREVIEW") == "1"', ensure)
        self.assertIn('parse_yard_support_target(OS.get_environment("SA_YARD_SUPPORT_TARGET"))', ensure)
        self.assertIn('if not yard_target.is_empty():', ensure)
        care = source.split('func _activate_ground_care(', 1)[1].split('\nfunc ', 1)[0]
        self.assertEqual(care.count('splat.paint_yard_support(coord, specs)'), 1)
        self.assertLess(care.index('splat.paint_domestic_care'), care.index('splat.paint_yard_support'))

    def test_factory_only_supported_hooks_and_current_care_unchanged(self):
        source = (GROUND / 'ground_splat.gdshader').read_text(encoding='utf-8-sig')
        needles = ['uniform sampler2D light_map : filter_linear, repeat_enable;', 'void fragment() {',
                   'float inside = 0.5 - yard_patch.y * 0.25 - field;', 'if (inside > -soft - 0.03) {',
                   'float amount = smoothstep(-soft, soft, inside);', '} else if (debug_view == 2) {']
        for needle in needles:
            self.assertEqual(source.count(needle), 1, needle)
        factory = (GROUND / 'YardSupportPreviewShader.gd').read_text(encoding='utf-8-sig')
        self.assertIn('if code.count(hook) != 1:', factory)
        self.assertIn('texelFetch(light_map, cell, 0).b > 0.0', factory)
        self.assertIn('texelFetch(yard_support_map, cell, 0).r <= 0.0', factory)
        self.assertNotIn('textureGrad(', factory)

    def test_portable_builder_data_bindings(self):
        # Isolated under ignored SDD evidence. Fresh roots only; never overwrite.
        out = EVIDENCE / 'data'
        builder.build(out)
        pins = json.loads((out / 'source-pins.json').read_text())
        self.assertEqual((out / '.gdignore').read_bytes(), b'')
        project = out / 'fixture'
        for pin in pins:
            path = out / pin['path'] if pin['path'].startswith('launcher-sources/') else project / pin['path']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), pin['sha256'])
        metadata = (project / '.godot/global_script_class_cache.cfg').read_text()
        self.assertIn('"class": &"WorldBlockerGeometry"', metadata)
        self.assertIn('"class": &"ChunkBuildData"', metadata)
        self.assertNotIn('[autoload]', (project / 'project.godot').read_text())
        old = (project / 'tools/tests/WorldGroundSplatTest.gd').read_text()
        self.assertIn('WorldGroundSplatDataSubset:', old)
        self.assertNotIn('_test_chunk_manager_path', old)
        old_run = old.split('func _run() -> void:', 1)[1].split('\nfunc ', 1)[0]
        harness = (project / 'tools/tests/YardSupportGroundDataSubsetTest.gd').read_text()
        self.assertEqual(re.findall(r'\n\t(_test_\w+)\(\)', old_run), re.findall(r'"(_test_\w+)"', harness))
        with self.assertRaises(SystemExit):
            builder.build(out)

    def test_native_fixture_source_contract(self):
        out = EVIDENCE / 'native'
        builder.build(out, native=True)
        project = out / 'fixture'
        original = subprocess.check_output(['git', 'show', 'd7cfb52f:core/systems/world/ground/GroundSplatRenderer.gd'], cwd=ROOT).decode('utf-8-sig')
        expected = original.replace('class_name GroundSplatRenderer\n', '').replace('preload("res://core/systems/world/ground/ground_splat.gdshader")', 'preload("res://core/systems/world/ground/baseline_ground_splat.gdshader")')
        self.assertEqual((project / 'core/systems/world/ground/BaselineGroundSplatRenderer.gd').read_bytes(), expected.encode())
        shader = subprocess.check_output(['git', 'show', 'd7cfb52f:core/systems/world/ground/ground_splat.gdshader'], cwd=ROOT)
        self.assertEqual((project / 'core/systems/world/ground/baseline_ground_splat.gdshader').read_bytes(), shader)
        cache = (project / 'assets/world/ground/baked/ground_materials.res').read_bytes()
        self.assertEqual(len(cache), 10134012)
        self.assertEqual(hashlib.sha256(cache).hexdigest(), '14a57921e0351de7a7ddbe343e783d7341cda75b6a8e774079e866dcb960d8b7')
        for filename in ['worn_setts.png', 'paving.png']:
            self.assertIn('mipmaps/generate=true', (project / ('assets/world/city_block/' + filename + '.import')).read_text())
        scene = (project / 'tools/tests/YardSupportNativeTest.gd').read_text()
        self.assertIn('IDENTICAL global world coordinates', scene)
        self.assertIn('baseline_view = viewport()', scene)
        self.assertIn('current_view = viewport()', scene)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, default=ROOT / 'output/yard-support-source' / uuid.uuid4().hex)
    args, remaining = parser.parse_known_args()
    EVIDENCE = args.evidence.resolve()
    if EVIDENCE.exists():
        raise SystemExit('Refusing to overwrite source-test evidence')
    EVIDENCE.mkdir(parents=True)
    (EVIDENCE / '.gdignore').write_bytes(b'')
    print(json.dumps({'evidence':str(EVIDENCE)},ensure_ascii=True))
    unittest.main(argv=[__file__] + remaining, verbosity=2)
