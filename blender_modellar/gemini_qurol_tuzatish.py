"""Gemini askar modellarida qurolni tuzatish:
 - qilich: tig'ni o'z o'qi atrofida burish (egri tomoni to'g'ri qarashi uchun)
 - nayza: uchidagi bayroqchani olib tashlash"""
import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
src, dst, mode, ang = a[0], a[1], a[2], float(a[3]) if len(a) > 3 else 0.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
me = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
gidx = me.vertex_groups['Weapon_Mount'].index
bm = bmesh.new(); bm.from_mesh(me.data)
dl = bm.verts.layers.deform.active
wv = [v for v in bm.verts if dl in [] or (v[dl].get(gidx, 0.0) > 0.5)]
P = np.array([tuple(v.co) for v in wv])
c = P.mean(0); u, s, vt = np.linalg.svd(P - c, full_matrices=False)
ax = Vector(vt[0]).normalized()
head = arm.data.bones['Weapon_Mount'].head_local
if mode == 'sword':
    # o'q chizig'i: suyak boshidan o'tadi (dasta qo'lda qoladi)
    R = Matrix.Rotation(math.radians(ang), 3, ax)
    for v in wv:
        v.co = head + R @ (v.co - head)
    print('rotated', len(wv), 'axis', ax, 'curve dir', Vector(vt[1]))
elif mode == 'spear':
    # bayroqcha: nayza o'qidan uzoq turgan alohida bo'lak(lar)
    def rad(v):
        d = Vector(v.co) - Vector(c)
        return (d - ax * d.dot(ax)).length
    wset = set(wv)
    seen = set(); kill = []
    for v in wv:
        if v in seen: continue
        isl = []; st = [v]; seen.add(v)
        while st:
            x = st.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o in wset and o not in seen:
                    seen.add(o); st.append(o)
        if max(rad(x) for x in isl) > 0.12:
            kill += isl
    print('flag verts', len(kill), 'of', len(wv))
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
bm.to_mesh(me.data); bm.free()
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_yup=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_apply=False)
print('SAVED', dst)
