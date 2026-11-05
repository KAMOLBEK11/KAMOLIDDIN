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


def M():
    return {'wood': mat('Wood', '#7a5434', 0.85), 'wood2': mat('WoodDark', '#4a3220', 0.85), 'iron': mat('Iron', '#2e2e32', 0.45, 0.75),
            'rope': mat('Rope', '#c8b48a', 0.95), 'hide': mat('Hide', '#8a6a4a', 0.95), 'bronze': mat('Bronze', '#8a6a3a', 0.35, 0.8),
            'team': mat('TeamColor', '#2f7d4a', 0.7), 'stone': mat('Stone', '#8a8278', 0.95)}


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


def trebuchet():
    clear(); m = M()
    p = []
    # rama (shassi) va g'ildiraklar
    for y in (-1.3, 1.3):
        p.append(box('Rail', (5.2, 0.35, 0.35), (0, y, 0.7), m['wood']))
    for x in (-2.2, 0, 2.2):
        p.append(box('Cross', (0.35, 2.9, 0.3), (x, 0, 0.7), m['wood']))
    for x in (-1.8, 1.8):
        for y in (-1.45, 1.45):
            p += wheel('W', 0.55, (x, y * 1.08, 0.55), m)
    # A-shaklidagi ustunlar
    for y in (-1.2, 1.2):
        p.append(beam('Leg1', (-2.0, y, 0.8), (0.3, y, 5.6), 0.3, m['wood']))
        p.append(beam('Leg2', (2.4, y, 0.8), (0.3, y, 5.6), 0.3, m['wood']))
        p.append(beam('Brace', (-1.1, y, 2.8), (1.4, y, 2.8), 0.22, m['wood2']))
    p.append(cyl('Axle', 0.12, 2.8, (0.3, 0, 5.6), m['iron'], axis='Y', verts=10))
    # yelka: orqa (-X) uchida sopqon, old (+X) uchida yuk qutisi
    arm = [box('Beam', (8.0, 0.3, 0.3), (0.3 - 2.0, 0, 5.6), m['wood2'])]
    arm.append(box('CW', (1.3, 1.5, 1.4), (0.3 + 1.8, 0, 5.6 - 1.0), m['wood']))
    arm.append(box('CWStone', (1.2, 1.3, 0.5), (0.3 + 1.8, 0, 5.6 - 0.45), m['stone']))
    for z in (-0.6, 0.6):
        arm.append(beam('CWHang', (0.3 + 1.8, z, 5.6), (0.3 + 1.8, z, 5.6 - 0.35), 0.1, m['iron']))
    arm.append(beam('Sling', (0.3 - 6.0, 0, 5.6), (0.3 - 6.0, 0, 5.6 - 1.4), 0.04, m['rope']))
    arm.append(cyl('Pouch', 0.32, 0.4, (0.3 - 6.0, 0, 5.6 - 1.55), m['hide'], axis='Y', verts=8))
    for k in range(4):
        arm.append(cyl('Band', 0.2, 0.12, (0.3 - 4.8 + k * 1.6, 0, 5.6), m['iron'], axis='X', verts=8))
    # Blender Y o'qi = Godot -Z: Godot'da rotation.z = +35 (yuk tepada, sopqon pastda orqada)
    export_named(os.path.join(OUT, 'manjaniq'), p, {'Arm': ((0.3, 0, 5.6), arm, (0, math.radians(-35), 0))})


def ram():
    clear(); m = M()
    p = []
    for y in (-1.0, 1.0):
        p.append(box('Rail', (5.4, 0.3, 0.3), (0, y, 0.75), m['wood']))
    for x in (-2.0, 2.0):
        for y in (-1.15, 1.15):
            p += wheel('W', 0.6, (x, y, 0.6), m)
    for x in (-2.4, -0.8, 0.8, 2.4):
        for y in (-1.05, 1.05):
            p.append(box('Post', (0.22, 0.22, 2.9), (x, y, 2.2), m['wood']))
    # ho'l teri bilan qoplangan tomi (o't o'tmasligi uchun)
    for s in (-1, 1):
        p.append(box('Roof', (5.8, 1.7, 0.14), (0, s * 0.7, 3.95), m['hide'], (s * math.radians(35), 0, 0)))
        for k in range(5):
            p.append(box('Seam', (0.05, 1.72, 0.17), (-2.4 + k * 1.2, s * 0.7, 3.96), m['wood2'], (s * math.radians(35), 0, 0)))
    p.append(box('Ridge', (5.9, 0.25, 0.25), (0, 0, 4.45), m['wood2']))
    for x in (-1.2, 1.2):
        p.append(beam('Chain', (x, 0, 3.6), (x, 0, 1.9), 0.06, m['iron']))
    log = [cyl('Ram', 0.3, 6.4, (0.8, 0, 1.9), m['wood2'], axis='X', verts=12)]
    log.append(cone('Head', 0.4, 0.15, 0.8, (0.8 + 3.4, 0, 1.9), m['iron'], verts=8) if 'cone' in globals() else cyl('Head', 0.4, 0.8, (0.8 + 3.4, 0, 1.9), m['iron'], axis='X', verts=8, r2=0.15))
    export_named(os.path.join(OUT, 'taran'), p, {'Log': ((0.8, 0, 1.9), log, (0, 0, 0))})


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


trebuchet(); ram(); cannon()
if PREVIEW:
    clear()
    for i, n in enumerate(['manjaniq', 'taran', 'top']):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location.x += i * 10 - 10
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 1200, 600
    cd = bpy.data.cameras.new('C'); cd.lens = 35
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (2, -24, 9)
    cam.rotation_euler = (Vector((0, 0, 2.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_engines.png')
    bpy.ops.render.render(write_still=True)
print('SE DONE')
