"""Jangovar fil (Hindiston, Afrika) va jangovar arava (Yunon).
blender -b -P beasts.py -- <chiqish_papka> [preview]
Fil: suyaklarga bog'langan silliq qismlar (tana, bosh, quloqlar, uch bo'g'imli xartum, tishlar, 4 oyoq, dum),
ustida minora (havda) - 'Howdah' suyagi (chavandozlar Godot'da shunga o'tqaziladi), 'Mahout' suyagi - filbon.
Animatsiyalar: Idle, Walk, Run, Attack (xartum va tish bilan urish, oldingi oyoqlarini ko'tarish), Hit, Death1.
Arava: 'Body' (g'ildiraklar aylanadi - 'WheelL/WheelR'), 'Driver'/'Warrior' joylari. Otlar Godot'da qo'shiladi.
Fil +X ga qaragan (askarlar kabi).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/beast_out'
PREVIEW = 'preview' in ARGS
os.makedirs(OUT, exist_ok=True)


def ell(name, r, loc, m, sc=(1, 1, 1), segs=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    o = _obj_from_bm(name, bm, m)
    o.location = loc
    o.scale = sc
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def tube(name, a, b, r1, r2, m, verts=16):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = cyl(name, r1, d.length, (0, 0, 0), m, axis='Z', verts=verts, r2=r2)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (a + b) / 2
    for f in o.data.polygons:
        f.use_smooth = True
    return o


# ================================================================ FIL

# suyaklar: nom, bosh, oxir, ota
FB = [
    ('Root', (0, 0, 0), (0, 0, 0.5), None),
    ('Body', (-0.2, 0, 2.3), (1.0, 0, 2.4), 'Root'),
    ('Head', (1.3, 0, 2.6), (2.0, 0, 2.7), 'Body'),
    ('Trunk1', (2.1, 0, 2.3), (2.25, 0, 1.6), 'Head'),
    ('Trunk2', (2.25, 0, 1.6), (2.25, 0, 0.95), 'Trunk1'),
    ('Trunk3', (2.25, 0, 0.95), (2.15, 0, 0.35), 'Trunk2'),
    ('EarL', (1.45, 0.5, 2.8), (1.3, 1.2, 2.5), 'Head'),
    ('EarR', (1.45, -0.5, 2.8), (1.3, -1.2, 2.5), 'Head'),
    ('Tail', (-1.45, 0, 2.5), (-1.6, 0, 1.6), 'Body'),
    ('Howdah', (-0.1, 0, 3.4), (-0.1, 0, 3.8), 'Body'),
    ('Mahout', (1.15, 0, 3.15), (1.15, 0, 3.5), 'Body'),
]
for side, sy in (('L', 0.55), ('R', -0.55)):
    for fr, fx in (('F', 0.85), ('B', -0.95)):
        FB.append(('%sLegU.%s' % (fr, side), (fx, sy, 1.9), (fx, sy, 1.0), 'Body'))
        FB.append(('%sLegD.%s' % (fr, side), (fx, sy, 1.0), (fx, sy, 0.08), '%sLegU.%s' % (fr, side)))


def build_elephant(style):
    clear()
    skin = mat('ElSkin', '#6e6964' if style == 'hind' else '#7a6e62', 0.9)
    tusk = mat('Ivory', '#efe6d0', 0.4)
    cloth = mat('Caparison', '#a8282a' if style == 'hind' else '#b8862e', 0.85)
    trim = mat('CapTrim', '#d8b040' if style == 'hind' else '#3a2a1a', 0.5, 0.3)
    iron = mat('ElIron', '#8a8f96', 0.4, 0.75)
    wood = mat('HWood', '#6e4a2c', 0.85)
    team = mat('TeamColor', '#2f7d4a', 0.7)
    arm = bpy.data.armatures.new('ElRig')
    rig = bpy.data.objects.new('Rig', arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for n, h, t, par in FB:
        eb = arm.edit_bones.new(n)
        eb.head = h
        eb.tail = t
        if par:
            eb.parent = arm.edit_bones[par]
    bpy.ops.object.mode_set(mode='OBJECT')
    parts = []      # (obj, bone)
    parts.append((ell('Torso', 1.0, (-0.15, 0, 2.2), skin, (1.55, 0.95, 0.95)), 'Body'))
    parts.append((ell('Belly', 0.9, (-0.1, 0, 1.85), skin, (1.4, 0.92, 0.7)), 'Body'))
    parts.append((ell('Skull', 0.62, (1.5, 0, 2.6), skin, (0.95, 0.85, 1.05)), 'Head'))
    parts.append((ell('Brow', 0.42, (1.85, 0, 2.55), skin, (0.8, 0.9, 0.9)), 'Head'))
    for s, b in ((1, 'EarL'), (-1, 'EarR')):
        e = ell('Ear', 0.55, (1.35, s * 0.62, 2.45), skin, (0.32, 1.0, 1.15) if style == 'hind' else (0.3, 1.25, 1.5))
        parts.append((e, b))
        tk = tube('Tusk', (1.95, s * 0.22, 2.05), (2.65, s * 0.3, 1.75 if style == 'hind' else 1.65), 0.075, 0.02, tusk, 10)
        parts.append((tk, 'Head'))
        for eye_z in (2.72,):
            parts.append((ell('Eye', 0.05, (1.98, s * 0.33, eye_z), mat('ElEye', '#151210', 0.3)), 'Head'))
    parts.append((tube('Trunk1M', (2.05, 0, 2.35), (2.25, 0, 1.6), 0.24, 0.17, skin), 'Trunk1'))
    parts.append((tube('Trunk2M', (2.25, 0, 1.6), (2.25, 0, 0.95), 0.17, 0.12, skin), 'Trunk2'))
    parts.append((tube('Trunk3M', (2.25, 0, 0.95), (2.15, 0, 0.32), 0.12, 0.08, skin), 'Trunk3'))
    for side, sy in (('L', 0.55), ('R', -0.55)):
        for fr, fx in (('F', 0.85), ('B', -0.95)):
            parts.append((tube('LegU', (fx, sy, 2.05), (fx, sy, 1.0), 0.33, 0.27, skin), '%sLegU.%s' % (fr, side)))
            parts.append((tube('LegD', (fx, sy, 1.0), (fx, sy, 0.12), 0.27, 0.29, skin), '%sLegD.%s' % (fr, side)))
            parts.append((ell('Foot', 0.31, (fx + 0.04, sy, 0.1), skin, (1.05, 1.0, 0.35)), '%sLegD.%s' % (fr, side)))
            if style == 'hind':
                parts.append((cyl('Anklet', 0.31, 0.12, (fx, sy, 0.45), trim, axis='Z', verts=16), '%sLegD.%s' % (fr, side)))
    parts.append((tube('TailM', (-1.45, 0, 2.5), (-1.65, 0, 1.55), 0.06, 0.03, skin, 8), 'Tail'))
    # yopinchiq (ikki yon) va zirh
    for s in (-1, 1):
        cap = box('Cloth', (2.2, 0.06, 1.3), (-0.15, s * 0.96, 2.25), cloth)
        parts.append((cap, 'Body'))
        parts.append((box('ClothTrim', (2.25, 0.07, 0.14), (-0.15, s * 0.97, 1.63), trim), 'Body'))
        parts.append((box('ClothTrim2', (2.25, 0.07, 0.1), (-0.15, s * 0.97, 2.88), trim), 'Body'))
    if style == 'hind':
        # bosh zirhi (po'lat plastina) va tishlarga taqilgan tig'lar
        parts.append((ell('HeadPlate', 0.5, (1.9, 0, 2.75), iron, (0.5, 0.9, 1.0)), 'Head'))
        for s in (-1, 1):
            parts.append((tube('TuskBlade', (2.6, s * 0.3, 1.77), (2.95, s * 0.32, 1.7), 0.03, 0.005, iron, 6), 'Head'))
    # havda (minora): yog'och sandiq, panjarali to'siq, soyabon
    hz = 3.1
    parts.append((box('HBase', (1.6, 1.4, 0.15), (-0.1, 0, hz), wood), 'Howdah'))
    for s in (-1, 1):
        parts.append((box('HSide', (1.6, 0.08, 0.55), (-0.1, s * 0.68, hz + 0.32), wood), 'Howdah'))
        parts.append((box('HEnd', (0.08, 1.4, 0.55), (-0.1 + s * 0.78, 0, hz + 0.32), wood), 'Howdah'))
        if style == 'afrika':
            for k in range(3):
                o = cyl('HShield', 0.22, 0.04, (-0.6 + k * 0.5, s * 0.74, hz + 0.3), team, axis='Y', verts=12)
                o.scale = (0.75, 1, 1.3)
                parts.append((o, 'Howdah'))
    if style == 'hind':
        for a in (-1, 1):
            for b in (-1, 1):
                parts.append((cyl('HPost', 0.04, 2.0, (-0.1 + a * 0.72, b * 0.62, hz + 1.3), trim, axis='Z', verts=6), 'Howdah'))
        parts.append((ell('Canopy', 0.95, (-0.1, 0, hz + 2.35), cloth, (1.0, 0.9, 0.3)), 'Howdah'))
        parts.append((cyl('CanopyFin', 0.04, 0.4, (-0.1, 0, hz + 2.75), trim, axis='Z', verts=6), 'Howdah'))
    parts.append((cyl('Pole', 0.03, 1.6, (-0.75, 0.55, hz + 0.9), wood, axis='Z', verts=6), 'Howdah'))
    parts.append((box('Flag', (0.5, 0.03, 0.34), (-0.5, 0.55, hz + 1.55), team), 'Howdah'))
    # bog'lash: qismni suyakka bog'lab qo'yish (rest holatida)
    for ob, bone in parts:
        bpy.context.view_layer.update()
        mw = ob.matrix_world.copy()
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
        ob.matrix_world = mw

    def key(pose, frame, loc=None):
        for pb in rig.pose.bones:
            ax, ay, az = pose.get(pb.name, (0, 0, 0))
            q = Euler((math.radians(ax), math.radians(ay), math.radians(az)), 'XYZ').to_quaternion()
            ml = pb.bone.matrix_local.to_3x3()
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = (ml.inverted() @ q.to_matrix() @ ml).to_quaternion()
            pb.keyframe_insert('rotation_quaternion', frame=frame)
            if pb.name == 'Root':
                pb.location = (ml.inverted() @ Vector(loc or (0, 0, 0)))
                pb.keyframe_insert('location', frame=frame)

    def act(name):
        a = bpy.data.actions.new(name)
        a.use_fake_user = True
        rig.animation_data_create()
        rig.animation_data.action = a
        return a

    act('Idle')
    for f, k in ((1, 0), (24, 1), (48, 0), (72, -1), (96, 0)):
        key({'EarL': (0, 0, 14 * k), 'EarR': (0, 0, -14 * k), 'Trunk1': (0, 6 * k, 4 * k), 'Trunk2': (0, 8 * k, 0), 'Trunk3': (0, 10 * k, 0),
             'Tail': (12 * k, 0, 0), 'Head': (0, 2 * k, 0)}, f)

    def gait(name, n, amp, bob):
        act(name)
        for i in range(n + 1):
            t = i / n * 2 * math.pi
            s1, s2 = math.sin(t), math.sin(t + math.pi)
            key({'FLegU.L': (0, -amp * s1, 0), 'BLegU.R': (0, -amp * s1, 0), 'FLegU.R': (0, -amp * s2, 0), 'BLegU.L': (0, -amp * s2, 0),
                 'FLegD.L': (0, max(0, amp * 0.8 * math.cos(t)), 0), 'BLegD.R': (0, -max(0, amp * 0.6 * math.cos(t)), 0),
                 'FLegD.R': (0, max(0, amp * 0.8 * math.cos(t + math.pi)), 0), 'BLegD.L': (0, -max(0, amp * 0.6 * math.cos(t + math.pi)), 0),
                 'Body': (4 * math.sin(t * 2), 0, 0), 'Head': (0, 3 * math.sin(t * 2), 0), 'Trunk1': (0, 10 * math.sin(t), 0),
                 'Trunk2': (0, 12 * math.sin(t), 0), 'Trunk3': (0, 14 * math.sin(t), 0), 'EarL': (0, 0, 10 * math.sin(t)), 'EarR': (0, 0, -10 * math.sin(t)),
                 'Tail': (15 * math.sin(t), 0, 0)}, 1 + int(i * 40 / n * (1.0 if name == 'Walk' else 0.6)), (0, 0, bob * abs(math.sin(t))))
    gait('Walk', 8, 18, 0.06)
    gait('Run', 8, 28, 0.14)
    act('Attack')
    # oldingi oyoqlarini ko'tarib, xartumini ko'tarib bosadi va tishi bilan uradi
    key({}, 1)
    key({'Body': (0, -14, 0), 'FLegU.L': (0, -40, 0), 'FLegU.R': (0, -35, 0), 'FLegD.L': (0, 50, 0), 'FLegD.R': (0, 45, 0),
         'Head': (0, -18, 0), 'Trunk1': (0, -60, 0), 'Trunk2': (0, -40, 0), 'Trunk3': (0, -30, 0), 'EarL': (0, 0, 30), 'EarR': (0, 0, -30)}, 12, (0, 0, 0.25))
    key({'Body': (0, 8, 0), 'FLegU.L': (0, 10, 0), 'FLegU.R': (0, 12, 0), 'Head': (0, 22, 0), 'Trunk1': (0, 30, 0), 'Trunk2': (0, 20, 0)}, 20, (0.15, 0, -0.05))
    key({}, 34)
    act('Hit')
    key({}, 1)
    key({'Body': (6, 0, 0), 'Head': (0, -10, 10), 'EarL': (0, 0, 25), 'EarR': (0, 0, -25), 'Trunk1': (0, -30, 0)}, 6)
    key({}, 16)
    act('Death1')
    key({}, 1)
    key({'Body': (25, 0, 0), 'FLegU.L': (0, 20, 0), 'Head': (0, 15, 0)}, 14, (0, 0, -0.3))
    key({'Body': (80, 0, 0), 'Head': (0, 20, 10), 'Trunk1': (0, 20, 0), 'FLegU.L': (40, 0, 0), 'BLegU.L': (40, 0, 0)}, 34, (0, -0.4, -1.1))
    for a in bpy.data.actions:
        if a.name in ('Idle', 'Walk', 'Run'):
            pass
    rig.animation_data.action = bpy.data.actions['Idle']
    smooth_all(50.0)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'fil_%s.glb' % style), export_format='GLB', export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_apply=False)
    return rig


# ================================================================ ARAVA

def build_chariot():
    clear()
    bronze = mat('Bronze', '#b08a4a', 0.35, 0.85)
    wood = mat('Wood', '#6e4a2c', 0.85)
    red = mat('TeamColor', '#a8282a', 0.7)
    body = []
    # savat (oldi baland, orqasi ochiq), pol, shoti (dyshlo), bo'yinturuq
    body.append(box('Floor', (1.0, 1.3, 0.08), (0, 0, 0.75), wood))
    pts = []
    for a in range(9):
        t = a / 8 * math.pi
        pts.append((0.45 * math.sin(t) + 0.0, -0.65 * math.cos(t), 0.79))
        pts.append((0.45 * math.sin(t) + 0.0, -0.65 * math.cos(t), 1.6))
    for i in range(8):
        a0 = pts[2 * i]; a1 = pts[2 * i + 2]
        body.append(hull_points('Rail%d' % i, [a0, pts[2 * i + 1], a1, pts[2 * i + 3],
                                                (a0[0] - 0.04, a0[1], a0[2]), (a1[0] - 0.04, a1[1], a1[2])], bronze if i % 2 else red))
    body.append(cyl('Axle', 0.05, 1.8, (0, 0, 0.62), wood, axis='Y', verts=8))
    body.append(tube('Pole', (0.4, 0, 0.7), (2.6, 0, 1.05), 0.05, 0.05, wood, 8))
    body.append(cyl('Yoke', 0.05, 1.5, (2.55, 0, 1.08), wood, axis='Y', verts=8))
    b = join('Body', body, origin=(0, 0, 0))
    wheels = []
    for nm, y in (('WheelL', 0.85), ('WheelR', -0.85)):
        w = [cyl('Rim', 0.62, 0.07, (0, y, 0.62), bronze, axis='Y', verts=24), cyl('Hub', 0.1, 0.18, (0, y, 0.62), bronze, axis='Y', verts=10)]
        for k in range(6):
            w.append(box('Spoke', (1.18, 0.04, 0.04), (0, y, 0.62), wood, (0, k * math.pi / 6, 0)))
        ob = join(nm, w, origin=(0, y, 0.62))
    for nm, loc in (('Driver', (0.15, 0.25, 0.8)), ('Warrior', (-0.15, -0.25, 0.8))):
        e = bpy.data.objects.new(nm, None)
        bpy.context.collection.objects.link(e)
        e.location = loc
    smooth_all(40.0)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'arava_yunon.glb'), export_format='GLB', export_yup=True)


build_elephant('hind')
build_elephant('afrika')
build_chariot()
if PREVIEW:
    clear()
    for i, n in enumerate(['fil_hind', 'fil_afrika', 'arava_yunon']):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location.y += i * 5.0 - 5.0
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 1400, 600
    cd = bpy.data.cameras.new('C'); cd.lens = 35
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (9, -14, 5)
    cam.rotation_euler = (Vector((0, 0, 2.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_beasts.png')
    bpy.ops.render.render(write_still=True)
print('BEASTS DONE')
