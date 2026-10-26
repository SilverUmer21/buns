"""Re-save isolated scene libraries as ordinary, directly openable blend files.

Run after build_assets.py with Blender's --python option. Does not touch master.
"""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
paths = sorted((ROOT / 'blend' / 'characters').glob('*.blend')) + sorted((ROOT / 'blend' / 'props').glob('*.blend'))
for path in paths:
    bpy.ops.wm.open_mainfile(filepath=str(path))
    assert len(bpy.data.scenes) == 1, (path.name, 'isolated scene')
    scene = next(iter(bpy.data.scenes))
    bpy.context.window.scene = scene
    assert scene.camera is not None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    print('STANDALONE_SOURCE', path.name, scene.name, len(scene.objects), flush=True)
print('SOURCE_FINALIZATION_COMPLETE', flush=True)
