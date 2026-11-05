"""Madaniyatlarga xos qal'a qismlari: devor, minora, darvoza, ark (keep).
blender -b -P culture_castles.py -- <chiqish_papka> <uslub> [preview]
uslublar: rus (Moskva kremli), yevropa (ritsar qal'asi), xitoy (Min darvozali qal'a),
          arab (cho'l qal'asi), bastion (1860-70 yillar yulduzsimon bastionli qal'a)
O'lchamlar castle_parts.py bilan bir xil: devor moduli X bo'ylab 4 m, qalinligi 3 m (tashqi tomoni -Y),
yurish yo'lagi 7 m balandlikda. Minora soqchisi turadigan maydon balandligi uslubga qarab (TOP).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/cc_out'
STYLE = ARGS[1] if len(ARGS) > 1 else 'rus'
PREVIEW = 'preview' in ARGS
TMP = '/home/claude/work/cc_blend'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

WALL_H = 7.0
WALL_T = 3.0


def exp(name):
    import shutil
    p = os.path.join(TMP, STYLE + '_' + name)
    export(p)
    shutil.copy(p + '.glb', os.path.join(OUT, name + '.glb'))


def M():
    base = {
        'wood': mat('Wood', '#6e4a2c', 0.8), 'wood2': mat('WoodDark', '#4a3220', 0.8), 'iron': mat('Iron', '#3a3a3e', 0.5, 0.7),
        'team': mat('TeamColor', '#2f7d4a', 0.7), 'dark': mat('Dark', '#1c1a18', 0.9), 'gold': mat('Gold', '#c9a03a', 0.35, 0.85),
        'grass': mat('Grass', '#5d7a3a', 0.95), 'earth': mat('Earth', '#7a6446', 0.95),
    }
    pal = {
        'rus': {'wall': '#a3412f', 'wall2': '#8a3424', 'trim': '#e9e3d6', 'roof': '#2f6b4a', 'roof2': '#3b7f5a', 'base': '#b9b2a4'},
        'yevropa': {'wall': '#8e8b84', 'wall2': '#73706a', 'trim': '#a8a49b', 'roof': '#3d4654', 'roof2': '#4b5666', 'base': '#6c6963'},
        'xitoy': {'wall': '#7f7c74', 'wall2': '#6a675f', 'trim': '#9a2a22', 'roof': '#2d3138', 'roof2': '#c9a23a', 'base': '#5f5c55'},
        'arab': {'wall': '#d3b48a', 'wall2': '#bb9c70', 'trim': '#e6d3b0', 'roof': '#2e7a8a', 'roof2': '#3fa0a8', 'base': '#a88f6c'},
        'bastion': {'wall': '#9b6a4c', 'wall2': '#7f5640', 'trim': '#d9d2c2', 'roof': '#3b6b4a', 'roof2': '#e2c25a', 'base': '#8a8478'},
    }[STYLE]
    for k, v in pal.items():
        base[k] = mat(k.capitalize(), v, 0.85 if 'roof' not in k else 0.6)
    return base


def pyramid(name, sx, sy, h, loc, m, top=0.15):
    x, y, z = loc
    pts = [(x + a * sx / 2, y + b * sy / 2, z) for a in (-1, 1) for b in (-1, 1)]
    pts += [(x + a * top / 2, y + b * top / 2, z + h) for a in (-1, 1) for b in (-1, 1)]
    return hull_points(name, pts, m)


def onion(name, r, loc, m, h=2.2):
    """piyozsimon gumbaz"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=r)
    for v in bm.verts:
        t = max(-1.0, min(1.0, v.co.z / r))
        if t > 0:
            k = (1.0 - t) ** 1.35
            v.co.x *= max(k * 1.12, 0.02)
            v.co.y *= max(k * 1.12, 0.02)
            v.co.z = t * h
        else:
            v.co.z = t * r * 0.55
    o = _obj_from_bm(name, bm, m)
    o.location = loc
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def dome(name, r, loc, m, hz=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=r)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0
    o = _obj_from_bm(name, bm, m)
    o.location = loc
    o.scale = (1, 1, hz)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def cn_roof(name, sx, sy, h, loc, m, eave=1.4, lift=0.7):
    """xitoycha egilgan tom: tepasi tizma, chetlari chiqib turadi, burchaklari ko'tarilgan"""
    x, y, z = loc
    out = [hull_points(name, [(x + a * (sx / 2 + eave), y + b * (sy / 2 + eave), z) for a in (-1, 1) for b in (-1, 1)] +
                       [(x + a * (sx / 2 - sy * 0.15), y + b * 0.3, z + h) for a in (-1, 1) for b in (-1, 1)], m)]
    # ostki qalinlik
    out.append(box(name + 'Under', (sx + eave * 2, sy + eave * 2, 0.25), (x, y, z - 0.12), m))
    # burchaklar yuqoriga qayrilgan
    for a in (-1, 1):
        for b in (-1, 1):
            cx, cy = x + a * (sx / 2 + eave), y + b * (sy / 2 + eave)
            out.append(hull_points(name + 'Horn', [(cx, cy, z - 0.1), (cx - a * 1.4, cy, z), (cx, cy - b * 1.4, z),
                                                    (cx + a * 0.35, cy + b * 0.35, z + lift)], m))
    out.append(box(name + 'Ridge', (sx - sy * 0.3 + 0.6, 0.5, 0.45), (x, y, z + h + 0.1), m))
    return out


def pavilion(m, sx, sy, z, posts_h=3.2, tiers=1, roof_key='roof'):
    """ustunli ayvon (xitoycha): qizil ustunlar + egilgan tom(lar)"""
    out = [box('PavFloor', (sx, sy, 0.3), (0, 0, z + 0.15), m['wall2'])]
    nx, ny = max(2, int(sx / 3) + 1), max(2, int(sy / 3) + 1)
    for i in range(nx):
        for j in (0, ny - 1):
            out.append(cyl('Col', 0.22, posts_h, (-sx / 2 + 0.4 + i * (sx - 0.8) / (nx - 1), -sy / 2 + 0.4 + j * (sy - 0.8) / (ny - 1), z + 0.3 + posts_h / 2), m['trim'], axis='Z', verts=8))
    for j in range(ny):
        for i in (0, nx - 1):
            out.append(cyl('Col', 0.22, posts_h, (-sx / 2 + 0.4 + i * (sx - 0.8) / (nx - 1), -sy / 2 + 0.4 + j * (sy - 0.8) / (ny - 1), z + 0.3 + posts_h / 2), m['trim'], axis='Z', verts=8))
    out.append(box('Beam', (sx, sy, 0.4), (0, 0, z + 0.3 + posts_h + 0.2), m['trim']))
    zz = z + 0.7 + posts_h
    s = 1.0
    for t in range(tiers):
        out += cn_roof('Roof%d' % t, sx * s, sy * s, 1.6 * s, (0, 0, zz), m[roof_key], eave=1.3 * s)
        if t < tiers - 1:
            out.append(box('Upper', (sx * s * 0.62, sy * s * 0.62, 2.2), (0, 0, zz + 1.6 * s + 0.9), m['trim']))
            zz += 1.6 * s + 2.0
            s *= 0.65
    return out


def merl_rect(m, x0, x1, y, z, step=1.4, w=0.8, h=1.1, t=0.5):
    out = []
    n = max(1, int(round((x1 - x0) / step)))
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        out.append(box('Merlon', (w, t, h), (x, y, z + h / 2), m))
    return out


def merl_swallow(m, x0, x1, y, z, step=1.6):
    """Moskva kremli 'qaldirg'och dumi' tishlari"""
    out = []
    n = max(1, int(round((x1 - x0) / step)))
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        out.append(box('Merlon', (0.95, 0.55, 1.1), (x, y, z + 0.55), m))
        for s in (-1, 1):
            out.append(hull_points('Prong', [(x + s * 0.48, y - 0.27, z + 1.1), (x + s * 0.48, y + 0.27, z + 1.1),
                                             (x + s * 0.12, y - 0.27, z + 1.1), (x + s * 0.12, y + 0.27, z + 1.1),
                                             (x + s * 0.4, y - 0.27, z + 1.75), (x + s * 0.4, y + 0.27, z + 1.75)], m))
    return out


def merl_step(m, x0, x1, y, z, step=1.5):
    """arabcha pog'onali (zinapoyasimon) tishlar"""
    out = []
    n = max(1, int(round((x1 - x0) / step)))
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        out.append(box('M1', (1.0, 0.5, 0.6), (x, y, z + 0.3), m))
        out.append(box('M2', (0.62, 0.5, 0.5), (x, y, z + 0.85), m))
        out.append(box('M3', (0.26, 0.5, 0.45), (x, y, z + 1.32), m))
    return out


def merl_ring_style(m, r, z, n, cx=0.0, cy=0.0):
    out = []
    for i in range(n):
        a = i / n * 2 * math.pi
        px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
        if STYLE == 'arab':
            for k, (w, h, zz) in enumerate([(0.9, 0.6, 0.3), (0.55, 0.5, 0.85), (0.22, 0.45, 1.32)]):
                out.append(box('M', (0.45, w, h), (px, py, z + zz), m, (0, 0, a)))
        else:
            out.append(box('M', (0.5, 0.9, 1.1), (px, py, z + 0.55), m, (0, 0, a)))
    return out


def merl_line_style(m, x0, x1, y, z):
    if STYLE == 'rus':
        return merl_swallow(m, x0, x1, y, z)
    if STYLE == 'arab':
        return merl_step(m, x0, x1, y, z)
    if STYLE == 'xitoy':
        return merl_rect(m, x0, x1, y, z, 1.6, 1.0, 0.9, 0.55)
    return merl_rect(m, x0, x1, y, z)


# ============================================================== DEVOR

def wall():
    clear(); m = M()
    p = []
    if STYLE == 'bastion':
        # tuproq val: tashqi tomoni g'isht bilan qoplangan qiya devor (eskarp), ustida parapet va ambrazuralar
        p.append(hull_points('Scarp', [(x, -WALL_T / 2 - 1.6, 0) for x in (-2, 2)] + [(x, WALL_T / 2 + 2.5, 0) for x in (-2, 2)] +
                             [(x, -WALL_T / 2 + 0.2, WALL_H - 0.9) for x in (-2, 2)] + [(x, WALL_T / 2 + 0.2, WALL_H - 0.9) for x in (-2, 2)], m['wall']))
        p.append(box('Cordon', (4.0, 0.4, 0.3), (0, -WALL_T / 2 + 0.1, WALL_H - 0.9), m['trim']))
        p.append(box('Walk', (4.0, WALL_T + 0.4, 0.9), (0, 0.4, WALL_H - 0.45), m['earth']))
        p.append(box('Grass', (4.0, 2.6, 0.12), (0, WALL_T / 2 + 1.3, WALL_H - 1.0), m['grass'], (math.radians(-35), 0, 0)))
        p.append(box('Parapet', (4.0, 1.2, 1.2), (0, -WALL_T / 2 + 0.6, WALL_H + 0.6), m['earth']))
        p.append(box('ParapetTop', (4.0, 1.2, 0.1), (0, -WALL_T / 2 + 0.6, WALL_H + 1.25), m['grass']))
        p.append(box('Embrasure', (0.8, 1.3, 0.6), (0, -WALL_T / 2 + 0.6, WALL_H + 0.95), m['dark']))
    else:
        tall = 1.0 if STYLE != 'xitoy' else 1.0
        batter = 0.5 if STYLE in ('xitoy', 'arab') else 0.15
        p.append(box('Base', (4.0, WALL_T + 0.8, 1.2), (0, 0, 0.6), m['base']))
        p.append(hull_points('Body', [(x, s * (WALL_T / 2 + batter), 1.2) for x in (-2, 2) for s in (-1, 1)] +
                             [(x, s * WALL_T / 2, WALL_H) for x in (-2, 2) for s in (-1, 1)], m['wall']))
        p.append(box('Walk', (4.0, WALL_T - 0.9, 0.12), (0, 0, WALL_H + 0.06), m['wood'] if STYLE != 'xitoy' else m['wall2']))
        if STYLE == 'rus':
            p.append(box('WhiteBand', (4.0, WALL_T + 0.2, 0.35), (0, 0, 1.4), m['trim']))
            for x in (-1.0, 1.0):
                p.append(box('Arch', (1.2, 0.1, 2.0), (x, -WALL_T / 2 - 0.02, 3.6), m['wall2']))
        if STYLE == 'yevropa':
            p.append(box('Buttress', (0.9, 0.8, 4.5), (0, -WALL_T / 2 - 0.3, 2.6), m['wall2']))
            for k in range(4):
                p.append(box('Course', (4.0, 0.05, 0.08), (0, -WALL_T / 2 - 0.02, 2.0 + k * 1.3), m['wall2']))
        if STYLE == 'xitoy':
            for k in range(5):
                p.append(box('Course', (4.0, 0.05, 0.06), (0, -WALL_T / 2 - 0.4 + k * 0.08, 1.8 + k * 1.1), m['wall2']))
        if STYLE == 'arab':
            p.append(box('Band', (4.0, WALL_T + 0.1, 0.3), (0, 0, WALL_H - 0.6), m['wall2']))
            p.append(box('Spout', (0.25, 0.6, 0.25), (0.8, -WALL_T / 2 - 0.25, WALL_H - 0.9), m['wood']))
        p += merl_line_style(m['wall'], -2.0, 2.0, -WALL_T / 2 + 0.27, WALL_H)
        p.append(box('Parapet', (4.0, 0.4, 0.6), (0, WALL_T / 2 - 0.2, WALL_H + 0.3), m['wall']))
    join('Wall', p, origin=(0, 0, 0))
    exp('wall')


# ============================================================== MINORA

def tower():
    clear(); m = M()
    p = []
    F = 11.55          # soqchi turadigan maydon
    if STYLE == 'rus':
        S = 7.0
        p.append(box('Base', (S + 0.8, S + 0.8, 1.2), (0, 0, 0.6), m['trim']))
        p.append(hull_points('Body', [(a * S / 2, b * S / 2, 1.2) for a in (-1, 1) for b in (-1, 1)] +
                             [(a * (S / 2 - 0.3), b * (S / 2 - 0.3), F) for a in (-1, 1) for b in (-1, 1)], m['wall']))
        for z in (4.0, 8.0):
            p.append(box('Band', (S - 0.2 + (0.6 - z * 0.05), S - 0.2 + (0.6 - z * 0.05), 0.35), (0, 0, z), m['trim']))
        p.append(box('Floor', (S - 0.4, S - 0.4, 0.3), (0, 0, F - 0.15), m['wood']))
        p += sum([merl_swallow(m['wall'], -S / 2 + 0.4, S / 2 - 0.4, s * (S / 2 - 0.55), F - 0.1) for s in (-1, 1)], [])
        for a in (-1, 1):
            for b in (-1, 1):
                p.append(box('Post', (0.45, 0.45, 3.2), (a * (S / 2 - 0.7), b * (S / 2 - 0.7), F + 1.6), m['wall']))
        p.append(box('Cornice', (S, S, 0.5), (0, 0, F + 3.4), m['trim']))
        p.append(pyramid('Tent', S + 0.4, S + 0.4, 7.5, (0, 0, F + 3.6), m['roof'], 0.4))
        p.append(box('Watch', (1.4, 1.4, 1.6), (0, 0, F + 11.4), m['trim']))
        p.append(pyramid('Tent2', 1.8, 1.8, 2.0, (0, 0, F + 12.2), m['roof2'], 0.1))
        p.append(cyl('Spire', 0.08, 2.5, (0, 0, F + 15.2), m['gold'], axis='Z', verts=6))
        p.append(box('Flag', (1.2, 0.05, 0.8), (0.65, 0, F + 15.9), m['team']))
    elif STYLE == 'yevropa':
        R = 3.6
        p.append(cyl('Base', R + 0.7, 2.0, (0, 0, 1.0), m['base'], axis='Z', verts=20, r2=R + 0.2))
        p.append(cyl('Body', R, F - 2.0, (0, 0, 2.0 + (F - 2.0) / 2), m['wall'], axis='Z', verts=20, r2=R - 0.2))
        p.append(cyl('Corbel', R + 0.35, 0.8, (0, 0, F - 0.6), m['wall2'], axis='Z', verts=20, r2=R + 0.5))
        p.append(cyl('Floor', R + 0.2, 0.25, (0, 0, F - 0.12), m['wood'], axis='Z', verts=20))
        p += merl_ring_style(m['wall'], R + 0.25, F - 0.1, 14)
        for k in range(6):
            a = k / 6 * 2 * math.pi
            p.append(box('Post', (0.35, 0.35, 3.0), (math.cos(a) * (R - 0.2), math.sin(a) * (R - 0.2), F + 1.5), m['wood2']))
        p.append(cyl('Cone', R + 0.6, 6.5, (0, 0, F + 3.0 + 3.25), m['roof'], axis='Z', verts=20, r2=0.15))
        for k in range(3):
            a = k * 2.1
            p.append(box('Slit', (0.3, 0.15, 1.3), (math.cos(a) * (R - 0.05), math.sin(a) * (R - 0.05), 5 + k * 1.4), m['dark'], (0, 0, a)))
        p.append(cyl('Pole', 0.07, 2.5, (0, 0, F + 10.5), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (1.4, 0.05, 0.9), (0.75, 0, F + 11.3), m['team']))
    elif STYLE == 'xitoy':
        S = 7.0
        p.append(hull_points('Body', [(a * (S / 2 + 0.5), b * (S / 2 + 0.5), 0) for a in (-1, 1) for b in (-1, 1)] +
                             [(a * S / 2, b * S / 2, F - 0.3) for a in (-1, 1) for b in (-1, 1)], m['wall']))
        p.append(box('Floor', (S - 0.4, S - 0.4, 0.3), (0, 0, F - 0.15), m['wall2']))
        for s in (-1, 1):
            p += merl_rect(m['wall'], -S / 2, S / 2, s * (S / 2 - 0.27), F - 0.3, 1.6, 1.0, 0.9, 0.55)
            p += [box('Mx', (0.55, 1.0, 0.9), (s * (S / 2 - 0.27), -S / 2 + 1.0 + k * 1.65, F + 0.15), m['wall']) for k in range(4)]
        p += [o for o in pavilion(m, 4.6, 4.6, F, 3.0, 1)]
    elif STYLE == 'arab':
        R = 3.6
        p.append(cyl('Body', R + 0.5, F, (0, 0, F / 2), m['wall'], axis='Z', verts=20, r2=R - 0.2))
        p.append(cyl('Band', R + 0.05, 0.4, (0, 0, F - 1.6), m['wall2'], axis='Z', verts=20))
        p.append(cyl('Floor', R - 0.3, 0.25, (0, 0, F - 0.12), m['wood'], axis='Z', verts=20))
        p += merl_ring_style(m['wall'], R - 0.25, F - 0.1, 12)
        for k in range(4):
            a = k / 4 * 2 * math.pi + 0.4
            p.append(box('Slit', (0.3, 0.15, 1.1), (math.cos(a) * (R + 0.05), math.sin(a) * (R + 0.05), 6.5), m['dark'], (0, 0, a)))
        p.append(cyl('Pole', 0.07, 4.0, (0, 0, F + 2.0), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (1.6, 0.05, 1.0), (0.85, 0, F + 3.4), m['team']))
    elif STYLE == 'bastion':
        # besh burchakli bastion: o'tkir uchi tashqariga (-Y), ustida to'p va qorovul budkasi
        F = WALL_H + 0.05
        pts = [(-6.5, 3.5), (6.5, 3.5), (7.5, -3.0), (0.0, -10.0), (-7.5, -3.0)]
        bot = [(x * 1.12, y * 1.12 - 0.6, 0) for x, y in pts]
        top = [(x, y, WALL_H - 0.9) for x, y in pts]
        p.append(hull_points('Bastion', bot + top, m['wall']))
        p.append(hull_points('Terre', [(x * 0.97, y * 0.97, WALL_H - 0.9) for x, y in pts] + [(x * 0.97, y * 0.97, WALL_H) for x, y in pts], m['earth']))
        for i in range(4):
            (x0, y0), (x1, y1) = pts[(i + 1) % 5], pts[(i + 2) % 5]
            if i == 3:
                break
            L = math.hypot(x1 - x0, y1 - y0)
            a = math.atan2(y1 - y0, x1 - x0)
            nx, ny = math.sin(a), -math.cos(a)
            cx, cy = (x0 + x1) / 2 - nx * 0.3, (y0 + y1) / 2 - ny * 0.3
            ob = box('Parapet', (L, 1.2, 1.1), (cx, cy, WALL_H + 0.55), m['earth'], (0, 0, a))
            p.append(ob)
            p.append(box('Embr', (0.8, 1.3, 0.55), (cx, cy, WALL_H + 0.9), m['dark'], (0, 0, a)))
        p.append(box('Cordon', (0.1, 0.1, 0.1), (0, 0, 0), m['trim']))
        # to'p
        p.append(box('Carriage', (1.6, 0.9, 0.6), (0, -5.0, WALL_H + 0.3), m['wood2']))
        p.append(cyl('Barrel', 0.22, 2.4, (0, -5.9, WALL_H + 0.75), m['iron'], axis='Y', verts=10, r2=0.18))
        for s in (-1, 1):
            p.append(cyl('Wheel', 0.5, 0.15, (s * 0.85, -4.9, WALL_H + 0.5), m['wood'], axis='X', verts=12))
        # qorovul budkasi (minora burchagida)
        p.append(box('Sentry', (1.2, 1.2, 2.2), (5.5, 2.4, WALL_H + 1.1), m['trim']))
        p.append(pyramid('SentryRoof', 1.5, 1.5, 0.9, (5.5, 2.4, WALL_H + 2.2), m['roof'], 0.1))
        p.append(cyl('Pole', 0.07, 6.0, (-4.0, 2.0, WALL_H + 3.0), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (1.6, 0.05, 1.0), (-3.15, 2.0, WALL_H + 5.4), m['team']))
    join('Tower', p, origin=(0, 0, 0))
    exp('tower')


# ============================================================== DARVOZA

def gate():
    clear(); m = M()
    p = []
    L = 10.0
    door = lambda: [box('Door', (1.25, 0.3, 5.0), (sx * 0.66, -WALL_T / 2 - 0.45, 2.5), m['wood']) for sx in (-1, 1)] + \
        [box('Strip', (1.2, 0.06, 0.1), (sx * 0.66, -WALL_T / 2 - 0.62, 0.8 + k * 1.3), m['iron']) for sx in (-1, 1) for k in range(4)]
    if STYLE == 'rus':
        # Spasskaya kabi baland darvoza minorasi
        S = 9.0
        p.append(box('Base', (S + 0.6, WALL_T + 4.6, 1.0), (0, 0, 0.5), m['trim']))
        p.append(box('Body', (S, WALL_T + 4, 14.0), (0, 0, 7.0), m['wall']))
        p.append(box('Arch', (3.0, 0.2, 5.6), (0, -WALL_T / 2 - 2.02, 2.8), m['dark']))
        p.append(box('ArchTrim', (3.8, 0.15, 0.5), (0, -WALL_T / 2 - 2.05, 5.9), m['trim']))
        for z in (9.0, 14.0):
            p.append(box('Band', (S + 0.3, WALL_T + 4.3, 0.45), (0, 0, z), m['trim']))
        p.append(box('Tier2', (S - 2.4, WALL_T + 1.6, 4.0), (0, 0, 16.2), m['wall']))
        p.append(cyl('Clock', 1.1, 0.2, (0, -(WALL_T + 1.6) / 2 - 0.08, 16.4), m['trim'], axis='Y', verts=16))
        p.append(box('Tier3', (S - 4.2, WALL_T - 0.2, 3.0), (0, 0, 19.7), m['trim']))
        p.append(pyramid('Tent', S - 3.6, WALL_T + 0.4, 6.5, (0, 0, 21.2), m['roof'], 0.3))
        p.append(cyl('Spire', 0.1, 3.0, (0, 0, 29.0), m['gold'], axis='Z', verts=6))
        p.append(dome('Star', 0.5, (0, 0, 30.4), m['team'], 1.2))
        p += merl_swallow(m['wall'], -S / 2, S / 2, -(WALL_T + 4) / 2 + 0.3, 14.0 - 0.1)
        p += door()
    elif STYLE == 'yevropa':
        for sx in (-1, 1):
            p.append(cyl('GT', 2.8, 11.0, (sx * 3.6, -1.0, 5.5), m['wall'], axis='Z', verts=16, r2=2.6))
            p.append(cyl('Corbel', 3.0, 0.7, (sx * 3.6, -1.0, 10.8), m['wall2'], axis='Z', verts=16, r2=3.1))
            p += merl_ring_style(m['wall'], 2.9, 11.1, 10, cx=sx * 3.6, cy=-1.0)
            p.append(cyl('Cone', 3.1, 5.0, (sx * 3.6, -1.0, 14.6), m['roof'], axis='Z', verts=16, r2=0.12))
        p.append(box('Arch', (4.6, WALL_T + 1.0, 4.0), (0, 0, 7.0), m['wall']))
        p.append(box('Portcullis', (2.6, 0.15, 4.8), (0, -WALL_T / 2 - 0.55, 2.4), m['iron']))
        for k in range(5):
            p.append(box('Bar', (0.08, 0.2, 4.8), (-1.1 + k * 0.55, -WALL_T / 2 - 0.6, 2.4), m['iron']))
        p.append(box('Walk', (L - 1, WALL_T - 0.9, 0.12), (0, 0, 9.06), m['wood']))
        p += merl_rect(m['wall'], -1.8, 1.8, -WALL_T / 2 - 0.25, 9.0)
    elif STYLE == 'xitoy':
        p.append(hull_points('Block', [(a * 6.2, b * (WALL_T / 2 + 2.6), 0) for a in (-1, 1) for b in (-1, 1)] +
                             [(a * 5.6, b * (WALL_T / 2 + 2.0), 9.0) for a in (-1, 1) for b in (-1, 1)], m['wall']))
        p.append(box('Tunnel', (3.2, 0.2, 5.4), (0, -WALL_T / 2 - 2.3, 2.7), m['dark']))
        p.append(dome('TunnelTop', 1.6, (0, -WALL_T / 2 - 2.32, 5.3), m['dark'], 0.6))
        p += door()
        for o in pavilion(m, 9.0, 4.6, 9.0, 3.4, 2):
            p.append(o)
    elif STYLE == 'arab':
        for sx in (-1, 1):
            p.append(box('GT', (4.0, WALL_T + 3.0, 11.5), (sx * 3.8, -0.6, 5.75), m['wall']))
            p += merl_step(m['wall'], sx * 3.8 - 2.0, sx * 3.8 + 2.0, -WALL_T / 2 - 1.8, 11.5)
        p.append(box('Arch', (3.6, WALL_T + 1.6, 3.0), (0, -0.2, 8.2), m['wall2']))
        p.append(hull_points('Pointed', [(-1.6, -WALL_T / 2 - 1.05, 5.4), (1.6, -WALL_T / 2 - 1.05, 5.4), (0, -WALL_T / 2 - 1.05, 7.2),
                                         (-1.6, -WALL_T / 2 - 0.9, 5.4), (1.6, -WALL_T / 2 - 0.9, 5.4), (0, -WALL_T / 2 - 0.9, 7.2)], m['dark']))
        p += door()
        p += merl_step(m['wall'], -1.8, 1.8, -WALL_T / 2 - 0.6, 9.7)
    elif STYLE == 'bastion':
        # klassik darvoza: g'isht portal, oq toshli pilyastrlar va uchburchak frontonli
        p.append(box('Body', (9.0, WALL_T + 2.0, 8.4), (0, 0, 4.2), m['wall']))
        p.append(box('Arch', (3.2, 0.2, 5.4), (0, -WALL_T / 2 - 1.02, 2.7), m['dark']))
        for sx in (-1, 1):
            for k in (1.0, 3.2):
                p.append(box('Pilaster', (0.6, 0.3, 7.4), (sx * k, -WALL_T / 2 - 1.1, 4.0), m['trim']))
        p.append(box('Entab', (9.4, WALL_T + 2.4, 0.6), (0, 0, 8.7), m['trim']))
        p.append(hull_points('Pediment', [(-4.0, -WALL_T / 2 - 1.2, 9.0), (4.0, -WALL_T / 2 - 1.2, 9.0), (0, -WALL_T / 2 - 1.2, 11.2),
                                          (-4.0, -WALL_T / 2 - 0.4, 9.0), (4.0, -WALL_T / 2 - 0.4, 9.0), (0, -WALL_T / 2 - 0.4, 11.2)], m['trim']))
        p.append(dome('Emblem', 0.6, (0, -WALL_T / 2 - 1.25, 9.8), m['roof2'], 0.3))
        p += door()
        p.append(cyl('Pole', 0.07, 4.0, (0, 0.6, 11.0), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (1.6, 0.05, 1.0), (0.85, 0.6, 12.4), m['team']))
    join('Gate', p, origin=(0, 0, 0))
    exp('gate')


# ============================================================== ARK

def keep():
    clear(); m = M()
    p = []
    if STYLE == 'rus':
        # oq tosh sobor: 5 ta oltin piyoz gumbaz + qo'ng'iroqxona
        p.append(box('Plinth', (17, 15, 1.4), (0, 0, 0.7), m['base']))
        p.append(box('Body', (15, 13, 10), (0, 0, 6.4), m['trim']))
        for sx in (-1, 0, 1):
            p.append(cyl('Zakomara', 2.4, 0.4, (sx * 5.0, -6.5, 11.4), m['trim'], axis='Y', verts=16))
            p.append(box('Window', (0.8, 0.2, 2.2), (sx * 5.0, -6.55, 7.0), m['dark']))
        p.append(box('Portal', (3.0, 0.6, 4.4), (0, -6.8, 3.6), m['wall2']))
        p.append(box('Door', (1.8, 0.2, 3.2), (0, -7.15, 3.0), m['wood']))
        p.append(box('Roof', (15.2, 13.2, 0.6), (0, 0, 11.7), m['roof']))
        for (x, y, r, h) in [(0, 0, 2.2, 5.0), (-4.2, -3.6, 1.4, 3.4), (4.2, -3.6, 1.4, 3.4), (-4.2, 3.6, 1.4, 3.4), (4.2, 3.6, 1.4, 3.4)]:
            p.append(cyl('Drum', r, h, (x, y, 12.0 + h / 2), m['trim'], axis='Z', verts=16))
            p.append(onion('Onion', r * 1.25, (x, y, 12.0 + h + r * 0.5), m['gold'], r * 2.2))
            p.append(cyl('Cross', 0.08, 1.6, (x, y, 12.0 + h + r * 3.0 + 0.6), m['gold'], axis='Z', verts=4))
        # qo'ng'iroqxona
        p.append(box('Bell1', (4.0, 4.0, 14), (10.0, 4.0, 7.0), m['trim']))
        p.append(box('Bell2', (3.2, 3.2, 4), (10.0, 4.0, 16.0), m['trim']))
        p.append(box('BellOpen', (3.3, 2.0, 2.4), (10.0, 4.0, 16.0), m['dark']))
        p.append(onion('BellOnion', 1.7, (10.0, 4.0, 18.6), m['gold'], 3.2))
        p.append(cyl('Pole', 0.1, 5.0, (-6, 5, 14.5), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (2.4, 0.05, 1.5), (-4.75, 5, 16.3), m['team']))
    elif STYLE == 'yevropa':
        S = 15.0; H = 17.0
        p.append(box('Base', (S + 1.4, S + 1.4, 2.0), (0, 0, 1.0), m['base']))
        p.append(box('Body', (S, S, H - 2), (0, 0, 2 + (H - 2) / 2), m['wall']))
        for s in (-1, 1):
            p += merl_rect(m['wall'], -S / 2, S / 2, s * (S / 2 - 0.27), H)
            p += [box('Mx', (0.5, 0.8, 1.1), (s * (S / 2 - 0.27), -S / 2 + 1.4 + k * 1.4, H + 0.55), m['wall']) for k in range(int(S / 1.4) - 1)]
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(cyl('Turret', 2.0, H + 4, (sx * S / 2, sy * S / 2, (H + 4) / 2), m['wall'], axis='Z', verts=14))
                p.append(cyl('TCone', 2.4, 4.5, (sx * S / 2, sy * S / 2, H + 4 + 2.25), m['roof'], axis='Z', verts=14, r2=0.1))
        p.append(box('Hall', (8, 8, 4), (0, 0, H + 2), m['wall2']))
        p.append(hull_points('HallRoof', [(a * 4.4, b * 4.4, H + 4) for a in (-1, 1) for b in (-1, 1)] + [(a * 4.4, 0, H + 8) for a in (-1, 1)], m['roof']))
        for k in range(3):
            p.append(box('Window', (0.6, 0.2, 1.6), (-4 + k * 4, -S / 2 - 0.05, 11), m['dark']))
        p.append(box('Door', (2.4, 0.3, 3.6), (0, -S / 2 - 0.1, 3.8), m['wood']))
        p.append(box('Stair', (3.0, 3.0, 2.0), (0, -S / 2 - 1.6, 1.0), m['base']))
        p.append(cyl('Pole', 0.1, 6.0, (0, 0, H + 11.0), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (2.6, 0.05, 1.6), (1.35, 0, H + 13.0), m['team']))
    elif STYLE == 'xitoy':
        # baland supa ustida saroy zali: qizil ustunlar, ikki qavatli sariq tom
        p.append(hull_points('Terrace', [(a * 12, b * 10, 0) for a in (-1, 1) for b in (-1, 1)] + [(a * 11, b * 9, 3.0) for a in (-1, 1) for b in (-1, 1)], m['wall']))
        p.append(box('Balustrade', (22.4, 18.4, 0.6), (0, 0, 3.3), m['trim']))
        p.append(box('Stair', (5.0, 4.0, 1.6), (0, -10.5, 0.8), m['base']))
        p.append(box('HallCore', (14, 9, 6.0), (0, 0, 6.0), m['trim']))
        p += pavilion(m, 17.0, 11.0, 3.0, 6.0, 2, 'roof2')
    elif STYLE == 'arab':
        S = 16.0; H = 12.0
        p.append(box('Body', (S, S, H), (0, 0, H / 2), m['wall']))
        for s in (-1, 1):
            p += merl_step(m['wall'], -S / 2, S / 2, s * (S / 2 - 0.27), H)
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(cyl('CT', 2.3, H + 2.5, (sx * S / 2, sy * S / 2, (H + 2.5) / 2), m['wall'], axis='Z', verts=14, r2=2.0))
                p += merl_ring_style(m['wall'], 1.8, H + 2.5, 8, cx=sx * S / 2, cy=sy * S / 2)
        p.append(box('Hall', (8, 8, 3), (2, 2, H + 1.5), m['wall2']))
        p.append(dome('Dome', 3.4, (2, 2, H + 3.0), m['roof'], 1.0))
        p.append(cyl('Minaret', 1.0, 12.0, (-4.5, 4.5, H + 6.0), m['trim'], axis='Z', verts=12, r2=0.8))
        p.append(cyl('Balc', 1.4, 0.4, (-4.5, 4.5, H + 10.5), m['wall2'], axis='Z', verts=12))
        p.append(dome('MinDome', 0.8, (-4.5, 4.5, H + 12.0), m['roof2'], 1.4))
        p.append(hull_points('Door', [(-1.4, -S / 2 - 0.1, 0), (1.4, -S / 2 - 0.1, 0), (-1.4, -S / 2 - 0.1, 3.2), (1.4, -S / 2 - 0.1, 3.2), (0, -S / 2 - 0.1, 4.6),
                                      (-1.4, -S / 2 + 0.1, 0), (1.4, -S / 2 + 0.1, 0), (-1.4, -S / 2 + 0.1, 3.2), (1.4, -S / 2 + 0.1, 3.2), (0, -S / 2 + 0.1, 4.6)], m['wood']))
        p.append(cyl('Pole', 0.1, 5.0, (5, -5, H + 2.5), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (2.4, 0.05, 1.5), (6.25, -5, H + 4.3), m['team']))
    elif STYLE == 'bastion':
        # neoklassik komendatura: sariq bino, oq ustunli portik, yashil tom
        yel = mat('Yellow', '#d8b860', 0.85)
        p.append(box('Plinth', (22, 13, 1.0), (0, 0, 0.5), m['base']))
        p.append(box('Body', (20, 11, 9), (0, 0, 5.5), yel))
        for k in range(7):
            for z in (3.8, 7.6):
                p.append(box('Win', (1.0, 0.2, 1.8), (-8.4 + k * 2.8, -5.55, z), m['dark']))
        p.append(box('Portico', (8.6, 3.0, 0.6), (0, -6.8, 1.2), m['trim']))
        for k in range(6):
            p.append(cyl('Column', 0.35, 7.6, (-3.6 + k * 1.44, -7.6, 5.0), m['trim'], axis='Z', verts=10))
        p.append(box('Entab', (8.8, 3.4, 0.8), (0, -7.0, 9.2), m['trim']))
        p.append(hull_points('Pediment', [(-4.4, -8.6, 9.6), (4.4, -8.6, 9.6), (0, -8.6, 11.8), (-4.4, -5.4, 9.6), (4.4, -5.4, 9.6), (0, -5.4, 11.8)], m['trim']))
        p.append(hull_points('Roof', [(a * 10.4, b * 5.8, 10) for a in (-1, 1) for b in (-1, 1)] + [(a * 8.0, 0, 13.0) for a in (-1, 1)], m['roof']))
        p.append(cyl('Lantern', 1.4, 2.0, (0, 0, 13.6), m['trim'], axis='Z', verts=12))
        p.append(dome('LDome', 1.5, (0, 0, 14.6), m['roof'], 1.1))
        p.append(cyl('Pole', 0.1, 6.0, (0, 0, 19.0), m['wood2'], axis='Z', verts=6))
        p.append(box('Flag', (2.6, 0.05, 1.6), (1.35, 0, 21.2), m['team']))
    join('Keep', p, origin=(0, 0, 0))
    exp('keep')


wall(); tower(); gate(); keep()

if PREVIEW:
    clear()
    for i, n in enumerate(['wall', 'tower', 'gate', 'keep']):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location = (i * 20 - 30, 0, 0)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 700
    cd = bpy.data.cameras.new('C'); cd.lens = 35
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (5, -75, 32)
    cam.rotation_euler = (Vector((0, 0, 8)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_%s.png' % STYLE)
    bpy.ops.render.render(write_still=True)
print('CC DONE', STYLE)
