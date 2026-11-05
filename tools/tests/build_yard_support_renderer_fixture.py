"""Build a fresh, pinned actual-renderer fixture. No Godot import or source edits.

Only WorldArt/CityBlockKit asset-loader leaves are doubled. Native mode loads
the original fourteen-layer cache and original city textures with imported mips.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GROUND = 'core/systems/world/ground/'


def sha(body):
    return hashlib.sha256(body).hexdigest()


def build(out, native=False):
    out = out.resolve()
    if out.exists():
        raise SystemExit('Refusing to overwrite fixture evidence')
    out.mkdir(parents=True)
    (out / '.gdignore').write_bytes(b'')  # FIRST artifact, before any project
    project = out / 'fixture'
    project.mkdir()
    pins = []

    def put(relative, body, role, source=None):
        path = project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
        pins.append(dict(path=relative, role=role, sha256=sha(body),
                         source_sha256=sha(source) if source is not None else None))

    def copy(relative):
        body = (ROOT / relative).read_bytes()
        put(relative, body, 'unchanged repository source', body)

    try:
        for relative in [
            GROUND + 'GroundSplatRenderer.gd', GROUND + 'ground_splat.gdshader',
            GROUND + 'DistrictGroundPolicy.gd', GROUND + 'CityGroundCare.gd',
            GROUND + 'CityYardSupport.gd', GROUND + 'CityYardSupportMap.gd',
            'core/systems/world/chunks/ChunkBuildData.gd',
            'core/systems/world/WorldBlockerGeometry.gd',
            'tools/tests/YardSupportRendererTest.gd',
            'tools/tests/YardSupportRendererTest.tscn',
            'tools/tests/WorldGroundSplatTest.tscn',
            'tools/tests/YardSupportGroundDataSubsetTest.gd',
            'tools/tests/YardSupportGroundDataSubsetTest.tscn',
            'tools/tests/CityYardSupportTest.gd',
            'tools/tests/CityYardSupportMapTest.gd',
        ]:
            copy(relative)
        if (ROOT / GROUND / 'YardSupportPreviewShader.gd').exists():
            copy(GROUND + 'YardSupportPreviewShader.gd')
        old = (ROOT / 'tools/tests/WorldGroundSplatTest.gd').read_bytes()
        text = old.decode('utf-8-sig')
        marker = '\nfunc _test_chunk_manager_path() -> void:'
        call = '\tawait _test_chunk_manager_path()'
        summary = 'WorldGroundSplatTest: %d passed'
        if text.count(marker) != 1 or text.count(call) != 1 or text.count(summary) != 1:
            raise ValueError('Unrecognized old test subset hooks')
        text = text.split(marker)[0].replace(call, '\tawait get_tree().process_frame\n\tawait get_tree().process_frame')
        text = text.replace(summary, 'WorldGroundSplatDataSubset: %d passed')
        put('tools/tests/WorldGroundSplatTest.gd', text.encode(),
            'omit ONLY three manager assertions/method+call; retain cleanup frames; distinct data subset summary', old)

        art = '''@static_unload
extends RefCounted
# TEST ASSET-LOADER LEAF ONLY. Material IDs and repeats match production.
const GROUND_CARED_LAWN_INDEX := 13
static var _array: Texture2DArray
static func ground_repeat_world_px(index: int = -1) -> int:
    return 320 if index in [0,10,11,12,13] else 384
static func is_overgrowth_ground(index: int) -> bool:
    return index in [0,10,11,12]
static func ground_material_array() -> Texture2DArray:
    if _array != null: return _array
'''
        if native:
            material = 'assets/world/ground/baked/ground_materials.res'
            body = (ROOT / material).read_bytes()
            if len(body) != 10134012 or sha(body) != '14a57921e0351de7a7ddbe343e783d7341cda75b6a8e774079e866dcb960d8b7':
                raise ValueError('Original fourteen-layer material cache unavailable/mismatched')
            copy(material)
            art += '    _array = load("res://assets/world/ground/baked/ground_materials.res") as Texture2DArray\n    return _array\n'
            kit = '''extends RefCounted
# TEST ASSET-LOADER LEAF ONLY; actual imported textures, no building behavior.
static func _texture(file: String) -> Texture2D:
    return load("res://assets/world/city_block/" + file) as Texture2D
'''
            for filename in ['worn_setts.png', 'paving.png']:
                relative = 'assets/world/city_block/' + filename
                copy(relative)
                copy(relative + '.import')
                imported = (ROOT / (relative + '.import')).read_text(encoding='utf-8-sig')
                ctex = re.findall(r'"res://(\.godot/imported/[^"\n]+\.ctex)"', imported)
                if not ctex or 'mipmaps/generate=true' not in imported:
                    raise ValueError('Missing actual imported mipmapped city texture')
                for path in sorted(set(ctex)):
                    copy(path)
            original_renderer = subprocess.check_output(['git', 'show', 'd7cfb52f:' + GROUND + 'GroundSplatRenderer.gd'], cwd=ROOT)
            original_shader = subprocess.check_output(['git', 'show', 'd7cfb52f:' + GROUND + 'ground_splat.gdshader'], cwd=ROOT)
            put(GROUND + 'baseline_ground_splat.gdshader', original_shader, 'original d7cfb52f shader; no changes', original_shader)
            baseline = original_renderer.decode('utf-8-sig')
            class_hook = 'class_name GroundSplatRenderer\n'
            shader_hook = 'preload("res://' + GROUND + 'ground_splat.gdshader")'
            if baseline.count(class_hook) != 1 or baseline.count(shader_hook) != 1:
                raise ValueError('Unsupported baseline renderer transformations')
            baseline = baseline.replace(class_hook, '').replace(shader_hook, 'preload("res://' + GROUND + 'baseline_ground_splat.gdshader")')
            put(GROUND + 'BaselineGroundSplatRenderer.gd', baseline.encode(),
                'original d7cfb52f renderer: remove sole class_name; redirect sole shader preload to original shader copy', original_renderer)
            copy('tools/tests/YardSupportNativeTest.gd')
            copy('tools/tests/YardSupportNativeTest.tscn')
            copy('tools/tests/YardSupportNativeParseTest.gd')
        else:
            art += '''    var images: Array[Image] = []
    for index in 14:
        var image := Image.create(2,2,true,Image.FORMAT_RGB8)
        image.fill(Color(0.35,0.35,0.33))
        images.append(image)
    _array = Texture2DArray.new()
    _array.create_from_images(images)
    return _array
'''
            kit = '''extends RefCounted
# TEST ASSET-LOADER LEAF ONLY: tiny white, NOT native art evidence.
static func _texture(_file: String) -> Texture2D:
    var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    return ImageTexture.create_from_image(image)
'''
        art += 'static func release_static_caches() -> void:\n    _array = null\n'
        put('core/systems/world/WorldArt.gd', art.encode(), 'explicit asset-loader leaf double')
        put('scenes/world/buildings/CityBlockKit.gd', kit.encode(), 'explicit asset-loader leaf double')
        # Godot's actual GDScript metadata format, including StringName fields.
        entries = []
        for name, base, path in [
            ('ChunkBuildData', 'RefCounted', 'core/systems/world/chunks/ChunkBuildData.gd'),
            ('WorldBlockerGeometry', 'RefCounted', 'core/systems/world/WorldBlockerGeometry.gd'),
            ('GroundSplatRenderer', 'Node2D', GROUND + 'GroundSplatRenderer.gd'),
        ]:
            entries.append('{\n"base": &' + json.dumps(base) + ',\n"class": &' + json.dumps(name) +
                ',\n"icon": "",\n"is_abstract": false,\n"is_tool": false,\n"language": &"GDScript",\n"path": ' + json.dumps('res://' + path) + '\n}')
        put('.godot/global_script_class_cache.cfg', ('list=[' + ', '.join(entries) + ']\n').encode(), 'minimal normal GDScript class metadata; not full project import')
        put('project.godot', ('config_version=5\n[application]\nconfig/name="Yard support actual renderer fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n').encode(), 'isolated minimal project; no autoloads or Game')
        for relative in ['tools/tests/build_yard_support_renderer_fixture.py', 'tools/tests/run_yard_support_renderer_fixture.ps1', 'tools/capture/city_resource_guard.ps1']:
            body = (ROOT / relative).read_bytes()
            destination = out / 'launcher-sources' / Path(relative).name
            destination.parent.mkdir(exist_ok=True)
            destination.write_bytes(body)
            pins.append(dict(path='launcher-sources/' + destination.name, role='exact launcher/guard snapshot', sha256=sha(body), source_sha256=sha(body)))
        (out / 'source-pins.json').write_text(json.dumps(pins, indent=2), encoding='utf-8')
        (out / 'fixture.json').write_text(json.dumps(dict(native=native, full_game=False, art='original baked fourteen-layer + imported city mipmaps' if native else 'tiny-color leaf double; NOT art evidence'), indent=2), encoding='utf-8')
    except Exception as error:
        (out / 'build-failure.txt').write_text(str(error), encoding='utf-8')
        raise
    print(json.dumps(dict(fixture=str(out), native=native), ensure_ascii=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    build(args.out, args.native)
