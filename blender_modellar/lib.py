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


def smooth_all(angle=38.0):
    """yumshatish: hamma meshlarda silliq soya; o'tkir qirralar (burchak > angle) saqlanadi.
    Shar, silindr, gumbaz, odam tanasi silliq ko'rinadi; quti va devor qirralari tik qoladi."""
    import math as _m
    for ob in bpy.data.objects:
        if ob.type != 'MESH':
            continue
        me = ob.data
        for poly in me.polygons:
            poly.use_smooth = True
        if hasattr(me, 'use_auto_smooth'):
            me.use_auto_smooth = True
            me.auto_smooth_angle = _m.radians(angle)


def export(path_noext):
    smooth_all()
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


def rbox(name, size, loc, material, r=0.03, seg=3, rot=(0, 0, 0)):
    """qirralari yumaloqlangan quti (yumshoq ko'rinish uchun)"""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    r = min(r, sx * 0.45, sy * 0.45, sz * 0.45)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=r, segments=seg, affect='EDGES', profile=0.5)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def sweep(name, pts, r, material, verts=10, closed=False):
    """polyline bo'ylab silliq quvur (halqa, tutqich, chiziqli bezaklar uchun)"""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        if closed:
            d = pts[(i + 1) % n] - pts[i - 1]
        else:
            d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        a = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        u = d.cross(a).normalized()
        w = d.cross(u).normalized()
        rings.append([bm.verts.new(p + (u * math.cos(t) + w * math.sin(t)) * r)
                      for t in [k / verts * 2 * math.pi for k in range(verts)]])
    m = n if closed else n - 1
    for i in range(m):
        a_, b_ = rings[i], rings[(i + 1) % n]
        for k in range(verts):
            bm.faces.new((a_[k], a_[(k + 1) % verts], b_[(k + 1) % verts], b_[k]))
    if not closed:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(name, bm, material)
    for f in ob.data.polygons:
        f.use_smooth = True
    return ob


def sheet(name, rows, material, thick=0.025):
    """nuqtalar to'ri (rows[i][j]) dan qalinlikka ega silliq mato/devor"""
    bm = bmesh.new()
    vs = [[bm.verts.new(Vector(p)) for p in row] for row in rows]
    for i in range(len(vs) - 1):
        for j in range(len(vs[i]) - 1):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(name, bm, material)
    for f in ob.data.polygons:
        f.use_smooth = True
    md = ob.modifiers.new('Solid', 'SOLIDIFY')
    md.thickness = thick
    md.offset = 0.0
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier='Solid')
    return ob
