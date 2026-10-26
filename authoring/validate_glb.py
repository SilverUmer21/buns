"""Check exported binary assets independently of the Blender authoring scene."""
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {'pip', 'berry', 'mango', 'tray', 'wafer_gate', 'jelly_bumper', 'reward_star', 'exit_plate'}
CLIPS = {'idle', 'blink', 'pull', 'release', 'impact', 'merge', 'hop', 'escape'}


def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', data)
    assert (magic, version, size) == (b'glTF', 2, len(data)), path.name
    length, kind = struct.unpack_from('<I4s', data, 12)
    assert kind == b'JSON'
    return json.loads(data[20:20 + length]), data


def validate():
    found, report = set(), {}
    for path in sorted((ROOT / 'exports').rglob('*.glb')):
        key = path.stem
        found.add(key)
        d, data = read_glb(path)
        assert len(d['scenes']) == 1, (key, 'only the intended asset is exported')
        assert d.get('meshes'), (key, 'geometry')
        for node in d['nodes']:
            for name in ('translation', 'rotation', 'scale', 'matrix'):
                assert all(math.isfinite(n) for n in node.get(name, [])), (key, 'finite transforms')
        triangles = sum(d['accessors'][p['indices']]['count'] // 3
                        for mesh in d['meshes'] for p in mesh['primitives'])
        for mesh in d['meshes']:
            for p in mesh['primitives']:
                assert {'POSITION', 'NORMAL', 'TEXCOORD_0'} <= set(p['attributes']), (key, 'normals and UVs')
                assert p.get('mode', 4) == 4, (key, 'triangle geometry')
                assert 'material' in p, (key, 'PBR material')
        names = [a['name'] for a in d.get('animations', [])]
        if key in {'pip', 'berry', 'mango'}:
            assert len(d.get('skins', [])) == 1, (key, 'single skeleton')
            assert len(d['skins'][0]['joints']) == 11, (key, 'eleven bones')
            assert set(names) == CLIPS and len(names) == 8, (key, 'eight unique clips')
            for a in d['animations']:
                assert any(c['target']['path'] == 'weights' for c in a['channels']), (key, a['name'], 'morph animation')
            assert any(m.get('weights') for m in d['meshes']), (key, 'editable morphs')
        else:
            assert not d.get('skins') and not names, (key, 'no foreign skeleton or clips')
        assert (ROOT / 'godot' / 'assets' / path.name).read_bytes() == data, 'Godot copy matches export'
        assert (ROOT / 'blend' / path.parent.name / (key + '.blend')).is_file(), 'Editable source'
        report[key] = {'bytes': len(data), 'triangles': triangles, 'mesh_nodes': len(d['meshes']),
                       'materials': len(d.get('materials', [])), 'animations': names}
    assert found == EXPECTED, (found, EXPECTED)
    result = {'passed': True, 'assets': report}
    (ROOT / 'reports' / 'glb-validation.json').write_text(json.dumps(result, indent=2))
    print('GLB validation PASS:', len(report), 'assets;', sum(x['bytes'] for x in report.values()), 'bytes total')


if __name__ == '__main__':
    validate()
