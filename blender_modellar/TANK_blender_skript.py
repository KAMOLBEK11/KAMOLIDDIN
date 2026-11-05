"""TANK - batafsil low-poly model (Global Strategiya o'yini uchun).
Qismlar: Hull, TrackA/TrackB (gusenitsa fazalari), Wheel_* (aylanadigan g'ildiraklar),
Turret -> Barrel -> Muzzle, TeamColor. O'yin shu nomlar bo'yicha animatsiya qiladi.
Blender'da: Scripting -> Open -> Run Script (Alt+P). Sahnadagi obyektlar o'chiriladi.
"""
import sys, os, math

import bpy
import bmesh
import math
from mathutils import Vector, Matrix

_mats = {}


def clear():
    if bpy.app.background:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    else:
        if bpy.context.object and bpy.context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for m in list(bpy.data.meshes):
            bpy.data.meshes.remove(m)
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
    _mats.clear()


def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c]


def mat(name, hexcol, rough=0.8, metal=0.0, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    col = srgb(hexcol)
    b.inputs['Base Color'].default_value = (*col, 1.0)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit > 0:
        b.inputs['Emission Color'].default_value = (*col, 1.0)
        b.inputs['Emission Strength'].default_value = emit
    m.diffuse_color = (*col, 1.0)   # Workbench preview uchun
    _mats[name] = m
    return m


def _obj_from_bm(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def hull_points(name, pts, material, loc=(0, 0, 0)):
    """Nuqtalar to'plamining qavariq qobig'i (burchakli zirh shakllari uchun eng qulay)."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(Vector(p) + Vector(loc))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, material)


def box(name, size, loc, material, rot=(0, 0, 0)):
    sx, sy, sz = size
    pts = [(x * sx / 2, y * sy / 2, z * sz / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    ob = hull_points(name, pts, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def profile_y(name, pts_xz, y0, y1, material):
    """XZ tekisligidagi profilni Y bo'ylab cho'zish (yon tomondan chizilgan shakl)."""
    pts = []
    for (x, z) in pts_xz:
        pts.append((x, y0, z))
        pts.append((x, y1, z))
    return hull_points(name, pts, material)


def cyl(name, r, depth, loc, material, axis='Y', verts=12, r2=None):
    bm = bmesh.new()
    r2 = r if r2 is None else r2
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r, radius2=r2, depth=depth)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    if axis == 'X':
        ob.rotation_euler = (0, math.pi / 2, 0)
    elif axis == 'Y':
        ob.rotation_euler = (math.pi / 2, 0, 0)
    return ob


def apply_all(objs):
    for o in objs:
        o.select_set(False)
    for o in objs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for o in objs:
        o.select_set(False)


def join(name, objs, origin=None):
    """Bir nechta obyektni bittaga birlashtiradi va pivot nuqtasini belgilaydi."""
    objs = [o for o in objs if o is not None]
    apply_all(objs)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if origin is not None:
        bpy.context.scene.cursor.location = origin
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    ob.select_set(False)
    return ob


def parent(child, par):
    mw = child.matrix_world.copy()
    child.parent = par
    child.matrix_world = mw


def export(path_noext):
    bpy.ops.wm.save_as_mainfile(filepath=path_noext + '.blend')
    bpy.ops.export_scene.gltf(filepath=path_noext + '.glb', export_format='GLB', export_apply=True,
                              export_yup=True)


def render_preview(path, target=(0, 0, 1.2), dist=14.0, views=((35, 25),), size=(900, 600)):
    """Workbench bilan tez rasm: views - (azimut, balandlik) gradusda."""
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = 'BOTH'
    sc.display.shading.show_object_outline = True
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new('W') if sc.world is None else sc.world
    sc.render.resolution_x, sc.render.resolution_y = size
    cam_data = bpy.data.cameras.new('Cam')
    cam_data.lens = 45
    cam = bpy.data.objects.new('Cam', cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    out = []
    for i, (az, el) in enumerate(views):
        a, e = math.radians(az), math.radians(el)
        t = Vector(target)
        cam.location = t + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * dist
        d = t - cam.location
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        p = path.replace('.png', '_%d.png' % i)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        out.append(p)
    bpy.data.objects.remove(cam)
    return out


def tracked_chassis(prefix, length, width, body, dark, n_wheels=7, wheel_r=0.38, track_w=0.62, skirt_z=0.78):
    """Gusenitsali shassi: gusenitsa lentasi, tayanch g'ildiraklar, oldingi/orqa g'ildiraklar."""
    parts = []
    hx = length / 2.0
    yt = width / 2.0 - track_w / 2.0
    for side in (-1, 1):
        y = side * yt
        prof = [(-hx + 0.1, 0.15), (-hx - 0.15, 0.55), (-hx + 0.05, 0.9), (hx - 0.05, 0.9), (hx + 0.2, 0.6), (hx - 0.15, 0.05),
                (-hx + 0.4, 0.05)]
        parts.append(profile_y(prefix + 'Track', prof, y - track_w / 2, y + track_w / 2, dark))
        span = length - 1.6
        for i in range(n_wheels):
            x = -span / 2 + span * i / (n_wheels - 1)
            parts.append(cyl(prefix + 'Wheel', wheel_r, 0.14, (x, side * (yt + track_w / 2 + 0.05), wheel_r + 0.04), body, verts=12))
            parts.append(cyl(prefix + 'Hub', wheel_r * 0.35, 0.18, (x, side * (yt + track_w / 2 + 0.07), wheel_r + 0.04), dark, verts=8))
        for x, z, r in ((hx - 0.2, 0.55, 0.3), (-hx + 0.05, 0.6, 0.3)):
            parts.append(cyl(prefix + 'Idler', r, 0.16, (x, side * (yt + track_w / 2 + 0.05), z), body, verts=10))
    return parts


out = sys.argv[sys.argv.index('--') + 1] if ('--' in sys.argv and bpy.app.background) else None
clear()

OL = mat('Olive', '#5d6c3c', 0.72)
OL2 = mat('OliveDark', '#4c5a31', 0.78)
OL3 = mat('OliveLight', '#6b7b46', 0.7)
LINE = mat('PanelLine', '#2f3820', 0.9)
DK = mat('Track', '#262724', 0.9)
DK2 = mat('TrackPin', '#3a3b37', 0.6, 0.4)
MT = mat('Metal', '#33362f', 0.45, 0.4)
GR = mat('Grille', '#1b1c19', 0.95)
GLS = mat('Glass', '#1d2b33', 0.15, 0.2)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
LAMP = mat('Lamp', '#e2e2d0', 0.3, 0.0, 1.5)
REAR = mat('RearLamp', '#d9772a', 0.3, 0.0, 1.5)

HL = 7.7          # korpus uzunligi
HW = 3.66         # korpus eni (ekranlar bilan)
TW = 0.64         # gusenitsa eni
YT = HW / 2 - TW / 2 - 0.02
WR = 0.36         # tayanch g'ildirak radiusi
WZ = WR + 0.07
WHEELS_X = [-2.75 + i * (5.5 / 6) for i in range(7)]
IDLER = (3.35, 0.62, 0.33)       # old yo'naltiruvchi (x, z, r)
SPROCKET = (-3.42, 0.66, 0.36)   # orqa yetaklovchi

hull = []

# ---------------------------------------------------------------- gusenitsa zvenolari
def track_path():
    """Gusenitsa lentasining yo'li (yon tomondan), soat yo'nalishida nuqtalar."""
    pts = []
    # pastki tekis qism
    x0, x1 = WHEELS_X[0], WHEELS_X[-1]
    for i in range(40):
        pts.append((x0 + (x1 - x0) * i / 39, 0.04))
    # oldingi qism (pastdan idler atrofiga)
    ix, iz, ir = IDLER
    for i in range(10):
        a = -math.pi / 2 + math.pi * i / 9
        pts.append((ix + math.cos(a) * (ir + 0.05) + (x1 - ix) * (1 - i / 9) * 0.0, iz + math.sin(a) * (ir + 0.05)))
    # yuqori qism (biroz osilgan)
    sx, sz, sr = SPROCKET
    top_a, top_b = (ix, iz + ir + 0.05), (sx, sz + sr + 0.05)
    for i in range(1, 38):
        t = i / 38
        x = top_a[0] + (top_b[0] - top_a[0]) * t
        z = top_a[1] + (top_b[1] - top_a[1]) * t - math.sin(t * math.pi) * 0.06
        pts.append((x, z))
    # orqa qism (sprocket atrofida pastga)
    for i in range(10):
        a = math.pi / 2 + math.pi * i / 9
        pts.append((sx + math.cos(a) * (sr + 0.05), sz + math.sin(a) * (sr + 0.05)))
    # orqadan pastki tekislikka
    for i in range(1, 6):
        t = i / 6
        pts.append((sx + (x0 - sx) * t, (sz - sr - 0.05) + (0.04 - (sz - sr - 0.05)) * t))
    return pts


def resample(pts, step, offset=0.0):
    total = []
    for i in range(len(pts)):
        a, b = Vector((*pts[i], 0)), Vector((*pts[(i + 1) % len(pts)], 0))
        total.append((a, b, (b - a).length))
    L = sum(t[2] for t in total)
    n = int(L / step)
    out_pts = []
    for k in range(n):
        d = (k + offset) * L / n
        for a, b, l in total:
            if d <= l and l > 0:
                p = a.lerp(b, d / l)
                out_pts.append((p, (b - a).normalized()))
                break
            d -= l
    return out_pts


# Gusenitsa ikki fazada: o'yinda navbat bilan ko'rsatilsa, lenta harakatlanayotgandek ko'rinadi
movers = []          # harakatlanadigan qismlar (keyin Hull ga bog'lanadi)
for phase, tname in ((0.0, 'TrackA'), (0.5, 'TrackB')):
    tl = []
    for side in (-1, 1):
        y = side * YT
        for p, tdir in resample(track_path(), 0.17, phase):
            ang = math.atan2(tdir.y, tdir.x)
            tl.append(box('Link', (0.15, TW, 0.07), (p.x, y, p.y), DK, rot=(0, -ang, 0)))
            tl.append(box('LinkPin', (0.04, TW - 0.08, 0.05), (p.x, y, p.y), DK2, rot=(0, -ang, 0)))
    movers.append(join(tname, tl, origin=(0, 0, 0)))

# ---------------------------------------------------------------- g'ildiraklar (har biri alohida - o'yinda aylanadi)
for side in (-1, 1):
    sname = 'L' if side > 0 else 'R'
    yo = side * (YT + 0.02)
    for wi, x in enumerate(WHEELS_X):
        w = []
        for k in (-1, 1):   # qo'sh g'ildirak
            w.append(cyl('Wheel', WR, 0.2, (x, yo + k * 0.16, WZ), OL, verts=16))
            w.append(cyl('Tyre', WR + 0.015, 0.06, (x, yo + k * 0.16 + side * 0.08 * k, WZ), DK, verts=16))
        w.append(cyl('Hub', WR * 0.42, 0.06, (x, yo + side * 0.27, WZ), OL2, verts=10))
        w.append(cyl('HubCap', WR * 0.2, 0.08, (x, yo + side * 0.3, WZ), MT, verts=8))
        for b in range(6):
            a = b * math.pi / 3
            w.append(cyl('Bolt', 0.025, 0.05, (x + math.cos(a) * WR * 0.3, yo + side * 0.3, WZ + math.sin(a) * WR * 0.3), MT, verts=6))
        movers.append(join('Wheel_%s%d_r%.2f' % (sname, wi, WR), w, origin=(x, yo, WZ)))
    # old idler - parmoqli
    ix, iz, ir = IDLER
    w = [cyl('Idler', ir, 0.4, (ix, yo, iz), OL, verts=16), cyl('IdlerHub', ir * 0.3, 0.46, (ix, yo, iz), MT, verts=8)]
    for b in range(6):
        a = b * math.pi / 3
        w.append(box('Spoke', (ir * 0.55, 0.05, 0.07), (ix + math.cos(a) * ir * 0.55, yo + side * 0.22, iz + math.sin(a) * ir * 0.55), OL2, rot=(0, -a, 0)))
    movers.append(join('Wheel_%sIdler_r%.2f' % (sname, ir), w, origin=(ix, yo, iz)))
    # orqa sprocket - tishli
    sx, sz, sr = SPROCKET
    w = [cyl('Sprocket', sr, 0.4, (sx, yo, sz), OL, verts=16), cyl('SprocketHub', sr * 0.35, 0.46, (sx, yo, sz), MT, verts=8)]
    for b in range(12):
        a = b * math.pi / 6
        w.append(box('Tooth', (0.09, 0.42, 0.09), (sx + math.cos(a) * (sr + 0.03), yo, sz + math.sin(a) * (sr + 0.03)), OL2, rot=(0, -a, 0)))
    for b in range(6):
        a = b * math.pi / 3 + 0.3
        w.append(cyl('Hole', 0.06, 0.44, (sx + math.cos(a) * sr * 0.62, yo, sz + math.sin(a) * sr * 0.62), DK, verts=8))
    movers.append(join('Wheel_%sSprocket_r%.2f' % (sname, sr), w, origin=(sx, yo, sz)))
    # yuqori tayanch roliklar
    for ri, x in enumerate((-1.6, 0.0, 1.6)):
        movers.append(join('Wheel_%sRoller%d_r0.11' % (sname, ri), [cyl('Roller', 0.11, 0.3, (x, yo, 0.9), OL2, verts=10)], origin=(x, yo, 0.9)))

# ---------------------------------------------------------------- korpus
hull.append(profile_y('LowerHull', [(-3.65, 0.42), (2.9, 0.42), (3.85, 0.98), (-3.65, 0.98)], -1.12, 1.12, OL2))
# yuqori korpus: old qiya zirh + tekis tom
hull.append(profile_y('UpperHull', [(-3.85, 0.98), (3.55, 0.98), (4.0, 1.18), (2.75, 1.62), (-3.85, 1.62)], -1.2, 1.2, OL))
# yon ekranlar (6 bo'lak, orasida chiziq)
SK_X = [3.55, 2.35, 1.15, -0.05, -1.25, -2.45, -3.85]
for side in (-1, 1):
    y0 = side * (HW / 2 - 0.06)
    for i in range(6):
        xa, xb = SK_X[i + 1] + 0.015, SK_X[i] - 0.015
        if i == 0:
            prof = [(xa, 0.74), (xb - 0.05, 0.74), (xb + 0.45, 1.16), (xb - 0.6, 1.62), (xa, 1.62)]
        else:
            prof = [(xa, 0.74), (xb, 0.74), (xb, 1.62), (xa, 1.62)]
        hull.append(profile_y('Skirt', prof, y0 - 0.06, y0 + 0.06, OL))
        hull.append(profile_y('SkirtLine', [(xb, 0.76), (xb + 0.03, 0.76), (xb + 0.03, 1.6), (xb, 1.6)], y0 - 0.05, y0 + 0.05, LINE))
    # ekran ustidagi polka (gusenitsa ustidagi tekislik)
    hull.append(box('Fender', (6.6, 0.62, 0.06), (-0.55, side * (HW / 2 - 0.36), 1.62), OL))
    # yon panjara (orqada)
    hull.append(box('SideVent', (1.0, 0.03, 0.18), (-2.9, side * (HW / 2 + 0.005), 1.45), GR))
# tomdagi panel chiziqlari
for x in (2.0, 0.6, -0.8, -2.0):
    hull.append(box('RoofLine', (0.03, 2.2, 0.01), (x, 0, 1.625), LINE))
# orqa motor bo'limi panjaralari
for i in range(3):
    gx = -3.45 + i * 0.5
    hull.append(box('GrilleFrame', (0.42, 1.5, 0.05), (gx, 0, 1.63), OL2))
    for j in range(7):
        hull.append(box('Slat', (0.36, 0.05, 0.04), (gx, -0.6 + j * 0.2, 1.665), GR))
hull.append(box('Exhaust', (0.06, 1.8, 0.35), (-3.88, 0, 1.3), GR))
for j in range(3):
    hull.append(box('RearGrille', (0.04, 0.6, 0.3), (-3.9, -0.7 + j * 0.7, 1.3), MT))
# chiroqlar, ilgaklar, haydovchi priborlari
for s in (-1, 1):
    hull.append(box('Lamp', (0.07, 0.22, 0.12), (3.72, s * 1.5, 1.24), LAMP))
    hull.append(box('LampFrame', (0.05, 0.3, 0.2), (3.69, s * 1.5, 1.24), MT))
    hull.append(box('RearLamp', (0.06, 0.24, 0.14), (-3.88, s * 1.52, 1.45), REAR))
    hull.append(cyl('TowHook', 0.1, 0.07, (3.62, s * 0.75, 0.88), MT, axis='Y', verts=8))
    hull.append(cyl('TowHookR', 0.1, 0.07, (-3.68, s * 0.75, 0.9), MT, axis='Y', verts=8))
hull.append(box('DriverHatch', (0.5, 0.6, 0.05), (2.35, 0.0, 1.645), OL2))
for k in range(3):
    hull.append(box('Periscope', (0.08, 0.12, 0.06), (2.62, -0.2 + k * 0.2, 1.66), GLS))
hull_ob = join('Hull', hull, origin=(0, 0, 0))

# ---------------------------------------------------------------- minora
TX, TZ = 0.35, 1.62
T = Vector((TX, 0, TZ))
tur = []
# asosiy faset shakl (tepadan sakkiz burchakli, old tomoni ponasimon)
tur.append(hull_points('TurretBody', [
    (2.2, -1.0, 0.05), (2.2, 1.0, 0.05), (1.3, -1.62, 0.05), (1.3, 1.62, 0.05),
    (-1.55, -1.62, 0.05), (-1.55, 1.62, 0.05), (-2.05, -1.22, 0.05), (-2.05, 1.22, 0.05),
    (1.95, -0.85, 0.58), (1.95, 0.85, 0.58), (1.1, -1.5, 0.7), (1.1, 1.5, 0.7),
    (-1.45, -1.5, 0.72), (-1.45, 1.5, 0.72), (-1.95, -1.12, 0.66), (-1.95, 1.12, 0.66)], OL, loc=T))
# old modul zirh (ponaning ikki tomoni)
for s in (-1, 1):
    tur.append(hull_points('Cheek', [(2.25, s * 0.42, 0.08), (2.25, s * 1.0, 0.08), (1.35, s * 1.6, 0.08), (1.35, s * 0.42, 0.08),
                                     (2.0, s * 0.42, 0.56), (2.0, s * 0.86, 0.56), (1.15, s * 1.5, 0.68), (1.15, s * 0.42, 0.68)], OL, loc=T))
    # tutun granata quvurlari
    for k in range(4):
        tur.append(cyl('Smoke', 0.06, 0.28, (TX + 1.0, s * (1.56 + 0.0), TZ + 0.18 + k * 0.12), OL2, axis='X', verts=8))
    # yon panjara va qopqoqlar
    tur.append(box('TurretVent', (0.45, 0.03, 0.2), (TX - 0.8, s * 1.6, TZ + 0.42), GR))
    tur.append(box('SidePanel', (1.1, 0.03, 0.4), (TX - 0.2, s * 1.585, TZ + 0.38), OL2))
# orqa savat (bustle rack)
tur.append(box('Bustle', (0.55, 2.3, 0.45), (TX - 2.25, 0, TZ + 0.38), OL2))
for k in range(5):
    tur.append(box('RackBar', (0.04, 2.3, 0.04), (TX - 2.5, 0, TZ + 0.18 + k * 0.1), MT))
# niqob va stvol
tur.append(hull_points('Mantlet', [(2.15, -0.42, 0.12), (2.15, 0.42, 0.12), (2.15, -0.42, 0.58), (2.15, 0.42, 0.58),
                                   (2.55, -0.32, 0.18), (2.55, 0.32, 0.18), (2.55, -0.32, 0.52), (2.55, 0.32, 0.52)], OL2, loc=T))
GZ = TZ + 0.36
brl = []
brl.append(cyl('BarrelBase', 0.17, 0.5, (TX + 2.8, 0, GZ), OL2, axis='X', verts=12))
brl.append(cyl('Barrel1', 0.13, 1.6, (TX + 3.85, 0, GZ), OL, axis='X', verts=12, r2=0.12))
brl.append(cyl('Evacuator', 0.18, 0.75, (TX + 4.95, 0, GZ), OL2, axis='X', verts=12))
brl.append(cyl('Barrel2', 0.115, 1.7, (TX + 6.15, 0, GZ), OL, axis='X', verts=12, r2=0.105))
brl.append(cyl('MuzzleBrake', 0.14, 0.32, (TX + 7.15, 0, GZ), OL2, axis='X', verts=12))
brl.append(cyl('Bore', 0.07, 0.34, (TX + 7.16, 0, GZ), GR, axis='X', verts=10))
for x in (3.3, 4.4, 5.6, 6.7):
    brl.append(cyl('SleeveRing', 0.135, 0.05, (TX + x, 0, GZ), OL2, axis='X', verts=12))
tur.append(box('CoaxPort', (0.06, 0.1, 0.08), (TX + 2.56, 0.25, GZ + 0.08), GR))
# tomdagi jihozlar: komandir lyuki, o'qchi pribori, masofadan boshqariladigan pulemyot
tur.append(cyl('HatchRing', 0.42, 0.08, (TX - 0.35, 0.0, TZ + 0.76), OL2, axis='Z', verts=16))
tur.append(cyl('Hatch', 0.36, 0.06, (TX - 0.35, 0.0, TZ + 0.82), OL, axis='Z', verts=16))
tur.append(box('HatchHinge', (0.1, 0.25, 0.05), (TX - 0.7, 0.0, TZ + 0.84), MT))
tur.append(box('GunnerSight', (0.45, 0.4, 0.35), (TX + 0.9, -0.95, TZ + 0.88), OL2))
tur.append(box('GunnerSightGlass', (0.04, 0.32, 0.18), (TX + 1.13, -0.95, TZ + 0.9), GLS))
tur.append(box('RWSBase', (0.45, 0.45, 0.2), (TX + 0.55, 0.45, TZ + 0.82), OL2))
tur.append(box('RWSBody', (0.5, 0.32, 0.28), (TX + 0.55, 0.45, TZ + 1.06), MT))
tur.append(box('RWSOptic', (0.2, 0.15, 0.18), (TX + 0.62, 0.7, TZ + 1.1), OL2))
tur.append(box('RWSAmmo', (0.25, 0.2, 0.2), (TX + 0.45, 0.2, TZ + 1.02), OL2))
tur.append(cyl('RWSBarrel', 0.035, 0.85, (TX + 1.2, 0.45, TZ + 1.1), MT, axis='X', verts=8))
tur.append(cyl('RWSMuzzle', 0.05, 0.1, (TX + 1.62, 0.45, TZ + 1.1), MT, axis='X', verts=8))
tur.append(box('MetSensor', (0.12, 0.12, 0.25), (TX - 1.3, 0.9, TZ + 0.85), MT))
tur.append(cyl('Antenna', 0.015, 1.9, (TX - 1.55, -1.2, TZ + 1.65), MT, axis='Z', verts=5))
tur.append(cyl('AntennaBase', 0.08, 0.12, (TX - 1.55, -1.2, TZ + 0.76), MT, axis='Z', verts=8))
tur.append(cyl('Antenna2', 0.012, 1.2, (TX - 1.55, 1.2, TZ + 1.3), MT, axis='Z', verts=5))
for k in range(3):
    tur.append(box('RoofLine', (0.02, 1.9, 0.01), (TX - 0.9 + k * 0.9, 0, TZ + 0.725), LINE))
tur_ob = join('Turret', tur, origin=(TX, 0, TZ))
barrel_ob = join('Barrel', brl, origin=(TX + 2.55, 0, GZ))
muzzle = bpy.data.objects.new('Muzzle', None)
bpy.context.collection.objects.link(muzzle)
muzzle.location = (TX + 7.35, 0, GZ)
parent(muzzle, barrel_ob)
parent(barrel_ob, tur_ob)
for m in movers:
    parent(m, hull_ob)

team = [box('TeamTop', (0.7, 1.0, 0.03), (TX - 1.05, -0.4, TZ + 0.735), TEAM)]
for s in (-1, 1):
    team.append(box('TeamSide', (0.9, 0.025, 0.16), (TX - 0.2, s * 1.605, TZ + 0.6), TEAM))
team_ob = join('TeamColor', team, origin=(TX, 0, TZ))
parent(tur_ob, hull_ob)
parent(team_ob, tur_ob)

print('POLYS', sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'))
if out:
    os.makedirs(out, exist_ok=True)
    export(os.path.join(out, 'tank'))
    render_preview(os.path.join(out, 'tank2_preview.png'), target=(0.8, 0, 1.2), dist=15,
                   views=((-90, 0), (-35, 28), (180, 0), (0, 89.5)), size=(1100, 650))
