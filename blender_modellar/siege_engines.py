"""Qamal qurollari: manjaniq (qarshi yukli trebushet, 1400), taran (yopiq g'ildirakli), to'p (1860-yillar, bronza, lafetli).
blender -b -P siege_engines.py -- <chiqish_papka> [preview]
Godot kodida nomlari bo'yicha harakatlantiriladi: 'Arm' (manjaniq yelkasi, Y o'qi atrofida aylanadi),
'Log' (taran xodasi, X bo'ylab siltanadi), 'Barrel' (to'p stvoli, orqaga tepadi). Hammasi +X ga qaragan.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/se_out'
PREVIEW = 'preview' in ARGS
os.makedirs(OUT, exist_ok=True)


STY = {   # yog'och, to'q yog'och, tom qoplamasi, bezak rangi
    'isl': ('#7a5434', '#4a3220', '#8a6a4a', '#1f4e8c'),
    'rus': ('#6e5238', '#3e2a1a', '#5a4632', '#9a2a24'),
    'yevropa': ('#6a5a48', '#3a3028', '#4b5260', '#c9a03a'),
    'xitoy': ('#6a3a22', '#3a2014', '#9a2a22', '#c9a03a'),
    'arab': ('#9a7a52', '#5e4630', '#c8a85a', '#2f6b4a'),
}


def M(style='isl'):
    w, w2, rf, tr = STY[style]
    return {'wood': mat('Wood_' + style, w, 0.85), 'wood2': mat('WoodDark_' + style, w2, 0.85), 'iron': mat('Iron', '#2e2e32', 0.45, 0.75),
            'rope': mat('Rope', '#c8b48a', 0.95), 'hide': mat('Hide_' + style, rf, 0.95), 'bronze': mat('Bronze', '#8a6a3a', 0.35, 0.8),
            'team': mat('TeamColor', '#2f7d4a', 0.7), 'stone': mat('Stone', '#8a8278', 0.95), 'trim': mat('Trim_' + style, tr, 0.6)}


def beam(name, a, b, t, m):
    """a->b to'rtburchak to'sin"""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    ob = box(name, (L, t, t), (0, 0, 0), m)
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((1, 0, 0)).rotation_difference(d.normalized())
    ob.location = (a + b) / 2
    return ob


def wheel(name, r, loc, m, width=0.22, spokes=8):
    out = [cyl(name + 'Rim', r, width, loc, m['wood2'], axis='Y', verts=16)]
    out.append(cyl(name + 'Hub', r * 0.22, width + 0.1, loc, m['iron'], axis='Y', verts=8))
    for k in range(spokes):
        a = k / spokes * math.pi
        out.append(box(name + 'Spoke', (r * 1.9, 0.06, 0.06), loc, m['wood'], (0, a, 0)))
    out.append(cyl(name + 'Tyre', r + 0.03, width * 0.8, loc, m['iron'], axis='Y', verts=16))
    return out


def export_named(path, root_parts, named):
    """root_parts - bitta 'Body' ga birlashtiriladi; named - {'Arm': (pivot, [parts])} alohida obyekt bo'lib qoladi"""
    body = join('Body', root_parts, origin=(0, 0, 0))
    for nm, (pivot, parts, rot) in named.items():
        ob = join(nm, parts, origin=pivot)
        ob.rotation_euler = rot
    export(path)


def trebuchet(style='isl'):
    clear(); m = M(style)
    p = []
    traction = style == 'xitoy'          # xitoycha "pao": qarshi yuk o'rniga ko'p arqonni odamlar tortadi
    for y in (-1.3, 1.3):
        p.append(box('Rail', (5.2, 0.35, 0.35), (0, y, 0.7), m['wood']))
    for x in (-2.2, 0, 2.2):
        p.append(box('Cross', (0.35, 2.9, 0.3), (x, 0, 0.7), m['wood']))
    if style != 'arab':
        for x in (-1.8, 1.8):
            for y in (-1.45, 1.45):
                p += wheel('W', 0.55, (x, y * 1.08, 0.55), m)
    else:
        for x in (-2.4, 2.4):
            p.append(box('Skid', (0.4, 3.2, 0.3), (x, 0, 0.35), m['wood2']))
    H = 4.4 if traction else 5.6
    if style == 'rus':
        # tik minorasimon rama (to'rt ustun) va qizil bezak
        for x in (-0.6, 1.2):
            for y in (-1.2, 1.2):
                p.append(beam('Post', (x, y, 0.8), (0.3, y, H), 0.3, m['wood']))
        for z in (2.2, 3.8):
            p.append(box('Band', (2.2, 2.6, 0.18), (0.3, 0, z), m['trim']))
    else:
        for y in (-1.2, 1.2):
            p.append(beam('Leg1', (-2.0 if not traction else -1.2, y, 0.8), (0.3, y, H), 0.3, m['wood']))
            p.append(beam('Leg2', (2.4 if not traction else 1.8, y, 0.8), (0.3, y, H), 0.3, m['wood']))
            p.append(beam('Brace', (-1.1, y, 2.6), (1.4, y, 2.6), 0.22, m['wood2']))
    if style == 'yevropa':
        p.append(box('Platform', (3.2, 2.8, 0.15), (-2.5, 0, 0.95), m['wood2']))
        for y in (-1.6, 1.6):
            p.append(cyl('Winch', 0.5, 0.3, (-1.6, y, 1.4), m['wood'], axis='Y', verts=10))
    p.append(cyl('Axle', 0.12, 2.8, (0.3, 0, H), m['iron'], axis='Y', verts=10))
    arm = [box('Beam', (8.0 if not traction else 7.0, 0.3, 0.3), (0.3 - 2.0, 0, H), m['wood2'])]
    if traction:
        # qisqa uchida ko'p tortish arqonlari osilib turadi
        for k in range(8):
            yy = -0.7 + k * 0.2
            arm.append(beam('PullRope', (0.3 + 1.4, yy * 0.4, H), (0.3 + 1.6 + (k % 2) * 0.3, yy, 0.6), 0.03, m['rope']))
        arm.append(box('Cap', (0.6, 0.6, 0.4), (0.3 + 1.4, 0, H), m['trim']))
    elif style == 'arab':
        arm.append(cyl('CWSack', 0.85, 1.2, (0.3 + 1.8, 0, H - 1.1), m['hide'], axis='Z', verts=12, r2=0.6))
        arm.append(box('CWNet', (0.12, 0.12, 0.8), (0.3 + 1.8, 0, H - 0.4), m['rope']))
    elif style == 'yevropa':
        # osma (sharnirli) qarshi yuk qutisi
        arm.append(box('CWHinge', (0.5, 0.5, 0.6), (0.3 + 1.8, 0, H - 0.3), m['iron']))
        arm.append(box('CW', (1.6, 1.8, 1.6), (0.3 + 1.8, 0, H - 1.6), m['wood']))
        arm.append(box('CWStone', (1.5, 1.6, 0.4), (0.3 + 1.8, 0, H - 0.85), m['stone']))
    else:
        arm.append(box('CW', (1.3, 1.5, 1.4), (0.3 + 1.8, 0, H - 1.0), m['wood']))
        arm.append(box('CWStone', (1.2, 1.3, 0.5), (0.3 + 1.8, 0, H - 0.45), m['stone']))
        arm.append(box('CWTrim', (1.35, 1.55, 0.18), (0.3 + 1.8, 0, H - 1.5), m['trim']))
    L = 6.0 if not traction else 5.0
    arm.append(beam('Sling', (0.3 - L, 0, H), (0.3 - L, 0, H - 1.4), 0.04, m['rope']))
    arm.append(cyl('Pouch', 0.32, 0.4, (0.3 - L, 0, H - 1.55), m['hide'], axis='Y', verts=8))
    for k in range(4):
        arm.append(cyl('Band', 0.2, 0.12, (0.3 - 4.8 + k * 1.6, 0, H), m['iron'] if style != 'xitoy' else m['trim'], axis='X', verts=8))
    # bayroqcha (xalq belgisi)
    p.append(beam('FlagPole', (-2.2, 1.3, 0.8), (-2.2, 1.3, 4.0), 0.06, m['wood2']))
    p.append(box('Flag', (0.9, 0.04, 0.6), (-1.75, 1.3, 3.65), m['trim']))
    export_named(os.path.join(OUT, 'manjaniq_' + style), p, {'Arm': ((0.3, 0, H), arm, (0, math.radians(-35), 0))})


def ram(style='isl'):
    clear(); m = M(style)
    p = []
    for y in (-1.0, 1.0):
        p.append(box('Rail', (5.4, 0.3, 0.3), (0, y, 0.75), m['wood']))
    for x in (-2.0, 2.0):
        for y in (-1.15, 1.15):
            p += wheel('W', 0.6, (x, y, 0.6), m)
    for x in (-2.4, -0.8, 0.8, 2.4):
        for y in (-1.05, 1.05):
            p.append(box('Post', (0.22, 0.22, 2.9), (x, y, 2.2), m['wood']))
    if style == 'xitoy':
        # "toshbaqa arava": o'tkir uchburchak tom, qizil bo'yalgan, oldi yopiq
        p.append(hull_points('Roof', [(x, y, 3.6) for x in (-2.9, 2.9) for y in (-1.45, 1.45)] + [(x, 0, 5.2) for x in (-2.9, 2.9)], m['hide']))
        p.append(hull_points('Front', [(2.9, y, 3.6) for y in (-1.3, 1.3)] + [(2.9, 0, 5.1), (2.95, 0, 3.6)], m['trim']))
    elif style == 'arab':
        # yassi tom: palma barglari va xurmo novdalari
        p.append(box('Roof', (6.0, 2.9, 0.25), (0, 0, 3.75), m['hide']))
        for k in range(10):
            p.append(box('Frond', (0.25, 3.1, 0.08), (-2.7 + k * 0.6, 0, 3.92), m['wood2']))
    else:
        steep = 48 if style == 'rus' else 35
        h = 0.7 * math.tan(math.radians(steep))
        # ikki qiyalikli tom: o'rtasi (tizma) baland, chetlari past - yomg'ir/o'q pastga sirpanadi
        for sgn in (-1, 1):
            w_ = 0.85 / math.cos(math.radians(steep)) * 1.0
            p.append(box('Roof', (5.8, 1.9 if style == 'rus' else 1.7, 0.14), (0, sgn * 0.7, 3.95 + (h - 0.49) * 0.5), m['hide'], (-sgn * math.radians(steep), 0, 0)))
            for k in range(5):
                p.append(box('Seam', (0.05, 1.9 if style == 'rus' else 1.72, 0.17), (-2.4 + k * 1.2, sgn * 0.7, 3.96 + (h - 0.49) * 0.5), m['wood2'] if style != 'yevropa' else m['iron'], (-sgn * math.radians(steep), 0, 0)))
        p.append(box('Ridge', (5.9, 0.25, 0.25), (0, 0, 3.95 + h * 0.75), m['wood2'] if style != 'rus' else m['trim']))
    for x in (-1.2, 1.2):
        p.append(beam('Chain', (x, 0, 3.6), (x, 0, 1.9), 0.06, m['iron']))
    log = [cyl('Ram', 0.3, 6.4, (0.8, 0, 1.9), m['wood2'], axis='X', verts=12)]
    hx = 0.8 + 3.4
    if style == 'yevropa':
        # qo'chqor boshi shaklidagi temir uch
        log.append(cyl('Head', 0.42, 0.7, (hx, 0, 1.9), m['iron'], axis='X', verts=10))
        for sgn in (-1, 1):
            log.append(cyl('Horn', 0.12, 0.5, (hx - 0.2, sgn * 0.42, 2.1), m['iron'], axis='Y', verts=8))
    elif style == 'rus':
        log.append(cyl('Head', 0.4, 0.8, (hx, 0, 1.9), m['iron'], axis='X', verts=8, r2=0.2))
        log.append(cyl('Ring', 0.34, 0.12, (hx - 0.9, 0, 1.9), m['trim'], axis='X', verts=10))
    else:
        log.append(cyl('Head', 0.4, 0.8, (hx, 0, 1.9), m['iron'], axis='X', verts=8, r2=0.15))
    for k in range(3):
        log.append(cyl('Band', 0.33, 0.1, (0.8 - 2.0 + k * 1.6, 0, 1.9), m['iron'], axis='X', verts=10))
    p.append(beam('FlagPole', (-2.6, 1.1, 3.8), (-2.6, 1.1, 5.6), 0.06, m['wood2']))
    p.append(box('Flag', (0.8, 0.04, 0.55), (-2.2, 1.1, 5.3), m['trim']))
    export_named(os.path.join(OUT, 'taran_' + style), p, {'Log': ((0.8, 0, 1.9), log, (0, 0, 0))})


def cannon():
    clear(); m = M()
    p = []
    # lafet: ikki yon taxta, dumi yerda
    for y in (-0.2, 0.2):
        p.append(beam('Cheek', (0.55, y, 0.95), (-1.9, y, 0.08), 0.16, m['wood']))
    p.append(box('Transom', (0.3, 0.55, 0.2), (-0.6, 0, 0.6), m['wood2']))
    p.append(box('Trail', (0.4, 0.5, 0.12), (-1.9, 0, 0.1), m['iron']))
    p.append(cyl('Axle', 0.07, 1.5, (0.1, 0, 0.62), m['iron'], axis='Y', verts=8))
    for y in (-0.68, 0.68):
        p += wheel('W', 0.62, (0.1, y, 0.62), m, 0.12, 12)
    p.append(box('Box', (0.5, 0.36, 0.3), (-1.2, 0, 0.55), m['wood2']))
    for k in range(4):
        p.append(sph('Ball', 0.09, (-1.85 + (k % 2) * 0.2, 0.55 + (k // 2) * 0.2, 0.09), m['iron']))
    # stvol (bronza, halqali), cascabel va tumshuq
    br = [cyl('Tube', 0.17, 1.9, (0.15 + 0.45, 0, 0.95), m['bronze'], axis='X', verts=16, r2=0.11)]
    br.append(cyl('Breech', 0.2, 0.25, (0.15 - 0.45, 0, 0.95), m['bronze'], axis='X', verts=16))
    br.append(sph('Knob', 0.08, (0.15 - 0.65, 0, 0.95), m['bronze']))
    br.append(cyl('Muzzle', 0.14, 0.14, (0.15 + 1.38, 0, 0.95), m['bronze'], axis='X', verts=16))
    br.append(cyl('Band1', 0.19, 0.08, (0.15 - 0.25, 0, 0.95), m['team'], axis='X', verts=16))
    br.append(cyl('Band2', 0.15, 0.06, (0.15 + 0.6, 0, 0.95), m['bronze'], axis='X', verts=16))
    br.append(cyl('Trunnion', 0.06, 0.5, (0.15, 0, 0.95), m['bronze'], axis='Y', verts=8))
    export_named(os.path.join(OUT, 'top'), p, {'Barrel': ((0.15, 0, 0.95), br, (0, 0, 0))})


def sph(name, r, loc, material):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=r)
    o = _obj_from_bm(name, bm, material)
    o.location = loc
    return o


for st_ in STY:
    trebuchet(st_); ram(st_)
cannon()
if PREVIEW:
    clear()
    for i, n in enumerate(['manjaniq_%s' % x for x in STY] + ['taran_%s' % x for x in STY]):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location.x += (i % 5) * 11 - 22
                o.location.y += (i // 5) * 12
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 1200, 600
    cd = bpy.data.cameras.new('C'); cd.lens = 35
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (2, -40, 22)
    cam.rotation_euler = (Vector((0, 0, 2.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_engines.png')
    bpy.ops.render.render(write_still=True)
print('SE DONE')
