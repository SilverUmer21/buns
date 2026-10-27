"""Render one standalone fruit bun for proportion and face-surface review.

blender -b blend/berry_proof.blend -t 3 --python authoring/render_fruit_proof.py -- berry
"""
import bpy
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
kind = sys.argv[-1]
assert kind in ('berry', 'mango')
scene = bpy.data.scenes[kind.title() + '_Studio']
bpy.context.window.scene = scene
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.resolution_x = scene.render.resolution_y = 720
scene.render.filepath = str(root / 'renders' / (kind + '-shape-proof.png'))
bpy.ops.render.render(write_still=True)
print('FRUIT_PROOF_RENDERED', kind, flush=True)
