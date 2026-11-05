"""Skeletli askar (rasm bo'yicha) + animatsiyalar.
blender -b -P soldier_rig.py -- <chiqish_papka>
Askar +X tomonga qaragan, Z - yuqori, Y - chap tomoni. Bo'yi ~1.8 m.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler, Quaternion
from lib import *
from lib import _obj_from_bm

out = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/soldier'
clear()
FPS = 24
bpy.context.scene.render.fps = FPS

UN = mat('Uniform', '#55683a', 0.85)
UN2 = mat('UniformDark', '#46572f', 0.85)
VS = mat('Vest', '#4a5a32', 0.8)
SK = mat('Skin', '#cf9f7a', 0.6)
BT = mat('Boots', '#6b4a2e', 0.75)
BK = mat('Black', '#1b1b1b', 0.5, 0.3)
HL = mat('Helmet', '#4f6034', 0.6)
EYE = mat('Eye', '#151515', 0.3)
BROW = mat('Brow', '#3a2a1e', 0.8)
LIP = mat('Lip', '#a8705a', 0.6)
TEAM = mat('TeamColor', '#e8b73a', 0.6)

# ---------------------------------------------------------------- skelet
J = {   # bo'g'im nuqtalari
    'pelvis': (0, 0, 0.98), 'spine': (0, 0, 1.12), 'chest': (0, 0, 1.30), 'neck': (0.01, 0, 1.47), 'head': (0.02, 0, 1.58), 'head_top': (0.02, 0, 1.80),
}
for s, sy in (('L', 1), ('R', -1)):
    J['shoulder_' + s] = (0, sy * 0.06, 1.43)
    J['arm_' + s] = (0, sy * 0.2, 1.42)
    J['elbow_' + s] = (0.0, sy * 0.24, 1.14)
    J['wrist_' + s] = (0.02, sy * 0.25, 0.9)
    J['hand_' + s] = (0.03, sy * 0.25, 0.8)
    J['hip_' + s] = (0, sy * 0.1, 0.95)
    J['knee_' + s] = (0.02, sy * 0.11, 0.53)
    J['ankle_' + s] = (0, sy * 0.115, 0.1)
    J['toe_' + s] = (0.17, sy * 0.115, 0.03)

BONES = [  # nom, bosh, oxir, ota
    ('Hips', 'pelvis', 'spine', None), ('Spine', 'spine', 'chest', 'Hips'), ('Chest', 'chest', 'neck', 'Spine'),
    ('Neck', 'neck', 'head', 'Chest'), ('Head', 'head', 'head_top', 'Neck')]
for s in ('L', 'R'):
    BONES += [('Shoulder.' + s, 'shoulder_' + s, 'arm_' + s, 'Chest'), ('UpperArm.' + s, 'arm_' + s, 'elbow_' + s, 'Shoulder.' + s),
              ('ForeArm.' + s, 'elbow_' + s, 'wrist_' + s, 'UpperArm.' + s), ('Hand.' + s, 'wrist_' + s, 'hand_' + s, 'ForeArm.' + s),
              ('Thigh.' + s, 'hip_' + s, 'knee_' + s, 'Hips'), ('Shin.' + s, 'knee_' + s, 'ankle_' + s, 'Thigh.' + s),
              ('Foot.' + s, 'ankle_' + s, 'toe_' + s, 'Shin.' + s)]

arm_data = bpy.data.armatures.new('SoldierRig')
rig = bpy.data.objects.new('SoldierRig', arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head = J[h]
    eb.tail = J[t]
    eb.roll = 0
    if par:
        eb.parent = arm_data.edit_bones[par]
        eb.use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- tana (skin modifier bilan silliq)
R = {'pelvis': 0.15, 'spine': 0.15, 'chest': 0.18, 'neck': 0.06, 'head': 0.06}
for s in ('L', 'R'):
    R.update({'shoulder_' + s: 0.09, 'arm_' + s: 0.065, 'elbow_' + s: 0.052, 'wrist_' + s: 0.04, 'hand_' + s: 0.045,
              'hip_' + s: 0.1, 'knee_' + s: 0.068, 'ankle_' + s: 0.055, 'toe_' + s: 0.045})
EDGES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck'), ('neck', 'head')]
for s in ('L', 'R'):
    EDGES += [('chest', 'shoulder_' + s), ('shoulder_' + s, 'arm_' + s), ('arm_' + s, 'elbow_' + s), ('elbow_' + s, 'wrist_' + s),
              ('wrist_' + s, 'hand_' + s), ('pelvis', 'hip_' + s), ('hip_' + s, 'knee_' + s), ('knee_' + s, 'ankle_' + s),
              ('ankle_' + s, 'toe_' + s)]
names = list(R.keys())
me = bpy.data.meshes.new('Body')
me.from_pydata([J[n] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
body = bpy.data.objects.new('Body', me)
bpy.context.collection.objects.link(body)
sk = body.modifiers.new('Skin', 'SKIN')
sm = body.modifiers.new('Subsurf', 'SUBSURF')
sm.levels = 1
for i, n in enumerate(names):
    r = R[n]
    sx = r
    sy = r
    if n in ('pelvis', 'spine', 'chest'):
        sx, sy = r * 0.72, r * 1.12   # tana old-orqadan tor, yondan keng
    me.skin_vertices[0].data[i].radius = (sx, sy)
me.skin_vertices[0].data[names.index('pelvis')].use_root = True
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.modifier_apply(modifier='Skin')
bpy.ops.object.modifier_apply(modifier='Subsurf')
body.select_set(False)
bpy.ops.object.shade_smooth()

# ---------------------------------------------------------------- vaznlar: har vertex eng yaqin 2 suyakka
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length

bone_segs = {b.name: (Vector(b.head_local), Vector(b.tail_local)) for b in arm_data.bones}
skip = set()
groups = {n: body.vertex_groups.new(name=n) for n in bone_segs}
for v in body.data.vertices:
    p = v.co
    ds = sorted(((seg_dist(p, a, b), n) for n, (a, b) in bone_segs.items() if n not in skip))[:3]
    w = [1.0 / max(1e-3, d) ** 3 for d, _ in ds]
    tot = sum(w)
    for (d, n), wi in zip(ds, w):
        groups[n].add([v.index], wi / tot, 'REPLACE')

# materiallar: qo'l - teri, botinka, qolgani forma
body.data.materials.append(UN)
body.data.materials.append(SK)
body.data.materials.append(BT)
for poly in body.data.polygons:
    c = poly.center
    nb = min(((seg_dist(c, a, b), n) for n, (a, b) in bone_segs.items() if n not in skip))[1]
    if nb.startswith('Hand'):
        poly.material_index = 1
    elif nb.startswith('Foot') or (nb.startswith('Shin') and c.z < 0.27):
        poly.material_index = 2
    elif nb == 'Neck':
        poly.material_index = 1

mod = body.modifiers.new('Armature', 'ARMATURE')
mod.object = rig
body.parent = rig

# ---------------------------------------------------------------- jihozlar (suyakka qattiq bog'langan)
GEAR = []
def attach(ob, bone):
    """Jihozni suyakka 100% vazn bilan bog'laydi (keyin tana bilan bitta mesh bo'ladi - o'yinda tez ishlaydi)."""
    apply_all([ob])
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.select_set(False)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    GEAR.append(ob)
    return ob

def sph(name, r, loc, material, scale=(1, 1, 1), segs=12, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    ob.scale = scale
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob

HZ = 1.66
attach(sph('HeadMesh', 0.115, (0.03, 0, HZ), SK, (1.0, 0.86, 1.08)), 'Head')
attach(sph('Nose', 0.025, (0.14, 0, HZ - 0.01), SK, (1.0, 0.8, 1.4), 8, 6), 'Head')
attach(sph('Jaw', 0.085, (0.06, 0, HZ - 0.075), SK, (1.0, 1.0, 0.7)), 'Head')
for s in (-1, 1):
    attach(sph('Eye', 0.016, (0.135, s * 0.042, HZ + 0.025), EYE, (0.6, 1, 1), 8, 6), 'Head')
    attach(box('Brow', (0.02, 0.045, 0.012), (0.138, s * 0.042, HZ + 0.055), BROW), 'Head')
    attach(sph('Ear', 0.03, (0.02, s * 0.1, HZ), SK, (0.6, 0.4, 1.0), 8, 6), 'Head')
attach(box('Mouth', (0.01, 0.05, 0.01), (0.145, 0, HZ - 0.06), LIP), 'Head')
# dubulg'a
helm = sph('Helmet', 0.145, (0.02, 0, HZ + 0.04), HL, (1.08, 1.0, 0.85), 14, 10)
attach(helm, 'Head')
attach(cyl('HelmetRim', 0.15, 0.025, (0.02, 0, HZ + 0.0), HL, axis='Z', verts=14), 'Head')
attach(box('NVGMount', (0.04, 0.06, 0.05), (0.16, 0, HZ + 0.1), BK), 'Head')
for s in (-1, 1):
    attach(box('Strap', (0.015, 0.012, 0.14), (0.05, s * 0.105, HZ - 0.06), BK), 'Head')
attach(cyl('HelmetBand', 0.152, 0.03, (0.02, 0, HZ + 0.03), TEAM, axis='Z', verts=14), 'Head')
# plitali jilet va cho'ntaklar
vest = hull_points('Vest', [(-0.11, -0.19, 1.05), (0.15, -0.18, 1.05), (-0.11, 0.19, 1.05), (0.15, 0.18, 1.05),
                            (-0.12, -0.2, 1.42), (0.15, -0.17, 1.4), (-0.12, 0.2, 1.42), (0.15, 0.17, 1.4)], VS)
attach(vest, 'Chest')
for k in range(3):
    attach(box('MagPouch', (0.05, 0.075, 0.12), (0.18, -0.09 + k * 0.09, 1.14), VS), 'Spine')
for s in (-1, 1):
    attach(box('SidePouch', (0.1, 0.05, 0.12), (0.04, s * 0.21, 1.1), VS), 'Spine')
    attach(box('Radio', (0.05, 0.04, 0.12), (0.12, s * 0.15, 1.33), BK), 'Chest')
attach(box('Belt', (0.27, 0.36, 0.06), (0.01, 0, 0.98), BK), 'Hips')
attach(box('Backpack', (0.17, 0.32, 0.42), (-0.21, 0, 1.24), VS), 'Chest')
attach(box('BackpackTop', (0.12, 0.28, 0.08), (-0.2, 0, 1.48), UN2), 'Chest')
for s in (-1, 1):
    attach(box('Armband', (0.1, 0.02, 0.06), (0.0, s * 0.255, 1.3), TEAM), 'UpperArm.' + ('L' if s > 0 else 'R'))
    attach(box('KneePad', (0.05, 0.1, 0.1), (0.08, s * 0.11, 0.54), BK), 'Thigh.' + ('L' if s > 0 else 'R'))
    attach(box('ThighPocket', (0.04, 0.08, 0.12), (0.03, s * 0.17, 0.72), UN2), 'Thigh.' + ('L' if s > 0 else 'R'))

# jihozlarni tana bilan birlashtirish (bitta skin mesh)
for o in bpy.context.selected_objects:
    o.select_set(False)
for o in GEAR:
    o.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = 'Soldier'

# avtomat: o'ng qo'lda; tayyor holatdagi joyi pozalarda o'ng qo'l orqali boshqariladi
rifle_parts = [box('Receiver', (0.42, 0.05, 0.09), (0.0, 0, 0.0), BK), box('Stock', (0.24, 0.045, 0.1), (-0.32, 0, -0.02), BK),
               box('Handguard', (0.26, 0.055, 0.065), (0.32, 0, 0.0), BK), cyl('Barrel', 0.012, 0.25, (0.57, 0, 0.0), BK, axis='X', verts=6),
               box('Mag', (0.05, 0.035, 0.14), (0.06, 0, -0.1), BK), box('Grip', (0.04, 0.035, 0.09), (-0.08, 0, -0.08), BK),
               box('Sight', (0.08, 0.03, 0.04), (0.05, 0, 0.065), BK)]
rifle = join('Rifle', rifle_parts, origin=(0, 0, 0))
muzzle = bpy.data.objects.new('RifleMuzzle', None)
bpy.context.collection.objects.link(muzzle)
muzzle.location = (0.7, 0, 0)
muzzle.parent = rifle

# ---------------------------------------------------------------- pozalar (armatura o'qlarida: X - oldinga, Y - chap, Z - yuqori)
def bone_rot(pb, ax, ay, az):
    """Armatura o'qlari bo'yicha burchak (gradus) -> suyakning lokal kvaternioni."""
    q = Euler((math.radians(ax), math.radians(ay), math.radians(az)), 'XYZ').to_quaternion()
    ml = pb.bone.matrix_local.to_3x3()
    local = ml.inverted() @ q.to_matrix() @ ml
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = local.to_quaternion()

def bone_loc(pb, dx, dy, dz):
    ml = pb.bone.matrix_local.to_3x3()
    pb.location = ml.inverted() @ Vector((dx, dy, dz))

READY = {  # avtomatni ko'krak oldida ushlab turish (low ready)
    'UpperArm.R': (0, -45, 12), 'ForeArm.R': (0, -60, 30), 'Hand.R': (0, 10, 0),
    'UpperArm.L': (0, -35, -12), 'ForeArm.L': (0, -85, -40), 'Hand.L': (0, 0, 0)}
AIM = {  # yelkaga qo'yib nishonga olish
    'UpperArm.R': (-20, -75, 8), 'ForeArm.R': (0, -50, 55), 'Hand.R': (0, 0, 0),
    'UpperArm.L': (10, -70, -25), 'ForeArm.L': (0, -10, -20), 'Chest': (0, 5, -10), 'Head': (0, 8, 8), 'Neck': (0, 0, 0)}

def apply_pose(pose, frame, loc=None):
    for pb in rig.pose.bones:
        e = pose.get(pb.name, (0, 0, 0))
        bone_rot(pb, *e)
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        if pb.name == 'Hips':
            bone_loc(pb, *(loc or (0, 0, 0)))
            pb.keyframe_insert('location', frame=frame)

def merge(*ps):
    out = {}
    for p in ps:
        for k, v in p.items():
            out[k] = tuple(a + b for a, b in zip(out.get(k, (0, 0, 0)), v))
    return out

def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    return act

def walk_pose(t, run=False):
    """t: 0..1 qadam fazasi."""
    a = math.sin(t * 2 * math.pi)
    c = math.cos(t * 2 * math.pi)
    sw = 42 if run else 26
    lean = 14 if run else 4
    p = dict(READY)
    p = merge(p, {'Thigh.L': (0, -sw * a, 0), 'Thigh.R': (0, sw * a, 0),
                  'Shin.L': (0, max(0, sw * 1.4 * c) + 5, 0), 'Shin.R': (0, max(0, -sw * 1.4 * c) + 5, 0),
                  'Foot.L': (0, -8 * a, 0), 'Foot.R': (0, 8 * a, 0),
                  'Spine': (0, lean, 3 * a), 'Chest': (0, 0, -3 * a), 'Hips': (0, 0, -5 * a)})
    bob = (abs(math.sin(t * 2 * math.pi)) * (0.06 if run else 0.03)) - (0.06 if run else 0.02)
    return p, (0, 0, bob)

# Idle
new_action('Idle')
for f, br in ((1, 0), (24, 1), (48, 0)):
    apply_pose(merge(READY, {'Chest': (0, 2 * br, 0), 'Head': (0, -2 * br, 3 * br)}), f)
# Walk / Run
new_action('Walk')
for i in range(9):
    pose, loc = walk_pose(i / 8)
    apply_pose(pose, 1 + i * 4, loc)
new_action('Run')
for i in range(9):
    pose, loc = walk_pose(i / 8, True)
    apply_pose(pose, 1 + int(i * 2.5), loc)
# Aim / Fire (tepki)
new_action('Aim')
apply_pose(AIM, 1)
apply_pose(merge(AIM, {'Chest': (0, 1, 0)}), 24)
new_action('Fire')
apply_pose(AIM, 1)
apply_pose(merge(AIM, {'Chest': (0, -6, 0), 'UpperArm.R': (0, 6, 0), 'UpperArm.L': (0, 6, 0), 'Head': (0, -4, 0)}), 3)
apply_pose(AIM, 8)
# Cho'kkalab otish
CROUCH = {'Thigh.L': (0, -85, 10), 'Shin.L': (0, 85, 0), 'Foot.L': (0, 0, 0),
          'Thigh.R': (0, -20, -10), 'Shin.R': (0, 110, 0), 'Foot.R': (0, -50, 0), 'Spine': (0, 10, 0)}
new_action('CrouchFire')
apply_pose(merge(AIM, CROUCH), 1, (0, 0, -0.42))
apply_pose(merge(AIM, CROUCH, {'Chest': (0, -6, 0), 'UpperArm.R': (0, 6, 0), 'UpperArm.L': (0, 6, 0)}), 3, (0, 0, -0.42))
apply_pose(merge(AIM, CROUCH), 8, (0, 0, -0.42))
# O'q tegishi (seskanish)
new_action('Hit')
apply_pose(READY, 1)
apply_pose(merge(READY, {'Spine': (0, -15, 10), 'Chest': (0, -10, 0), 'Head': (0, -20, 0), 'UpperArm.L': (0, 30, 0)}), 4, (-0.08, 0, -0.03))
apply_pose(READY, 14)
# O'lim 1: orqaga yiqilish
new_action('Death1')
apply_pose(READY, 1)
apply_pose(merge(READY, {'Spine': (0, -25, 0), 'Head': (0, -30, 0), 'UpperArm.L': (0, 60, 40), 'UpperArm.R': (0, 50, -40),
                         'Thigh.L': (0, -20, 0), 'Shin.L': (0, 40, 0), 'Shin.R': (0, 30, 0)}), 8, (-0.1, 0, -0.15))
apply_pose({'Hips': (0, -80, 0), 'Spine': (0, -8, 0), 'Head': (0, -10, 20), 'UpperArm.L': (0, 100, 70), 'UpperArm.R': (0, 80, -60),
            'ForeArm.L': (0, -20, 0), 'Thigh.L': (0, 70, 10), 'Shin.L': (0, 25, 0), 'Thigh.R': (0, 80, -5), 'Shin.R': (0, 10, 0)},
           22, (-0.55, 0, -0.82))
apply_pose({'Hips': (0, -88, 0), 'Spine': (0, -2, 0), 'Head': (0, 0, 25), 'UpperArm.L': (0, 110, 75), 'UpperArm.R': (0, 85, -65),
            'ForeArm.L': (0, -10, 0), 'Thigh.L': (0, 80, 10), 'Shin.L': (0, 20, 0), 'Thigh.R': (0, 88, -5), 'Shin.R': (0, 5, 0)},
           30, (-0.62, 0, -0.85))
# O'lim 2: tizzaga cho'kib, oldinga yiqilish
new_action('Death2')
apply_pose(READY, 1)
apply_pose(merge(READY, CROUCH, {'Spine': (0, 30, 0), 'Head': (0, 20, 0)}), 10, (0, 0, -0.45))
apply_pose({'Hips': (0, 75, 0), 'Spine': (0, 10, 0), 'Head': (0, -40, 30), 'UpperArm.L': (0, -150, 20), 'UpperArm.R': (0, -140, -25),
            'Thigh.L': (0, -60, 0), 'Shin.L': (0, 60, 0), 'Thigh.R': (0, -70, 0), 'Shin.R': (0, 80, 0)}, 24, (0.45, 0, -0.85))
apply_pose({'Hips': (0, 88, 0), 'Spine': (0, 2, 0), 'Head': (0, -10, 40), 'UpperArm.L': (0, -160, 25), 'UpperArm.R': (0, -150, -30),
            'Thigh.L': (0, -85, 0), 'Shin.L': (0, 10, 0), 'Thigh.R': (0, -88, 0), 'Shin.R': (0, 20, 0)}, 32, (0.6, 0, -0.88))
# G'alaba: avtomatni boshdan baland ko'tarib quvonish
new_action('Cheer')
for f, up in ((1, 0), (8, 1), (16, 0), (24, 1), (32, 0)):
    apply_pose(merge(READY, {'UpperArm.R': (0, -110 * up - 40, -20), 'ForeArm.R': (0, -30, 0), 'UpperArm.L': (0, -60 * up, 30),
                             'Head': (0, -15 * up, 0), 'Chest': (0, -5 * up, 0)}), f, (0, 0, 0.06 * up))

# avtomat o'ng qo'lga bog'lanadi: nishonga olish pozasida oldinga (+X) qaragan holda
rig.animation_data.action = bpy.data.actions['Aim']
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
hand = rig.pose.bones['Hand.R']
hp = rig.matrix_world @ hand.head
rifle.matrix_world = Matrix.Translation(hp + Vector((0.02, 0.0, 0.03)))
bpy.context.view_layer.update()
mw = rifle.matrix_world.copy()
rifle.parent = rig
rifle.parent_type = 'BONE'
rifle.parent_bone = 'Hand.R'
rifle.matrix_world = mw

# ---------------------------------------------------------------- jamoa rangi qismlarini bitta nomga yig'ish
rig.animation_data.action = bpy.data.actions['Idle']
os.makedirs(out, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'soldier_rig.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(out, 'soldier_rig.glb'), export_format='GLB', export_yup=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_apply=False)
print('ACTIONS', [a.name for a in bpy.data.actions])

# ---------------------------------------------------------------- tekshirish uchun rasmlar
if bpy.app.background:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 520, 620
    cd = bpy.data.cameras.new('C'); cd.lens = 50
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    shots = [('Idle', 1, -60), ('Walk', 9, -90), ('Run', 6, -90), ('Aim', 1, -50), ('CrouchFire', 1, -60), ('Death1', 30, -60), ('Death2', 32, -60), ('Cheer', 8, -40)]
    for name, fr, az in shots:
        rig.animation_data.action = bpy.data.actions[name]
        sc.frame_set(fr)
        a = math.radians(az)
        t = Vector((0, 0, 0.3)) if name.startswith('Death') else Vector((0, 0, 0.95))
        dd = 5.0 if name.startswith('Death') else 3.6
        cam.location = t + Vector((math.cos(a) * dd, math.sin(a) * dd, 1.6 if name.startswith('Death') else 0.9))
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(out, 'pose_%s.png' % name)
        bpy.ops.render.render(write_still=True)
