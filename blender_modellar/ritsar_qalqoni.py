"""Gemini Yevropa askarlarining dumaloq qalqonini ritsar qalqoni (tepasi tekis, pasti uchli - heater) bilan almashtirish"""
import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a[0], a[1]
ROT = float(a[2]) if len(a) > 2 else 0.0
FLIP = (a[3] == 'flip') if len(a) > 3 else False
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
me = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
gname = 'Offhand_Mount'
gidx = me.vertex_groups[gname].index
bm = bmesh.new(); bm.from_mesh(me.data)
dl = bm.verts.layers.deform.active
sv = [v for v in bm.verts if v[dl].get(gidx, 0.0) > 0.5]
P = np.array([tuple(v.co) for v in sv])
c = Vector(P.mean(0)); u_, s_, vt = np.linalg.svd(P - P.mean(0), full_matrices=False)
nrm = Vector(vt[2]).normalized()
R = float(np.max(np.linalg.norm(P - P.mean(0), axis=1)))
print('shield verts', len(sv), 'center', c, 'normal', nrm, 'R', R)
# old shield: which side is front? front = side away from the body (body center x ~ 0)
if nrm.dot(c - Vector((0, c.y, c.z))) < 0:
    nrm = -nrm
bmesh.ops.delete(bm, geom=sv, context='VERTS')
bm.to_mesh(me.data); bm.free()
# yangi qalqon
if FLIP:
    nrm = -nrm
up = Vector((0, 0, 1))
uu = up.cross(nrm).normalized()
vv = nrm.cross(uu).normalized()
_r = Matrix.Rotation(math.radians(ROT), 3, nrm)
uu = (_r @ uu).normalized(); vv = (_r @ vv).normalized()
W, H = R * 1.05, R * 1.55
outline = []
for i in range(9):          # tepa (tekis, biroz egilgan)
    t = i / 8
    outline.append((-W + 2 * W * t, H * 0.42))
for i in range(1, 15):      # o'ng yon -> uchi -> chap yon (egri)
    t = i / 14
    ang = math.pi * t
    x = W * math.cos(ang * 0.5) if t <= 1 else 0
    outline_pt = None
pts = []
for i in range(9):
    t = i / 8
    pts.append((-W + 2 * W * t, H * 0.42))
N = 16
for i in range(1, N):
    t = i / N            # o'ng tomondan pastki uchgacha
    x = W * (1 - t) ** 0.8
    y = H * 0.42 - (H * 1.0) * (1 - math.cos(t * math.pi / 2)) - H * 0.12 * t
    pts.append((x, y * 1.0))
tip_y = pts[-1][1] - 0.04
pts.append((0.0, tip_y))
for i in range(N - 1, 0, -1):
    t = i / N
    x = -W * (1 - t) ** 0.8
    y = H * 0.42 - (H * 1.0) * (1 - math.cos(t * math.pi / 2)) - H * 0.12 * t
    pts.append((x, y))
yc = (H * 0.42 + tip_y) / 2
def P3(x, y, z):
    bulge = 0.06 * R * (1 - (x / W) ** 2)
    return c + uu * x + vv * (y - yc) + nrm * (z + bulge)
def make(name, z0, z1, mat, scale=1.0):
    b = bmesh.new()
    f = [b.verts.new(P3(x * scale, y * scale + yc * (1 - scale), z1)) for x, y in pts]
    k = [b.verts.new(P3(x * scale, y * scale + yc * (1 - scale), z0)) for x, y in pts]
    b.faces.new(f); b.faces.new(k[::-1])
    n = len(pts)
    for i in range(n):
        b.faces.new((f[i], f[(i + 1) % n], k[(i + 1) % n], k[i]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    m = bpy.data.meshes.new(name); b.to_mesh(m); b.free()
    o = bpy.data.objects.new(name, m); bpy.context.collection.objects.link(o)
    m.materials.append(mat)
    vg = o.vertex_groups.new(name=gname); vg.add(list(range(len(m.vertices))), 1.0, 'REPLACE')
    return o
def mat(name, col, metal=0.0, rough=0.6):
    mm = bpy.data.materials.new(name); mm.use_nodes = True
    bs = mm.node_tree.nodes['Principled BSDF']
    bs.inputs['Base Color'].default_value = (*col, 1); bs.inputs['Metallic'].default_value = metal; bs.inputs['Roughness'].default_value = rough
    return mm
team = mat('TeamColor', (0.6, 0.05, 0.05))
iron = mat('ShieldRim', (0.55, 0.56, 0.58), 0.8, 0.35)
gold = mat('ShieldCross', (0.85, 0.66, 0.2), 0.7, 0.4)
rim = make('Rim', -0.02, 0.025, iron, 1.0)
face = make('Face', 0.0, 0.035, team, 0.92)
# xoch / sher o'rniga oddiy tasma (gerb)
b = bmesh.new()
for (x0, x1, y0, y1) in ((-0.035 * W / 0.3, 0.035 * W / 0.3, tip_y + 0.12 * H, H * 0.38), (-W * 0.8, W * 0.8, H * 0.05, H * 0.05 + 0.07 * H)):
    q = [b.verts.new(P3(x, y, 0.045)) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    b.faces.new(q)
m = bpy.data.meshes.new('Cross'); b.to_mesh(m); b.free()
cr = bpy.data.objects.new('Cross', m); bpy.context.collection.objects.link(cr); m.materials.append(gold)
cr.vertex_groups.new(name=gname).add(list(range(len(m.vertices))), 1.0, 'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
for o in (rim, face, cr):
    o.select_set(True)
me.select_set(True)
bpy.context.view_layer.objects.active = me
bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_yup=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_apply=False)
print('SAVED', dst)
