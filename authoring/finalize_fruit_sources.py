"""Make the two revised fruit sources directly openable without touching Pip."""
import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for name in ('berry', 'mango'):
    path = root / 'blend' / 'characters' / (name + '.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    assert len(bpy.data.scenes) == 1
    scene = next(iter(bpy.data.scenes))
    assert scene.camera is not None
    bpy.context.window.scene = scene
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    print('STANDALONE_FRUIT_SOURCE', name, len(scene.objects), flush=True)
