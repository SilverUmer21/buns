"""Author Bunbreak's original, editable 3D asset set from the supplied references.

Run with: blender -b --factory-startup -t 3 --python authoring/build_assets.py
Blender coordinates: Z up, faces toward -Y. GLB: Y up, faces toward +Z.
All model roots are at the ground contact point; no collision nodes are animated.
"""
import bpy
import math
import json
import shutil
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[1]
PI = math.pi
FPS = 60
CURRENT = None
ASSETS = {}
MATS = {}
CLIPS = {"idle": 2.4, "blink": 0.27, "pull": 0.12, "release": 0.65,
         "impact": 0.60, "merge": 0.50, "hop": 0.60, "escape": 0.70}


def srgb(c):
    return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4


def material(name, hexcolor, rough=.45, coat=.0, subsurface=.0, metallic=0):
    rgb = [int(hexcolor[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*[srgb(x) for x in rgb], 1)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs['Base Color'].default_value = m.diffuse_color
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Coat Weight'].default_value = coat
    p.inputs['Coat Roughness'].default_value = .22
    p.inputs['Subsurface Weight'].default_value = subsurface
    p.inputs['Subsurface Radius'].default_value = (1, .45, .24)
    MATS[name] = m
    return m


def mesh(name, vertices, faces, mat=None, parent=None, smooth=True):
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    # Explicit projected UVs allow normal/tangent generation in downstream engines.
    # These assets use untextured PBR colors; the UVs remain editable for later painting.
    uvmap = data.uv_layers.new(name='UVMap')
    mins = [min(v.co[i] for v in data.vertices) for i in range(3)]
    spans = [max(.001, max(v.co[i] for v in data.vertices) - mins[i]) for i in range(3)]
    for poly in data.polygons:
        dominant = max(range(3), key=lambda i: abs(poly.normal[i]))
        axes = [(1, 2), (0, 2), (0, 1)][dominant]
        for li in poly.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            uvmap.data[li].uv = tuple((co[a] - mins[a]) / spans[a] for a in axes)
    ob = bpy.data.objects.new(name, data)
    CURRENT.objects.link(ob)
    if mat:
        data.materials.append(mat)
    if smooth:
        for p in data.polygons:
            p.use_smooth = True
    ob.parent = parent
    return ob


def empty(name, parent=None):
    ob = bpy.data.objects.new(name, None)
    CURRENT.objects.link(ob)
    ob.parent = parent
    ob.empty_display_size = .15
    return ob


def uv(name, center, scale, mat, parent=None, seg=24, rings=14, rotation=None):
    v = [(0, 0, -1)]
    for j in range(1, rings):
        p = -PI / 2 + PI * j / rings
        v.extend([(math.cos(p) * math.cos(2 * PI * i / seg),
                   math.cos(p) * math.sin(2 * PI * i / seg), math.sin(p))
                  for i in range(seg)])
    top = len(v)
    v.append((0, 0, 1))
    f = [(0, 1 + (i + 1) % seg, 1 + i) for i in range(seg)]
    for j in range(rings - 2):
        a, b = 1 + j * seg, 1 + (j + 1) * seg
        f.extend([(a + i, a + (i + 1) % seg, b + (i + 1) % seg, b + i)
                  for i in range(seg)])
    a = 1 + (rings - 2) * seg
    f.extend([(a + i, a + (i + 1) % seg, top) for i in range(seg)])
    ob = mesh(name, v, f, mat, parent)
    ob.location, ob.scale = center, scale
    if rotation:
        ob.rotation_euler = rotation
    return ob


def bevel(ob, width, segments=3):
    b = ob.modifiers.new("Soft manufactured edges", 'BEVEL')
    b.width, b.segments = width, segments
    b.limit_method = 'ANGLE'
    b = ob.modifiers.new("Weighted corner normals", 'WEIGHTED_NORMAL')
    b.keep_sharp = True
    return ob


def box(name, center, size, mat, parent=None, radius=.08):
    x, y, z = [s / 2 for s in size]
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
         (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    f = [(0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5),
         (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)]
    ob = mesh(name, v, f, mat, parent)
    ob.location = center
    return bevel(ob, radius, 4)


def tube(name, points, radius, mat, parent=None, sides=8, closed=False):
    v, f = [], []
    count = len(points)
    points = [Vector(p) for p in points]
    for j, p in enumerate(points):
        a = points[(j - 1) % count] if (j or closed) else points[0]
        b = points[(j + 1) % count] if (j < count - 1 or closed) else points[-1]
        t = (b - a).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((0, 1, 0))
        n = t.cross(ref).normalized()
        m = t.cross(n).normalized()
        for i in range(sides):
            q = p + radius * (n * math.cos(2 * PI * i / sides) +
                              m * math.sin(2 * PI * i / sides))
            v.append(tuple(q))
    for j in range(count if closed else count - 1):
        a, b = j * sides, ((j + 1) % count) * sides
        f.extend([(a + i, a + (i + 1) % sides, b + (i + 1) % sides, b + i)
                  for i in range(sides)])
    if not closed:
        f += [tuple(reversed(range(sides))), tuple((count - 1) * sides + i for i in range(sides))]
    return mesh(name, v, f, mat, parent)


def lathe(name, profile, mat, parent=None, seg=64, lobes=0, amplitude=0):
    v, f = [], []
    for z, r in profile:
        for i in range(seg):
            a = 2 * PI * i / seg
            rr = max(.001, r) * (1 + amplitude * math.cos(lobes * a))
            v.append((rr * math.cos(a), rr * math.sin(a), z))
    for j in range(len(profile) - 1):
        a, b = j * seg, (j + 1) * seg
        f.extend([(a + i, a + (i + 1) % seg, b + (i + 1) % seg, b + i) for i in range(seg)])
    f.extend([tuple(reversed(range(seg))), tuple((len(profile) - 1) * seg + i for i in range(seg))])
    return mesh(name, v, f, mat, parent)


def catmull(points, subdivisions=4):
    out = []
    for i in range(len(points) - 1):
        p0, p1 = Vector(points[max(0, i - 1)]), Vector(points[i])
        p2, p3 = Vector(points[i + 1]), Vector(points[min(len(points) - 1, i + 2)])
        for j in range(subdivisions):
            t = j / subdivisions
            p = .5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                      (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
            out.append(tuple(p))
    out.append(points[-1])
    return out


PIP_PROFILE = catmull([(.19, .001), (.22, .30), (.31, .51), (.48, .65),
                       (.70, .72), (.88, .71), (1.07, .63), (1.23, .48),
                       (1.33, .30), (1.44, .13), (1.50, .001)], 4)


def pip_radius(z):
    for (z0, r0), (z1, r1) in zip(PIP_PROFILE, PIP_PROFILE[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return .01


def face_surface(kind, x, z):
    if kind == 'pip':
        r = pip_radius(z)
        return -.84 * math.sqrt(max(.005, r * r - x * x))
    sx, sy, sz, cz = ((.72, .62, .65, .83) if kind == 'berry' else (.77, .66, .69, .87))
    return -sy * math.sqrt(max(.005, 1 - (x / sx) ** 2 - ((z - cz) / sz) ** 2))


def face_patch(name, coords, mat, kind, parent, offset=.014):
    # Interior rings follow the curved dough surface too. A flat polygon spanning
    # only the perimeter can sink into the belly during squash, leaving a ring.
    cx = sum(x for x, z in coords) / len(coords)
    cz = sum(z for x, z in coords) / len(coords)
    pts = [Vector((cx, face_surface(kind, cx, cz) - offset, cz))]
    n = len(coords)
    for r in (.34, .67, 1):
        for x, z in coords:
            xx, zz = cx + (x - cx) * r, cz + (z - cz) * r
            pts.append(Vector((xx, face_surface(kind, xx, zz) - offset, zz)))
    faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
    for ring in range(2):
        a, b = 1 + ring * n, 1 + (ring + 1) * n
        faces.extend([(a + i, a + (i + 1) % n, b + (i + 1) % n, b + i) for i in range(n)])
    faces = [tuple(reversed(t)) if (pts[t[1]] - pts[t[0]]).cross(pts[t[2]] - pts[t[0]]).y > 0
             else t for t in faces]
    ob = mesh(name, pts, faces, mat, parent, smooth=True)
    solid = ob.modifiers.new("Raised facial inlay", 'SOLIDIFY')
    solid.thickness = .008
    return ob


def new_asset(key, title, category):
    global CURRENT
    CURRENT = bpy.data.collections.new(title)
    bpy.context.scene.collection.children.link(CURRENT)
    root = empty(title)
    root['asset_id'] = key
    root['category'] = category
    root['coordinate_notes'] = 'Ground pivot; Blender Z up / face -Y; GLB Y up / face +Z'
    ASSETS[key] = {'key': key, 'title': title, 'category': category,
                   'collection': CURRENT, 'root': root}
    return root


def rig_character(key, root, parts, body, eye_centers):
    arm_data = bpy.data.armatures.new(key.title() + "_skeleton")
    arm = bpy.data.objects.new(key.title() + "Rig", arm_data)
    CURRENT.objects.link(arm)
    arm.parent = root
    arm.show_in_front = True
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    defs = {'Root': ((0, 0, 0), (0, 0, .18), None),
            'Body': ((0, 0, .25), (0, 0, 1.15), 'Root'),
            'Crest': ((0, 0, 1.12), (0, 0, 1.48), 'Body'),
            'Arm.L': ((-.55, 0, .66), (-.85, 0, .66), 'Body'),
            'Arm.R': ((.55, 0, .66), (.85, 0, .66), 'Body'),
            'Foot.L': ((-.26, -.04, .14), (-.26, -.26, .14), 'Root'),
            'Foot.R': ((.26, -.04, .14), (.26, -.26, .14), 'Root')}
    for label, pt in eye_centers.items():
        defs['Eye.' + label] = (pt, (pt[0], pt[1], pt[2] + .10), 'Body')
        defs['Lid.' + label] = (pt, (pt[0], pt[1], pt[2] + .10), 'Body')
    for name, (head, tail, parent) in defs.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob, bone in parts:
        ob.parent = arm
        group = ob.vertex_groups.new(name=bone)
        group.add(list(range(len(ob.data.vertices))), 1, 'REPLACE')
        if ob == body and key == 'pip':
            crest = ob.vertex_groups.new(name='Crest')
            for vertex in ob.data.vertices:
                w = max(0., min(1., (vertex.co.z - 1.10) / .27))
                if w:
                    group.add([vertex.index], 1 - w, 'REPLACE')
                    crest.add([vertex.index], w, 'REPLACE')
        mod = ob.modifiers.new("Bun deformation rig", 'ARMATURE')
        mod.object = arm
    body.shape_key_add(name='Basis')
    breath = body.shape_key_add(name='Breath')
    puff = body.shape_key_add(name='Squash')
    for base, a, b in zip(body.data.vertices, breath.data, puff.data):
        # Gentle radial morphs complement bone squash while keeping the face registered.
        w = max(0, 1 - abs(base.co.z - .70) / .65)
        # Keep the radial surface displacement below the 0.019 facial inlay
        # clearance. The shared Body bone supplies the large squash/stretch.
        a.co.x *= 1 + .008 * w
        a.co.y *= 1 + .008 * w
        b.co.x *= 1 + .015 * w
        b.co.y *= 1 + .007 * w
    ASSETS[key]['rig'] = arm
    ASSETS[key]['body'] = body
    animate(arm, body)


def add_nla(data, action, clip):
    data.animation_data_create()
    track = data.animation_data.nla_tracks.new()
    track.name = clip
    strip = track.strips.new(clip, 1, action)
    strip.name = clip
    strip.extrapolation = 'NOTHING'
    data.animation_data.action = None


def animate(arm, body):
    for clip, seconds in CLIPS.items():
        action = bpy.data.actions.new(clip)
        arm.animation_data_create()
        arm.animation_data.action = action
        morphs = body.data.shape_keys
        morph_action = bpy.data.actions.new(clip + '_morph')
        morphs.animation_data_create()
        morphs.animation_data.action = morph_action
        end = max(4, round(seconds * FPS))
        for frame in range(1, end + 2):
            t = (frame - 1) / end
            bump = math.sin(PI * t) ** 2
            ease = t * t * (3 - 2 * t)
            breathe, squash, blink = 0., 0., 0.
            for b in arm.pose.bones:
                b.rotation_mode = 'XYZ'
                b.location = (0, 0, 0)
                b.rotation_euler = (0, 0, 0)
                b.scale = (1, 1, 1)
            B, R = arm.pose.bones['Body'], arm.pose.bones['Root']
            if clip == 'idle':
                breathe = (1 - math.cos(2 * PI * t)) / 2
                B.scale = (1, 1 + .016 * breathe, 1)
                for label, sign in [('L', -1), ('R', 1)]:
                    arm.pose.bones['Arm.' + label].rotation_euler.z = sign * .035 * math.sin(2 * PI * t)
                blink = max(0., 1 - abs(t - .73) / .035)
            elif clip == 'blink':
                blink = min(1., max(0., bump * 1.5 - .25))
            elif clip == 'pull':
                squash = ease
                h = 1 - .28 * squash
                B.scale = (1 / math.sqrt(h), h, 1 / math.sqrt(h))
                B.rotation_euler.x = -.10 * squash
            elif clip == 'release':
                s = math.sin(5 * PI * t) * math.exp(-4.8 * t) * (1 - ease)
                h = 1 + .31 * s
                B.scale = (1 / math.sqrt(h), h, 1 / math.sqrt(h))
            elif clip == 'impact':
                squash = max(0., math.sin(5 * PI * t) * math.exp(-4.2 * t) * (1 - ease))
                h = 1 - .32 * math.sin(5 * PI * t) * math.exp(-4.2 * t) * (1 - ease)
                B.scale = (1 / math.sqrt(h), h, 1 / math.sqrt(h))
            elif clip == 'merge':
                R.location.y = .22 * bump
                h = 1 + .22 * math.sin(3 * PI * t) * (1 - ease)
                B.scale = (1 / math.sqrt(h), h, 1 / math.sqrt(h))
                breathe = bump
            elif clip in ('hop', 'escape'):
                R.location.y = (.35 if clip == 'hop' else .52) * bump
                B.rotation_euler.z = (.10 if clip == 'hop' else .24) * math.sin(2 * PI * t)
                for label, sign in [('L', -1), ('R', 1)]:
                    arm.pose.bones['Arm.' + label].rotation_euler.z = sign * .40 * bump
                    arm.pose.bones['Foot.' + label].rotation_euler.x = sign * .25 * bump
            arm.pose.bones['Crest'].rotation_euler.x = .16 * math.sin(5 * PI * t) * math.exp(-3 * t) * (1 - ease) if clip in ('release', 'impact', 'merge') else -.08 * squash
            for label in ['L', 'R']:
                arm.pose.bones['Eye.' + label].scale = (1, max(.015, 1 - blink), 1)
                arm.pose.bones['Lid.' + label].scale = (max(.001, blink),) * 3
            for b in arm.pose.bones:
                for channel in ('location', 'rotation_euler', 'scale'):
                    b.keyframe_insert(channel, frame=frame, group=b.name)
            morphs.key_blocks['Breath'].value = breathe
            morphs.key_blocks['Squash'].value = squash
            morphs.key_blocks['Breath'].keyframe_insert('value', frame=frame)
            morphs.key_blocks['Squash'].keyframe_insert('value', frame=frame)
        for act in (action, morph_action):
            for fc in act.fcurves:
                for k in fc.keyframe_points:
                    k.interpolation = 'LINEAR'
        add_nla(arm, action, clip)
        add_nla(morphs, morph_action, clip)
    reset_pose(arm, body)


def reset_pose(arm, body):
    for data in (arm, body.data.shape_keys):
        if data.animation_data:
            data.animation_data.action = None
            for t in data.animation_data.nla_tracks:
                t.mute = True
    for b in arm.pose.bones:
        b.location, b.rotation_euler, b.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
        if b.name.startswith('Lid'):
            b.scale = (.001,) * 3
    for k in body.data.shape_keys.key_blocks:
        k.value = 0


def character(kind):
    title = kind.title()
    root = new_asset(kind, title, 'characters')
    parts = []
    color = MATS[{'pip': 'Warm dough', 'berry': 'Strawberry dough', 'mango': 'Mango dough'}[kind]]
    cheekmat = MATS['Berry blush' if kind == 'berry' else 'Peach blush']
    if kind == 'pip':
        v, f, seg = [], [], 64
        for z, rad in PIP_PROFILE:
            w = max(0, min(1, (z - 1.07) / .43))
            for i in range(seg):
                a = 2 * PI * i / seg
                r = max(.001, rad) * (1 + .14 * math.sin(PI * w) * math.cos(7 * a + w * .8))
                v.append((r * math.cos(a), .84 * r * math.sin(a), z))
        for j in range(len(PIP_PROFILE) - 1):
            a, b = j * seg, (j + 1) * seg
            f.extend([(a + i, a + (i + 1) % seg, b + (i + 1) % seg, b + i) for i in range(seg)])
        f += [tuple(reversed(range(seg))), tuple((len(PIP_PROFILE) - 1) * seg + i for i in range(seg))]
        body = mesh('Pip_pleated_dough', v, f, color, root)
    else:
        dims = (.72, .62, .65) if kind == 'berry' else (.77, .66, .69)
        center = (0, 0, .83 if kind == 'berry' else .87)
        # Baked dimensions keep body morphs in the same world-space convention as Pip.
        body = uv(title + '_dough', (0, 0, 0), (1, 1, 1), color, root, seg=40, rings=24)
        for v in body.data.vertices:
            v.co = Vector((v.co.x * dims[0], v.co.y * dims[1], v.co.z * dims[2] + center[2]))
        count = 3 if kind == 'berry' else 4
        for i in range(count):
            if kind == 'berry':
                x, z, lean = [(-.16, 1.48, -.55), (0, 1.55, .05), (.16, 1.48, .55)][i]
                ob = uv(title + '_cream_petal_' + str(i + 1), (x, .0, z), (.105, .105, .185),
                        MATS['Warm dough'], root, seg=20, rings=12, rotation=(0, lean, 0))
            else:
                x = (i - 1.5) * .16
                z = 1.51 + (.07 if i in (1, 2) else .0)
                ob = uv(title + '_crown_lobe_' + str(i + 1), (x, .01, z), (.13, .12, .19),
                        MATS['Golden crest'], root, seg=20, rings=12,
                        rotation=(0, (i - 1.5) * .22, 0))
            parts.append((ob, 'Crest'))
    parts.append((body, 'Body'))
    width = {'pip': .73, 'berry': .74, 'mango': .79}[kind]
    for label, sign in [('L', -1), ('R', 1)]:
        arm = uv(title + '_arm_' + label, (sign * width, -.025, .66), (.14, .14, .17), color,
                 root, seg=20, rings=12, rotation=(0, sign * .35, 0))
        foot = uv(title + '_foot_' + label, (sign * .25, -.055, .135), (.165, .205, .135), color,
                  root, seg=20, rings=12)
        parts.extend([(arm, 'Arm.' + label), (foot, 'Foot.' + label)])
    eyes = {}
    for label, sign in [('L', -1), ('R', 1)]:
        x, z = sign * .217, .865
        y = face_surface(kind, x, z) - .022
        eyes[label] = (x, y, z)
        angle = sign * .30
        eye = uv(title + '_chocolate_eye_' + label, (x, y, z), (.057, .037, .081), MATS['Chocolate'],
                 root, seg=24, rings=14, rotation=(0, 0, angle))
        gleam = uv(title + '_eye_glint_' + label, (x - .016, y - .033, z + .026),
                   (.015, .008, .020), MATS['Eye light'], root, seg=12, rings=8)
        small = uv(title + '_eye_glint_small_' + label, (x + .016, y - .032, z - .027),
                   (.007, .006, .009), MATS['Eye light'], root, seg=10, rings=6)
        parts.extend([(eye, 'Eye.' + label), (gleam, 'Eye.' + label), (small, 'Eye.' + label)])
        lidpoints = []
        for i in range(13):
            xx = x - .054 + .108 * i / 12
            zz = z - .012 + .036 * math.sin(PI * i / 12)
            lidpoints.append((xx, face_surface(kind, xx, zz) - .030, zz))
        lid = tube(title + '_closed_eye_' + label, lidpoints, .012, MATS['Chocolate'], root, sides=6)
        parts.append((lid, 'Lid.' + label))
        cx, cz = sign * .395, .705
        cheek = [(cx + .087 * math.cos(2 * PI * i / 32), cz + .078 * math.sin(2 * PI * i / 32))
                 for i in range(32)]
        parts.append((face_patch(title + '_blush_' + label, cheek, cheekmat, kind, root, .019), 'Body'))
    # A broad open U-shaped smile and a pink tongue inset, both modeled geometry.
    w, z = .165, .765
    outline = [(-w + 2 * w * i / 24, z + .022 * ((-w + 2 * w * i / 24) / w) ** 2) for i in range(25)]
    outline += [(w * math.cos(PI * i / 24), z - .157 * math.sin(PI * i / 24)) for i in range(1, 24)]
    parts.append((face_patch(title + '_smile', outline, MATS['Mouth cocoa'], kind, root, .028), 'Body'))
    tongue = [(.090 * math.cos(2 * PI * i / 36), .651 + .040 * math.sin(2 * PI * i / 36)) for i in range(36)]
    parts.append((face_patch(title + '_tongue', tongue, MATS['Tongue'], kind, root, .044), 'Body'))
    rig_character(kind, root, parts, body, eyes)
    root['tier'] = {'pip': 1, 'berry': 2, 'mango': 3}[kind]
    root['silhouette'] = {'pip': 'Seven folded dough pleats', 'berry': 'Three cream petals',
                          'mango': 'Four golden crown lobes'}[kind]
    return root


def roundrect(w, h, r, n=12):
    pts = []
    for cx, cy, start in [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90),
                           (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]:
        for j in range(n):
            a = math.radians(start + 90 * j / (n - 1))
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def tray():
    root = new_asset('tray', 'TurquoiseTray', 'props')
    rings = [(7.40, 11.00, .78, .02), (7.62, 11.22, .88, .12), (7.66, 11.26, .92, .42),
             (7.60, 11.20, .92, .57), (7.48, 11.08, .88, .64), (7.12, 10.72, .72, .65),
             (6.92, 10.52, .65, .56), (6.83, 10.43, .60, .34), (6.77, 10.37, .57, .20)]
    v, f = [], []
    for w, h, r, z in rings:
        v.extend([(x, y, z) for x, y in roundrect(w, h, r)])
    seg = len(v) // len(rings)
    for j in range(len(rings) - 1):
        for i in range(seg):
            f.append((j * seg + i, j * seg + (i + 1) % seg,
                      (j + 1) * seg + (i + 1) % seg, (j + 1) * seg + i))
    rim = mesh('Cream_sculpted_tray_rim', v, f, MATS['Vanilla ceramic'], root)
    rim.data.materials.append(MATS['Honey trim'])
    rim.data.materials.append(MATS['Turquoise ceramic'])
    for p in rim.data.polygons:
        ring = p.index // seg
        p.material_index = 1 if ring < 2 else (2 if ring >= 6 else 0)
    floor = box('Turquoise_play_surface', (0, 0, .115), (6.86, 10.46, .20),
                MATS['Turquoise ceramic'], root, .18)
    pts = [(x, y, .212) for x, y in roundrect(6.40, 9.98, .45, 16)]
    tube('Quiet_inner_pinstripe', pts, .012, MATS['Mint inlay'], root, sides=6, closed=True)
    # Sparse, low-contrast embossed flower marks echo the reference without visual noise.
    for i, (x, y) in enumerate([(-2.5, -3.7), (2.4, -1.7), (-2.4, .3), (2.4, 2.1), (-1.5, 4.0)]):
        for dx, dy in [(-.065, 0), (.065, 0), (0, -.065), (0, .065)]:
            uv('Tray_flower_%s_%s_%s' % (i, dx, dy), (x + dx, y + dy, .217),
               (.065, .065, .004), MATS['Quiet glaze'], root, seg=12, rings=6)
    root['interior_dimensions'] = [6.77, 10.37]
    root['surface_height'] = .215
    return root


def rounded_star(name, radius, height, mat, parent=None, z=0):
    corners = [Vector((radius * (1 if i % 2 == 0 else .52) * math.sin(i * PI / 5),
                       radius * (1 if i % 2 == 0 else .52) * math.cos(i * PI / 5))) for i in range(10)]
    # Quadratic corner rounding keeps the five lobes tactile rather than razor-edged.
    outline = []
    for i, c in enumerate(corners):
        a = c.lerp(corners[(i - 1) % 10], .20)
        b = c.lerp(corners[(i + 1) % 10], .20)
        for j in range(5):
            t = j / 4
            q = (1 - t) ** 2 * a + 2 * (1 - t) * t * c + t ** 2 * b
            outline.append(tuple(q))
    n = len(outline)
    v = [(x, y, z) for x, y in outline] + [(x, y, z + height) for x, y in outline]
    flat = [Vector((x, y, 0)) for x, y in outline]
    index = {tuple(p): i for i, p in enumerate(flat)}
    tris = [tuple(p if isinstance(p, int) else index[tuple(p)] for p in t)
            for t in tessellate_polygon([flat])]
    tris = [tuple(reversed(t)) if (flat[t[1]] - flat[t[0]]).cross(flat[t[2]] - flat[t[0]]).z < 0
            else t for t in tris]
    f = [tuple(reversed(t)) for t in tris] + [tuple(i + n for i in t) for t in tris]
    f += [(i + n, (i + 1) % n + n, (i + 1) % n, i) for i in range(n)]
    return bevel(mesh(name, v, f, mat, parent), min(.045, height * .35), 3)


def gate():
    root = new_asset('wafer_gate', 'WaferGate', 'props')
    bar_group = empty('WaferBar', root)
    bar = box('Breakable_strawberry_wafer', (0, 0, .43), (5.65, .48, .51),
              MATS['Wafer strawberry'], bar_group, .055)
    bar['role'] = 'Replace or animate this node when a matching-tier bun breaks the gate'
    # Clip diagonal relief lines against the face rectangle.
    for slope in [-1, 1]:
        for k in range(-16, 17):
            intercept = k * .26
            pts = []
            for x in [-2.74, 2.74]:
                z = slope * x + intercept
                if -.21 <= z <= .21:
                    pts.append((x, -.246, z + .43))
            for z in [-.21, .21]:
                x = (z - intercept) / slope
                if -2.74 < x < 2.74:
                    pts.append((x, -.246, z + .43))
            if len(pts) == 2:
                tube('Wafer_diamond_relief_%s_%s' % (slope, k), pts, .014,
                     MATS['Wafer relief'], bar_group, sides=6)
    # A second shallow grid on the top catches the studio light.
    for i in range(21):
        x = -2.67 + i * .26
        tube('Wafer_top_ridge_' + str(i), [(x, -.20, .690), (x + .17, .20, .690)],
             .010, MATS['Wafer relief'], bar_group, sides=6)
    for sign in [-1, 1]:
        box('Vanilla_gate_support_' + str(sign), (sign * 2.94, 0, .43), (.50, .76, .86),
            MATS['Warm biscuit'], root, .12)
        s = rounded_star('Gate_biscuit_star_' + str(sign), .126, .026, MATS['Honey trim'], root)
        s.rotation_euler.x = PI / 2
        s.location = (sign * 2.94, -.385, .57)
        uv('Support_lower_button_' + str(sign), (sign * 2.94, -.38, .25), (.067, .018, .067),
           MATS['Biscuit shading'], root, seg=16, rings=8)
    root['opening_width'] = 5.38
    return root


def jelly():
    root = new_asset('jelly_bumper', 'JellyBumper', 'props')
    lathe('Jelly_vanilla_saucer', [(0, .001), (.015, .64), (.05, .73), (.10, .77),
                                 (.16, .76), (.19, .69), (.16, .60), (.13, .001)],
          MATS['Vanilla ceramic'], root)
    profile = catmull([(.17, .001), (.17, .57), (.22, .62), (.36, .61), (.57, .55),
                       (.75, .46), (.84, .34), (.88, .17), (.885, .001)], 3)
    lathe('Eight_lobed_strawberry_jelly', profile, MATS['Glossy jelly'], root,
          seg=80, lobes=8, amplitude=.12)
    root['bumper_radius'] = .69
    return root


def reward():
    root = new_asset('reward_star', 'RewardStar', 'props')
    rounded_star('Golden_reward_star', .76, .23, MATS['Mango dough'], root, z=.04)
    rounded_star('Vanilla_star_inlay', .37, .065, MATS['Warm dough'], root, z=.28)
    return root


def plate():
    root = new_asset('exit_plate', 'ExitPlate', 'props')
    lathe('Cream_exit_dish', [(0, .001), (.0, .62), (.035, .87), (.10, .94),
                            (.17, .95), (.22, .91), (.21, .84), (.14, .73), (.12, .001)],
          MATS['Vanilla ceramic'], root)
    lathe('Turquoise_dish_glaze', [(.125, .001), (.128, .66), (.16, .76), (.18, .79),
                                  (.176, .76), (.135, .66), (.134, .001)],
          MATS['Turquoise ceramic'], root)
    tube('Honey_dish_rim', [(.868 * math.cos(2 * PI * i / 80), .868 * math.sin(2 * PI * i / 80), .22)
                           for i in range(80)], .025, MATS['Mango dough'], root, closed=True)
    # Friendly bun outline and face embossed into the glaze.
    outline = catmull([(-.33, -.12, .143), (-.34, .10, .143), (-.22, .25, .143),
                       (-.10, .28, .143), (-.10, .38, .143), (.0, .41, .143),
                       (.07, .30, .143), (.18, .31, .143), (.31, .12, .143),
                       (.32, -.12, .143), (.18, -.27, .143), (-.15, -.27, .143),
                       (-.33, -.12, .143)], 4)
    tube('Embossed_bun_outline', outline, .021, MATS['Mint inlay'], root)
    for x in [-.12, .12]:
        tube('Dish_bun_eye_' + str(x), [(x - .032 + .064 * i / 10, .015 - .026 * math.sin(PI * i / 10), .149)
                                      for i in range(11)], .014, MATS['Mint inlay'], root, sides=6)
    tube('Dish_bun_smile', [(-.06 + .12 * i / 12, -.08 - .045 * math.sin(PI * i / 12), .149)
                           for i in range(13)], .014, MATS['Mint inlay'], root, sides=6)
    return root


def look_at(ob, point):
    ob.rotation_euler = (Vector(point) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def area(scene, name, loc, energy, size, color=(1, 1, 1)):
    d = bpy.data.lights.new(name, 'AREA')
    d.energy, d.shape, d.size, d.color = energy, 'DISK', size, color
    o = bpy.data.objects.new(name, d)
    scene.collection.objects.link(o)
    o.location = loc
    look_at(o, (0, 0, .6))
    return o


def studio(scene, size=3.0, camera=(3, -5, 2.6), target=(0, 0, .78), transparent=False):
    world = bpy.data.worlds.new(scene.name + '_world')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.82, .90, .88, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = .35
    scene.world = world
    area(scene, scene.name + '_large_softbox', (-3.5, -4.5, 6), 330, 4.5, (1, .96, .88))
    area(scene, scene.name + '_mint_fill', (4, -1, 3.5), 140, 4, (.86, .96, 1))
    area(scene, scene.name + '_rim', (1, 4, 5), 300, 3.5, (1, .97, .88))
    d = bpy.data.cameras.new(scene.name + '_camera')
    o = bpy.data.objects.new(scene.name + '_camera', d)
    scene.collection.objects.link(o)
    o.location = camera
    look_at(o, target)
    d.type, d.ortho_scale, d.lens = 'ORTHO', size, 50
    d.clip_start, d.clip_end = .05, 250
    scene.camera = o
    scene.render.engine = 'CYCLES'
    scene.cycles.device, scene.cycles.samples = 'CPU', 32
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 3
    scene.render.resolution_x, scene.render.resolution_y = 1024, 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = transparent
    scene.render.fps = FPS
    scene.view_settings.view_transform = 'Khronos PBR Neutral'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = -.3
    scene.render.threads_mode, scene.render.threads = 'FIXED', 3
    return scene


def instance(scene, asset, location=(0, 0, 0), scale=1, angle=0, label=None, tilt=0):
    ob = bpy.data.objects.new(label or asset['title'] + '_instance', None)
    ob.instance_type = 'COLLECTION'
    ob.instance_collection = asset['collection']
    ob.location = location
    ob.scale = (scale,) * 3
    ob.rotation_euler.z = angle
    ob.rotation_euler.x = tilt
    scene.collection.objects.link(ob)
    return ob


def ground(scene, color='Studio ivory', size=200, z=-.012):
    global CURRENT
    old = CURRENT
    c = bpy.data.collections.new(scene.name + '_set')
    scene.collection.children.link(c)
    CURRENT = c
    box('Studio_ground', (0, 0, z - .03), (size, size, .06), MATS[color], radius=.01)
    CURRENT = old


def asset_scene(asset):
    scene = bpy.data.scenes.new(asset['title'] + '_Studio')
    scene.collection.children.link(asset['collection'])
    if asset['category'] == 'characters':
        studio(scene, 2.55, (2.1, -5, 2.25), (0, 0, .80))
    elif asset['key'] == 'tray':
        studio(scene, 13.8, (8, -12, 19), (0, 0, 0))
        for ob in scene.objects:
            if ob.type == 'LIGHT':
                ob.data.energy *= 6
                ob.location *= 2
                ob.data.size *= 2
    elif asset['key'] == 'wafer_gate':
        studio(scene, 7.6, (2.8, -6, 3.2), (0, 0, .40))
    else:
        studio(scene, 2.7, (2, -3.5, 3), (0, 0, .30))
    asset['scene'] = scene
    return scene


def consolidate_asset(asset):
    """Batch like-colored parts without changing bone weights or morph topology.

    Beveled authoring meshes and the morph body stay independent. In particular,
    all wafer relief belongs to WaferBar so it can disappear as one breakable unit.
    """
    global CURRENT
    CURRENT = asset['collection']
    bpy.context.view_layer.update()
    groups = {}
    for ob in list(CURRENT.objects):
        if ob.type != 'MESH' or ob.data.shape_keys or len(ob.data.materials) != 1:
            continue
        if any(m.type not in {'ARMATURE', 'SOLIDIFY'} for m in ob.modifiers):
            continue
        solid = next((m.thickness for m in ob.modifiers if m.type == 'SOLIDIFY'), 0)
        key = (ob.parent, ob.data.materials[0], solid)
        groups.setdefault(key, []).append(ob)
    for (parent, mat, solid), objects in groups.items():
        if len(objects) < 2:
            continue
        verts, faces, weights = [], [], {}
        for ob in objects:
            offset = len(verts)
            verts.extend([tuple(ob.matrix_local @ v.co) for v in ob.data.vertices])
            faces.extend([tuple(offset + i for i in p.vertices) for p in ob.data.polygons])
            for v in ob.data.vertices:
                for assignment in v.groups:
                    name = ob.vertex_groups[assignment.group].name
                    weights.setdefault(name, []).append((offset + v.index, assignment.weight))
        combined = mesh(asset['title'] + '_' + mat.name.replace(' ', '_'), verts, faces, mat, parent)
        if solid:
            mod = combined.modifiers.new('Raised facial inlay', 'SOLIDIFY')
            mod.thickness = solid
        for name, assignments in weights.items():
            vg = combined.vertex_groups.new(name=name)
            for index, weight in assignments:
                vg.add([index], weight, 'REPLACE')
        if parent and parent.type == 'ARMATURE':
            mod = combined.modifiers.new('Bun deformation rig', 'ARMATURE')
            mod.object = parent
        for ob in objects:
            bpy.data.objects.remove(ob, do_unlink=True)


def export_asset(asset):
    bpy.context.window.scene = asset['scene']
    bpy.ops.object.select_all(action='DESELECT')
    for ob in asset['collection'].all_objects:
        ob.select_set(True)
    if 'rig' in asset:
        for data in (asset['rig'], asset['body'].data.shape_keys):
            data.animation_data.action = None
            for t in data.animation_data.nla_tracks:
                t.mute = False
    path = ROOT / 'exports' / asset['category'] / (asset['key'] + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, use_active_scene=True,
        export_yup=True, export_extras=True, export_animations='rig' in asset,
        export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
        export_force_sampling=True, export_frame_range=False,
        export_apply=asset['category'] == 'props',
        export_morph=True, export_morph_animation=True, export_morph_normal=True,
        export_materials='EXPORT', export_cameras=False, export_lights=False)
    if 'rig' in asset:
        reset_pose(asset['rig'], asset['body'])
    bpy.context.view_layer.update()
    out = ROOT / 'blend' / asset['category'] / (asset['key'] + '.blend')
    bpy.data.libraries.write(str(out), {asset['scene']}, fake_user=True, compress=True)
    shutil.copy2(path, ROOT / 'godot' / 'assets' / path.name)
    dg = bpy.context.evaluated_depsgraph_get()
    triangles, vertices, meshes, materials = 0, 0, 0, set()
    for ob in asset['collection'].all_objects:
        if ob.type == 'MESH':
            ev = ob.evaluated_get(dg)
            data = ev.to_mesh()
            data.calc_loop_triangles()
            triangles += len(data.loop_triangles)
            vertices += len(data.vertices)
            meshes += 1
            materials.update(m.name for m in ob.data.materials if m)
            ev.to_mesh_clear()
    asset['stats'] = {'triangles': triangles, 'vertices': vertices, 'mesh_objects': meshes,
                      'materials': sorted(materials), 'glb_bytes': path.stat().st_size,
                      'animations': list(CLIPS) if 'rig' in asset else [],
                      'root_at_ground': True, 'front_axis_glb': '+Z', 'up_axis_glb': '+Y'}
    print('ASSET_EXPORTED', asset['key'], json.dumps(asset['stats']), flush=True)


def composition_scenes():
    scene = bpy.data.scenes.new('Family_Studio')
    studio(scene, 6.9, (3.2, -9, 4.2), (0, 0, .80))
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    ground(scene)
    instance(scene, ASSETS['pip'], (-1.8, -.05, 0), angle=-.08)
    instance(scene, ASSETS['berry'], (0, .2, 0), angle=.03)
    instance(scene, ASSETS['mango'], (1.85, .0, 0), angle=.12)
    scene['description'] = 'Original 3D characters reconstructed from supplied concept screenshots'
    board = bpy.data.scenes.new('Board_Showcase')
    studio(board, 12.8, (0, -10.5, 18), (0, 0, .15))
    board.render.resolution_x, board.render.resolution_y = 1000, 1400
    ground(board, 'Studio mint')
    for ob in board.objects:
        if ob.type == 'LIGHT':
            ob.data.energy *= 8
            ob.location *= 2.4
            ob.data.size *= 2.5
    instance(board, ASSETS['tray'])
    instance(board, ASSETS['wafer_gate'], (0, 3.65, .215))
    instance(board, ASSETS['exit_plate'], (0, 4.5, .215), scale=.65)
    instance(board, ASSETS['pip'], (-1.75, -2.8, .215), angle=-.18, tilt=-.35)
    instance(board, ASSETS['pip'], (1.65, -2.5, .215), angle=.14, tilt=-.35)
    instance(board, ASSETS['berry'], (-1.6, .1, .215), scale=1.05, angle=-.12, tilt=-.35)
    instance(board, ASSETS['mango'], (1.35, 1.3, .215), scale=1.08, angle=.18, tilt=-.35)
    instance(board, ASSETS['jelly_bumper'], (.7, -1.0, .215), scale=1.12)
    props = bpy.data.scenes.new('Props_Studio')
    studio(props, 8.0, (5, -8, 9), (0, 0, .2))
    props.render.resolution_x, props.render.resolution_y = 1400, 1000
    ground(props)
    instance(props, ASSETS['wafer_gate'], (0, 1.1, 0))
    instance(props, ASSETS['jelly_bumper'], (-2.1, -1.0, 0), 1.2)
    instance(props, ASSETS['reward_star'], (0, -1.3, 0), 1.1)
    instance(props, ASSETS['exit_plate'], (2.1, -1, 0), 1.1)
    for key in ('pip', 'berry', 'mango'):
        s = bpy.data.scenes.new('Turnaround_' + key.title())
        studio(s, 7.0, (0, -8, 2.9), (0, 0, .8))
        s.render.resolution_x, s.render.resolution_y = 1800, 700
        ground(s)
        for x, a, lab in [(-2.1, 0, 'Front'), (0, -PI / 2, 'Side'), (2.1, PI, 'Back')]:
            instance(s, ASSETS[key], (x, 0, 0), angle=a, label=key.title() + '_' + lab)


def main():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)
    material('Warm dough', 'FFF0C4', .48, .04, .06)
    material('Strawberry dough', 'FF528D', .48, .04, .04)
    material('Mango dough', 'FFB824', .43, .10, .035)
    material('Golden crest', 'FFA619', .42, .10, .03)
    material('Chocolate', '44231D', .20, .22)
    material('Mouth cocoa', '582421', .38)
    material('Tongue', 'FF7B8E', .45)
    material('Eye light', 'FFF6DD', .22)
    material('Peach blush', 'F99155', .57)
    material('Berry blush', 'E8427B', .56)
    material('Vanilla ceramic', 'FFF0C9', .25, .30)
    material('Turquoise ceramic', '21B9AC', .26, .26)
    material('Mint inlay', 'A2E2CD', .38)
    material('Quiet glaze', '69C4B5', .38)
    material('Honey trim', 'EAC57B', .37)
    material('Warm biscuit', 'FFE5AB', .48, .04)
    material('Biscuit shading', 'E9BF7B', .50)
    material('Wafer strawberry', 'F75081', .53)
    material('Wafer relief', 'FF8EAD', .55)
    material('Glossy jelly', 'F83675', .16, .40)
    material('Studio ivory', 'F7F2E6', .65)
    material('Studio mint', 'D2ECE2', .65)
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    for kind in ((only,) if only else ('pip', 'berry', 'mango')):
        bpy.context.window.scene = bpy.data.scenes['Scene']
        character(kind)
        bpy.context.view_layer.update()
        consolidate_asset(ASSETS[kind])
        asset_scene(ASSETS[kind])
        export_asset(ASSETS[kind])
    if only:
        bpy.context.window.scene = ASSETS[only]['scene']
        ground(bpy.context.scene)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blend' / (only + '_proof.blend')), compress=True)
        return
    # Return to the working scene so subsequent asset collections are independent.
    bpy.context.window.scene = bpy.data.scenes['Scene']
    for factory in (tray, gate, jelly, reward, plate):
        root = factory()
        key = root['asset_id']
        bpy.context.view_layer.update()
        consolidate_asset(ASSETS[key])
        asset_scene(ASSETS[key])
        export_asset(ASSETS[key])
        bpy.context.window.scene = bpy.data.scenes['Scene']
    composition_scenes()
    # The working collection scene is a data staging area; open the polished family scene.
    bpy.context.window.scene = bpy.data.scenes['Family_Studio']
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blend' / 'bunbreak_master.blend'), compress=True)
    report = {'generator': 'Blender ' + bpy.app.version_string,
              'fps': FPS, 'clip_seconds': CLIPS,
              'source': 'Original geometry authored from supplied JPG screenshots; no prototype source used',
              'assets': {key: a['stats'] for key, a in ASSETS.items()}}
    (ROOT / 'reports' / 'asset-manifest.json').write_text(json.dumps(report, indent=2))
    print('BUILD_COMPLETE', len(ASSETS), 'assets', flush=True)


if __name__ == '__main__':
    main()
