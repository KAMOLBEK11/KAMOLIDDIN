"""Ot (skelet + animatsiyalar): Idle, Walk, Gallop, Rear, Death.
blender -b -P horse.py -- <chiqish_papka> [preview]
Ot +X tomonga qaragan, Z - yuqori. Yag'rini ~1.5 m. Egar balandligi (chavandoz tos joyi) SADDLE_Z.
"""
import sys, os, math, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Euler
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/medieval_out'
PREVIEW = 'preview' in ARGS
SADDLE_Z = 1.42
clear()
bpy.context.scene.render.fps = 24

COAT = mat('HorseCoat', '#6b4226', 0.75)
DARK = mat('Mane', '#1f1510', 0.9)
HOOF = mat('Hoof', '#2a2420', 0.6)
LEATH = mat('Leather', '#4a2e1a', 0.7)
TEAM = mat('TeamColor', '#2f7d4a', 0.7)
GOLD = mat('Gold', '#c9a03a', 0.35, 0.8)
EYE = mat('Eye', '#0c0c0c', 0.3)

J = {'tail0': (-0.95, 0, 1.32), 'rump': (-0.72, 0, 1.36), 'back': (-0.1, 0, 1.3), 'withers': (0.45, 0, 1.45),
     'neck1': (0.72, 0, 1.62), 'poll': (1.02, 0, 1.92), 'muzzle': (1.38, 0, 1.6), 'tail1': (-1.12, 0, 1.0), 'tail2': (-1.18, 0, 0.62)}
for s, sy in (('L', 1), ('R', -1)):
    y = sy * 0.2
    J['fsh_' + s] = (0.52, y, 1.22); J['fel_' + s] = (0.5, y, 0.92); J['fkn_' + s] = (0.52, y, 0.52)
    J['ffe_' + s] = (0.52, y, 0.18); J['fho_' + s] = (0.56, y, 0.0)
    J['hhip_' + s] = (-0.72, y, 1.25); J['hsti_' + s] = (-0.58, y, 0.9); J['hhock_' + s] = (-0.82, y, 0.55)
    J['hfe_' + s] = (-0.78, y, 0.18); J['hho_' + s] = (-0.75, y, 0.0)

BONES = [('Root', 'back', 'withers', None), ('Hind', 'back', 'rump', 'Root'), ('Neck', 'withers', 'neck1', 'Root'),
         ('Neck2', 'neck1', 'poll', 'Neck'), ('Head', 'poll', 'muzzle', 'Neck2'),
         ('Tail', 'tail0', 'tail1', 'Hind'), ('Tail2', 'tail1', 'tail2', 'Tail')]
for s in ('L', 'R'):
    BONES += [('FUpper.' + s, 'fsh_' + s, 'fel_' + s, 'Root'), ('FFore.' + s, 'fel_' + s, 'fkn_' + s, 'FUpper.' + s),
              ('FCannon.' + s, 'fkn_' + s, 'ffe_' + s, 'FFore.' + s), ('FHoof.' + s, 'ffe_' + s, 'fho_' + s, 'FCannon.' + s),
              ('HThigh.' + s, 'hhip_' + s, 'hsti_' + s, 'Hind'), ('HShin.' + s, 'hsti_' + s, 'hhock_' + s, 'HThigh.' + s),
              ('HCannon.' + s, 'hhock_' + s, 'hfe_' + s, 'HShin.' + s), ('HHoof.' + s, 'hfe_' + s, 'hho_' + s, 'HCannon.' + s)]

arm_data = bpy.data.armatures.new('HorseRig')
rig = bpy.data.objects.new('HorseRig', arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head = J[h]; eb.tail = J[t]; eb.roll = 0
    if par:
        eb.parent = arm_data.edit_bones[par]; eb.use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')

# ---- tana: skin modifier
pts = {'tail0': 0.17, 'rump': 0.36, 'back': 0.36, 'chest': 0.37, 'withers': 0.28, 'neck1': 0.2, 'poll': 0.13,
       'head_m': 0.12, 'muzzle': 0.09}
P = dict(J)
P['chest'] = (0.38, 0, 1.2)
P['head_m'] = (1.2, 0, 1.78)
edges = [('tail0', 'rump'), ('rump', 'back'), ('back', 'chest'), ('chest', 'withers'), ('withers', 'neck1'),
         ('neck1', 'poll'), ('poll', 'head_m'), ('head_m', 'muzzle')]
for s in ('L', 'R'):
    for k, r in (('fsh_', 0.13), ('fel_', 0.085), ('fkn_', 0.06), ('ffe_', 0.05), ('fho_', 0.06),
                 ('hhip_', 0.17), ('hsti_', 0.11), ('hhock_', 0.065), ('hfe_', 0.05), ('hho_', 0.06)):
        pts[k + s] = r
    edges += [('chest', 'fsh_' + s), ('fsh_' + s, 'fel_' + s), ('fel_' + s, 'fkn_' + s), ('fkn_' + s, 'ffe_' + s), ('ffe_' + s, 'fho_' + s),
              ('rump', 'hhip_' + s), ('hhip_' + s, 'hsti_' + s), ('hsti_' + s, 'hhock_' + s), ('hhock_' + s, 'hfe_' + s), ('hfe_' + s, 'hho_' + s)]
names = list(pts.keys())
me = bpy.data.meshes.new('HorseBody')
me.from_pydata([P[n] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
body = bpy.data.objects.new('Horse', me)
bpy.context.collection.objects.link(body)
body.modifiers.new('Skin', 'SKIN')
body.modifiers.new('Sub', 'SUBSURF').levels = 1
for i, n in enumerate(names):
    r = pts[n]
    if n in ('rump', 'back', 'chest'):
        me.skin_vertices[0].data[i].radius = (r * 0.85, r)
    elif n in ('neck1', 'poll'):
        me.skin_vertices[0].data[i].radius = (r * 1.2, r * 0.75)
    else:
        me.skin_vertices[0].data[i].radius = (r, r)
me.skin_vertices[0].data[names.index('back')].use_root = True
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.modifier_apply(modifier='Skin')
bpy.ops.object.modifier_apply(modifier='Sub')
body.select_set(False)
bpy.ops.object.shade_smooth()


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length


segs = {b.name: (Vector(b.head_local), Vector(b.tail_local)) for b in arm_data.bones}
def limb(n):
    if '.' in n:
        return n.split('.')[0][0] + n[-1]   # FL, FR, HL, HR
    return 'body'
groups = {n: body.vertex_groups.new(name=n) for n in segs}
for v in body.data.vertices:
    near = min(((seg_dist(v.co, a, b), n) for n, (a, b) in segs.items()))[1]
    lb = limb(near)
    ok = [n for n in segs if limb(n) == lb or (lb != 'body' and n in ('Root', 'Hind'))]
    ds = sorted(((seg_dist(v.co, a, b), n) for n, (a, b) in segs.items() if n in ok))[:3]
    w = [1.0 / max(1e-3, d) ** 3 for d, _ in ds]
    tot = sum(w)
    for (d, n), wi in zip(ds, w):
        groups[n].add([v.index], wi / tot, 'REPLACE')
for m in (COAT, HOOF, DARK):
    body.data.materials.append(m)
for poly in body.data.polygons:
    if poly.center.z < 0.13:
        poly.material_index = 1
body.modifiers.new('Arm', 'ARMATURE').object = rig
body.parent = rig

GEAR = []
def attach(ob, bone):
    apply_all([ob])
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.select_set(False)
    ob.vertex_groups.new(name=bone).add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    GEAR.append(ob)

# yol (mane), quloqlar, ko'zlar, egar, jabduq
mp = []
for k in range(8):
    t = k / 7
    p = Vector(J['withers']).lerp(Vector(J['poll']), t)
    for dy in (-0.035, 0.035):
        mp.append((p.x - 0.03, dy, p.z + 0.06))
        mp.append((p.x - 0.08, dy, p.z + 0.15 - t * 0.04))
attach(hull_points('Mane', mp[:8], DARK), 'Neck')
attach(hull_points('Mane2', mp[6:], DARK), 'Neck2')
for s in (-1, 1):
    attach(cone_ear := hull_points('Ear', [(1.0, s * 0.05, 1.98), (1.05, s * 0.07, 1.98), (1.02, s * 0.05, 1.96), (0.99, s * 0.07, 2.07)], COAT), 'Head')
    attach(box('Eye', (0.03, 0.02, 0.03), (1.15, s * 0.085, 1.84), EYE), 'Head')
    attach(cyl('Bridle', 0.012, 0.3, (1.2, s * 0.08, 1.72), LEATH, axis='X', verts=6), 'Head')
attach(box('Saddle', (0.42, 0.36, 0.1), (0.05, 0, 1.39), LEATH), 'Root')
attach(box('Cantle', (0.06, 0.3, 0.12), (-0.16, 0, 1.46), LEATH), 'Root')
attach(box('Pommel', (0.06, 0.2, 0.12), (0.26, 0, 1.47), GOLD), 'Root')
attach(box('Blanket', (0.7, 0.66, 0.03), (0.05, 0, 1.36), TEAM), 'Root')
for s in (-1, 1):
    attach(box('BlanketSide', (0.7, 0.03, 0.42), (0.05, s * 0.33, 1.16), TEAM), 'Root')
    attach(box('BlanketTrim', (0.72, 0.035, 0.05), (0.05, s * 0.335, 0.96), GOLD), 'Root')
    attach(cyl('Stirrup', 0.012, 0.45, (0.08, s * 0.32, 1.12), LEATH, axis='Z', verts=6), 'Root')
# dum
t0, t1, t2 = Vector(J['tail0']), Vector(J['tail1']), Vector(J['tail2'])
attach(hull_points('TailHair', [(t0.x, -0.05, t0.z + 0.05), (t0.x, 0.05, t0.z + 0.05), (t0.x, 0, t0.z - 0.06),
                                (t1.x - 0.06, -0.07, t1.z), (t1.x - 0.06, 0.07, t1.z), (t1.x + 0.04, 0, t1.z)], DARK), 'Tail')
attach(hull_points('TailHair2', [(t1.x - 0.06, -0.07, t1.z), (t1.x - 0.06, 0.07, t1.z), (t1.x + 0.04, 0, t1.z),
                                 (t2.x - 0.06, -0.09, t2.z), (t2.x - 0.06, 0.09, t2.z), (t2.x + 0.06, 0, t2.z - 0.05)], DARK), 'Tail2')

for o in bpy.context.selected_objects:
    o.select_set(False)
for o in GEAR:
    o.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = 'Horse'

# chavandoz o'tiradigan nuqta (Godot'da shu nuqtaga askar tosi qo'yiladi)
seat = bpy.data.objects.new('RiderSeat', None)
bpy.context.collection.objects.link(seat)
seat.location = (0.02, 0, SADDLE_Z)
seat.parent = rig
seat.parent_type = 'BONE'
seat.parent_bone = 'Root'
seat.location = (0.02, 0, SADDLE_Z)
bpy.context.view_layer.update()
mw = seat.matrix_world.copy()


def bone_rot(pb, ax, ay, az):
    q = Euler((math.radians(ax), math.radians(ay), math.radians(az)), 'XYZ').to_quaternion()
    ml = pb.bone.matrix_local.to_3x3()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (ml.inverted() @ q.to_matrix() @ ml).to_quaternion()


def bone_loc(pb, dx, dy, dz):
    pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector((dx, dy, dz))


def apply_pose(pose, frame, loc=None):
    for pb in rig.pose.bones:
        bone_rot(pb, *pose.get(pb.name, (0, 0, 0)))
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        if pb.name == 'Root':
            bone_loc(pb, *(loc or (0, 0, 0)))
            pb.keyframe_insert('location', frame=frame)


def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act


def leg(prefix, s, swing, bend):
    """swing: oyoq oldinga (-) / orqaga (+) gradus; bend: bo'g'imlarni bukish."""
    if prefix == 'F':
        return {'FUpper.' + s: (0, swing, 0), 'FFore.' + s: (0, -bend * 0.3, 0), 'FCannon.' + s: (0, bend, 0), 'FHoof.' + s: (0, bend * 0.4, 0)}
    return {'HThigh.' + s: (0, swing, 0), 'HShin.' + s: (0, bend * 0.6, 0), 'HCannon.' + s: (0, -bend * 0.9, 0), 'HHoof.' + s: (0, bend * 0.4, 0)}


def gait(t, phases, amp, lift, bob, neck_amp):
    pose = {}
    for (pre, s), ph in phases.items():
        a = 2 * math.pi * (t + ph)
        sw = -amp * math.sin(a)
        bend = lift * max(0.0, math.cos(a))
        pose.update(leg(pre, s, sw, bend))
    pose['Neck'] = (0, neck_amp * math.sin(2 * math.pi * t * 2), 0)
    pose['Tail'] = (0, 10 + 6 * math.sin(2 * math.pi * t), 0)
    pose['Root'] = (0, 2 * math.sin(2 * math.pi * t), 0)
    return pose, (0, 0, bob * math.sin(4 * math.pi * t))


new_action('Idle')
for f, b in ((1, 0), (30, 1), (60, 0)):
    apply_pose({'Neck': (0, -4 * b, 0), 'Neck2': (0, 6 * b, 3 * b), 'Tail': (0, 12, 8 * b)}, f)
new_action('Walk')
WALK = {('H', 'L'): 0.0, ('F', 'L'): 0.25, ('H', 'R'): 0.5, ('F', 'R'): 0.75}
for i in range(13):
    pose, loc = gait(i / 12, WALK, 18, 30, 0.02, 4)
    apply_pose(pose, 1 + i * 3, loc)
new_action('Gallop')
GAL = {('H', 'L'): 0.0, ('H', 'R'): 0.1, ('F', 'L'): 0.45, ('F', 'R'): 0.55}
for i in range(9):
    pose, loc = gait(i / 8, GAL, 38, 55, 0.08, 10)
    pose['Root'] = (0, 6 * math.sin(2 * math.pi * i / 8), 0)
    apply_pose(pose, 1 + int(i * 1.75), (0, 0, 0.1 * math.sin(2 * math.pi * i / 8)))
new_action('Rear')
apply_pose({}, 1)
REAR = {'Root': (0, -38, 0), 'Hind': (0, 38, 0), 'Neck': (0, 15, 0), 'FUpper.L': (0, -70, 0), 'FCannon.L': (0, 90, 0),
        'FUpper.R': (0, -55, 0), 'FCannon.R': (0, 100, 0), 'HThigh.L': (0, -30, 0), 'HThigh.R': (0, -30, 0), 'Tail': (0, 40, 0)}
apply_pose(REAR, 12, (-0.2, 0, 0.35))
apply_pose(REAR, 24, (-0.2, 0, 0.35))
apply_pose({}, 40)
new_action('Death')
apply_pose({}, 1)
apply_pose({'Root': (25, 0, 0), 'FUpper.L': (0, -20, 0), 'FCannon.L': (0, 60, 0), 'Neck': (0, 20, 0)}, 10, (0, 0, -0.3))
DEAD = {'Root': (85, 0, 0), 'Neck': (0, 25, -20), 'Neck2': (0, 10, 0), 'FUpper.L': (0, -30, 0), 'FUpper.R': (0, 20, 0),
        'HThigh.L': (0, 25, 0), 'HThigh.R': (0, -15, 0), 'Tail': (0, 0, 20)}
apply_pose(DEAD, 26, (0, -0.3, -0.85))
apply_pose(DEAD, 34, (0, -0.32, -0.88))

rig.animation_data.action = bpy.data.actions['Idle']
os.makedirs('/home/claude/work/medieval_blend', exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath='/home/claude/work/medieval_blend/horse.blend')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'horse.glb'), export_format='GLB', export_yup=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_apply=False)

if PREVIEW:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 560, 460
    cd = bpy.data.cameras.new('C'); cd.lens = 45
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    for act, fr in (('Idle', 1), ('Walk', 7), ('Gallop', 5), ('Gallop', 11), ('Rear', 12), ('Death', 34)):
        rig.animation_data.action = bpy.data.actions[act]
        sc.frame_set(fr)
        t = Vector((0, 0, 0.9))
        a = math.radians(-70)
        cam.location = t + Vector((math.cos(a) * 5.2, math.sin(a) * 5.2, 0.8))
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(OUT, 'prev_horse_%s_%d.png' % (act, fr))
        bpy.ops.render.render(write_still=True)
print('HORSE DONE')
