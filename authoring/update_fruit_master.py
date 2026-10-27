"""Replace Berry/Mango inside the existing master without rebuilding Pip or props."""
import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[1]
master = root / 'blend' / 'bunbreak_master.blend'
bpy.ops.wm.open_mainfile(filepath=str(master))
for kind in ('berry', 'mango'):
    title = kind.title()
    old_scene = bpy.data.scenes[title + '_Studio']
    old_collection = bpy.data.collections[title]
    old_scene.name = '__old_' + title + '_Studio'
    old_collection.name = '__old_' + title
    source = root / 'blend' / 'characters' / (kind + '.blend')
    with bpy.data.libraries.load(str(source), link=False) as (available, destination):
        assert title + '_Studio' in available.scenes
        destination.scenes = [title + '_Studio']
    updated = destination.scenes[0]
    assert updated is not None and updated.camera is not None
    updated_collection = bpy.data.collections[title]
    swapped = 0
    for obj in bpy.data.objects:
        if obj.instance_type == 'COLLECTION' and obj.instance_collection == old_collection:
            obj.instance_collection = updated_collection
            swapped += 1
    assert swapped >= 4, (kind, 'family, board and turnarounds reference the new asset')
    bpy.data.scenes.remove(old_scene)
    bpy.data.collections.remove(old_collection)
    print('MASTER_FRUIT_REPLACED', kind, swapped, flush=True)
bpy.context.window.scene = bpy.data.scenes['Family_Studio']
bpy.ops.wm.save_as_mainfile(filepath=str(master), compress=True)
print('MASTER_FRUIT_UPDATE_COMPLETE', flush=True)
