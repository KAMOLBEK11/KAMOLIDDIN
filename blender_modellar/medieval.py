"""1-zamon (Amir Temur davri) O'rta Osiyo askarlari: umumiy skelet + animatsiyalar + kiyim/qurol to'plamlari.
blender -b -P medieval.py -- <chiqish_papka> [preview]
Har askar alohida GLB: ichida tana, kiyim, qurol va bir xil nomli animatsiyalar:
  Idle, Walk, Run, Attack, Block, Hit, Death1, Death2, Cheer, Ride, RideAttack
Askar +X tomonga qaragan, Z - yuqori, Y - chap. Bo'yi ~1.75 m.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/medieval_out'
PREVIEW = 'preview' in ARGS
TMP = '/home/claude/work/medieval_blend'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

# ================================================================ skelet nuqtalari
J = {'pelvis': (0, 0, 0.96), 'spine': (0, 0, 1.10), 'chest': (0, 0, 1.28), 'neck': (0.01, 0, 1.45),
     'head': (0.02, 0, 1.55), 'head_top': (0.02, 0, 1.76)}
for s, sy in (('L', 1), ('R', -1)):
    J['shoulder_' + s] = (0, sy * 0.06, 1.41)
    J['arm_' + s] = (0, sy * 0.19, 1.40)
    J['elbow_' + s] = (0.0, sy * 0.23, 1.12)
    J['wrist_' + s] = (0.02, sy * 0.24, 0.88)
    J['hand_' + s] = (0.03, sy * 0.24, 0.79)
    J['hip_' + s] = (0, sy * 0.1, 0.93)
    J['knee_' + s] = (0.02, sy * 0.11, 0.52)
    J['ankle_' + s] = (0, sy * 0.115, 0.1)
    J['toe_' + s] = (0.17, sy * 0.115, 0.03)

BONES = [('Hips', 'pelvis', 'spine', None), ('Spine', 'spine', 'chest', 'Hips'), ('Chest', 'chest', 'neck', 'Spine'),
         ('Neck', 'neck', 'head', 'Chest'), ('Head', 'head', 'head_top', 'Neck')]
for s in ('L', 'R'):
    BONES += [('Shoulder.' + s, 'shoulder_' + s, 'arm_' + s, 'Chest'), ('UpperArm.' + s, 'arm_' + s, 'elbow_' + s, 'Shoulder.' + s),
              ('ForeArm.' + s, 'elbow_' + s, 'wrist_' + s, 'UpperArm.' + s), ('Hand.' + s, 'wrist_' + s, 'hand_' + s, 'ForeArm.' + s),
              ('Thigh.' + s, 'hip_' + s, 'knee_' + s, 'Hips'), ('Shin.' + s, 'knee_' + s, 'ankle_' + s, 'Thigh.' + s),
              ('Foot.' + s, 'ankle_' + s, 'toe_' + s, 'Shin.' + s)]


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length


def sph(name, r, loc, material, scale=(1, 1, 1), segs=12, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    ob.scale = scale
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cone(name, r1, r2, h, loc, material, verts=14):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r1, radius2=r2, depth=h)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def torus(name, R, r, loc, material, segs=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=segs, minor_segments=8, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


# ================================================================ ranglar (fraksiya to'plami)
FACTIONS = {
    'osiyo': {  # O'rta Osiyo (Temuriylar)
        'coat': '#7a2f2a', 'coat2': '#5a2420', 'trouser': '#3a3a44', 'skin': '#c8956c', 'boots': '#3a2618',
        'metal': '#9aa0a6', 'leather': '#6b4a2e', 'turban': '#e8e2d2', 'beard': '#1e1712', 'team': '#2f7d4a',
    },
    'rus': {  # Rus knyazliklari (XIV-XV asr): kolchuga, shishak dubulg'a, dumaloq qalqon, to'g'ri qilich
        'coat': '#6d7278', 'coat2': '#7a2a22', 'trouser': '#8c8676', 'skin': '#d6a684', 'boots': '#4a3020',
        'metal': '#8f959c', 'leather': '#5e4630', 'turban': '#e8e2d2', 'beard': '#6b4a2e', 'team': '#9a2a24',
        'rus': True,
    },
    'xitoy': {  # Min imperiyasi (XIV-XV asr): qizil brigandina (oltin mixli), popukli dubulg'a, dao, rotang qalqon
        'coat': '#8e2a22', 'coat2': '#2c2a2e', 'trouser': '#2f3038', 'skin': '#d9b48c', 'boots': '#1e1a18',
        'metal': '#7d848c', 'leather': '#5a3a24', 'turban': '#e8e2d2', 'beard': '#141210', 'team': '#c9a03a',
        'xitoy': True,
    },
    'arabi': {  # Arab qo'shini (XIV-XV asr): oq-qumrang to'n, oq salla, charm sovut
        'coat': '#d9cdb2', 'coat2': '#7a5a34', 'trouser': '#5a4a38', 'skin': '#b88660', 'boots': '#3a2618',
        'metal': '#9aa0a6', 'leather': '#6b4a2e', 'turban': '#f4f0e6', 'beard': '#1a1410', 'team': '#2f6b4a',
    },
    'afrika': {  # Mali / Kanem-Bornu (XIV-XV asr): paxtali qavat sovut, teri qalqon, temir qalpoq
        'coat': '#c9b48a', 'coat2': '#8a5a2e', 'trouser': '#d8cba8', 'skin': '#5a3826', 'boots': '#4a3020',
        'metal': '#8a8f96', 'leather': '#7a5230', 'turban': '#efe6d0', 'beard': '#141010', 'team': '#b8862e', 'look': 'afrika',
    },
    'hind': {  # Rajputlar / Dehli (XIV-XV asr): kolchuga, za'faron salla, dhal qalqon, egri talvar
        'coat': '#9aa0a6', 'coat2': '#c0392b', 'trouser': '#e8dcc0', 'skin': '#a8724e', 'boots': '#5a3a22',
        'metal': '#a0a6ac', 'leather': '#6b4a2e', 'turban': '#e8901c', 'beard': '#141010', 'team': '#d35400', 'look': 'hind',
    },
    'yunon': {  # Yunon (Vizantiya) piyodasi: bronza dubulg'a va sovut, qizil plash, katta dumaloq qalqon
        'coat': '#e8dcc0', 'coat2': '#a8282a', 'trouser': '#e8dcc0', 'skin': '#c99872', 'boots': '#6b4a2e',
        'metal': '#b08a4a', 'leather': '#7a5230', 'turban': '#e8dcc0', 'beard': '#2a1e14', 'team': '#a8282a', 'look': 'yunon',
    },
    'angliya': {  # Winston (Angliya) qirolligi: gerbli ustko'ylak, kolchuga, uchburchak qalqon, uzun kamon
        'coat': '#9aa0a6', 'coat2': '#2f6b3a', 'trouser': '#4a4a3a', 'skin': '#e0b08c', 'boots': '#3a2a1a',
        'metal': '#aab0b6', 'leather': '#6b4a2e', 'turban': '#e8e2d0', 'beard': '#7a5a3a', 'team': '#b0242a', 'look': 'angliya',
    },
    'ozbek': {  # 2-zamon (1850-1870) Buxoro/Xiva/Qo'qon askarlari: yo'l-yo'l to'n, salla yoki qora telpak
        'coat': '#5a2440', 'coat2': '#c9a03a', 'trouser': '#3a3530', 'skin': '#c8956c', 'boots': '#2e2018',
        'metal': '#9aa0a6', 'leather': '#5e4026', 'turban': '#ece6d6', 'beard': '#1e1712', 'team': '#2f7d4a',
        'era2': True,
    },
    # 2-zamonning boshqa qo'shinlari (1860-lar)
    'rus2': {'coat': '#e6e2d4', 'coat2': '#b03030', 'trouser': '#2e3a2e', 'skin': '#d6a684', 'boots': '#1e1a18',
             'metal': '#9aa0a6', 'leather': '#1e1e1e', 'turban': '#f0ece0', 'beard': '#6b4a2e', 'team': '#3a7a3a', 'era2': True, 'bayonet': True},
    'ingliz': {'coat': '#b0242a', 'coat2': '#e8d8a0', 'trouser': '#1e2340', 'skin': '#e0b08c', 'boots': '#151515',
               'metal': '#a0a6ac', 'leather': '#ecebe4', 'turban': '#f2efe6', 'beard': '#7a5a3a', 'team': '#c0303a', 'era2': True, 'bayonet': True},
    'yevropa2': {'coat': '#2a3a6a', 'coat2': '#c9a03a', 'trouser': '#a82a2a', 'skin': '#e0b08c', 'boots': '#151515',
                 'metal': '#a0a6ac', 'leather': '#ecebe4', 'turban': '#f2efe6', 'beard': '#4a3420', 'team': '#3a6ab8', 'era2': True, 'bayonet': True},
    'usmonli': {'coat': '#1e2a4a', 'coat2': '#b03030', 'trouser': '#1e2a4a', 'skin': '#c8956c', 'boots': '#151515',
                'metal': '#9aa0a6', 'leather': '#2a1e14', 'turban': '#f0ece0', 'beard': '#1e1712', 'team': '#b84a3a', 'era2': True, 'bayonet': True},
    'xitoy2': {'coat': '#2a3a7a', 'coat2': '#c03030', 'trouser': '#1e1e2a', 'skin': '#d9b48c', 'boots': '#151515',
               'metal': '#8d939a', 'leather': '#3a2a1a', 'turban': '#f0ece0', 'beard': '#141210', 'team': '#c8a03a', 'era2': True},
}
# 2-zamon: boshqa qo'shinlar kiyimi (har tur uchun bir xil, faqat bosh kiyim/kalta mundir)
E2X = {
    'rus2':     {'stripes': ('#e6e2d4',), 'hat': 'furajka', 'short': True},
    'ingliz':   {'stripes': ('#b0242a',), 'hat': 'pith', 'short': True},
    'yevropa2': {'stripes': ('#2a3a6a',), 'hat': 'kepi', 'short': True},
    'usmonli':  {'stripes': ('#1e2a4a',), 'hat': 'fez', 'short': False},
    'xitoy2':   {'stripes': ('#2a3a7a',), 'hat': 'qing', 'short': True},
}
# 2-zamon: har askar turining kiyimi (to'n yo'llari, bosh kiyim)
E2 = {
    'sarboz':    {'stripes': ('#5a2440', '#8a3a3a', '#3b2a4a'), 'hat': 'salla'},
    'miltiqchi': {'stripes': ('#6a5040', '#4a5560', '#7a6a50'), 'hat': 'salla'},
    'nayzachi':  {'stripes': ('#3d4a32', '#34402b'), 'hat': 'telpak'},
    'qilichboz': {'stripes': ('#3d4a32', '#34402b'), 'hat': 'telpak'},
    'kamonchi':  {'stripes': ('#8a3f2a', '#a0522d', '#6e3020'), 'hat': 'salla'},
    'qomondon':  {'stripes': ('#5a2a5e', '#8a6a2a'), 'hat': 'salla_oltin'},
    'otliq':     {'stripes': ('#2e3a5a', '#5a2a2a', '#3a4a6a'), 'hat': 'telpak'},
}
RIFLE_KINDS = ('sarboz', 'miltiqchi')
SWORD_KINDS = ('qilichboz', 'otliq', 'qomondon')


def stripe(ob, slot, cols, n=28):
    """to'n yo'llari: slot materialli yuzlarni tik yo'llarga bo'lib, navbat bilan cols ranglariga bo'yaydi"""
    base = len(ob.data.materials)
    for i, c in enumerate(cols):
        ob.data.materials.append(mat('Stripe%d_%s' % (i, c), c, 0.88))
    for poly in ob.data.polygons:
        if poly.material_index != slot:
            continue
        a = math.atan2(poly.center.y, poly.center.x)
        k = int((a + math.pi) / (2 * math.pi) * n) % len(cols)
        poly.material_index = base + k


def _tube(name, a, b, r, groups, verts=4):
    """a->b ingichka quvur; groups: (uchidagi guruh, oxiridagi guruh)"""
    bm = bmesh.new()
    d = (b - a).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = d.cross(u).normalized()
    rings = []
    for c in (a, b):
        ring = []
        for k in range(verts):
            t = k / verts * 2 * math.pi
            ring.append(bm.verts.new(c + (u * math.cos(t) + v * math.sin(t)) * r))
        rings.append(ring)
    for k in range(verts):
        bm.faces.new((rings[0][k], rings[0][(k + 1) % verts], rings[1][(k + 1) % verts], rings[1][k]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    g0 = ob.vertex_groups.new(name=groups[0])
    g1 = ob.vertex_groups.new(name=groups[1]) if groups[1] != groups[0] else g0
    g0.add(list(range(verts)), 1.0, 'REPLACE')
    g1.add(list(range(verts, 2 * verts)), 1.0, 'REPLACE')
    return ob


def archery_rig(rig, Matrix, half=0.55):
    """kamon tori va o'q.
    BowB - chap qo'lning bolasi, Copy Rotation bilan doim tik turadi (qorni nishonga, +X);
    tor uchlari BowB ga, o'rtasi 'Nock' suyagiga bog'langan. Otishda Nock o'ng qo'lga ergashadi (ta'siri kalitlangan);
    o'q 'ArrowB' da (Nock bolasi, Damped Track bilan doim kamon dastasiga qaraydi), faqat o'q qo'yilganda ko'rinadi."""
    hl = rig.pose.bones['Hand.L']
    grip = hl.head.lerp(hl.tail, 0.55)             # GRIP holatida kaft o'rtasi - kamon dastasi shu yerdan o'tadi
    MAPL = hl.bone.matrix_local @ hl.matrix.inverted()
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    gb = MAPL @ grip
    b0 = eb.new('BowB'); b0.head = gb; b0.tail = gb + Vector((0, 0.08, 0))     # ota-suyaksiz: aylanishi doim 0 (kamon tik)
    bpy.ops.object.mode_set(mode='OBJECT')
    cr = rig.pose.bones['BowB'].constraints.new('COPY_LOCATION')
    cr.target = rig; cr.subtarget = 'Hand.L'; cr.head_tail = 0.55     # joyi - chap kaft o'rtasi
    bpy.context.view_layer.update()
    bb = rig.pose.bones['BowB']
    MAP = bb.bone.matrix_local @ bb.matrix.inverted()
    # kamon: tik (yelkalari yuqori-pastga), qorni nishonga (+X), dastasi kaft ichida, tori kamonchi tomonda.
    # Copy Rotation tufayli BowB ning aylanishi doimiy (armatura bilan bir xil) - kamonni shu holatda qayta joylaymiz.
    GRIPX = 0.12 * (0.8 if half > 0.6 else 1.0)   # kamon obyektida dasta markazi (uzun ingliz kamoni x bo'yicha 0.8 ga siqilgan)
    org = bb.head - Vector((GRIPX, 0, 0))          # kamon obyektining boshlang'ich nuqtasi (armatura fazosi)
    mid = org + Vector((-0.055, 0, 0))
    t1 = org + Vector((-0.06, 0, half))
    t2 = org + Vector((-0.06, 0, -half))
    m_rest = MAP @ mid
    fwd = (MAP.to_3x3() @ Vector((1, 0, 0))).normalized()
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    b = eb.new('Nock'); b.head = m_rest; b.tail = m_rest + fwd * 0.06; b.parent = eb['BowB']
    b2 = eb.new('ArrowB'); b2.head = m_rest; b2.tail = m_rest + fwd * 0.06; b2.parent = b
    bpy.ops.object.mode_set(mode='OBJECT')
    c = rig.pose.bones['Nock'].constraints.new('COPY_LOCATION')
    c.name = 'DrawString'
    c.target = rig; c.subtarget = 'Hand.R'; c.head_tail = 0.55
    c.influence = 0.0
    dt = rig.pose.bones['ArrowB'].constraints.new('DAMPED_TRACK')
    dt.target = rig; dt.subtarget = 'BowB'; dt.head_tail = 0.0; dt.track_axis = 'TRACK_Y'
    # kamonni BowB ga ko'chirish (joyi o'zgarmaydi)
    bow = bpy.data.objects.get('Bow')
    if bow:
        bow.parent_bone = 'BowB'
        bpy.context.view_layer.update()
        bow.matrix_world = rig.matrix_world @ Matrix.Translation(org)
        bpy.context.view_layer.update()
    smat = mat('String', '#ddd8c8', 0.9)
    parts = [_tube('StringTop', MAP @ t1, m_rest, 0.0035, ('BowB', 'Nock')),
             _tube('StringBot', MAP @ t2, m_rest, 0.0035, ('BowB', 'Nock'))]
    tip = m_rest + fwd * 0.8
    parts.append(_tube('ArrowShaft', m_rest, tip, 0.006, ('ArrowB', 'ArrowB'), 5))
    parts.append(_tube('ArrowHead', tip, tip + fwd * 0.07, 0.013, ('ArrowB', 'ArrowB'), 3))
    parts.append(_tube('Fletch', m_rest + fwd * 0.02, m_rest + fwd * 0.14, 0.02, ('ArrowB', 'ArrowB'), 3))
    mats = [smat, smat, mat('ArrowWood', '#a07a4a', 0.8), mat('ArrowIron', '#4a4a4e', 0.5, 0.7), mat('Fletching', '#e8e2d0', 0.9)]
    for ob, m_ in zip(parts, mats):
        ob.data.materials.append(m_)
        ob.parent = rig
        md = ob.modifiers.new('Armature', 'ARMATURE')
        md.object = rig
    ab = rig.pose.bones['ArrowB']
    for act in bpy.data.actions:
        if act.name == 'Grip':
            continue
        rig.animation_data.action = act
        keys = [(1, 0.001, 0.0)]
        if act.name == 'Attack':
            keys = [(1, 0.001, 0.0), (8, 1.0, 0.0), (11, 1.0, 1.0), (28, 1.0, 1.0), (29, 0.001, 0.0)]
        elif act.name == 'Block':        # nishonga olib turish: o'q tortilgan
            keys = [(1, 1.0, 1.0)]
        for f, sc, inf in keys:
            ab.scale = (sc, sc, sc)
            ab.keyframe_insert('scale', frame=f)
            c.influence = inf
            c.keyframe_insert('influence', frame=f)
        for fc in act.fcurves:
            if 'ArrowB' in fc.data_path or 'DrawString' in fc.data_path:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'CONSTANT'
    c.influence = 0.0
    ab.scale = (1, 1, 1)


def look_shield(look, sr, TEAM, MT, BRZ, GOLD, LT):
    """xalqqa xos qalqon (bo'sh ro'yxat - odatiy dumaloq)"""
    if look == 'yunon':      # aspis: katta botiq bronza qalqon, o'rtasi jamoa rangida
        r = 0.44
        return [cyl('ShieldDisk', r, 0.04, (0, 0, 0), TEAM, axis='X', verts=32),
                cyl('ShieldRim', r + 0.02, 0.05, (-0.008, 0, 0), BRZ, axis='X', verts=32),
                sph('ShieldBoss', 0.12, (0.015, 0, 0), BRZ, (0.3, 1, 1))]
    if look == 'afrika':     # cho'zinchoq teri (buyvol) qalqon
        d = cyl('ShieldDisk', 0.3, 0.03, (0, 0, 0), LT, axis='X', verts=24)
        d.scale = (1.0, 0.75, 1.35)
        st = cyl('ShieldStripe', 0.04, 0.035, (0.004, 0, 0), TEAM, axis='X', verts=8)
        st.scale = (1.0, 0.6, 9.0)
        return [d, st, sph('ShieldBoss', 0.05, (0.02, 0, 0), MT, (0.6, 1, 1))]
    if look == 'hind':       # dhal: kichik botiq po'lat qalqon, 4 oltin bo'rtma
        sh = [cyl('ShieldDisk', 0.26, 0.03, (0, 0, 0), MT, axis='X', verts=28), cyl('ShieldRim', 0.27, 0.025, (-0.008, 0, 0), GOLD, axis='X', verts=28)]
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            sh.append(sph('Stud', 0.025, (0.02, math.cos(a) * 0.12, math.sin(a) * 0.12), GOLD, (0.6, 1, 1), 8, 6))
        return sh
    if look == 'angliya':    # uchburchak (kayt) qalqon, gerb rangida
        pts = []
        for x in (-0.015, 0.015):
            pts += [(x, -0.24, 0.3), (x, 0.24, 0.3), (x, -0.25, 0.05), (x, 0.25, 0.05), (x, 0.0, -0.42)]
        return [hull_points('ShieldDisk', pts, TEAM), box('ShieldBand', (0.035, 0.5, 0.06), (0.0, 0, 0.18), GOLD)]
    return []


def build_soldier(faction, kind):
    """kind: qilichboz | nayzachi | kamonchi | otliq"""
    clear()
    bpy.context.scene.render.fps = 24
    F = FACTIONS[faction]
    RUS = F.get('rus', False)
    XI = F.get('xitoy', False)
    LOOK = F.get('look', '')
    BRZ = mat('Bronze', '#b08a4a', 0.35, 0.85)
    E2K = (E2.get(kind) if faction == 'ozbek' else E2X.get(faction)) if F.get('era2') else None
    SHORT = bool(E2K and E2K.get('short'))
    RIFLE = E2K is not None and kind in RIFLE_KINDS
    COAT = mat('Coat', F['coat'], 0.55, 0.55) if (RUS or LOOK in ('hind', 'angliya')) else mat('Coat', F['coat'], 0.85)   # rus/hind/angliya: tana = kolchuga
    COAT2 = mat('CoatTrim', F['coat2'], 0.85)
    TR = mat('Trouser', F['trouser'], 0.9)
    SK = mat('Skin', F['skin'], 0.6)
    BT = mat('Boots', F['boots'], 0.7)
    MT = mat('Metal', F['metal'], 0.35, 0.8)
    LT = mat('Leather', F['leather'], 0.7)
    TU = mat('Turban', F['turban'], 0.9)
    BR = mat('Beard', F['beard'], 0.9)
    EYE = mat('Eye', '#151515', 0.3)
    WD = mat('Wood', '#7a5532', 0.8)
    TEAM = mat('TeamColor', F['team'], 0.6)
    GOLD = mat('Gold', '#c9a03a', 0.35, 0.8)

    # ---- armatura
    arm_data = bpy.data.armatures.new('Rig')
    rig = bpy.data.objects.new('Rig', arm_data)
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

    # ---- tana (skin modifier)
    R = {'pelvis': 0.15, 'spine': 0.145, 'chest': 0.175, 'neck': 0.055, 'head': 0.055}
    for s in ('L', 'R'):
        R.update({'shoulder_' + s: 0.07, 'arm_' + s: 0.064, 'elbow_' + s: 0.05, 'wrist_' + s: 0.038, 'hand_' + s: 0.043,
                  'hip_' + s: 0.098, 'knee_' + s: 0.066, 'ankle_' + s: 0.055, 'toe_' + s: 0.045})
    EDGES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck'), ('neck', 'head')]
    for s in ('L', 'R'):
        EDGES += [('shoulder_' + s, 'arm_' + s), ('arm_' + s, 'elbow_' + s), ('elbow_' + s, 'wrist_' + s),
                  ('wrist_' + s, 'hand_' + s), ('pelvis', 'hip_' + s), ('hip_' + s, 'knee_' + s), ('knee_' + s, 'ankle_' + s),
                  ('ankle_' + s, 'toe_' + s)]
    names = list(R.keys())
    me = bpy.data.meshes.new('Body')
    me.from_pydata([J[n] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
    body = bpy.data.objects.new('Body', me)
    bpy.context.collection.objects.link(body)
    body.modifiers.new('Skin', 'SKIN')
    sm = body.modifiers.new('Subsurf', 'SUBSURF')
    sm.levels = 1
    for i, n in enumerate(names):
        r = R[n]
        sx, sy = r, r
        if n in ('pelvis', 'spine', 'chest'):
            sx, sy = r * 0.72, r * 1.12
        me.skin_vertices[0].data[i].radius = (sx, sy)
    me.skin_vertices[0].data[names.index('pelvis')].use_root = True
    # qo'llar tanadan alohida bo'lak (yelka ostida tana bilan ulanmaydi) - qo'l ko'tarilganda teri cho'zilmaydi
    for s_ in ('L', 'R'):
        me.skin_vertices[0].data[names.index('shoulder_' + s_)].use_root = True
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.modifier_apply(modifier='Skin')
    bpy.ops.object.modifier_apply(modifier='Subsurf')
    body.select_set(False)
    bpy.ops.object.shade_smooth()

    bone_segs = {b.name: (Vector(b.head_local), Vector(b.tail_local)) for b in arm_data.bones}
    groups = {n: body.vertex_groups.new(name=n) for n in bone_segs}
    # har vertex avval o'z a'zosiga (tana / chap qo'l / o'ng qo'l / oyoqlar) ajratiladi, keyin faqat shu a'zo suyaklariga
    # vazn oladi - qo'l ko'tarilganda tana terisi qo'lga yopishib cho'zilmaydi
    def limb(n):
        if n.startswith(('UpperArm', 'ForeArm', 'Hand')):
            return 'arm' + n[-1]
        if n.startswith(('Thigh', 'Shin', 'Foot')):
            return 'leg' + n[-1]
        return 'torso'
    LIMB_OK = {'armL': ('UpperArm.L', 'ForeArm.L', 'Hand.L', 'Shoulder.L'), 'armR': ('UpperArm.R', 'ForeArm.R', 'Hand.R', 'Shoulder.R'),
               'legL': ('Thigh.L', 'Shin.L', 'Foot.L', 'Hips'), 'legR': ('Thigh.R', 'Shin.R', 'Foot.R', 'Hips'),
               'torso': ('Hips', 'Spine', 'Chest', 'Neck', 'Head', 'Shoulder.L', 'Shoulder.R')}
    # bog'langan bo'laklar: qo'llar alohida bo'lak, qolgani (tana+oyoq+bosh) bitta
    import collections
    adj = collections.defaultdict(list)
    for e in body.data.edges:
        adj[e.vertices[0]].append(e.vertices[1]); adj[e.vertices[1]].append(e.vertices[0])
    comp = [-1] * len(body.data.vertices)
    ncomp = 0
    for st in range(len(comp)):
        if comp[st] >= 0:
            continue
        stack = [st]; comp[st] = ncomp
        while stack:
            u = stack.pop()
            for w_ in adj[u]:
                if comp[w_] < 0:
                    comp[w_] = ncomp; stack.append(w_)
        ncomp += 1
    comp_arm = {}
    for ci in range(ncomp):
        ys = [v.co.y for v in body.data.vertices if comp[v.index] == ci]
        zs = [v.co.z for v in body.data.vertices if comp[v.index] == ci]
        my = sum(ys) / len(ys)
        comp_arm[ci] = ('armL' if my > 0 else 'armR') if abs(my) > 0.15 and max(zs) < 1.5 and min(zs) > 0.7 else None
    for v in body.data.vertices:
        ca = comp_arm[comp[v.index]]
        cand = [(seg_dist(v.co, a, b), n) for n, (a, b) in bone_segs.items()
                if (limb(n) == ca or (ca and n == 'Shoulder.' + ca[-1])) if ca] if ca else \
               [(seg_dist(v.co, a, b), n) for n, (a, b) in bone_segs.items() if not limb(n).startswith('arm')]
        near = min(cand)[1]
        ok = LIMB_OK[limb(near)]
        ds = sorted(((seg_dist(v.co, a, b), n) for n, (a, b) in bone_segs.items() if n in ok))[:3]
        w = [1.0 / max(1e-3, d) ** 3 for d, _ in ds]
        tot = sum(w)
        for (d, n), wi in zip(ds, w):
            groups[n].add([v.index], wi / tot, 'REPLACE')
    # materiallar: ko'ylak (chopon), shim, teri, etik
    for m in (COAT, SK, BT, TR):
        body.data.materials.append(m)
    for poly in body.data.polygons:
        c = poly.center
        nb = min(((seg_dist(c, a, b), n) for n, (a, b) in bone_segs.items()))[1]
        if nb.startswith('Hand') or nb == 'Neck':
            poly.material_index = 1
        elif nb.startswith('Foot') or (nb.startswith('Shin') and c.z < 0.42):
            poly.material_index = 2
        elif nb.startswith('Thigh') or nb.startswith('Shin'):
            poly.material_index = 3
    if E2K:
        stripe(body, 0, E2K['stripes'])
    mod = body.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig
    body.parent = rig

    GEAR = []

    def attach(ob, bone, weights=None):
        """Jihozni suyakka bog'laydi. weights: {suyak: vazn} - kiyim etagi kabi bir nechta suyakka."""
        apply_all([ob])
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        ob.select_set(False)
        if weights is None:
            vg = ob.vertex_groups.new(name=bone)
            vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
        else:
            for v in ob.data.vertices:
                ws = weights(v.co)
                for bn, w in ws.items():
                    g = ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
                    g.add([v.index], w, 'REPLACE')
        GEAR.append(ob)
        return ob

    HZ = 1.63
    # ---- bosh: yuz, soqol
    attach(sph('HeadMesh', 0.11, (0.03, 0, HZ), SK, (1.0, 0.86, 1.08)), 'Head')
    attach(sph('Nose', 0.024, (0.135, 0, HZ - 0.01), SK, (1.0, 0.8, 1.4), 8, 6), 'Head')
    for s in (-1, 1):
        attach(sph('Eye', 0.015, (0.128, s * 0.04, HZ + 0.025), EYE, (0.6, 1, 1), 8, 6), 'Head')
        attach(box('Brow', (0.02, 0.045, 0.012), (0.132, s * 0.04, HZ + 0.052), BR), 'Head')
    if XI:   # ingichka mo'ylov va kichik soqolcha
        attach(sph('Beard', 0.03, (0.12, 0, HZ - 0.095), BR, (0.6, 0.7, 1.3), 8, 6), 'Head')
        for s_ in (-1, 1):
            attach(box('Moustache', (0.012, 0.035, 0.01), (0.14, s_ * 0.03, HZ - 0.045), BR), 'Head')
    else:
        attach(sph('Beard', 0.06, (0.09, 0, HZ - 0.1), BR, (0.8, 1.0, 1.3) if RUS else (0.7, 0.9, 1.0), 10, 8), 'Head')
        attach(box('Moustache', (0.02, 0.08, 0.015), (0.14, 0, HZ - 0.04), BR), 'Head')
    # ---- dubulg'a: konussimon temir qalpoq + salla + halqali to'r (aventail)
    if E2K:
        hat = E2K['hat']
        if hat in ('furajka', 'pith', 'kepi', 'fez', 'qing'):
            # Yevropa/Usmonli/Tsin bosh kiyimlari; soqol o'rniga mo'ylov ko'proq
            if hat == 'furajka':      # rus: oq g'ilofli furajka, orqada bo'yinni yopuvchi oq mato (Turkiston qo'shini)
                attach(cyl('Cap', 0.118, 0.07, (0.02, 0, HZ + 0.1), TU, axis='Z', verts=18), 'Head')
                attach(cyl('CapBand', 0.112, 0.03, (0.02, 0, HZ + 0.06), mat('CapBand', '#b03030', 0.8), axis='Z', verts=18), 'Head')
                attach(box('Visor', (0.08, 0.16, 0.012), (0.14, 0, HZ + 0.05), mat('Visor', '#151515', 0.4)), 'Head')
                attach(box('Havelock', (0.02, 0.2, 0.16), (-0.08, 0, HZ - 0.02), TU, rot=(0, math.radians(12), 0)), 'Head')
            elif hat == 'pith':       # ingliz: oq dubulg'a (tropik)
                attach(sph('Helmet', 0.13, (0.02, 0, HZ + 0.08), TU, (1.15, 1.0, 0.9), 16, 10), 'Head')
                brim = cone('Brim', 0.2, 0.16, 0.04, (0.02, 0, HZ + 0.04), TU, verts=20)
                brim.scale = (1.2, 1.0, 1.0)
                attach(brim, 'Head')
                attach(sph('Spike', 0.02, (0.02, 0, HZ + 0.2), GOLD, (1, 1, 1), 8, 6), 'Head')
            elif hat == 'kepi':       # fransuz kepisi: qizil tepa, ko'k gardish, qora soyabon
                kp = cone('Kepi', 0.11, 0.095, 0.14, (0.0, 0, HZ + 0.11), mat('KepiRed', '#a82a2a', 0.8), verts=16)
                kp.rotation_euler = (0, math.radians(-12), 0)
                attach(kp, 'Head')
                attach(cyl('KepiBand', 0.112, 0.045, (0.02, 0, HZ + 0.06), mat('KepiBlue', '#2a3a6a', 0.8), axis='Z', verts=16), 'Head')
                attach(box('Visor', (0.07, 0.15, 0.01), (0.14, 0, HZ + 0.04), mat('Visor', '#151515', 0.4)), 'Head')
            elif hat == 'fez':        # usmonli/eron: qizil fes, qora popuk
                attach(cone('Fez', 0.112, 0.085, 0.15, (0.02, 0, HZ + 0.11), mat('Fez', '#b0242a', 0.85), verts=16), 'Head')
                attach(cyl('Tassel', 0.008, 0.12, (-0.06, 0, HZ + 0.13), mat('TasselK', '#141210', 0.9), axis='Z', verts=5), 'Head')
            else:                     # tsin askari: keng somon shlyapa, qizil popuk
                attach(cone('Straw', 0.24, 0.02, 0.13, (0.02, 0, HZ + 0.11), mat('Straw', '#c8a868', 0.9), verts=20), 'Head')
                attach(cone('Tuft', 0.05, 0.01, 0.05, (0.02, 0, HZ + 0.18), mat('Tuft', '#c02020', 0.9), verts=10), 'Head')
        elif hat.startswith('salla'):
            # katta oq salla: uch qavat o'ram + tepa gumbaz; qo'mondonda oltin gardish va javohir
            for k_, (rr, zz) in enumerate(((0.135, 0.05), (0.14, 0.095), (0.128, 0.14))):
                tw = torus('Salla%d' % k_, rr, 0.042, (0.015, 0, HZ + zz), TU)
                tw.rotation_euler = (math.radians(4 * (k_ - 1)), math.radians(-6), 0)
                attach(tw, 'Head')
            attach(sph('SallaTop', 0.115, (0.01, 0, HZ + 0.15), TU, (1.0, 1.0, 0.62)), 'Head')
            if hat == 'salla_oltin':
                attach(torus('SallaGold', 0.142, 0.012, (0.015, 0, HZ + 0.1), GOLD), 'Head')
                attach(sph('Jewel', 0.022, (0.15, 0, HZ + 0.12), mat('Ruby', '#b01020', 0.2, 0.3)), 'Head')
                attach(cone('Plume', 0.012, 0.004, 0.14, (0.13, 0, HZ + 0.2), mat('PlumeW', '#f4f0e6', 0.9), verts=6), 'Head')
        else:
            # qora qo'y terisidan telpak: jingalak (g'adir-budur) katta shar
            import random
            rnd = random.Random(7)
            tb = bmesh.new()
            bmesh.ops.create_icosphere(tb, subdivisions=3, radius=0.19)
            for v_ in tb.verts:
                v_.co *= 1.0 + rnd.uniform(-0.07, 0.07)
            tp = _obj_from_bm('Telpak', tb, mat('Telpak', '#141210', 1.0))
            tp.location = (0.0, 0, HZ + 0.13)
            tp.scale = (1.0, 1.0, 0.85)
            for p_ in tp.data.polygons:
                p_.use_smooth = False
            attach(tp, 'Head')
    elif LOOK == 'yunon':
        # korinf bronza dubulg'asi: yuzni yopuvchi yonoqliklar, tepada qizil tojsimon pat (krista)
        attach(sph('Helmet', 0.13, (0.02, 0, HZ + 0.05), BRZ, (1.05, 1.0, 1.05), 18, 12), 'Head')
        for s_ in (-1, 1):
            attach(box('Cheek', (0.07, 0.025, 0.12), (0.1, s_ * 0.085, HZ - 0.04), BRZ), 'Head')
        attach(box('NoseG', (0.02, 0.02, 0.08), (0.15, 0, HZ - 0.0), BRZ), 'Head')
        crest = []
        for k_ in range(9):
            a_ = math.radians(-70 + k_ * 17.5)
            crest.append(box('Crest', (0.07, 0.035, 0.09), (0.02 + math.sin(a_) * 0.14, 0, HZ + 0.12 + math.cos(a_) * 0.11), mat('Crest', '#b01e1e', 0.9)))
        for c_ in crest:
            attach(c_, 'Head')
    elif LOOK == 'hind':
        # za'faron salla ustida kichik nayzali dubulg'a (qilichboz/otliq), qolganlarda faqat salla
        for k_, (rr, zz) in enumerate(((0.132, 0.045), (0.137, 0.09), (0.124, 0.13))):
            tw = torus('Salla%d' % k_, rr, 0.04, (0.015, 0, HZ + zz), TU)
            tw.rotation_euler = (0, math.radians(-8), 0)
            attach(tw, 'Head')
        if kind in ('qilichboz', 'otliq'):
            attach(sph('Helmet', 0.11, (0.015, 0, HZ + 0.15), MT, (1.0, 1.0, 0.8), 16, 10), 'Head')
            attach(cyl('HelmSpike', 0.008, 0.1, (0.015, 0, HZ + 0.26), GOLD, axis='Z', verts=6), 'Head')
        else:
            attach(sph('SallaTop', 0.11, (0.01, 0, HZ + 0.14), TU, (1.0, 1.0, 0.6)), 'Head')
        attach(sph('Jewel', 0.018, (0.15, 0, HZ + 0.1), mat('Emerald', '#1a8a4a', 0.2, 0.3)), 'Head')
    elif LOOK == 'afrika':
        if kind == 'kamonchi':
            # yengil paxta salla
            for k_, (rr, zz) in enumerate(((0.128, 0.05), (0.13, 0.09))):
                attach(torus('Wrap%d' % k_, rr, 0.036, (0.015, 0, HZ + zz), TU), 'Head')
            attach(sph('WrapTop', 0.11, (0.01, 0, HZ + 0.12), TU, (1.0, 1.0, 0.55)), 'Head')
        else:
            # yumaloq temir qalpoq + bo'yinni yopuvchi qavat paxta
            attach(sph('Helmet', 0.125, (0.02, 0, HZ + 0.06), MT, (1.0, 1.0, 0.9), 16, 10), 'Head')
            attach(cyl('HelmSpike', 0.01, 0.06, (0.02, 0, HZ + 0.2), MT, axis='Z', verts=6), 'Head')
            ap = []
            for k in range(9):
                ang = math.radians(75 + k * 26.25)
                for zz, rr in ((HZ + 0.04, 0.13), (HZ - 0.14, 0.16)):
                    ap.append((0.02 + math.cos(ang) * rr, math.sin(ang) * rr, zz))
            attach(hull_points('Hood', ap, COAT), 'Head')
    elif LOOK == 'angliya':
        if kind == 'kamonchi':
            # yashil kapyushon (uzun kamonchi)
            attach(sph('Hood', 0.135, (0.0, 0, HZ + 0.04), COAT2, (1.0, 1.0, 1.05), 16, 10), 'Head')
            attach(cone('HoodTip', 0.06, 0.01, 0.16, (-0.1, 0, HZ + 0.08), COAT2, verts=8), 'Head')
        else:
            # bascinet: yumaloq-uchli po'lat dubulg'a + kolchuga kapyushon
            attach(cone('Helmet', 0.13, 0.03, 0.2, (0.0, 0, HZ + 0.12), MT, verts=18), 'Head')
            attach(sph('HelmBowl', 0.128, (0.02, 0, HZ + 0.05), MT, (1.0, 1.0, 0.9), 16, 10), 'Head')
            ap = []
            for k in range(11):
                ang = math.radians(62 + k * 23.6)
                for zz, rr in ((HZ + 0.06, 0.13), (HZ - 0.08, 0.15), (HZ - 0.19, 0.2)):
                    ap.append((0.02 + math.cos(ang) * rr, math.sin(ang) * rr, zz))
            attach(hull_points('Coif', ap, COAT), 'Head')
    elif XI:
        # Min dubulg'asi: yumaloq kosa + gardish + tepada nayzacha va qizil popuk; yon-orqada matoli quloqchin
        attach(sph('Helmet', 0.128, (0.02, 0, HZ + 0.06), MT, (1.0, 1.0, 0.95), 16, 10), 'Head')
        attach(torus('HelmBrim', 0.132, 0.014, (0.02, 0, HZ + 0.03), GOLD), 'Head')
        attach(cyl('HelmSpike', 0.01, 0.12, (0.02, 0, HZ + 0.22), GOLD, axis='Z', verts=6), 'Head')
        attach(cone('Plume', 0.05, 0.012, 0.1, (0.02, 0, HZ + 0.25), mat('Plume', '#b31b1b', 0.9), verts=10), 'Head')
        ap = []
        for k in range(9):
            ang = math.radians(80 + k * 25)
            for zz, rr in ((HZ + 0.05, 0.13), (HZ - 0.13, 0.16)):
                ap.append((0.02 + math.cos(ang) * rr, math.sin(ang) * rr, zz))
        attach(hull_points('NeckGuard', ap, COAT), 'Head')
    elif RUS:
        # shishak: baland, uchli temir dubulg'a + gardish + burun himoyasi; kolchuga to'r bo'yin va yelkagacha
        hb = bmesh.new()
        prof = [(0.122, 0.0), (0.124, 0.05), (0.112, 0.11), (0.085, 0.17), (0.05, 0.22), (0.022, 0.26), (0.006, 0.31)]
        rings_ = []
        for r_, z_ in prof:
            rings_.append([hb.verts.new((0.02 + math.cos(a_) * r_, math.sin(a_) * r_, HZ + 0.05 + z_))
                           for a_ in [i * 2 * math.pi / 16 for i in range(16)]])
        for i in range(len(rings_) - 1):
            for k in range(16):
                hb.faces.new((rings_[i][k], rings_[i][(k + 1) % 16], rings_[i + 1][(k + 1) % 16], rings_[i + 1][k]))
        hb.faces.new(rings_[-1][::-1])
        helm = _obj_from_bm('Helmet', hb, MT)
        for p_ in helm.data.polygons:
            p_.use_smooth = True
        attach(helm, 'Head')
        attach(torus('HelmBand', 0.124, 0.012, (0.02, 0, HZ + 0.055), GOLD if kind in ('qilichboz', 'otliq') else MT), 'Head')
        attach(box('Nasal', (0.012, 0.024, 0.1), (0.146, 0, HZ + 0.02), MT), 'Head')
        ap = []
        for k in range(11):
            ang = math.radians(62 + k * 23.6)
            for zz, rr in ((HZ + 0.06, 0.128), (HZ - 0.08, 0.15), (HZ - 0.19, 0.2)):
                ap.append((0.02 + math.cos(ang) * rr, math.sin(ang) * rr, zz))
        attach(hull_points('Aventail', ap, COAT), 'Head')
    else:
        attach(cone('Helmet', 0.128, 0.015, 0.2, (0.02, 0, HZ + 0.13), MT), 'Head')
        attach(cyl('HelmSpike', 0.008, 0.08, (0.02, 0, HZ + 0.27), MT, axis='Z', verts=6), 'Head')
        attach(torus('TurbanWrap', 0.125, 0.032, (0.02, 0, HZ + 0.045), TU), 'Head')
        attach(torus('TurbanWrap2', 0.12, 0.026, (0.02, 0, HZ + 0.085), TU), 'Head')
        # halqali to'r faqat bosh orqasi va yonlarida (yuz ochiq)
        ap = []
        for k in range(9):
            ang = math.radians(75 + k * 26.25)
            for zz, rr in ((HZ + 0.04, 0.13), (HZ - 0.1, 0.15)):
                ap.append((0.02 + math.cos(ang) * rr, math.sin(ang) * rr, zz))
        attach(hull_points('Aventail', ap, MT), 'Head')
    # ---- chopon (uzun ko'ylak): tanadan tizzagacha etak
    def skirt_w(co):
        side = 'L' if co.y > 0 else 'R'
        t = max(0.0, min(1.0, (0.92 - co.z) / 0.4))
        return {'Hips': 1.0 - t * 0.85, 'Thigh.' + side: t * 0.85}
    if E2K and SHORT:
        # kalta mundir etagi (son o'rtasigacha), oldida tugmalar qatori
        sk = cone('Skirt', 0.215, 0.178, 0.3, (0.0, 0, 0.8), COAT, verts=24)
        sk.scale = (0.95, 1.08, 1.0)
        stripe(sk, 0, E2K['stripes'], n=24)
        attach(sk, None, skirt_w)
        for zb in (1.0, 1.1, 1.2, 1.3):
            attach(sph('Button', 0.012, (0.165, 0, zb), GOLD, (0.6, 1, 1), 6, 4), 'Chest')
    elif E2K:
        # uzun to'n etagi (boldirgacha), oldida jiyak; yo'l-yo'l
        sk = cone('Skirt', 0.235, 0.17, 0.58, (0.0, 0, 0.66), COAT, verts=36)
        sk.scale = (0.95, 1.1, 1.0)
        stripe(sk, 0, E2K['stripes'], n=36)
        attach(sk, None, skirt_w)
        attach(box('CoatFront', (0.02, 0.05, 0.58), (0.2, 0.0, 0.66), COAT2), None, skirt_w)
        attach(cone('Hem', 0.238, 0.236, 0.035, (0.0, 0, 0.385), COAT2, verts=36), None, skirt_w)
    elif LOOK == 'yunon':
        # pteruges: beldan osilgan charm/mato tasmalar (oq), ostida qisqa xiton
        tu = cone('Chiton', 0.2, 0.18, 0.3, (0.0, 0, 0.8), COAT, verts=24)
        tu.scale = (0.95, 1.08, 1.0)
        attach(tu, None, skirt_w)
        for k_ in range(14):
            a_ = k_ / 14 * 2 * math.pi
            attach(box('Pteryx', (0.02, 0.055, 0.22), (math.cos(a_) * 0.205, math.sin(a_) * 0.22, 0.82), LT if k_ % 2 else COAT, rot=(0, 0, a_)), None, skirt_w)
    elif LOOK in ('hind', 'afrika'):
        # uzun ko'ylak etagi (hind: qizil, afrika: qavat paxta)
        sk = cone('Skirt', 0.22, 0.17, 0.5, (0.0, 0, 0.69), COAT2 if LOOK == 'hind' else COAT, verts=24)
        sk.scale = (0.95, 1.08, 1.0)
        attach(sk, None, skirt_w)
        if LOOK == 'afrika':
            for z_ in (0.55, 0.67, 0.79):
                attach(cone('Quilt', 0.205 - (0.79 - z_) * 0.1, 0.2 - (0.79 - z_) * 0.1, 0.012, (0, 0, z_), COAT2, verts=24), None, skirt_w)
    elif LOOK == 'angliya':
        # gerbli ustko'ylak (surcoat) - jamoa rangida, ostida kolchuga etagi
        ml = cone('MailSkirt', 0.215, 0.18, 0.36, (0.0, 0, 0.76), COAT, verts=24)
        ml.scale = (0.95, 1.08, 1.0)
        attach(ml, None, skirt_w)
        sc_ = cone('Surcoat', 0.228, 0.2, 0.48, (0.0, 0, 0.72), COAT2 if kind == 'kamonchi' else TEAM, verts=24)
        sc_.scale = (0.9, 1.1, 1.0)
        attach(sc_, None, skirt_w)
    elif XI:
        # uzun brigandina etagi (tizzadan pastgacha), oldi ochiq - qora tagko'ylak ko'rinadi, oltin mix qatorlari
        sk = cone('Skirt', 0.22, 0.17, 0.5, (0.0, 0, 0.69), COAT, verts=18)
        sk.scale = (0.95, 1.08, 1.0)
        attach(sk, None, skirt_w)
        attach(box('CoatFront', (0.03, 0.07, 0.5), (0.19, 0.0, 0.68), COAT2), None, skirt_w)
        for row in range(4):
            for k in range(12):
                a_ = math.radians(-150 + k * 27.3)
                if abs(a_) < 0.25:
                    continue
                z_ = 0.88 - row * 0.12
                r_ = 0.2 - (0.88 - z_) * 0.06
                attach(box('Stud', (0.014, 0.014, 0.014), (math.cos(a_) * r_ * 0.95, math.sin(a_) * r_ * 1.08, z_), GOLD), None, skirt_w)
    elif RUS:
        # qizil ko'ylak etagi (tizzagacha) va ustida kalta kolchuga etagi
        tu = cone('Tunic', 0.205, 0.17, 0.4, (0.0, 0, 0.73), COAT2, verts=18)
        tu.scale = (0.95, 1.08, 1.0)
        attach(tu, None, skirt_w)
        ml = cone('MailSkirt', 0.225, 0.185, 0.3, (0.0, 0, 0.8), COAT, verts=18)
        ml.scale = (0.95, 1.08, 1.0)
        attach(ml, None, skirt_w)
    else:
        sk = cone('Skirt', 0.21, 0.165, 0.42, (0.0, 0, 0.73), COAT, verts=18)
        sk.scale = (0.95, 1.08, 1.0)
        attach(sk, None, skirt_w)
        attach(box('CoatFront', (0.03, 0.06, 0.4), (0.18, 0.0, 0.72), COAT2), None, skirt_w)
    # ko'krakdagi plastinkali zirh (lamellar); rusda faqat drujina (qilichboz, otliq) da
    if E2K:
      # ko'krak: to'n yoqasi (oltin jiyak), miltiqchida ikki charm tasma (patrontash) va o'q xaltachalari
      attach(box('Collar', (0.03, 0.05, 0.36), (0.165, 0.0, 1.22), COAT2, rot=(0, math.radians(-8), 0)), 'Chest')
      if RIFLE:
          for s_ in (1, -1):
              attach(box('CrossBelt', (0.02, 0.05, 0.6), (0.155, 0, 1.2), LT, rot=(math.radians(38 * s_), math.radians(-8), 0)), 'Chest')
              attach(box('CrossBeltB', (0.02, 0.05, 0.6), (-0.13, 0, 1.2), LT, rot=(math.radians(-38 * s_), math.radians(8), 0)), 'Chest')
          for s_ in (-0.09, 0.0, 0.09):
              attach(box('Pouch', (0.06, 0.07, 0.07), (0.19, s_ - 0.06, 0.93), LT), 'Hips')
      if kind == 'miltiqchi':
          ph = cone('PowderHorn', 0.035, 0.008, 0.26, (0.0, -0.21, 0.88), mat('Horn', '#e0d4b0', 0.5), verts=10)
          ph.rotation_euler = (0, math.radians(70), 0)
          attach(ph, 'Hips')
      if kind in ('sarboz', 'qomondon', 'miltiqchi'):
          # qinidagi qilich chap yonda
          sc_ = cyl('Scabbard', 0.022, 0.8, (0.05, 0.22, 0.62), LT, axis='Z', verts=8)
          sc_.rotation_euler = (math.radians(-8), math.radians(28), 0)
          attach(sc_, 'Hips')
          hl = cyl('Hilt', 0.016, 0.13, (0.25, 0.25, 0.98), GOLD, axis='Z', verts=8)
          hl.rotation_euler = (0, math.radians(28), 0)
          attach(hl, 'Hips')
    elif LOOK == 'yunon':
      # bronza "muskul" sovut va orqada qizil plash
      vest = hull_points('Cuirass', [(-0.11, -0.17, 0.98), (0.14, -0.16, 0.98), (-0.11, 0.17, 0.98), (0.14, 0.16, 0.98),
                                     (-0.12, -0.18, 1.4), (0.15, -0.15, 1.38), (-0.12, 0.18, 1.4), (0.15, 0.15, 1.38), (0.17, 0, 1.2)], BRZ)
      attach(vest, 'Chest')
      attach(box('Cloak', (0.03, 0.36, 0.62), (-0.15, 0, 1.08), COAT2, rot=(0, math.radians(8), 0)), 'Chest')
    elif LOOK == 'afrika':
      vest = hull_points('Quilted', [(-0.1, -0.17, 1.0), (0.14, -0.16, 1.0), (-0.1, 0.17, 1.0), (0.14, 0.16, 1.0),
                                     (-0.11, -0.18, 1.38), (0.14, -0.15, 1.36), (-0.11, 0.18, 1.38), (0.14, 0.15, 1.36)], COAT)
      attach(vest, 'Chest')
      for k in range(6):
        attach(box('QuiltRow', (0.006, 0.32, 0.012), (0.148, 0, 1.04 + k * 0.06), COAT2), 'Chest')
    elif LOOK == 'hind':
      vest = hull_points('Mail', [(-0.1, -0.16, 1.0), (0.13, -0.15, 1.0), (-0.1, 0.16, 1.0), (0.13, 0.15, 1.0),
                                  (-0.11, -0.17, 1.38), (0.13, -0.14, 1.36), (-0.11, 0.17, 1.38), (0.13, 0.14, 1.36)], MT)
      attach(vest, 'Chest')
      attach(box('Sash2', (0.02, 0.06, 0.5), (0.13, 0.0, 1.2), GOLD, rot=(math.radians(35), 0, 0)), 'Chest')
    elif LOOK == 'angliya':
      vest = hull_points('SurcoatTop', [(-0.11, -0.17, 1.0), (0.14, -0.16, 1.0), (-0.11, 0.17, 1.0), (0.14, 0.16, 1.0),
                                        (-0.12, -0.17, 1.37), (0.14, -0.14, 1.35), (-0.12, 0.17, 1.37), (0.14, 0.14, 1.35)], COAT2 if kind == 'kamonchi' else TEAM)
      attach(vest, 'Chest')
      if kind != 'kamonchi':
        # gerb: oltin sher o'rniga oltin bo'rtma va ikki chiziq
        attach(box('Arms', (0.008, 0.11, 0.13), (0.15, 0, 1.2), GOLD), 'Chest')
        attach(box('ArmsBar', (0.009, 0.15, 0.025), (0.152, 0, 1.2), TEAM), 'Chest')
    elif XI:
      vest = hull_points('Brigandine', [(-0.1, -0.16, 1.0), (0.13, -0.15, 1.0), (-0.1, 0.16, 1.0), (0.13, 0.15, 1.0),
                                        (-0.11, -0.17, 1.38), (0.13, -0.14, 1.36), (-0.11, 0.17, 1.38), (0.13, 0.14, 1.36)], COAT)
      attach(vest, 'Chest')
      for zr in range(5):
        for yr in range(-2, 3):
          attach(box('Stud', (0.012, 0.014, 0.014), (0.142, yr * 0.055, 1.06 + zr * 0.065), GOLD), 'Chest')
    elif not RUS or kind in ('qilichboz', 'otliq'):
      vest = hull_points('Lamellar', [(-0.1, -0.16, 1.0), (0.13, -0.15, 1.0), (-0.1, 0.16, 1.0), (0.13, 0.15, 1.0),
                                    (-0.11, -0.17, 1.38), (0.13, -0.14, 1.36), (-0.11, 0.17, 1.38), (0.13, 0.14, 1.36)], MT if RUS else LT)
      attach(vest, 'Chest')
      for k in range(5):
        attach(box('LamRow', (0.006, 0.3, 0.014), (0.142, 0, 1.06 + k * 0.07), MT), 'Chest')
    # belbog' (jamoa rangi) va oltin to'qa
    attach(cyl('Sash', 0.19 if E2K else (0.178 if RUS else 0.175), 0.05 if RUS else (0.11 if E2K else 0.09), (0.01, 0, 0.98), TEAM, axis='Z', verts=18), 'Hips')
    if E2K and not SHORT and faction == 'ozbek':
        attach(box('SashEnd', (0.02, 0.08, 0.3), (0.19, 0.08, 0.82), TEAM), None, skirt_w)
    attach(box('Buckle', (0.02, 0.06, 0.05), (0.18, 0, 0.98), GOLD), 'Hips')
    for s, sd in ((1, 'L'), (-1, 'R')):
        if not E2K:
            attach(sph('Pauldron', 0.085, (0.0, s * 0.2, 1.38), MT, (1.0, 0.9, 0.7)), 'UpperArm.' + sd)
            attach(cyl('Bracer', 0.045, 0.16, (0.01, s * 0.235, 0.96), LT, axis='Z', verts=10), 'ForeArm.' + sd)
        else:
            attach(cyl('Cuff', 0.05, 0.05, (0.01, s * 0.238, 0.9), COAT2, axis='Z', verts=10), 'ForeArm.' + sd)
        attach(cyl('BootTop', 0.068, 0.12, (0.0, s * 0.113, 0.4), BT, axis='Z', verts=12), 'Shin.' + sd)

    # ---- qurollar
    weapon_parts = []   # (obyekt, suyak)
    if kind in SWORD_KINDS:
        # egri qilich (shamshir): o'ng qo'lda, tig'i yuqoriga-oldinga
        # egri tig': bitta silliq mesh (yo'l bo'ylab kesimlar)
        bmb = bmesh.new()
        n = 12
        rows = []
        for i in range(n + 1):
            t = i / n
            z = 0.06 + t * 0.78
            STR_ = RUS or LOOK in ('angliya', 'afrika', 'yunon')
            x = 0.0 if STR_ else (0.045 if XI else (0.16 if LOOK == 'hind' else 0.09)) * t * t      # rus/ingliz qilichi to'g'ri, hind talvari kuchli egri
            w = (0.024 * (1 - t) + 0.016 if t < 0.9 else 0.006) if STR_ else (0.034 * (1 - t) + 0.006 if t < 0.92 else 0.004)
            if LOOK == 'yunon':
                z = 0.06 + t * 0.55             # kalta ksifos
                w = 0.03 * math.sin(math.pi * (0.25 + t * 0.6)) + 0.012 if t < 0.92 else 0.004
            rows.append([bmb.verts.new((x - w * 0.2, -0.004, z)), bmb.verts.new((x + w, 0.0, z)),
                         bmb.verts.new((x - w * 0.2, 0.004, z))])
        for i in range(n):
            a, b = rows[i], rows[i + 1]
            for k in range(3):
                bmb.faces.new((a[k], a[(k + 1) % 3], b[(k + 1) % 3], b[k]))
        bmb.faces.new(rows[-1][::-1])
        bmb.faces.new(rows[0])
        blade = [_obj_from_bm('Blade', bmb, MT)]
        blade.append(box('Guard', (0.03, 0.22 if (RUS or LOOK == 'angliya') else 0.12, 0.022), (0, 0, 0.03), GOLD if LOOK != 'angliya' else MT))
        blade.append(cyl('Grip', 0.017, 0.12, (0, 0, -0.04), LT, axis='Z', verts=8))
        blade.append(sph('Pommel', 0.022, (0, 0, -0.11), GOLD, segs=8, rings=6))
        sword = join('Sword', blade, origin=(0, 0, 0))
        weapon_parts.append((sword, 'Hand.R', 'sword'))
        if kind == 'qomondon' and faction == 'ozbek':
            # po'lat dumaloq qalqon, oltin bo'rtma (kulohxud)
            sh = [cyl('ShieldDisk', 0.27, 0.03, (0, 0, 0), MT, axis='X', verts=28),
                  cyl('ShieldRim', 0.28, 0.025, (-0.008, 0, 0), GOLD, axis='X', verts=28),
                  sph('ShieldBoss', 0.075, (0.02, 0, 0), GOLD, (0.6, 1, 1))]
            for k_ in range(4):
                a_ = k_ * math.pi / 2 + math.pi / 4
                sh.append(sph('Stud', 0.022, (0.018, math.cos(a_) * 0.15, math.sin(a_) * 0.15), GOLD, (0.6, 1, 1), 8, 6))
            shield = join('Shield', sh, origin=(0, 0, 0))
            weapon_parts.append((shield, 'ForeArm.L', 'shield'))
        if kind == 'qilichboz' and not E2K:
            sr = 0.34 if RUS else 0.3
            if XI:   # tengpai: rotang qalqon (to'qilgan halqalar), o'rtada jamoa rangidagi yo'lbars boshi o'rniga doira
                RT = mat('Rattan', '#a07a42', 0.85)
                sh = [cyl('ShieldDisk', 0.33, 0.05, (0, 0, 0), RT, axis='X', verts=24)]
                for rr in (0.12, 0.2, 0.28):
                    t_ = torus('Weave', rr, 0.012, (0.028, 0, 0), mat('RattanDark', '#6e5028', 0.9), segs=24)
                    t_.rotation_euler = (0, math.radians(90), 0)
                    sh.append(t_)
                sh.append(sph('ShieldBoss', 0.1, (0.03, 0, 0), TEAM, (0.35, 1, 1)))
                shield = join('Shield', sh, origin=(0, 0, 0))
                weapon_parts.append((shield, 'ForeArm.L', 'shield'))
            sh = look_shield(LOOK, sr, TEAM, MT, BRZ, GOLD, LT) or [cyl('ShieldDisk', sr, 0.03, (0, 0, 0), TEAM, axis='X', verts=24),
                  cyl('ShieldRim', sr + 0.01, 0.02, (-0.008, 0, 0), MT, axis='X', verts=24),
                  sph('ShieldBoss', 0.07, (0.02, 0, 0), MT, (0.6, 1, 1))]
            if not XI:
                shield = join('Shield', sh, origin=(0, 0, 0))
                weapon_parts.append((shield, 'ForeArm.L', 'shield'))
            else:
                for o_ in sh:
                    bpy.data.objects.remove(o_, do_unlink=True)
    if kind == 'nayzachi':
        sp = [cyl('Shaft', 0.016, 2.6, (0, 0, 0), WD, axis='X', verts=8),
              cone('SpearHead', 0.03, 0.002, 0.22, (1.39, 0, 0), MT, verts=6),
              cyl('Tassel', 0.03, 0.06, (1.24, 0, 0), TEAM, axis='X', verts=8)]
        sp[1].rotation_euler = (0, math.radians(90), 0)
        spear = join('Spear', sp, origin=(0, 0, 0))
        weapon_parts.append((spear, 'Hand.R', 'spear'))
        sh = [] if E2K else (look_shield(LOOK, 0.28, TEAM, MT, BRZ, GOLD, LT) or [cyl('ShieldDisk', 0.28, 0.03, (0, 0, 0), TEAM, axis='X', verts=24),
              cyl('ShieldRim', 0.29, 0.02, (-0.008, 0, 0), MT, axis='X', verts=24),
              sph('ShieldBoss', 0.065, (0.02, 0, 0), MT, (0.6, 1, 1))])
        if sh:
            shield = join('Shield', sh, origin=(0, 0, 0))
            weapon_parts.append((shield, 'ForeArm.L', 'shield'))
    rifle = None
    if RIFLE:
        # fitilli miltiq: yog'och qo'ndoq, uzun stvol, mis halqalar. Mahalliy o'qlar: +X - stvol, 0 - qo'ndoq bo'yni (o'ng qo'l)
        WD2 = mat('Walnut', '#5a3820', 0.7)
        BR_ = mat('Brass', '#b08a3a', 0.35, 0.8)
        rp = [hull_points('Butt', [(-0.33, -0.022, -0.09), (-0.33, 0.022, -0.09), (-0.33, -0.022, 0.03), (-0.33, 0.022, 0.03),
                                   (-0.02, -0.016, -0.03), (-0.02, 0.016, -0.03), (-0.02, -0.016, 0.02), (-0.02, 0.016, 0.02)], WD2),
              box('Fore', (0.75, 0.03, 0.035), (0.36, 0, 0.0), WD2),
              cyl('Barrel', 0.012, 1.16, (0.58, 0, 0.024), MT, axis='X', verts=8),
              box('Lock', (0.08, 0.036, 0.03), (0.02, 0, 0.012), MT),
              cyl('Serpentine', 0.005, 0.07, (0.0, -0.022, 0.04), BR_, axis='Z', verts=5)]
        for xb in (0.25, 0.5, 0.72):
            rp.append(cyl('Band', 0.022, 0.025, (xb, 0, 0.012), BR_, axis='X', verts=8))
        rp.append(cyl('Ramrod', 0.004, 0.9, (0.5, 0, -0.022), mat('RamrodWood', '#3a2414', 0.6), axis='X', verts=4))
        if F.get('bayonet'):
            # nayza-shtik: stvol uchida uchburchak tig'
            rp.append(cyl('BayonetSock', 0.016, 0.06, (1.15, 0, 0.024), MT, axis='X', verts=8))
            bay = cone('Bayonet', 0.012, 0.001, 0.42, (1.39, 0, 0.04), MT, verts=3)
            bay.rotation_euler = (0, math.radians(90), 0)
            rp.append(bay)
        rifle = join('Rifle', rp, origin=(0, 0, 0))
    if kind == 'kamonchi':
        # kompozit kamon: ikki egilgan yelka (C shaklida), chap qo'lda vertikal
        # silliq egilgan kamon: yo'l bo'ylab to'rtburchak kesimli quvur
        bmw = bmesh.new()
        segs = 16
        rows = []
        for i in range(segs + 1):
            t = i / segs * 2 - 1
            z = t * 0.55
            x = 0.12 * (1 - t * t) - 0.06 * abs(t) ** 4
            r = 0.016 if abs(t) < 0.2 else 0.011
            rows.append([bmw.verts.new((x + dx * r, dy * r, z)) for dx, dy in ((1, 1), (1, -1), (-1, -1), (-1, 1))])
        for i in range(segs):
            a, b = rows[i], rows[i + 1]
            for k in range(4):
                bmw.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
        bmw.faces.new(rows[0]); bmw.faces.new(rows[-1][::-1])
        bp = [_obj_from_bm('BowLimb', bmw, LT)]
        bow = join('Bow', bp, origin=(0, 0, 0))
        if LOOK == 'angliya':
            bow.scale = (0.8, 1.0, 1.55)       # ingliz uzun kamoni (odam bo'yiday)
            bpy.context.view_layer.objects.active = bow
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        weapon_parts.append((bow, 'Hand.L', 'bow'))
        qv = [cyl('Quiver', 0.06, 0.5, (0, 0, 0), LT, axis='Z', verts=10)]
        for k in range(5):
            qv.append(cyl('Arrow', 0.005, 0.12, (0.02 * (k % 2), -0.03 + 0.015 * k, 0.29), WD, axis='Z', verts=4))
            qv.append(box('Fletch', (0.03, 0.004, 0.06), (0.02 * (k % 2), -0.03 + 0.015 * k, 0.33), TEAM))
        quiver = join('Quiver', qv, origin=(0, 0, 0))
        quiver.location = (-0.2, -0.1, 1.2)
        quiver.rotation_euler = (math.radians(-15), math.radians(-10), 0)
        attach(quiver, 'Chest')

    # ---- jihozlarni tana bilan birlashtirish
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in GEAR:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = 'Body'

    RH = Vector((0.27, -0.14, 1.36))      # miltiq "nishonga olish" holati: qo'ndoq bo'yni (o'ng qo'l) shu yerda
    if RIFLE:
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        eb = arm_data.edit_bones
        b = eb.new('Rifle'); b.head = RH; b.tail = RH + Vector((0.3, 0, 0)); b.parent = eb['Chest']
        b = eb.new('GripR'); b.head = RH + Vector((0.0, 0, -0.03)); b.tail = b.head + Vector((0.06, 0, 0)); b.parent = eb['Rifle']
        b = eb.new('GripL'); b.head = RH + Vector((0.46, 0, -0.03)); b.tail = b.head + Vector((0.06, 0, 0)); b.parent = eb['Rifle']
        b = eb.new('PoleR'); b.head = Vector((-0.25, -0.6, 0.85)); b.tail = b.head + Vector((0, 0, 0.05)); b.parent = eb['Chest']
        b = eb.new('PoleL'); b.head = Vector((-0.05, 0.6, 0.85)); b.tail = b.head + Vector((0, 0, 0.05)); b.parent = eb['Chest']
        bpy.ops.object.mode_set(mode='OBJECT')
        for sd, gb in (('R', 'GripR'), ('L', 'GripL')):
            c_ = rig.pose.bones['ForeArm.' + sd].constraints.new('IK')
            c_.name = 'IK'
            c_.target = rig; c_.subtarget = gb
            c_.pole_target = rig; c_.pole_subtarget = 'Pole' + sd
            c_.pole_angle = math.radians(POLE_ANGLE)
            c_.chain_count = 2
        rifle.matrix_world = Matrix.Translation(RH)
        weapon_parts.append((rifle, 'Rifle', 'rifle'))

    # ================================================================ pozalar
    def bone_rot(pb, ax, ay, az):
        q = Euler((math.radians(ax), math.radians(ay), math.radians(az)), 'XYZ').to_quaternion()
        ml = pb.bone.matrix_local.to_3x3()
        local = ml.inverted() @ q.to_matrix() @ ml
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = local.to_quaternion()

    def bone_loc(pb, dx, dy, dz):
        ml = pb.bone.matrix_local.to_3x3()
        pb.location = ml.inverted() @ Vector((dx, dy, dz))

    def merge(*ps):
        out = {}
        for p in ps:
            for k, v in p.items():
                out[k] = tuple(a + b for a, b in zip(out.get(k, (0, 0, 0)), v))
        return out

    def apply_pose(pose, frame, loc=None):
        for pb in rig.pose.bones:
            bone_rot(pb, *pose.get(pb.name, (0, 0, 0)))
            pb.keyframe_insert('rotation_quaternion', frame=frame)
            if pb.name == 'Hips':
                bone_loc(pb, *(loc or (0, 0, 0)))
                pb.keyframe_insert('location', frame=frame)
            if pb.name == 'Rifle':
                bone_loc(pb, *pose.get('RifleLoc', (0, 0, 0)))
                pb.keyframe_insert('location', frame=frame)
            ik = pb.constraints.get('IK')
            if ik:
                ik.influence = pose.get('IK' + pb.name[-1], 1.0)
                ik.keyframe_insert('influence', frame=frame)

    def new_action(name):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data_create()
        rig.animation_data.action = act
        return act

    # qurol turi bo'yicha qo'l holatlari
    if RIFLE:
        AIMP = {'Head': (0, 12, 8), 'Neck': (0, 0, 0), 'Chest': (0, 0, 8), 'Spine': (0, 0, 4)}
        READY = {'Rifle': (0, -38, 38), 'RifleLoc': (-0.08, 0.06, -0.5), 'Chest': (0, 0, -5)}     # miltiq ko'krak oldida qiya (qo'llar tabiiy, tirsaklar pastda)
        WIND = {'Rifle': (0, -10, 0), 'RifleLoc': (-0.3, 0.0, -0.32), 'Chest': (0, -4, 10)}
        STRIKE = {'Rifle': (0, 6, 0), 'RifleLoc': (0.22, 0.0, -0.3), 'Spine': (0, 14, 0), 'Chest': (0, 6, 0)}
        BLOCK = {'Rifle': (0, 0, 90), 'RifleLoc': (0.02, -0.12, -0.04), 'Chest': (0, -4, 0)}
    elif kind in SWORD_KINDS:
        READY = {'UpperArm.R': (-8, -30, 0), 'ForeArm.R': (0, -55, 0), 'Hand.R': (0, -35, 0),
                 'UpperArm.L': (12, -35, 0), 'ForeArm.L': (0, -75, -55)}
        WIND = {'UpperArm.R': (-25, -150, 0), 'ForeArm.R': (0, -60, 0), 'Hand.R': (0, -10, 0), 'Chest': (0, -4, 20), 'Spine': (0, 0, 10)}
        STRIKE = {'UpperArm.R': (-5, -55, 30), 'ForeArm.R': (0, -5, 0), 'Hand.R': (0, -60, 0), 'Chest': (0, 12, -25), 'Spine': (0, 6, -10)}
        BLOCK = {'UpperArm.L': (0, -32, 0), 'ForeArm.L': (0, 26, 0), 'Chest': (0, 4, 0)}     # qalqonni ko'tarib, nishonga qaratib to'sish
    elif kind == 'nayzachi':
        READY = {'UpperArm.R': (0, -15, 0), 'ForeArm.R': (0, -80, 0), 'Hand.R': (0, 0, 0),
                 'UpperArm.L': (12, -35, 0), 'ForeArm.L': (0, -75, -55)}
        # (READY ustiga qo'shiladigan farqlar) - nayza gorizontal qoladi
        WIND = {'UpperArm.R': (0, 30, 0), 'ForeArm.R': (0, -25, 0), 'Chest': (0, -4, 15)}
        STRIKE = {'UpperArm.R': (0, -45, 0), 'ForeArm.R': (0, 45, 0), 'Chest': (0, 6, -8)}
        BLOCK = {'UpperArm.L': (0, -32, 0), 'ForeArm.L': (0, 26, 0), 'Chest': (0, 4, 0)}
    else:  # kamonchi: tanasi yonga burilgan, chap qo'l oldinga cho'zilgan
        READY = {'UpperArm.L': (0, -30, 0), 'ForeArm.L': (0, -40, 0), 'UpperArm.R': (0, -10, 0), 'ForeArm.R': (0, -30, 0)}
        GRIP = READY
        # tinch holat: kamon chap qo'lda pastda, yon tomonda; o'ng qo'l bo'sh osilib turadi
        READY = {'UpperArm.L': (6, -14, 0), 'ForeArm.L': (0, -22, 0), 'Hand.L': (0, 10, 0), 'UpperArm.R': (-4, -6, 0), 'ForeArm.R': (0, -14, 0)}
        WIND = {'Hips': (0, 0, -62), 'Spine': (0, 0, -6), 'Chest': (0, 0, -10), 'Head': (0, 0, 70), 'Neck': (0, 0, 0),
                'UpperArm.L': (85, 0, 0), 'ForeArm.L': (0, 0, 0), 'Hand.L': (-85, 0, 0),
                'UpperArm.R': (-80, 10, 0), 'ForeArm.R': (0, -150, 0), 'Hand.R': (0, 0, 0)}
        STRIKE = merge(WIND, {'UpperArm.R': (0, 20, 0), 'ForeArm.R': (0, 70, 0)})
        BLOCK = dict(WIND)
        BLOCK.update({'UpperArm.R': (120, 0, -120), 'ForeArm.R': (0, -120, 150), 'Chest': (0, -4, -14)})   # tortib nishonga olish
    GRIP = locals().get('GRIP', READY)
    RIDE = {'Thigh.L': (22, -80, 0), 'Thigh.R': (-22, -80, 0), 'Shin.L': (0, 75, 0), 'Shin.R': (0, 75, 0),
            'Foot.L': (0, -10, 0), 'Foot.R': (0, -10, 0), 'Spine': (0, 6, 0)}

    free_r = kind in ('kamonchi',)                 # bo'sh qo'l yurganda tabiiy tebranadi
    free_l = kind in ('kamonchi', 'nayzachi') and not RIFLE

    def walk_pose(t, run=False):
        ## tabiiy yurish: tos burilishi va yon tomonga chayqalishi, ko'krak qarshi burilishi, tizza bukilishi,
        ## tovondan qadam qo'yish va panjadan itarilish, bo'sh qo'lning qarama-qarshi tebranishi
        a = math.sin(t * 2 * math.pi)
        c = math.cos(t * 2 * math.pi)
        sw = 38 if run else 24
        # tizza: oyoq oldinga uchib borayotganda ko'proq bukiladi, yerga tekkanda deyarli to'g'ri
        kl = max(0.0, c) * (sw * 2.0 if run else sw * 1.55) + (12 if run else 4)
        kr = max(0.0, -c) * (sw * 2.0 if run else sw * 1.55) + (12 if run else 4)
        p = merge(READY, {'Thigh.L': (0, -sw * a - (8 if run else 0), 0), 'Thigh.R': (0, sw * a - (8 if run else 0), 0),
                          'Shin.L': (0, kl, 0), 'Shin.R': (0, kr, 0),
                          'Foot.L': (0, -10 * a + max(0.0, c) * 12, 0), 'Foot.R': (0, 10 * a + max(0.0, -c) * 12, 0),
                          'Hips': (0, 0, (7 if run else 5) * a),
                          'Spine': (0, 14 if run else 3, 0), 'Chest': (0, 2 if run else 0, -(9 if run else 7) * a),
                          'Neck': (0, -4 if run else 0, 2 * a), 'Head': (0, -8 if run else -1, 0)})
        sa = (32 if run else 20) * a
        if free_r:
            p = merge(p, {'UpperArm.R': (0, -sa, 0), 'ForeArm.R': (0, -(25 if run else 12) - max(0.0, -a) * 15, 0)})
        if free_l:
            p = merge(p, {'UpperArm.L': (0, sa * 0.6, 0)})
        # ikki marta ko'tarilish-tushish (har qadamda), yon tomonga chayqalish
        bob = (1.0 - math.cos(t * 4 * math.pi)) * 0.5 * (0.07 if run else 0.035) - (0.08 if run else 0.025)
        sway = (0.012 if run else 0.022) * math.sin(t * 2 * math.pi - 0.6)
        return p, (0, sway, bob)

    new_action('Idle')
    # nafas olish va og'irlikni bir oyoqdan ikkinchisiga o'tkazish (4 soniya)
    for f, br, ws in ((1, 0, 0), (24, 1, 0.5), (48, 0, 1), (72, 1, 0.5), (96, 0, 0)):
        apply_pose(merge(READY, {'Chest': (0, 1.8 * br, 0), 'Neck': (0, -0.8 * br, 0), 'Head': (0, -1.2 * br, 2 * (ws - 0.5)),
                                 'Hips': (2.5 * (ws - 0.5), 0, 0), 'Thigh.L': (-2.5 * (ws - 0.5), -2 * ws, 0),
                                 'Thigh.R': (-2.5 * (ws - 0.5), -2 * (1 - ws), 0), 'Shin.L': (0, 5 * ws, 0), 'Shin.R': (0, 5 * (1 - ws), 0)}),
                   f, (0, 0.018 * (ws - 0.5), -0.004 * br))
    # soqchi: atrofni kuzatish - bosh va gavda sekin o'ngga, keyin chapga buriladi (6 soniya)
    new_action('Look')
    LOOK = [(1, 0, 0), (26, 1, 0), (52, 1, 0.3), (70, 0, 0), (96, -1, 0), (122, -1, 0.3), (144, 0, 0)]
    for f, side, up in LOOK:
        apply_pose(merge(READY, {'Head': (0, -6 * up, 48 * side), 'Neck': (0, 0, 14 * side), 'Chest': (0, 1.5, 12 * side),
                                 'Spine': (0, 0, 5 * side)}), f)
    new_action('Walk')
    for i in range(9):
        pose, loc = walk_pose(i / 8)
        apply_pose(pose, 1 + i * 4, loc)
    new_action('Run')
    for i in range(9):
        pose, loc = walk_pose(i / 8, True)
        apply_pose(pose, 1 + int(i * 2.5), loc)
    _merge0 = merge
    def rifle_abs(*ps):
        # miltiq qiymatlari qo'shilmaydi - oxirgisi ustun (to'liq holat)
        ABS = ('Rifle', 'RifleLoc', 'IKR', 'IKL')
        out = _merge0(*[{k: v for k, v in p.items() if k not in ABS} for p in ps])
        for p in ps:
            for k in ABS:
                if k in p:
                    out[k] = p[k]
        return out
    if RIFLE:
        merge = rifle_abs
    new_action('Attack')
    if kind == 'kamonchi':
        # haqiqiy otish: o'qni o'qdondan oladi -> kamonga qo'yadi -> torni yuzgacha tortadi (gavda egiladi) -> qo'yib yuboradi
        def over(b_, d_):
            o_ = dict(b_)
            o_.update(d_)
            return o_
        # (qo'l burchaklari Blender'da qidiruv bilan topilgan: o'ng qo'l kamon yonida / yuz yonida)
        REACH = over(WIND, {'UpperArm.R': (-20, -150, -40), 'ForeArm.R': (0, -60, 0), 'Head': (0, 0, 60)})
        NOCK = over(WIND, {'UpperArm.R': (90, 0, 0), 'ForeArm.R': (0, 0, -30), 'Hand.R': (0, 0, 0)})
        HALF = over(WIND, {'UpperArm.R': (110, 0, -60), 'ForeArm.R': (0, -60, 60)})
        DRAWN = over(WIND, {'UpperArm.R': (120, 0, -120), 'ForeArm.R': (0, -120, 150), 'Chest': (0, -4, -14), 'Spine': (0, -3, -8)})
        REL = over(DRAWN, {'UpperArm.R': (120, 0, -140), 'ForeArm.R': (0, -100, 170), 'Chest': (0, -2, -10)})
        apply_pose(WIND, 1)
        apply_pose(REACH, 6)                        # o'qdondan o'q olish
        apply_pose(NOCK, 11)                        # o'qni torga qo'yish
        apply_pose(HALF, 16)                        # tortish
        apply_pose(DRAWN, 21)                       # to'liq tortilgan - gavda orqaga egiladi
        apply_pose(over(DRAWN, {'Chest': (0, -5, -15)}), 27)  # nishonga olib ushlab turish
        apply_pose(REL, 29)                         # qo'yib yuborish: qo'l orqaga siltanadi
        apply_pose(over(REL, {'Chest': (0, 0, -10)}), 34)
        apply_pose(WIND, 44)
    else:
        apply_pose(READY, 1)
        apply_pose(merge(READY, WIND), 8, (-0.04, 0, 0))
        apply_pose(merge(READY, STRIKE), 13, (0.12, 0, -0.03))
        apply_pose(READY, 24)
    new_action('Block')
    if kind == 'kamonchi':   # kamonchida "Block" = nishonga olib turish
        apply_pose(BLOCK, 1)
        apply_pose(merge(BLOCK, {'Chest': (0, 1, 0)}), 24)
    else:
        apply_pose(merge(READY, BLOCK), 1, (-0.03, 0, -0.04))
        apply_pose(merge(READY, BLOCK, {'Chest': (0, 2, 0)}), 24, (-0.03, 0, -0.04))
    new_action('Hit')
    apply_pose(READY, 1)
    apply_pose(merge(READY, {'Spine': (0, -15, 10), 'Chest': (0, -10, 0), 'Head': (0, -20, 0)}), 4, (-0.08, 0, -0.03))
    apply_pose(READY, 14)
    new_action('Death1')
    apply_pose(READY, 1)
    apply_pose(merge(READY, {'Spine': (0, -25, 0), 'Head': (0, -30, 0), 'Thigh.L': (0, -20, 0), 'Shin.L': (0, 40, 0), 'Shin.R': (0, 30, 0)}), 8, (-0.1, 0, -0.15))
    apply_pose({'Hips': (0, -80, 0), 'Spine': (0, -8, 0), 'Head': (0, -10, 20), 'UpperArm.L': (0, 100, 70), 'UpperArm.R': (0, 80, -60),
                'Thigh.L': (0, 70, 10), 'Shin.L': (0, 25, 0), 'Thigh.R': (0, 80, -5), 'Shin.R': (0, 10, 0)}, 22, (-0.55, 0, -0.82))
    apply_pose({'Hips': (0, -88, 0), 'Head': (0, 0, 25), 'UpperArm.L': (0, 110, 75), 'UpperArm.R': (0, 85, -65),
                'Thigh.L': (0, 80, 10), 'Shin.L': (0, 20, 0), 'Thigh.R': (0, 88, -5), 'Shin.R': (0, 5, 0)}, 30, (-0.62, 0, -0.85))
    new_action('Death2')
    CR = {'Thigh.L': (0, -85, 10), 'Shin.L': (0, 85, 0), 'Thigh.R': (0, -20, -10), 'Shin.R': (0, 110, 0), 'Foot.R': (0, -50, 0)}
    apply_pose(READY, 1)
    apply_pose(merge(READY, CR, {'Spine': (0, 30, 0), 'Head': (0, 20, 0)}), 10, (0, 0, -0.45))
    apply_pose({'Hips': (0, 75, 0), 'Spine': (0, 10, 0), 'Head': (0, -40, 30), 'UpperArm.L': (0, -150, 20), 'UpperArm.R': (0, -140, -25),
                'Thigh.L': (0, -60, 0), 'Shin.L': (0, 60, 0), 'Thigh.R': (0, -70, 0), 'Shin.R': (0, 80, 0)}, 24, (0.45, 0, -0.85))
    apply_pose({'Hips': (0, 88, 0), 'Head': (0, -10, 40), 'UpperArm.L': (0, -160, 25), 'UpperArm.R': (0, -150, -30),
                'Thigh.L': (0, -85, 0), 'Shin.L': (0, 10, 0), 'Thigh.R': (0, -88, 0), 'Shin.R': (0, 20, 0)}, 32, (0.6, 0, -0.88))
    new_action('Cheer')
    for f, up in ((1, 0), (8, 1), (16, 0), (24, 1), (32, 0)):
        apply_pose(merge(READY, {'UpperArm.R': (0, -120 * up - 20, -20), 'ForeArm.R': (0, -30, 0), 'Head': (0, -15 * up, 0),
                                 'Chest': (0, -5 * up, 0)}), f, (0, 0, 0.05 * up))
    # otda: oyoqlar ot biqiniga, tana otning yurishi bilan tebranadi
    new_action('Ride')
    for f, b in ((1, 0), (6, 1), (12, 0)):
        apply_pose(merge(READY, RIDE, {'Spine': (0, 4 * b, 0)}), f, (0, 0, 0.03 * b))
    new_action('RideAttack')
    if kind == 'kamonchi':
        apply_pose(merge(WIND, RIDE), 1)
        apply_pose(merge(STRIKE, RIDE), 17)
        apply_pose(merge(WIND, RIDE), 30)
    else:
        apply_pose(merge(READY, RIDE), 1)
        apply_pose(merge(READY, WIND, RIDE), 8)
        apply_pose(merge(READY, STRIKE, RIDE), 13)
        apply_pose(merge(READY, RIDE), 24)

    if RIFLE:
        AIMR = merge(AIMP, {'Rifle': (0, 0, 0), 'RifleLoc': (0, 0, 0)})
        new_action('Aim')
        apply_pose(AIMR, 1)
        apply_pose(merge(AIMR, {'Chest': (0, 1, 0)}), 24)
        new_action('Fire')
        apply_pose(AIMR, 1)
        apply_pose(merge(AIMR, {'Rifle': (0, -12, 0), 'RifleLoc': (-0.08, 0, 0.03), 'Chest': (0, -6, 8), 'Head': (0, 2, 8)}), 3, (-0.03, 0, 0))
        apply_pose(merge(AIMR, {'Rifle': (0, -4, 0), 'RifleLoc': (-0.02, 0, 0.01)}), 9)
        apply_pose(AIMR, 18)
        # o'qlash (5 s): miltiq tik, qo'ndoq yerda; o'ng qo'l porox quyadi va shompol bilan 3 marta tiqadi
        RL = {'Rifle': (0, -84, 0), 'RifleLoc': (0.0, 0.12, -0.84), 'Spine': (0, 14, 0), 'Chest': (0, 6, 0), 'Head': (0, 15, 0), 'IKR': 0.0}
        UP = {'UpperArm.R': (0, -105, 15), 'ForeArm.R': (0, -45, 0)}
        DN = {'UpperArm.R': (0, -70, 15), 'ForeArm.R': (0, -60, 0)}
        POUR = {'UpperArm.R': (0, -95, 25), 'ForeArm.R': (0, -70, 0), 'Hand.R': (60, 0, 0)}
        new_action('Reload')
        apply_pose(AIMR, 1)
        apply_pose(merge(RL, {'IKR': 1.0}), 10)
        apply_pose(merge(RL, {'UpperArm.R': (0, -20, 0), 'ForeArm.R': (0, -100, 0)}), 18)      # xaltadan porox
        apply_pose(merge(RL, POUR), 28)
        apply_pose(merge(RL, POUR, {'Hand.R': (90, 0, 0)}), 38)
        apply_pose(merge(RL, {'UpperArm.R': (0, -20, 0), 'ForeArm.R': (0, -100, 0)}), 46)      # o'q
        apply_pose(merge(RL, UP), 54)
        f_ = 60
        for k_ in range(3):                                                                   # shompol
            apply_pose(merge(RL, UP), f_)
            apply_pose(merge(RL, DN), f_ + 7)
            f_ += 14
        apply_pose(merge(RL, UP), f_)
        apply_pose(merge(RL, {'IKR': 1.0}), f_ + 8)
        apply_pose(READY, f_ + 18)
        apply_pose(AIMR, 120)
        # orqasidan o'qlanadigan miltiq (Snider/Berdan, 1866+): miltiqni bel balandligiga tushiradi, o'ng qo'l bilan
        # zatvorni ochadi, xaltadan patron olib joylaydi, yopadi va yana yelkaga qo'yadi (~2 s)
        PORT = {'Rifle': (0, -12, 25), 'RifleLoc': (0.06, 0.02, -0.28), 'Chest': (0, 5, 0), 'Head': (0, 22, 0)}
        AT_LOCK = {'UpperArm.R': (-60, 45, 75), 'ForeArm.R': (0, -75, 0), 'Hand.R': (0, 0, 0), 'IKR': 0.0}
        new_action('Reload2')
        apply_pose(merge(AIMR, {'IKR': 1.0}), 1)
        apply_pose(merge(PORT, {'IKR': 1.0}), 6)
        apply_pose(merge(PORT, AT_LOCK), 10)                                                   # zatvor dastasiga
        apply_pose(merge(PORT, AT_LOCK, {'Hand.R': (45, 0, 0), 'ForeArm.R': (0, -8, 0)}), 14)   # ochish
        apply_pose(merge(PORT, {'UpperArm.R': (-15, 45, 45), 'ForeArm.R': (0, -90, 0), 'IKR': 0.0}), 21)   # belbog'dagi xaltadan patron
        apply_pose(merge(PORT, AT_LOCK, {'ForeArm.R': (0, 4, 0)}), 28)                         # patronni joylash
        apply_pose(merge(PORT, AT_LOCK, {'Hand.R': (-30, 0, 0)}), 33)                          # yopish
        apply_pose(merge(PORT, {'IKR': 1.0}), 38)
        apply_pose(merge(AIMR, {'IKR': 1.0}), 46)
        new_action('Kneel_Fire')
        KN = {'Thigh.L': (0, -85, 10), 'Shin.L': (0, 85, 0), 'Thigh.R': (0, -20, -10), 'Shin.R': (0, 110, 0), 'Foot.R': (0, -50, 0)}
        apply_pose(merge(READY, KN), 1, (0, 0, -0.45))
        apply_pose(merge(AIMR, KN), 10, (0, 0, -0.45))
        apply_pose(merge(AIMR, KN, {'Rifle': (0, -12, 0), 'RifleLoc': (-0.08, 0, 0.03), 'Chest': (0, -6, 8)}), 14, (-0.03, 0, -0.45))
        apply_pose(merge(AIMR, KN), 22, (0, 0, -0.45))
        apply_pose(merge(AIMR, KN), 30, (0, 0, -0.45))
        new_action('Attack2')      # qo'ndoq bilan urish
        apply_pose(READY, 1)
        apply_pose(merge(READY, {'Rifle': (0, -25, 150), 'RifleLoc': (-0.15, -0.05, -0.15), 'Chest': (0, -4, 25)}), 8)
        apply_pose(merge(READY, {'Rifle': (0, -35, 185), 'RifleLoc': (0.18, 0.0, 0.0), 'Chest': (0, 10, -20), 'Spine': (0, 8, -8)}), 13, (0.1, 0, -0.02))
        apply_pose(READY, 26)
        merge = _merge0

    # ---- qurollarni qo'lga bog'lash (Idle 1-kadr holatida)
    # qurollar "ushlash" holatida (GRIP) qo'lga bog'lanadi - tinch holat boshqacha bo'lsa ham qurol qo'lda to'g'ri turadi
    grip_act = new_action('Grip')
    apply_pose(GRIP, 1)
    rig.animation_data.action = grip_act
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    for ob, bone, wk in weapon_parts:
        pb = rig.pose.bones[bone]
        bm = rig.matrix_world @ pb.matrix
        if wk == 'sword':
            # dasta kaftda, tig' suyak yo'nalishi bo'ylab (qo'l davomida)
            loc = rig.matrix_world @ pb.tail
            m = bm.to_3x3().normalized()
            # suyakning Y o'qi = qo'l yo'nalishi; qilichning Z o'qi shu tomonga
            rot = m @ Matrix.Rotation(math.radians(-90), 3, 'X')
            ob.matrix_world = Matrix.Translation(loc) @ rot.to_4x4()
        elif wk == 'spear':
            loc = rig.matrix_world @ pb.tail
            ob.matrix_world = Matrix.Translation(loc + Vector((0.55, 0, 0)))   # nayza gorizontal, oldinga (+X), uchi oldinda
        elif wk == 'shield':
            # markaziy dastali qalqon (umbo): musht qalqon bo'rtmasining ORQASIDA dastani ushlaydi,
            # qalqon tekisligi nishonga qaragan; bilak va kaft to'liq qalqon orqasida qoladi (qo'l teshib chiqmaydi)
            hand_ = rig.pose.bones.get('Hand.L')
            hh_ = rig.matrix_world @ (hand_.head if hand_ else pb.tail)
            ht_ = rig.matrix_world @ (hand_.tail if hand_ else pb.tail)
            palm_ = hh_.lerp(ht_, 0.5)
            front_ = max(hh_.x, ht_.x) + 0.05            # kaftning eng oldingi nuqtasidan oldinda
            dep_ = 0.05 if (RUS or XI) else 0.0
            ob.matrix_world = Matrix.Translation(Vector((front_ + dep_, palm_.y, palm_.z)))
        elif wk == 'rifle':
            # dam olish (rest) holatida joylashtirib suyakka bog'lanadi
            rig.data.pose_position = 'REST'
            bpy.context.view_layer.update()
            ob.matrix_world = Matrix.Translation(rig.matrix_world @ rig.data.bones['Rifle'].head_local)
            bpy.context.view_layer.update()
            mw = ob.matrix_world.copy()
            ob.parent = rig
            ob.parent_type = 'BONE'
            ob.parent_bone = bone
            ob.matrix_world = mw
            bpy.context.view_layer.update()
            rig.data.pose_position = 'POSE'
            bpy.context.view_layer.update()
            continue
        elif wk == 'bow':
            loc = rig.matrix_world @ pb.tail
            ob.matrix_world = Matrix.Translation(loc)
        bpy.context.view_layer.update()
        mw = ob.matrix_world.copy()
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
        ob.matrix_world = mw

    if kind == 'kamonchi':
        archery_rig(rig, Matrix, 0.55 * (1.55 if LOOK == 'angliya' else 1.0))
    rig.animation_data.action = bpy.data.actions['Idle']
    bpy.data.actions.remove(grip_act)
    name = '%s_%s' % (faction, kind)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(TMP, name + '.blend'))
    smooth_all(45.0)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + '.glb'), export_format='GLB', export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                              export_apply=False)
    if PREVIEW:
        preview(rig, name, ['Idle', 'Walk', 'Run', 'Look', 'Attack', 'Block', 'Death1', 'Ride'] + (['Aim', 'Fire', 'Reload', 'Reload2', 'Kneel_Fire', 'Attack2'] if RIFLE else []))
    return rig


def preview(rig, name, acts):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 420, 520
    cd = bpy.data.cameras.new('C')
    cd.lens = 50
    cam = bpy.data.objects.new('C', cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for act in acts:
        rig.animation_data.action = bpy.data.actions[act]
        if act == 'Attack' and 'kamonchi' in name:
            for fr_ in (1, 6, 11, 16, 21, 29):
                sc.frame_set(fr_)
                a_ = math.radians(-70)
                t_ = Vector((0, 0, 1.1))
                cam.location = t_ + Vector((math.cos(a_) * 3.4, math.sin(a_) * 3.4, 0.5))
                cam.rotation_euler = (t_ - cam.location).to_track_quat('-Z', 'Y').to_euler()
                sc.render.filepath = os.path.join(OUT, 'prev_%s_shoot%02d.png' % (name, fr_))
                bpy.ops.render.render(write_still=True)
            continue
        fr = {'Attack': 13 if 'kamonchi' not in name else 14, 'Walk': 9, 'Run': 5, 'Look': 26, 'Death1': 30, 'Block': 1, 'Fire': 3, 'Reload': 64, 'Kneel_Fire': 14, 'Attack2': 13, 'Reload2': 21}.get(act, 1)
        sc.frame_set(fr)
        a = math.radians(-55 if 'kamonchi' not in name else -100)
        t = Vector((0, 0, 0.3)) if act.startswith('Death') else Vector((0, 0, 0.95))
        dd = 4.6 if act.startswith('Death') else 3.4
        cam.location = t + Vector((math.cos(a) * dd, math.sin(a) * dd, 1.4 if act.startswith('Death') else 0.7))
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(OUT, 'prev_%s_%s.png' % (name, act))
        bpy.ops.render.render(write_still=True)


FAC = 'osiyo'
for f_ in ('rus2', 'ingliz', 'yevropa2', 'usmonli', 'xitoy2', 'rus', 'xitoy', 'ozbek', 'arabi', 'afrika', 'hind', 'yunon', 'angliya'):
    if f_ in ARGS:
        FAC = f_
        break
if FAC in E2X:
    ALL = ['sarboz', 'otliq', 'qomondon']
else:
    ALL = ['qilichboz', 'nayzachi', 'kamonchi', 'otliq'] + (['sarboz', 'miltiqchi', 'qomondon'] if FAC == 'ozbek' else [])
POLE_ANGLE = float(os.environ.get('POLE', '-90'))
KINDS = [a for a in ARGS[1:] if a in ALL] or ALL
for k in KINDS:
    build_soldier(FAC, k)
print('MEDIEVAL DONE')
