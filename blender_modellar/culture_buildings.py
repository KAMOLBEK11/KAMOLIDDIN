"""Madaniyatlarga xos qal'a ichidagi binolar.
blender -b -P culture_buildings.py -- <chiqish_papka> <uslub> [preview]
uslublar: rus (yog'och izba, o'yma deraza, tik tom), yevropa (fahverk, tosh, cherepitsa),
          xitoy (kulrang g'isht, qizil ustun, egilgan tom), arab (tekis tomli paxsa/qumtosh, ravoq, palma, badgir)
O'lchamlar (joy egallashi) o'yindagi FOOT bilan bir xil; eshik -Y tomonda.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/cb_out'
STYLE = ARGS[1] if len(ARGS) > 1 else 'rus'
PREVIEW = 'preview' in ARGS
TMP = '/home/claude/work/cb_blend'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
random.seed(7)


def exp(name):
    import shutil
    p = os.path.join(TMP, STYLE + '_' + name)
    export(p)
    shutil.copy(p + '.glb', os.path.join(OUT, name + '.glb'))


def M():
    m = {
        'wood': mat('Wood', '#7a5434', 0.85), 'wood2': mat('WoodDark', '#4a3220', 0.85), 'log': mat('Log', '#8a6240', 0.9),
        'iron': mat('Iron', '#3a3a3e', 0.5, 0.7), 'team': mat('TeamColor', '#2f7d4a', 0.7), 'dark': mat('Dark', '#1c1a18', 0.9),
        'gold': mat('Gold', '#c9a03a', 0.35, 0.85), 'water': mat('Water', '#2c5a6a', 0.1), 'soil': mat('Soil', '#6b5236', 0.95),
        'wheat': mat('Wheat', '#d0b050', 0.9), 'straw': mat('Straw', '#c8a85a', 0.95), 'leaf': mat('Leaf', '#4a6a2a', 0.9),
        'stone': mat('Stone', '#8f8a80', 0.95), 'white': mat('Plaster', '#e8e2d2', 0.9), 'cloth1': mat('Cloth1', '#b8462e', 0.9),
        'cloth2': mat('Cloth2', '#2e6fb8', 0.9), 'cloth3': mat('Cloth3', '#d8b040', 0.9), 'gravel': mat('Gravel', '#8a8070', 0.95),
        'rock': mat('Rock', '#9a9286', 0.95), 'dirt': mat('Dirt', '#6e5a3e', 0.95),
    }
    pal = {
        'rus': {'roof': '#5a4a3a', 'roof2': '#2f6b4a', 'trim': '#e9e3d6', 'wall': '#a3412f', 'accent': '#c43a2a'},
        'yevropa': {'roof': '#a8553a', 'roof2': '#3d4654', 'trim': '#3a2a1c', 'wall': '#8e8b84', 'accent': '#2e4f8a'},
        'xitoy': {'roof': '#2d3138', 'roof2': '#c9a23a', 'trim': '#9a2a22', 'wall': '#7f7c74', 'accent': '#c43a2a'},
        'arab': {'roof': '#bb9c70', 'roof2': '#2e7a8a', 'trim': '#e6d3b0', 'wall': '#d3b48a', 'accent': '#2e7a8a'},
    }[STYLE]
    for k, v in pal.items():
        m[k] = mat(k.capitalize(), v, 0.8)
    return m


# ------------------------------------------------------------------ yordamchi shakllar

def gable(name, sx, sy, h, loc, mt, over=0.5, along='X'):
    """ikki qiyalikli tom; tizma X bo'ylab (yoki Y)"""
    x, y, z = loc
    if along == 'X':
        pts = [(x + a * (sx / 2 + over), y + b * (sy / 2 + over), z) for a in (-1, 1) for b in (-1, 1)] + \
              [(x + a * (sx / 2 + over), y, z + h) for a in (-1, 1)]
    else:
        pts = [(x + a * (sx / 2 + over), y + b * (sy / 2 + over), z) for a in (-1, 1) for b in (-1, 1)] + \
              [(x, y + b * (sy / 2 + over), z + h) for b in (-1, 1)]
    return hull_points(name, pts, mt)


def gable_end(name, sx, sy, h, loc, mt):
    """tom ostidagi uchburchak (frontonlar) - X uchlarida"""
    x, y, z = loc
    return hull_points(name, [(x + a * sx / 2, y + b * sy / 2, z) for a in (-1, 1) for b in (-1, 1)] +
                       [(x + a * sx / 2, y, z + h) for a in (-1, 1)], mt)


def pyramid(name, sx, sy, h, loc, mt, top=0.15):
    x, y, z = loc
    return hull_points(name, [(x + a * sx / 2, y + b * sy / 2, z) for a in (-1, 1) for b in (-1, 1)] +
                       [(x + a * top / 2, y + b * top / 2, z + h) for a in (-1, 1) for b in (-1, 1)], mt)


def dome(name, r, loc, mt, hz=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=r)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0
    o = _obj_from_bm(name, bm, mt)
    o.location = loc
    o.scale = (1, 1, hz)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def cn_roof(name, sx, sy, h, loc, mt, eave=1.0, lift=0.55):
    x, y, z = loc
    out = [hull_points(name, [(x + a * (sx / 2 + eave), y + b * (sy / 2 + eave), z) for a in (-1, 1) for b in (-1, 1)] +
                       [(x + a * max(sx / 2 - sy * 0.18, 0.3), y + b * 0.25, z + h) for a in (-1, 1) for b in (-1, 1)], mt)]
    for a in (-1, 1):
        for b in (-1, 1):
            cx, cy = x + a * (sx / 2 + eave), y + b * (sy / 2 + eave)
            out.append(hull_points(name + 'Horn', [(cx, cy, z - 0.08), (cx - a * 1.1, cy, z), (cx, cy - b * 1.1, z),
                                                    (cx + a * 0.3, cy + b * 0.3, z + lift)], mt))
    out.append(box(name + 'Ridge', (max(sx - sy * 0.36, 0.6) + 0.5, 0.4, 0.35), (x, y, z + h + 0.08), mt))
    return out


def log_walls(m, sx, sy, h, cx=0.0, cy=0.0, z0=0.0, door=None):
    """yog'och izba devorlari: ustma-ust yotqizilgan xodalar, burchaklarda chiqib turadi"""
    out = [box('Core', (sx - 0.2, sy - 0.2, h), (cx, cy, z0 + h / 2), m['log'])]
    n = int(h / 0.42)
    for i in range(n):
        z = z0 + 0.21 + i * 0.42
        if i % 2 == 0:
            for s in (-1, 1):
                out.append(cyl('LogX', 0.22, sx + 0.7, (cx, cy + s * sy / 2, z), m['log'], axis='X', verts=7))
        else:
            for s in (-1, 1):
                out.append(cyl('LogY', 0.22, sy + 0.7, (cx + s * sx / 2, cy, z), m['log'], axis='Y', verts=7))
    return out


def rus_window(m, x, y, z, w=0.8, h=1.0):
    """o'yma oq ramali deraza (nalichnik)"""
    return [box('Win', (w, 0.12, h), (x, y, z), m['dark']),
            box('Nal', (w + 0.4, 0.1, 0.18), (x, y - 0.04, z + h / 2 + 0.12), m['trim']),
            box('NalTop', (w + 0.1, 0.1, 0.35), (x, y - 0.04, z + h / 2 + 0.38), m['trim']),
            box('NalB', (w + 0.3, 0.1, 0.14), (x, y - 0.04, z - h / 2 - 0.08), m['trim']),
            box('ShutL', (w * 0.5, 0.08, h), (x - w * 0.75, y - 0.06, z), m['accent']),
            box('ShutR', (w * 0.5, 0.08, h), (x + w * 0.75, y - 0.06, z), m['accent'])]


def half_timber(m, sx, sy, h, cx=0.0, cy=0.0, z0=0.0):
    """fahverk: oq suvoq va qora yog'och to'sinlar"""
    out = [box('Plaster', (sx, sy, h), (cx, cy, z0 + h / 2), m['white'])]
    for side in (-1, 1):
        y = cy + side * (sy / 2 + 0.03)
        n = max(2, int(sx / 1.6))
        for i in range(n + 1):
            x = cx - sx / 2 + i * sx / n
            out.append(box('Post', (0.22, 0.08, h), (x, y, z0 + h / 2), m['trim']))
            if i < n and i % 2 == 0:
                L = math.hypot(sx / n, h / 2)
                ang = math.atan2(h / 2, sx / n)
                out.append(box('Brace', (L, 0.07, 0.18), (x + sx / n / 2, y, z0 + h * 0.25), m['trim'], (0, -ang, 0)))
        for z in (z0 + 0.1, z0 + h / 2, z0 + h - 0.1):
            out.append(box('Beam', (sx, 0.09, 0.2), (cx, y, z), m['trim']))
    for side in (-1, 1):
        x = cx + side * (sx / 2 + 0.03)
        for z in (z0 + 0.1, z0 + h / 2, z0 + h - 0.1):
            out.append(box('BeamY', (0.09, sy, 0.2), (x, cy, z), m['trim']))
        for i in range(3):
            out.append(box('PostY', (0.08, 0.22, h), (x, cy - sy / 2 + i * sy / 2, z0 + h / 2), m['trim']))
    return out


def palm(m, x, y, h=6.0):
    out = [cyl('Trunk', 0.22, h, (x, y, h / 2), m['wood'], axis='Z', verts=7, r2=0.16)]
    for k in range(7):
        a = k / 7 * 2 * math.pi
        out.append(box('Frond', (2.6, 0.5, 0.06), (x + math.cos(a) * 1.2, y + math.sin(a) * 1.2, h - 0.2), m['leaf'],
                       (0, math.radians(18), a)))
    return out


def tree(m, x, y, h=4.0, r=1.6, conifer=False):
    out = [cyl('Trunk', 0.2, h * 0.5, (x, y, h * 0.25), m['wood2'], axis='Z', verts=6)]
    if conifer:
        for k in range(3):
            out.append(cyl('Cone', r * (1.0 - k * 0.25), h * 0.45, (x, y, h * 0.4 + k * h * 0.22), m['leaf'], axis='Z', verts=8, r2=0.05))
    else:
        out.append(dome('Crown', r, (x, y, h * 0.45), m['leaf'], 1.3))
    return out


def door(m, x, y, z=0.0, w=1.3, h=2.3, mt=None):
    return [box('Door', (w, 0.18, h), (x, y, z + h / 2), mt or m['wood2'])]


def arch_open(m, x, y, z, w, h, depth=0.3, axis='Y', mt=None):
    hw = w / 2
    pts = []
    for d in (-depth / 2, depth / 2):
        for px, pz in ((-hw, 0), (hw, 0), (-hw, h - hw), (hw, h - hw), (0, h)):
            pts.append((x + px, y + d, z + pz) if axis == 'Y' else (x + d, y + px, z + pz))
    return hull_points('Arch', pts, mt or m['dark'])


def flat_parapet(m, sx, sy, z, mt, cx=0.0, cy=0.0, h=0.5):
    out = []
    for s in (-1, 1):
        out.append(box('Par', (sx, 0.3, h), (cx, cy + s * (sy / 2 - 0.15), z + h / 2), mt))
        out.append(box('Par', (0.3, sy, h), (cx + s * (sx / 2 - 0.15), cy, z + h / 2), mt))
    return out


def chimney(m, x, y, z, h=2.0, mt=None):
    return [box('Chimney', (0.8, 0.8, h), (x, y, z + h / 2), mt or m['stone']),
            box('ChimTop', (1.0, 1.0, 0.2), (x, y, z + h + 0.1), m['dark'])]


def stalls(m, n, ox, oy, roof='flat'):
    out = []
    cloths = [m['cloth1'], m['cloth2'], m['cloth3']]
    for i in range(n):
        x = ox + (i % 2) * 6.0 - 3.0
        y = oy + (i // 2) * 5.0 - 2.5
        out.append(box('Counter', (2.6, 1.2, 1.0), (x, y, 0.5), m['wood']))
        for a in (-1, 1):
            for b in (-1, 1):
                out.append(box('Pole', (0.12, 0.12, 2.5), (x + a * 1.3, y + b * 0.9, 1.25), m['wood2']))
        if roof == 'cn':
            out += cn_roof('StallRoof', 2.4, 1.6, 0.6, (x, y, 2.5), m['roof'], eave=0.4, lift=0.3)
            out.append(sph_('Lantern', 0.25, (x + 1.3, y - 1.0, 2.2), m['accent']))
        elif roof == 'gable':
            out.append(gable('StallRoof', 2.6, 1.8, 0.8, (x, y, 2.5), m['roof'], 0.2))
        else:
            out.append(box('Awning', (3.0, 2.2, 0.08), (x, y, 2.55), cloths[i % 3], (math.radians(8), 0, 0)))
        out.append(box('Goods', (0.6, 0.5, 0.5), (x - 0.6, y, 1.25), cloths[(i + 1) % 3]))
        out.append(box('Goods2', (0.6, 0.5, 0.4), (x + 0.6, y, 1.2), m['straw']))
    return out


def sph_(name, r, loc, mt):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=r)
    o = _obj_from_bm(name, bm, mt)
    o.location = loc
    return o


# ================================================================== BINOLAR

def barracks():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        p += [box('Found', (16.6, 8.6, 0.6), (0, 0, 0.3), m['stone'])]
        p += log_walls(m, 16, 8, 4.6, z0=0.6)
        p.append(gable('Roof', 16, 8, 3.4, (0, 0, 5.2), m['roof'], 0.6))
        p.append(gable_end('Gable', 16, 7.6, 3.2, (0, 0, 5.2), m['log']))
        for x in (-5.5, -2.5, 2.5, 5.5):
            p += rus_window(m, x, -4.15, 3.0)
        p += door(m, 0, -4.15, 0.6, 1.4, 2.4)
        p.append(box('Porch', (3.0, 1.8, 0.5), (0, -5.0, 0.6), m['wood']))
        p.append(gable('PorchRoof', 3.0, 2.0, 1.2, (0, -5.0, 3.2), m['roof'], 0.2, along='Y'))
        for a in (-1, 1):
            p.append(cyl('PorchPost', 0.13, 2.6, (a * 1.3, -5.8, 1.9), m['wood'], axis='Z', verts=8))
        p += chimney(m, 4.0, 1.5, 7.0, 1.6, m['wall'])
        for x in (-6.5, 6.5):
            p.append(box('Rack', (1.6, 0.3, 1.8), (x, -4.7, 1.5), m['wood2']))
            p.append(cyl('Spear', 0.03, 2.8, (x, -4.8, 2.0), m['wood'], axis='Z', verts=5))
    elif STYLE == 'yevropa':
        p.append(box('Ground', (16, 8, 3.2), (0, 0, 1.6), m['wall']))
        p += half_timber(m, 16, 8, 2.6, z0=3.2)
        p.append(gable('Roof', 16, 8, 4.0, (0, 0, 5.8), m['roof'], 0.5))
        p.append(gable_end('Gable', 16, 7.9, 3.8, (0, 0, 5.8), m['white']))
        for x in (-5, -2.5, 2.5, 5):
            p.append(box('Win', (0.7, 0.12, 1.0), (x, -4.05, 4.4), m['dark']))
            p.append(box('WinL', (0.6, 0.12, 0.9), (x, -4.05, 1.9), m['dark']))
        p += door(m, 0, -4.05, 0, 1.6, 2.6)
        p += chimney(m, -5, 2, 8.0, 1.8)
        p.append(box('Shield', (0.9, 0.12, 1.1), (0, -4.08, 3.8), m['accent']))
    elif STYLE == 'xitoy':
        p.append(box('Plinth', (17, 9, 0.6), (0, 0, 0.3), m['stone']))
        p.append(box('Body', (14, 6.4, 3.6), (0, 0.6, 2.4), m['white']))
        p.append(box('Base', (14.1, 6.5, 0.8), (0, 0.6, 1.0), m['wall']))
        for i in range(8):
            p.append(cyl('Col', 0.2, 3.6, (-7.0 + i * 2.0, -3.4, 2.4), m['trim'], axis='Z', verts=8))
        p.append(box('Beam', (15, 0.4, 0.4), (0, -3.4, 4.3), m['trim']))
        p += cn_roof('Roof', 15, 7.6, 2.4, (0, 0, 4.4), m['roof'], 1.0)
        p += door(m, 0, -2.65, 0.6, 1.6, 2.5, m['trim'])
        for x in (-4.5, 4.5):
            p.append(box('Lattice', (1.6, 0.1, 1.4), (x, -2.62, 2.8), m['wood2']))
        for x in (-6.5, 6.5):
            p.append(box('Rack', (1.6, 0.3, 1.8), (x, -4.2, 1.5), m['wood2']))
            p.append(cyl('Halberd', 0.03, 3.0, (x, -4.3, 2.0), m['wood'], axis='Z', verts=5))
    elif STYLE == 'arab':
        p.append(box('Body', (16, 8, 4.6), (0, 0, 2.3), m['wall']))
        p += flat_parapet(m, 16, 8, 4.6, m['wall'])
        for i in range(6):
            p.append(arch_open(m, -6.25 + i * 2.5, -4.05, 0.3, 1.8, 3.2, 0.3))
        p.append(box('Band', (16.1, 8.1, 0.3), (0, 0, 3.9), m['roof']))
        p.append(box('Badgir', (2.0, 2.0, 2.6), (5.0, 1.5, 5.9), m['wall']))
        for a in (-1, 1):
            p.append(box('BadgirSlot', (0.4, 2.05, 1.6), (5.0 + a * 0.5, 1.5, 6.4), m['dark']))
        p += palm(m, -9.5, -3.0, 6.5)
    join('Barracks', p, origin=(0, 0, 0)); exp('barracks')


def granary():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        # ambar: yog'och ustunlar ustida xodali ombor
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(box('Stilt', (0.4, 0.4, 0.9), (a * 4.2, b * 3.2, 0.45), m['wood2']))
        p += log_walls(m, 10, 8, 3.2, z0=0.9)
        p.append(gable('Roof', 10, 8, 2.6, (0, 0, 4.1), m['roof'], 0.7))
        p.append(gable_end('Gable', 10, 7.6, 2.4, (0, 0, 4.1), m['log']))
        p += door(m, 0, -4.15, 0.9, 1.8, 2.2)
        p.append(box('Steps', (2.0, 1.2, 0.9), (0, -4.8, 0.45), m['wood']))
    elif STYLE == 'yevropa':
        p += half_timber(m, 10, 8, 4.0)
        p.append(gable('Roof', 10, 8, 3.6, (0, 0, 4.0), m['roof'], 0.5, along='Y'))
        p.append(hull_points('GableF', [(-5, b * 4, 4.0) for b in (-1, 1)] + [(5, b * 4, 4.0) for b in (-1, 1)] + [(0, b * 4, 7.4) for b in (-1, 1)], m['white']))
        p += door(m, 0, -4.05, 0, 3.0, 3.2)
        p.append(box('Hoist', (0.25, 1.4, 0.25), (0, -4.6, 6.2), m['wood2']))
    elif STYLE == 'xitoy':
        p.append(box('Plinth', (10.5, 8.5, 1.0), (0, 0, 0.5), m['stone']))
        p.append(box('Body', (9, 7, 3.6), (0, 0, 2.8), m['wall']))
        p += cn_roof('Roof', 9, 7, 2.2, (0, 0, 4.6), m['roof'], 0.9)
        p += door(m, 0, -3.55, 1.0, 1.6, 2.4, m['trim'])
        for x in (-3, 3):
            p.append(box('Vent', (1.0, 0.1, 0.6), (x, -3.55, 3.8), m['dark']))
    elif STYLE == 'arab':
        p.append(box('Body', (10, 8, 4.0), (0, 0, 2.0), m['wall']))
        p += flat_parapet(m, 10, 8, 4.0, m['wall'])
        for x in (-3, 0, 3):
            p.append(cyl('Silo', 1.2, 2.2, (x, 1.5, 5.1), m['wall'], axis='Z', verts=12, r2=0.9))
            p.append(dome('SiloTop', 0.9, (x, 1.5, 6.2), m['wall'], 0.8))
        p.append(arch_open(m, 0, -4.05, 0, 2.0, 3.0, 0.3, mt=m['wood2']))
        for k in range(4):
            p.append(box('Sack', (0.9, 0.7, 0.6), (-3 + k * 1.8, -5.0, 0.3), m['straw']))
    join('Granary', p, origin=(0, 0, 0)); exp('granary')


def well():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        p += log_walls(m, 1.8, 1.8, 0.9)
        for a in (-1, 1):
            p.append(box('Post', (0.2, 0.2, 2.4), (a * 0.9, 0, 1.2), m['wood2']))
        p.append(cyl('Winch', 0.12, 2.0, (0, 0, 1.9), m['wood'], axis='X', verts=8))
        p.append(gable('Roof', 2.4, 2.0, 0.9, (0, 0, 2.4), m['roof'], 0.2))
        p.append(box('Bucket', (0.4, 0.4, 0.4), (0.5, -1.1, 0.8), m['wood']))
    elif STYLE == 'yevropa':
        p.append(cyl('Ring', 1.0, 0.9, (0, 0, 0.45), m['stone'], axis='Z', verts=16))
        p.append(cyl('Water', 0.8, 0.05, (0, 0, 0.88), m['water'], axis='Z', verts=12))
        for a in (-1, 1):
            p.append(box('Post', (0.2, 0.2, 2.4), (a * 1.0, 0, 1.2), m['wood2']))
        p.append(cyl('Winch', 0.12, 2.2, (0, 0, 1.9), m['wood'], axis='X', verts=8))
        p.append(gable('Roof', 2.4, 1.8, 1.0, (0, 0, 2.4), m['roof'], 0.25))
    elif STYLE == 'xitoy':
        p.append(cyl('Ring', 1.0, 0.8, (0, 0, 0.4), m['stone'], axis='Z', verts=8))
        p.append(cyl('Water', 0.8, 0.05, (0, 0, 0.78), m['water'], axis='Z', verts=8))
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(cyl('Col', 0.1, 2.4, (a * 1.2, b * 1.0, 1.2), m['trim'], axis='Z', verts=6))
        p += cn_roof('Roof', 2.2, 1.8, 0.9, (0, 0, 2.4), m['roof'], 0.4, 0.3)
    elif STYLE == 'arab':
        p.append(cyl('Ring', 1.0, 1.0, (0, 0, 0.5), m['wall'], axis='Z', verts=14))
        p.append(cyl('Water', 0.8, 0.05, (0, 0, 0.98), m['water'], axis='Z', verts=12))
        for a in (-1, 1):
            p.append(box('Post', (0.25, 0.25, 2.6), (a * 1.0, 0, 1.3), m['wood2']))
        p.append(box('Beam', (2.4, 0.25, 0.25), (0, 0, 2.6), m['wood2']))
        p.append(cyl('Pulley', 0.25, 0.1, (0, 0, 2.35), m['wood'], axis='Y', verts=10))
        p.append(box('Trough', (1.8, 0.6, 0.4), (0, -1.4, 0.2), m['wall']))
    join('Well', p, origin=(0, 0, 0)); exp('well')


def smithy():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        p += log_walls(m, 8, 6, 3.2)
        p.append(gable('Roof', 8, 6, 2.4, (0, 0, 3.2), m['roof'], 0.5))
        p.append(gable_end('Gable', 8, 5.6, 2.2, (0, 0, 3.2), m['log']))
        p.append(box('Open', (3.0, 0.2, 2.4), (0, -3.1, 1.2), m['dark']))
        p += chimney(m, 2.4, 1.2, 4.2, 2.0, m['wall'])
    elif STYLE == 'yevropa':
        p.append(box('Body', (8, 6, 3.4), (0, 0, 1.7), m['wall']))
        p.append(gable('Roof', 8, 6, 2.6, (0, 0, 3.4), m['roof2'], 0.4))
        p.append(gable_end('Gable', 8, 5.9, 2.5, (0, 0, 3.4), m['wall']))
        p.append(box('Open', (3.0, 0.2, 2.4), (-1.0, -3.05, 1.2), m['dark']))
        p += chimney(m, 2.6, 1.4, 4.4, 2.2)
        p.append(box('LeanTo', (3.0, 2.2, 0.15), (2.0, -4.0, 2.6), m['roof'], (math.radians(-12), 0, 0)))
    elif STYLE == 'xitoy':
        p.append(box('Body', (8, 6, 3.2), (0, 0, 1.6), m['wall']))
        p += cn_roof('Roof', 8, 6, 2.0, (0, 0, 3.2), m['roof'], 0.7)
        p.append(box('Open', (3.0, 0.2, 2.4), (0, -3.05, 1.2), m['dark']))
        p += chimney(m, 2.6, 1.6, 3.6, 2.4, m['wall'])
    elif STYLE == 'arab':
        p.append(box('Body', (8, 6, 3.4), (0, 0, 1.7), m['wall']))
        p += flat_parapet(m, 8, 6, 3.4, m['wall'])
        p.append(arch_open(m, -1.0, -3.05, 0, 2.8, 3.0, 0.3))
        p += chimney(m, 2.6, 1.6, 3.4, 2.2, m['wall'])
        p.append(box('Shade', (3.0, 2.0, 0.08), (2.0, -4.0, 2.5), m['straw']))
    p.append(box('Anvil', (0.8, 0.4, 0.8), (1.4, -4.3, 0.4), m['iron']))
    p.append(cyl('Forge', 0.6, 0.6, (-1.6, -4.2, 0.3), m['stone'], axis='Z', verts=10))
    p.append(box('Embers', (0.8, 0.8, 0.05), (-1.6, -4.2, 0.62), mat('Ember', '#ff6a20', 0.6, 0, 3.0)))
    join('Smithy', p, origin=(0, 0, 0)); exp('smithy')


def stable():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        p += log_walls(m, 14, 1.0, 3.0, cy=3.3)
        p.append(gable('Roof', 14, 8, 2.4, (0, 0, 3.2), m['roof'], 0.4))
        for k in range(6):
            x = -6.5 + k * 2.6
            p.append(cyl('Post', 0.16, 3.2, (x, -3.6, 1.6), m['log'], axis='Z', verts=7))
            if k < 5:
                p.append(box('Stall', (0.12, 5.0, 1.3), (x + 1.3, 0.5, 0.65), m['wood']))
        p.append(box('Fence', (14, 0.12, 0.2), (0, -3.6, 1.1), m['wood']))
    elif STYLE == 'yevropa':
        p += half_timber(m, 14, 7, 3.0)
        p.append(gable('Roof', 14, 7, 3.0, (0, 0, 3.0), m['roof'], 0.5))
        for k in range(5):
            x = -5.2 + k * 2.6
            p.append(box('StallDoor', (1.6, 0.15, 1.4), (x, -3.6, 0.7), m['wood']))
            p.append(box('StallOpen', (1.6, 0.12, 1.0), (x, -3.56, 2.0), m['dark']))
        p.append(box('Hay', (2.0, 1.4, 1.0), (6.0, -4.6, 0.5), m['straw']))
    elif STYLE == 'xitoy':
        p.append(box('Back', (14, 0.6, 3.0), (0, 3.4, 1.5), m['wall']))
        for k in range(7):
            p.append(cyl('Col', 0.18, 3.0, (-6.6 + k * 2.2, -3.4, 1.5), m['trim'], axis='Z', verts=8))
            if k < 6:
                p.append(box('Stall', (0.12, 5.6, 1.2), (-5.5 + k * 2.2, 0.2, 0.6), m['wood']))
        p += cn_roof('Roof', 14, 7.4, 1.8, (0, 0, 3.0), m['roof'], 0.7)
    elif STYLE == 'arab':
        p.append(box('Back', (14, 0.8, 3.2), (0, 3.4, 1.6), m['wall']))
        for k in range(6):
            p.append(arch_open(m, -6.0 + k * 2.4, -3.6, 0, 1.8, 2.6, 0.5, mt=m['wall']))
        p.append(box('Roof', (14.6, 8, 0.3), (0, 0, 3.2), m['straw']))
        for k in range(7):
            p.append(box('Pillar', (0.5, 0.5, 3.2), (-7.0 + k * 2.33, -3.6, 1.6), m['wall']))
        p += palm(m, 7.8, -3.0, 6.0)
    p.append(box('Trough', (10, 0.6, 0.6), (0, 2.6, 0.3), m['wood2']))
    join('Stable', p, origin=(0, 0, 0)); exp('stable')


def farm():
    clear(); m = M(); p = []
    if STYLE == 'xitoy':
        # sholipoya: suvli kataklar va yashil maysalar
        p.append(box('Field', (20, 14, 0.12), (0, 0, 0.06), m['water']))
        for i in range(4):
            for j in range(3):
                p.append(box('Paddy', (4.4, 4.0, 0.2), (-7.5 + i * 5, -4.5 + j * 4.5, 0.1), mat('Rice', '#7aa848', 0.9)))
        p.append(box('House', (4, 3.4, 2.4), (12.5, 4.0, 1.2), m['white']))
        p += cn_roof('HRoof', 4, 3.4, 1.4, (12.5, 4.0, 2.4), m['roof'], 0.6, 0.3)
    else:
        crop = m['wheat'] if STYLE != 'rus' else mat('Rye', '#c8a050', 0.9)
        p.append(box('Field', (20, 14, 0.15), (0, 0, 0.08), m['soil']))
        for k in range(9):
            p.append(box('Row', (19, 0.8, 0.7), (0, -6 + k * 1.5, 0.45), crop))
        if STYLE == 'rus':
            p += log_walls(m, 4, 3.4, 2.4, cx=12.5, cy=4.0)
            p.append(gable('HRoof', 4, 3.4, 1.8, (12.5, 4.0, 2.4), m['straw'], 0.4))
            for k in range(8):
                p.append(box('Fence', (0.1, 0.1, 1.1), (-10.2, -7 + k * 2.0, 0.55), m['wood2']))
            p.append(box('Rail', (0.08, 14, 0.1), (-10.2, 0, 0.9), m['wood']))
            p += tree(m, 13.5, -3.0, 5.0, 1.4, True)
        elif STYLE == 'yevropa':
            p += half_timber(m, 4, 3.4, 2.4, cx=12.5, cy=4.0)
            p.append(gable('HRoof', 4, 3.4, 2.0, (12.5, 4.0, 2.4), m['roof'], 0.4))
            # shamol tegirmoni
            p.append(cyl('Mill', 1.4, 6.0, (13.0, -3.5, 3.0), m['stone'], axis='Z', verts=12, r2=1.0))
            p.append(cyl('MillCap', 1.2, 1.4, (13.0, -3.5, 6.7), m['roof'], axis='Z', verts=12, r2=0.1))
            for k in range(4):
                p.append(box('Sail', (0.9, 0.08, 4.6), (13.0, -4.7, 5.8), m['white'], (0, k * math.pi / 2 + 0.3, 0)))
        elif STYLE == 'arab':
            p.append(box('Ariq', (20, 0.6, 0.06), (0, -6.9, 0.17), m['water']))
            p.append(box('House', (4, 3.4, 2.6), (12.5, 4.0, 1.3), m['wall']))
            p += flat_parapet(m, 4, 3.4, 2.6, m['wall'], 12.5, 4.0, 0.4)
            for k in range(3):
                p += palm(m, 11.0 + k * 1.8, -4.0 + k * 1.2, 5.5 + k * 0.6)
    join('Farm', p, origin=(0, 0, 0)); exp('farm')


def lumber():
    clear(); m = M(); p = []
    p.append(box('Yard', (12, 10, 0.15), (0, 0, 0.08), m['dirt']))
    roof_m = m['roof']
    if STYLE == 'xitoy':
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(cyl('Col', 0.14, 2.8, (-2 + a * 2.6, 3 + b * 1.6, 1.4), m['trim'], axis='Z', verts=6))
        p += cn_roof('Shed', 5.6, 3.6, 1.2, (-2, 3, 2.8), roof_m, 0.5, 0.3)
    elif STYLE == 'arab':
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(box('Post', (0.25, 0.25, 2.8), (-2 + a * 2.6, 3 + b * 1.6, 1.4), m['wood2']))
        p.append(box('Shade', (6, 4, 0.12), (-2, 3, 2.85), m['straw']))
        p += palm(m, 4.5, 3.5, 5.5)
    else:
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(box('Post', (0.25, 0.25, 2.8), (-2 + a * 2.6, 3 + b * 1.6, 1.4), m['wood2']))
        p.append(gable('Shed', 5.4, 3.4, 1.4, (-2, 3, 2.8), roof_m, 0.3))
        p += tree(m, 4.5, 3.5, 6.0, 1.6, STYLE == 'rus')
    for k in range(6):
        p.append(cyl('Log', 0.35, 5.0, (2.5, -3 + (k % 3) * 0.75, 0.35 + (k // 3) * 0.6), m['log'], axis='X', verts=10))
    p.append(box('Sawhorse', (1.8, 0.6, 0.9), (-3, -2.5, 0.45), m['wood']))
    p.append(box('Axe', (0.08, 0.6, 0.08), (-3, -2.5, 1.1), m['iron']))
    join('Lumber', p, origin=(0, 0, 0)); exp('lumber')


def quarry():
    clear(); m = M(); p = []
    rock = m['wall'] if STYLE == 'arab' else m['rock']
    p.append(box('Pit', (14, 12, 0.15), (0, 0, 0.08), m['gravel']))
    random.seed(3)
    for k in range(7):
        r = random.uniform(1.2, 2.6)
        p.append(hull_points('Rock', [(random.uniform(-5, 5) + dx * r, 3.5 + random.uniform(-1, 2) + dy * r, dz * r * 1.4)
                                      for dx, dy, dz in ((-1, -1, 0), (1, -1, 0), (-1, 1, 0), (1, 1, 0), (0, 0, 1), (0.4, -0.3, 0.8))], rock))
    for k in range(8):
        p.append(box('Block', (1.2, 0.8, 0.7), (-4 + (k % 4) * 1.5, -3.5 + (k // 4) * 1.0, 0.35), rock))
    p.append(box('Cart', (2.2, 1.4, 0.9), (4, -3.5, 0.8), m['wood']))
    for sy in (-1, 1):
        p.append(cyl('Wheel', 0.5, 0.15, (4, -3.5 + sy * 0.8, 0.5), m['wood2'], axis='Y', verts=10))
    # ko'targich (kran)
    p.append(box('CraneA', (0.25, 0.25, 4.0), (-5.5, -1.0, 2.0), m['wood2']))
    p.append(box('CraneB', (3.0, 0.2, 0.2), (-4.3, -1.0, 3.9), m['wood2']))
    join('Quarry', p, origin=(0, 0, 0)); exp('quarry')


def market():
    clear(); m = M(); p = []
    p.append(box('Plaza', (16, 12, 0.15), (0, 0, 0.08), m['stone'] if STYLE != 'arab' else m['wall']))
    if STYLE == 'rus':
        p += stalls(m, 4, -3.5, 0, 'gable')
        # yog'och ibodatxona (kichik cherkov)
        p += log_walls(m, 3.6, 3.6, 3.6, cx=4.5, cy=1.0)
        p.append(pyramid('Tent', 4.0, 4.0, 3.0, (4.5, 1.0, 3.6), m['roof2'], 0.3))
        p.append(cyl('Drum', 0.5, 1.0, (4.5, 1.0, 7.0), m['log'], axis='Z', verts=8))
        p.append(dome('Onion', 0.7, (4.5, 1.0, 7.5), m['roof2'], 1.6))
        p.append(cyl('Cross', 0.05, 1.2, (4.5, 1.0, 9.2), m['gold'], axis='Z', verts=4))
    elif STYLE == 'yevropa':
        p += stalls(m, 4, -3.5, 0, 'flat')
        # bozor xochi / favvora
        p.append(cyl('Fountain', 1.6, 0.8, (4.5, 1.0, 0.4), m['stone'], axis='Z', verts=12))
        p.append(cyl('FWater', 1.4, 0.05, (4.5, 1.0, 0.82), m['water'], axis='Z', verts=12))
        p.append(cyl('Column', 0.25, 3.5, (4.5, 1.0, 2.2), m['stone'], axis='Z', verts=8))
        p.append(box('Cross', (0.9, 0.18, 0.18), (4.5, 1.0, 3.6), m['stone']))
    elif STYLE == 'xitoy':
        p += stalls(m, 4, -3.5, 0, 'cn')
        p.append(box('Gate1', (0.4, 0.4, 4.0), (3.0, -4.5, 2.0), m['trim']))
        p.append(box('Gate2', (0.4, 0.4, 4.0), (7.0, -4.5, 2.0), m['trim']))
        p += cn_roof('Paifang', 5.0, 0.8, 0.7, (5.0, -4.5, 4.0), m['roof'], 0.5, 0.35)
        for k in range(4):
            p.append(sph_('Lantern', 0.3, (3.5 + k * 1.0, -4.5, 3.4), m['accent']))
    elif STYLE == 'arab':
        p += stalls(m, 4, -3.5, 0, 'flat')
        p.append(box('Souk', (5, 5, 3.6), (4.5, 1.0, 1.8), m['wall']))
        p.append(dome('SoukDome', 2.0, (4.5, 1.0, 3.6), m['wall'], 0.7))
        p.append(arch_open(m, 4.5, -1.55, 0, 2.0, 3.0, 0.3))
        p += palm(m, 7.2, -4.5, 6.0)
    join('Market', p, origin=(0, 0, 0)); exp('market')


def mint():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        # g'isht xazina: qizil g'isht, oq bezak, yashil chodir tom
        p.append(box('Body', (10, 10, 5), (0, 0, 2.5), m['wall']))
        p.append(box('Band', (10.2, 10.2, 0.4), (0, 0, 2.4), m['trim']))
        p.append(pyramid('Roof', 10.6, 10.6, 3.6, (0, 0, 5.0), m['roof2'], 1.6))
        p.append(box('Lantern', (1.6, 1.6, 1.2), (0, 0, 9.2), m['trim']))
        p.append(dome('Onion', 0.9, (0, 0, 9.8), m['gold'], 1.6))
        for x in (-3, 3):
            p += rus_window(m, x, -5.1, 3.2, 0.7, 1.1)
        p += door(m, 0, -5.1, 0, 1.4, 2.6, m['iron'])
    elif STYLE == 'yevropa':
        p.append(box('Body', (10, 10, 6), (0, 0, 3), m['wall']))
        p.append(gable('Roof', 10, 10, 4.0, (0, 0, 6), m['roof2'], 0.3, along='Y'))
        # pog'onali fronton (gildiya uyi)
        for k in range(4):
            w = 10 - k * 2.4
            p.append(box('Step', (w, 0.4, 1.0), (0, -5.0, 6.5 + k * 1.0), m['wall']))
        for x in (-3, 0, 3):
            p.append(box('Win', (1.0, 0.12, 1.6), (x, -5.05, 4.0), m['dark']))
        p += door(m, 0, -5.05, 0, 1.6, 2.6, m['iron'])
        p.append(cyl('Sign', 0.5, 0.08, (1.8, -5.4, 2.6), m['gold'], axis='Y', verts=12))
    elif STYLE == 'xitoy':
        p.append(box('Plinth', (11, 11, 0.8), (0, 0, 0.4), m['stone']))
        p.append(box('Body', (9, 9, 3.6), (0, 0, 2.6), m['trim']))
        p += cn_roof('Roof', 9, 9, 2.4, (0, 0, 4.4), m['roof2'], 1.0)
        p += door(m, 0, -4.55, 0.8, 1.6, 2.4, m['wood2'])
        for k in range(4):
            p.append(cyl('Coin', 0.45, 0.12, (-1.5 + k, -6.0, 0.06 + k * 0.12), m['gold'], axis='Z', verts=12))
    elif STYLE == 'arab':
        p.append(box('Body', (10, 10, 5), (0, 0, 2.5), m['wall']))
        p += flat_parapet(m, 10, 10, 5, m['wall'])
        p.append(dome('Dome', 2.6, (0, 0, 5.0), m['roof2'], 1.0))
        p.append(box('Portal', (4, 0.8, 6.2), (0, -5.2, 3.1), m['trim']))
        p.append(arch_open(m, 0, -5.65, 0, 2.2, 4.0, 0.2, mt=m['wood2']))
    join('Mint', p, origin=(0, 0, 0)); exp('mint')


def house():
    clear(); m = M(); p = []
    if STYLE == 'rus':
        p += log_walls(m, 5.4, 5.0, 3.0)
        p.append(gable('Roof', 5.4, 5.0, 2.6, (0, 0, 3.0), m['roof'], 0.5, along='Y'))
        p.append(hull_points('Front', [(-2.7, -2.55, 3.0), (2.7, -2.55, 3.0), (0, -2.55, 5.5), (-2.7, -2.4, 3.0), (2.7, -2.4, 3.0), (0, -2.4, 5.5)], m['log']))
        p.append(box('Prichelina', (0.2, 0.15, 3.6), (-1.3, -2.7, 4.2), m['trim'], (0, math.radians(-46), 0)))
        p.append(box('Prichelina2', (0.2, 0.15, 3.6), (1.3, -2.7, 4.2), m['trim'], (0, math.radians(46), 0)))
        p += rus_window(m, -1.2, -2.75, 1.7, 0.7, 0.9)
        p += rus_window(m, 1.2, -2.75, 1.7, 0.7, 0.9)
        p += door(m, 2.9, -1.0, 0, 0.2, 2.0)
        p += chimney(m, 1.0, 1.0, 4.0, 1.6, m['wall'])
        for k in range(5):
            p.append(box('Fence', (0.1, 0.1, 1.0), (-3.2 + k * 1.6, -3.8, 0.5), m['wood2']))
    elif STYLE == 'yevropa':
        p.append(box('Ground', (5.4, 5.0, 1.6), (0, 0, 0.8), m['wall']))
        p += half_timber(m, 5.4, 5.0, 2.0, z0=1.6)
        p.append(gable('Roof', 5.4, 5.0, 3.0, (0, 0, 3.6), m['roof'], 0.5))
        p.append(gable_end('Gable', 5.4, 4.9, 2.9, (0, 0, 3.6), m['white']))
        p += door(m, -1.2, -2.55, 0, 1.0, 1.9)
        p.append(box('Win', (0.8, 0.12, 0.8), (1.2, -2.55, 2.5), m['dark']))
        p += chimney(m, 1.8, 1.2, 4.6, 1.4)
        p += tree(m, -3.2, 2.8, 4.0, 1.2)
    elif STYLE == 'xitoy':
        p.append(box('Plinth', (6, 5.6, 0.4), (0, 0, 0.2), m['stone']))
        p.append(box('Body', (5.2, 4.6, 2.8), (0, 0, 1.8), m['white']))
        p.append(box('Base', (5.25, 4.65, 0.8), (0, 0, 0.8), m['wall']))
        for a in (-1, 1):
            p.append(cyl('Col', 0.14, 2.8, (a * 2.4, -2.5, 1.8), m['trim'], axis='Z', verts=6))
        p += cn_roof('Roof', 5.2, 4.6, 1.6, (0, 0, 3.2), m['roof'], 0.7, 0.35)
        p += door(m, 0, -2.35, 0.4, 1.1, 2.0, m['trim'])
        p.append(box('Lattice', (1.0, 0.1, 0.9), (-1.6, -2.35, 2.0), m['wood2']))
        p.append(sph_('Lantern', 0.22, (1.2, -2.8, 2.6), m['accent']))
    elif STYLE == 'arab':
        p.append(box('Body', (5.6, 5.4, 3.2), (0, 0, 1.6), m['wall']))
        p += flat_parapet(m, 5.6, 5.4, 3.2, m['wall'], h=0.45)
        p.append(box('Upper', (2.6, 2.4, 2.0), (1.2, 1.2, 4.2), m['wall']))
        p.append(box('Badgir', (1.0, 1.0, 1.6), (1.2, 1.2, 6.0), m['wall']))
        p.append(box('BadSlot', (1.05, 0.3, 0.9), (1.2, 1.2, 6.2), m['dark']))
        p.append(arch_open(m, -1.2, -2.75, 0, 1.0, 2.1, 0.2, mt=m['wood2']))
        p.append(box('Mashrabiya', (1.2, 0.3, 1.0), (1.3, -2.85, 2.2), m['wood']))
        p += palm(m, -3.4, 2.6, 5.5)
    join('House', p, origin=(0, 0, 0)); exp('house')


ALL = [barracks, granary, well, smithy, stable, farm, lumber, quarry, market, mint, house]
for f in ALL:
    f()

if PREVIEW:
    clear()
    for i, f in enumerate(ALL):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, f.__name__ + '.glb'))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location = ((i % 6) * 24 - 60, (i // 6) * 24 - 10, 0)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 800
    cd = bpy.data.cameras.new('C'); cd.lens = 30
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (0, -95, 60)
    cam.rotation_euler = (Vector((0, 2, 2)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_b_%s.png' % STYLE)
    bpy.ops.render.render(write_still=True)
print('CB DONE', STYLE)
