"""Qo'shimcha qurollar (dron, qiruvchi samolyot, artilleriya) va barcha qurollar uchun katalog rasmlari.
blender -b -P weapons.py -- <models_units_papka> <rasm_papka>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

args = sys.argv[sys.argv.index('--') + 1:]
units, pics = args[0], args[1]
os.makedirs(pics, exist_ok=True)


def wing(name, root, tip, span, z, thick, material, sweep=0.0, y0=0.0, side=1, dihedral=0.0):
    """Trapetsiya qanot: root/tip - vatar uzunligi (X bo'ylab)."""
    pts = []
    for (x, yy, zz) in ((0, 0, 0), (-root, 0, 0), (-sweep - tip, span, dihedral), (-sweep, span, dihedral)):
        for dz in (-thick / 2, thick / 2):
            pts.append((x, y0 + side * yy, z + zz + dz * (1.0 if yy == 0 else 0.5)))
    return hull_points(name, pts, material)


def drone():
    clear()
    G = mat('Grey', '#9aa0a4', 0.55)
    D = mat('Dark', '#2b2e31', 0.6)
    GL = mat('Glass', '#1b2733', 0.15, 0.3)
    parts = []
    # fyuzelyaj
    parts.append(hull_points('Body', [(x, y, z) for x in (3.2, -3.0) for y in (-0.38, 0.38) for z in (-0.32, 0.38)] +
                             [(4.0, 0, 0.05), (3.8, 0, 0.42), (-3.8, 0, 0.05)], G))
    parts.append(hull_points('Nose', [(3.2, -0.38, -0.32), (3.2, 0.38, -0.32), (3.2, 0, 0.5), (4.6, 0, 0.05), (4.2, 0, 0.4)], G))
    parts.append(box('Sensor', (0.5, 0.5, 0.45), (2.6, 0, -0.55), D))
    parts.append(hull_points('Ball', [(2.6 + 0.3 * math.cos(a), 0.3 * math.sin(a), -0.85 + z) for a in [i * 0.8 for i in range(8)] for z in (0, 0.25)], GL))
    for s in (-1, 1):
        parts.append(wing('Wing', 1.1, 0.55, 7.5, 0.25, 0.14, G, sweep=0.4, y0=0.35, side=s, dihedral=0.25))
        # V-dum
        parts.append(hull_points('Tail', [(-2.4, s * 0.2, 0.3), (-3.6, s * 0.2, 0.3), (-4.0, s * 1.9, 1.5), (-3.4, s * 1.9, 1.5),
                                          (-2.4, s * 0.25, 0.36), (-3.6, s * 0.25, 0.36)], G))
        # osma raketalar
        parts.append(cyl('Rocket', 0.11, 1.5, (1.1, s * 2.6, -0.15), D, axis='X', verts=8))
        parts.append(box('Pylon', (0.6, 0.06, 0.3), (1.1, s * 2.6, 0.05), G))
    parts.append(cyl('Prop', 0.12, 0.25, (-3.9, 0, 0.2), D, axis='X', verts=8))
    parts.append(box('Blade', (0.05, 1.5, 0.12), (-4.05, 0, 0.2), D))
    for s in (-1, 1):
        parts.append(cyl('Gear', 0.12, 0.08, (-0.2, s * 0.5, -0.75), D, axis='Y', verts=10))
    parts.append(cyl('Gear', 0.12, 0.08, (2.8, 0, -0.95), D, axis='Y', verts=10))
    ob = join('Drone', parts, origin=(0, 0, 0))
    ob.location.z = 1.2


def jet():
    clear()
    G = mat('JetGrey', '#7d868c', 0.45, 0.2)
    D = mat('JetDark', '#3a4046', 0.5)
    GL = mat('Canopy', '#2a3a48', 0.05, 0.4)
    E = mat('Exhaust', '#1a1a1a', 0.4, 0.6)
    T = mat('TeamColor', '#e8b73a', 0.5)
    parts = []
    L = 15.0
    # fyuzelyaj: kesimlar bo'ylab
    secs = [(7.5, 0.05, 0.05, 0.1), (6.0, 0.45, 0.45, 0.15), (3.5, 0.75, 0.75, 0.25), (0.0, 1.05, 0.7, 0.1),
            (-4.0, 1.25, 0.65, 0.0), (-6.5, 0.9, 0.55, 0.05), (-7.5, 0.7, 0.5, 0.05)]
    pts = []
    for x, w, h, zc in secs:
        for k in range(10):
            a = k / 10 * math.tau
            pts.append((x, math.cos(a) * w, zc + math.sin(a) * h * (1.0 if math.sin(a) > 0 else 0.7)))
    parts.append(hull_points('Fuselage', pts, G))
    parts.append(hull_points('Canopy', [(4.8, 0, 0.55), (2.0, -0.45, 0.6), (2.0, 0.45, 0.6), (1.0, 0, 0.7), (3.0, 0, 1.15), (2.0, 0, 1.15),
                                        (4.0, -0.3, 0.6), (4.0, 0.3, 0.6)], GL))
    for s in (-1, 1):
        parts.append(hull_points('Wing', [(2.0, s * 0.8, 0.0), (-4.5, s * 1.0, 0.0), (-5.0, s * 5.5, -0.1), (-3.6, s * 5.5, -0.1),
                                          (2.0, s * 0.8, 0.12), (-4.5, s * 1.0, 0.12)], G))
        parts.append(hull_points('Stab', [(-5.0, s * 1.0, 0.0), (-7.4, s * 1.0, 0.0), (-7.8, s * 3.2, -0.05), (-6.8, s * 3.2, -0.05),
                                          (-5.0, s * 1.0, 0.08), (-7.4, s * 1.0, 0.08)], G))
        parts.append(hull_points('Fin', [(-4.2, s * 0.7, 0.5), (-7.2, s * 0.7, 0.5), (-7.6, s * 1.1, 3.0), (-6.5, s * 1.1, 3.0),
                                         (-4.2, s * 0.62, 0.5), (-7.2, s * 0.62, 0.5)], G))
        parts.append(hull_points('Intake', [(3.0, s * 0.8, -0.5), (3.0, s * 1.4, -0.5), (3.0, s * 0.8, 0.2), (3.0, s * 1.3, 0.2),
                                            (-1.0, s * 0.9, -0.4), (-1.0, s * 1.3, -0.4), (-1.0, s * 0.9, 0.2), (-1.0, s * 1.3, 0.2)], D))
        parts.append(cyl('Nozzle', 0.5, 1.0, (-7.8, s * 0.48, 0.0), E, axis='X', verts=12, r2=0.42))
        parts.append(cyl('Missile', 0.09, 2.4, (-2.5, s * 4.2, -0.35), mat('Missile', '#e0e0e0', 0.4), axis='X', verts=8))
        parts.append(box('TeamFin', (1.0, 0.02, 0.8), (-6.8, s * 1.12, 2.2), T))
    ob = join('Jet', parts, origin=(0, 0, 0))
    ob.location.z = 1.5


def artillery():
    clear()
    G = mat('ArtOlive', '#5f6e3d', 0.75)
    D = mat('ArtDark', '#2a2b28', 0.85)
    M = mat('ArtMetal', '#40433d', 0.5, 0.3)
    parts = []
    # stvol va beshik
    parts.append(cyl('Barrel', 0.12, 6.2, (2.4, 0, 1.75), M, axis='X', verts=12))
    parts.append(cyl('Muzzle', 0.2, 0.5, (5.6, 0, 1.75), M, axis='X', verts=10))
    parts.append(cyl('Recoil', 0.22, 2.2, (0.0, 0, 1.6), G, axis='X', verts=12))
    parts.append(box('Breech', (0.8, 0.6, 0.6), (-0.9, 0, 1.7), G))
    parts.append(box('Shield', (0.12, 2.4, 1.2), (0.9, 0, 1.4), G))
    parts.append(box('Cradle', (1.6, 0.9, 0.5), (0.0, 0, 1.15), G))
    for s in (-1, 1):
        parts.append(cyl('Wheel', 0.55, 0.35, (0.3, s * 1.3, 0.55), D, axis='Y', verts=16))
        parts.append(cyl('Hub', 0.25, 0.38, (0.3, s * 1.3, 0.55), G, axis='Y', verts=10))
        # ochilgan lafet oyoqlari
        a = math.radians(s * 16)
        p0 = Vector((-0.2, s * 0.4, 0.75))
        p1 = Vector((-4.2, s * 0.4 + math.sin(a) * 4.0 * 0.6, 0.25))
        d = p1 - p0
        tr = box('Trail', (d.length, 0.22, 0.25), (p0 + p1) / 2, G)
        tr.rotation_euler = (0, math.atan2(-d.z, math.hypot(d.x, d.y)) * -1, math.atan2(d.y, d.x))
        parts.append(tr)
        parts.append(box('Spade', (0.15, 0.6, 0.6), p1 + Vector((-0.1, 0, -0.15)), M))
    parts.append(box('Axle', (0.3, 2.6, 0.2), (0.3, 0, 0.6), M))
    ob = join('Artillery', parts, origin=(0, 0, 0))
    ob.rotation_euler.y = math.radians(-12)   # stvol yuqoriga


def render_card(path, size_hint):
    """Katalog rasmi: shaffof fon, Cycles, yumshoq yorug'lik."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = False
    sc.cycles.samples = 96
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    sc.view_settings.view_transform = 'Filmic' if 'Filmic' in [i.identifier for i in sc.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Standard'
    w = bpy.data.worlds.new('W')
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.9
    sc.world = w
    for nm, loc, en, sz in (('Key', (6, -8, 10), 900, 6), ('Fill', (-8, 6, 5), 300, 8), ('Rim', (-6, -6, 6), 400, 4)):
        ld = bpy.data.lights.new(nm, 'AREA')
        ld.energy = en * (size_hint / 8.0) ** 2
        ld.size = sz
        lo = bpy.data.objects.new(nm, ld)
        lo.location = Vector(loc) * (size_hint / 8.0)
        lo.rotation_euler = (Vector((0, 0, 0)) - lo.location).to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(lo)
    # sahnadagi obyekt chegarasi
    mn = Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in sc.objects:
        if o.type == 'MESH':
            for c in o.bound_box:
                v = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, v)); mx = Vector(map(max, mx, v))
    ctr = (mn + mx) / 2
    rad = (mx - mn).length / 2
    cd = bpy.data.cameras.new('Cam'); cd.lens = 50
    cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    a, e = math.radians(-38), math.radians(22)
    cam.location = ctr + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * rad * 2.9
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def team_paint():
    for m in bpy.data.materials:
        if m.name.startswith('TeamColor') and m.node_tree:
            b = m.node_tree.nodes.get('Principled BSDF')
            if b:
                b.inputs['Base Color'].default_value = (0.85, 0.55, 0.08, 1)


# 1) yangi modellar
drone(); export(os.path.join(units, 'drone')); render_card(os.path.join(pics, 'drone.png'), 9)
jet(); export(os.path.join(units, 'jet')); render_card(os.path.join(pics, 'jet.png'), 16)
artillery(); export(os.path.join(units, 'artillery')); render_card(os.path.join(pics, 'artillery.png'), 9)
# 2) mavjud modellar uchun rasm
for src, dst, sz in (('tank', 'mbt', 9), ('apc', 'apc', 8), ('aa', 'sam', 9), ('missile_truck', 'missile', 11), ('soldier_rig', 'soldier', 2.5)):
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(units, src + '.glb'))
    team_paint()
    render_card(os.path.join(pics, dst + '.png'), sz)
print('WEAPONS DONE')
