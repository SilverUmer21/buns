"""Render real evaluated idle/blink/squash/hop poses to inspect animation clarity."""
import bpy
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'authoring'))
import build_assets as author

review = bpy.data.scenes.new('Animation_Review')
author.studio(review, 7.7, (0, -14, 3.1), (0, 0, 3.1), transparent=True)
review.render.resolution_x = review.render.resolution_y = 1200
review.cycles.samples = 32
review.view_settings.exposure = -.3
review.render.filepath = str(ROOT / 'renders' / 'animation-states.png')
textmat = author.material('Review teal ink', '26685D', .6)
coll = bpy.data.collections.new('Evaluated_animation_states')
review.collection.children.link(coll)
poses = [('idle', 1, 'IDLE'), ('blink', 9, 'BLINK'), ('pull', 8, 'SQUASH'), ('hop', 19, 'HOP')]


def text(label, x, z, size=.16):
    data = bpy.data.curves.new(label + '_label', 'FONT')
    data.body, data.align_x, data.size = label, 'CENTER', size
    data.materials.append(textmat)
    ob = bpy.data.objects.new(label + '_label', data)
    coll.objects.link(ob)
    ob.location = (x, -.6, z)
    ob.rotation_euler.x = math.pi / 2


for row, key in enumerate(['pip', 'berry', 'mango']):
    source = bpy.data.scenes[key.title() + '_Studio']
    source_coll = bpy.data.collections[key.title()]
    arm = next(ob for ob in source_coll.all_objects if ob.type == 'ARMATURE')
    body = next(ob for ob in source_coll.all_objects if ob.type == 'MESH' and ob.data.shape_keys)
    for column, (clip, frame, caption) in enumerate(poses):
        bpy.context.window.scene = source
        author.reset_pose(arm, body)
        for data in (arm, body.data.shape_keys):
            for track in data.animation_data.nla_tracks:
                track.mute = track.name != clip
        source.frame_set(frame)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        parent = bpy.data.objects.new(key.title() + '_' + caption, None)
        coll.objects.link(parent)
        parent.location = (-2.7 + column * 1.8, 0, 4.3 - row * 2.05)
        for ob in source_coll.all_objects:
            if ob.type != 'MESH':
                continue
            evaluated = ob.evaluated_get(dg)
            data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=dg)
            for v in data.vertices:
                v.co = ob.matrix_world @ v.co
            frozen = bpy.data.objects.new(key + '_' + clip + '_' + ob.name, data)
            coll.objects.link(frozen)
            frozen.parent = parent
        author.reset_pose(arm, body)
        if row == 0:
            text(caption, -2.7 + column * 1.8, 6.20, .18)
    text(key.title().upper(), 0, 4.3 - row * 2.05 - .20, .12)

bpy.context.window.scene = review
review.frame_set(1)
for light in review.objects:
    if light.type == 'LIGHT':
        light.location.z += 2
        light.data.energy *= 1.4
        light.data.size *= 1.3
        author.look_at(light, (0, 0, 3))
bpy.data.libraries.write(str(ROOT / 'blend' / 'animation_review.blend'), {review}, fake_user=True, compress=True)
bpy.ops.render.render(write_still=True)
print('ANIMATION_VISUAL_REVIEW_COMPLETE', flush=True)
