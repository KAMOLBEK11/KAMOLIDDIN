"""Qo'shimcha zamonaviy modellar va xarita rasmlari.
blender -b -P assets2.py -- <game_papka>
 - models/buildings/post.glb      chegara posti (minora, shlagbaum, beton bloklar, bayroq)
 - models/units/truck.glb         zamonaviy yuk mashinasi
 - models/units/car.glb           yengil avtomobil (SUV)
 - models/units/airliner.glb      yo'lovchi samolyoti
 - models/units/missile.glb       ballistik raketa
 - pics/buildings/<nom>.png       binolar uchun zamonaviy ikonka-rasmlar (3/4 ko'rinish)
 - pics/sprites/top_<nom>.png     samolyot/raketa - tepadan ko'rinish (xaritada uchishi uchun)
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

game = sys.argv[sys.argv.index('--') + 1]
tmp = '/home/claude/work/assets2_out'
os.makedirs(tmp, exist_ok=True)
os.makedirs(os.path.join(game, 'pics/buildings'), exist_ok=True)
os.makedirs(os.path.join(game, 'pics/sprites'), exist_ok=True)


def exp(sub, name):
    p = os.path.join(tmp, name)
    export(p)
    import shutil
    shutil.copy(p + '.glb', os.path.join(game, 'models', sub, name + '.glb'))


def wheels(m, xs, half_w, r, z=None, width=0.35):
    out = []
    for x in xs:
        for s in (-1, 1):
            out.append(cyl('Wheel', r, width, (x, s * half_w, r if z is None else z), m, axis='Y', verts=14))
    return out


# ---------------------------------------------------------------- chegara posti
def post():
    clear()
    conc = mat('Concrete', '#8a8a83', 0.9)
    dark = mat('Dark', '#2f3236', 0.6)
    glass = mat('Glass', '#3f6f96', 0.1, 0.3)
    stripe = mat('Stripe', '#d23a2a', 0.6)
    white = mat('White', '#e6e6e0', 0.6)
    green = mat('Olive', '#56643a', 0.8)
    team = mat('TeamColor', '#e8b73a', 0.5)
    p = [box('Pad', (34, 22, 0.3), (0, 0, 0.15), mat('Asphalt', '#45474a', 0.95))]
    # kuzatuv minorasi
    for x in (-1.6, 1.6):
        for y in (-1.6, 1.6):
            p.append(box('Leg', (0.4, 0.4, 11), (8 + x, 6 + y, 5.5), dark))
    p.append(box('Cab', (5, 5, 3), (8, 6, 12.5), white))
    p.append(box('Win', (5.1, 5.1, 1.2), (8, 6, 12.8), glass))
    p.append(box('Roof', (6, 6, 0.4), (8, 6, 14.2), dark))
    # nazorat binosi
    p.append(box('Office', (10, 6, 4), (-8, 6, 2.3), white))
    p.append(box('OfficeWin', (10.1, 6.1, 1.2), (-8, 6, 2.8), glass))
    p.append(box('Canopy', (16, 10, 0.5), (0, -3, 6), white))
    for x in (-7, 7):
        p.append(box('Pillar', (0.6, 0.6, 5.8), (x, -3, 3), dark))
    # shlagbaum
    p.append(box('BarPost', (0.6, 0.6, 1.4), (-5, -10, 0.9), dark))
    for i in range(6):
        p.append(box('Bar', (1.4, 0.18, 0.18), (-4.0 + i * 1.4, -10, 1.4), stripe if i % 2 == 0 else white))
    # beton bloklar va qum qoplari
    for i in range(7):
        p.append(hull_points('Block', [(x, y, z) for x in (-0.9, 0.9) for y in (-0.4, 0.4) for z in (0, 1.1)] +
                             [(0, 0, 1.3)], conc, loc=(-15 + i * 2.2, -8.5, 0.3)))
    for i in range(5):
        p.append(box('Bag', (1.1, 0.6, 0.45), (12 - i * 1.15, -7, 0.55 + (i % 2) * 0.05), green))
        p.append(box('Bag', (1.1, 0.6, 0.45), (12.5 - i * 1.15, -7, 1.0), green))
    pole = cyl('Pole', 0.1, 10, (-14, 8, 5), dark, axis='Z', verts=8)
    flag = box('TeamColor', (2.4, 0.05, 1.5), (-12.7, 8, 9.2), team)
    p += [pole, flag]
    join('Post', p, origin=(0, 0, 0))
    exp('buildings', 'post')


# ---------------------------------------------------------------- zamonaviy yuk mashinasi
def truck():
    clear()
    body = mat('TruckBody', '#e7e5df', 0.5)
    cab = mat('Cab', '#2f5d8a', 0.35, 0.3)
    dark = mat('Tyre', '#1d1e20', 0.9)
    glass = mat('Glass', '#16222e', 0.05, 0.4)
    chrome = mat('Chrome', '#c9ccd0', 0.2, 0.9)
    p = []
    p.append(hull_points('Cab', [(2.4, -1.25, 0.9), (2.4, 1.25, 0.9), (4.2, -1.25, 0.9), (4.2, 1.25, 0.9),
                                 (2.4, -1.2, 3.4), (2.4, 1.2, 3.4), (3.9, -1.15, 3.3), (3.9, 1.15, 3.3), (4.3, -1.2, 1.8), (4.3, 1.2, 1.8)], cab))
    p.append(hull_points('Windshield', [(4.0, -1.1, 2.0), (4.0, 1.1, 2.0), (3.85, -1.08, 3.15), (3.85, 1.08, 3.15),
                                        (4.06, -1.1, 2.0), (3.91, 1.08, 3.15)], glass))
    p.append(box('Grille', (0.08, 1.8, 0.7), (4.32, 0, 1.3), chrome))
    p.append(box('Box', (6.6, 2.5, 2.8), (-1.3, 0, 2.3), body))
    p.append(box('Chassis', (8.8, 1.6, 0.4), (0, 0, 0.75), dark))
    p += wheels(dark, (3.2, -2.0, -3.4), 1.15, 0.55)
    for s in (-1, 1):
        p.append(box('Mirror', (0.1, 0.25, 0.5), (3.9, s * 1.45, 2.6), dark))
        p.append(box('Lamp', (0.06, 0.4, 0.2), (4.33, s * 0.95, 1.1), mat('Lamp', '#fff6d0', 0.3, 0, 2.0)))
    join('Truck', p, origin=(0, 0, 0))
    exp('units', 'truck')


def car():
    clear()
    body = mat('CarBody', '#1f2328', 0.25, 0.6)
    glass = mat('Glass', '#16222e', 0.05, 0.4)
    dark = mat('Tyre', '#151515', 0.9)
    p = []
    p.append(hull_points('Body', [(x, y, z) for x in (-2.3, 2.3) for y in (-0.95, 0.95) for z in (0.35, 1.05)] +
                         [(2.45, -0.8, 0.7), (2.45, 0.8, 0.7)], body))
    p.append(hull_points('Top', [(1.2, -0.85, 1.05), (1.2, 0.85, 1.05), (-1.9, -0.85, 1.05), (-1.9, 0.85, 1.05),
                                 (0.5, -0.75, 1.75), (0.5, 0.75, 1.75), (-1.7, -0.75, 1.75), (-1.7, 0.75, 1.75)], glass))
    p += wheels(dark, (1.5, -1.5), 0.85, 0.38, width=0.28)
    join('Car', p, origin=(0, 0, 0))
    exp('units', 'car')


def airliner():
    clear()
    w = mat('Fuselage', '#f2f2ee', 0.4, 0.1)
    grey = mat('Wing', '#c7ccd2', 0.4, 0.3)
    team = mat('TeamColor', '#e8b73a', 0.5)
    glass = mat('Glass', '#1b2733', 0.1, 0.4)
    eng = mat('Engine', '#9aa0a6', 0.35, 0.5)
    p = []
    pts = []
    for x, r in ((17, 0.1), (16.2, 0.9), (14.5, 1.9), (11, 2.1), (-10, 2.1), (-14, 1.6), (-17, 0.6)):
        for k in range(14):
            a = k / 14 * math.tau
            pts.append((x, math.cos(a) * r, 3.0 + math.sin(a) * r + (0.8 if x < -12 else 0)))
    p.append(hull_points('Fus', pts, w))
    p.append(box('Cockpit', (1.2, 1.4, 0.5), (15.6, 0, 3.9), glass))
    for s in (-1, 1):
        p.append(hull_points('Wing', [(3, s * 1.8, 2.4), (-4, s * 1.8, 2.4), (-9, s * 17, 3.2), (-6.8, s * 17, 3.2),
                                      (3, s * 1.8, 2.7), (-4, s * 1.8, 2.7)], grey))
        p.append(cyl('Engine', 1.0, 3.6, (0.5, s * 6.5, 1.6), eng, axis='X', verts=14))
        p.append(hull_points('Stab', [(-13.5, s * 1, 4.4), (-16.5, s * 1, 4.4), (-17.5, s * 6.5, 4.8), (-16, s * 6.5, 4.8),
                                      (-13.5, s * 1, 4.6), (-16.5, s * 1, 4.6)], grey))
    p.append(hull_points('Fin', [(-12.5, -0.15, 4.5), (-12.5, 0.15, 4.5), (-17, -0.15, 4.5), (-17, 0.15, 4.5),
                                 (-16.5, -0.1, 10.5), (-16.5, 0.1, 10.5), (-18.3, -0.1, 10.5), (-18.3, 0.1, 10.5)], team))
    join('Airliner', p, origin=(0, 0, 0))
    exp('units', 'airliner')


def missile():
    clear()
    w = mat('MissileBody', '#e3e3dd', 0.4)
    r = mat('Nose', '#b83a2e', 0.5)
    d = mat('Fins', '#3a3d40', 0.6)
    p = [cyl('Body', 0.55, 11, (0, 0, 0), w, axis='X', verts=16),
         cyl('Nose', 0.55, 2.4, (6.7, 0, 0), r, axis='X', verts=16, r2=0.02),
         cyl('Nozzle', 0.45, 0.6, (-5.8, 0, 0), d, axis='X', verts=12, r2=0.55)]
    for a in range(4):
        ang = a * math.pi / 2
        p.append(hull_points('Fin', [(-5.4, 0, 0), (-3.4, 0, 0), (-5.6, math.cos(ang) * 1.6, math.sin(ang) * 1.6),
                                     (-4.8, math.cos(ang) * 1.6, math.sin(ang) * 1.6),
                                     (-5.4, math.sin(ang) * 0.05, -math.cos(ang) * 0.05)], d))
    join('Missile', p, origin=(0, 0, 0))
    exp('units', 'missile')


# ---------------------------------------------------------------- rasm chizish
def cam_render(path, res, ortho, target, el_deg, az_deg, sun=True):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 40
    sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    w = bpy.data.worlds.new('W'); w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.6, 0.66, 0.75, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.9
    sc.world = w
    if sun:
        ld = bpy.data.lights.new('Sun', 'SUN'); ld.energy = 3.5; ld.angle = 0.25
        lo = bpy.data.objects.new('Sun', ld); lo.rotation_euler = (math.radians(42), math.radians(8), math.radians(-35))
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new('Cam'); cd.type = 'ORTHO'; cd.ortho_scale = ortho
    cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    el, az = math.radians(el_deg), math.radians(az_deg)
    t = Vector(target)
    cam.location = t + Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el))) * 300
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_end = 1000
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def bounds():
    mn = Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            for c in o.bound_box:
                v = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, v)); mx = Vector(map(max, mx, v))
    return mn, mx


def paint_team():
    for m in bpy.data.materials:
        if m.name.startswith('TeamColor') and m.node_tree:
            b = m.node_tree.nodes.get('Principled BSDF')
            if b:
                b.inputs['Base Color'].default_value = (0.85, 0.55, 0.08, 1)


post(); truck(); car(); airliner(); missile()

# binolar ikonkalari (3/4 ko'rinish)
bnames = ['hq', 'politic', 'civil', 'mine', 'military', 'lab_civ', 'lab_mil', 'airbase', 'airport', 'barracks', 'depot', 'shipyard', 'post']
for n in bnames:
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(game, 'models/buildings', n + '.glb'))
    paint_team()
    mn, mx = bounds()
    size = max(mx.x - mn.x, mx.y - mn.y) * 1.15
    cam_render(os.path.join(game, 'pics/buildings', n + '.png'), 160, size, ((mn + mx) / 2).to_tuple(), 40, -60)

# tepadan ko'rinish: samolyotlar va raketa (+X - oldinga)
for src, dst in (('units/jet', 'top_jet'), ('units/airliner', 'top_airliner'), ('units/missile', 'top_missile')):
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(game, 'models', src + '.glb'))
    paint_team()
    mn, mx = bounds()
    size = max(mx.x - mn.x, mx.y - mn.y) * 1.05
    c = (mn + mx) / 2
    cam_render(os.path.join(game, 'pics/sprites', dst + '.png'), 128, size, c.to_tuple(), 89.9, -90)
print('ASSETS2 DONE')
