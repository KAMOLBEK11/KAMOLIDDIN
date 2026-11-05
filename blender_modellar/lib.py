"""Blender uchun umumiy yordamchi funksiyalar (low-poly texnika yasash).
Koordinatalar: Z - yuqoriga, +X - oldinga (tumshug'i), Y - chap/o'ng. O'lchov - metr.
"""
import bpy
import bmesh
import math
from mathutils import Vector, Matrix

_mats = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
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
