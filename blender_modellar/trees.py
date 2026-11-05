"""Real ko'rinishdagi low-poly daraxtlar: bargli daraxt, archa, buta, quruq daraxt (cho'l uchun).
blender -b -P trees.py -- <chiqish_papka>
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, noise
from lib import *
from lib import _obj_from_bm

out = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/trees'
os.makedirs(out, exist_ok=True)


def blob(name, r, loc, material, squash=(1, 1, 0.8), rough=0.35, seed=0, subdiv=2):
    """Notekis barg to'plami (shovqin bilan buzilgan sfera)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in bm.verts:
        n = noise.noise(v.co * 2.2 + off)
        v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2])) * (1.0 + n * rough)
    ob = _obj_from_bm(name, bm, material)
    ob.location = loc
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def limb(name, a, b, r1, r2, material, verts=7):
    """a dan b gacha toraygan shox/tana."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = cyl(name, r1, d.length, (0, 0, 0), material, axis='Z', verts=verts, r2=r2)
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.location = (a + b) / 2
    return ob


def oak(seed, light=False):
    random.seed(seed)
    clear()
    bark = mat('Bark', '#4a3a2a', 0.95)
    g1 = mat('Leaf1', '#3f6a2c' if not light else '#5b7f34', 0.9)
    g2 = mat('Leaf2', '#4f7d35' if not light else '#6d9040', 0.9)
    g3 = mat('Leaf3', '#2f5523', 0.9)
    parts = []
    # tana: 3 bo'lakli, biroz egri
    pts = [Vector((0, 0, 0)), Vector((0.1, 0.05, 1.6)), Vector((-0.05, 0.1, 3.0)), Vector((0.05, 0, 4.0))]
    rads = [0.32, 0.24, 0.17, 0.11]
    for i in range(3):
        parts.append(limb('Trunk', pts[i], pts[i + 1], rads[i], rads[i + 1], bark))
    parts.append(cyl('Root', 0.45, 0.35, (0, 0, 0.12), bark, axis='Z', verts=7, r2=0.3))
    # shoxlar
    tips = []
    for k in range(5):
        ang = k * 2 * math.pi / 5 + random.uniform(-0.3, 0.3)
        base = pts[1].lerp(pts[3], random.uniform(0.2, 0.9))
        L = random.uniform(1.4, 2.2)
        tip = base + Vector((math.cos(ang) * L, math.sin(ang) * L, random.uniform(0.8, 1.6)))
        parts.append(limb('Branch', base, tip, 0.1, 0.04, bark, verts=5))
        tips.append(tip)
    tips.append(pts[3] + Vector((0, 0, 0.8)))
    # barglar
    for i, t in enumerate(tips):
        for j in range(2):
            c = t + Vector((random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), random.uniform(-0.2, 0.4)))
            parts.append(blob('Leaves', random.uniform(1.0, 1.5), c, random.choice([g1, g2, g3]), seed=i * 3 + j + seed))
    parts.append(blob('LeavesTop', 1.8, pts[3] + Vector((0, 0, 0.9)), g2, seed=seed + 50))
    return join('Tree', parts, origin=(0, 0, 0))


def pine(seed):
    random.seed(seed)
    clear()
    bark = mat('Bark', '#4a3626', 0.95)
    g1 = mat('Needle1', '#26472a', 0.9)
    g2 = mat('Needle2', '#2f5532', 0.9)
    parts = [limb('Trunk', (0, 0, 0), (0, 0, 7.0), 0.24, 0.05, bark)]
    levels = 6
    for i in range(levels):
        z = 1.5 + i * 0.95
        r = 2.1 * (1 - i / (levels + 0.5)) + 0.3
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=11, radius1=r, radius2=0.0, depth=1.7)
        for v in bm.verts:
            if v.co.z < 0:   # pastki chet - tishli
                k = 1.0 + random.uniform(-0.18, 0.12)
                v.co.x *= k
                v.co.y *= k
                v.co.z += random.uniform(-0.15, 0.1)
        ob = _obj_from_bm('Layer', bm, g1 if i % 2 == 0 else g2)
        ob.location = (0, 0, z + 0.6)
        ob.rotation_euler = (0, 0, random.uniform(0, 6.28))
        parts.append(ob)
    return join('Tree', parts, origin=(0, 0, 0))


def bush(seed, dry=False):
    random.seed(seed)
    clear()
    g = mat('Bush', '#4c6d30' if not dry else '#7a7444', 0.9)
    g2 = mat('Bush2', '#3c5a27' if not dry else '#8a8250', 0.9)
    parts = []
    for i in range(4):
        c = Vector((random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), 0.4))
        parts.append(blob('Bush', random.uniform(0.5, 0.8), c, g if i % 2 else g2, squash=(1, 1, 0.75), seed=seed + i, subdiv=1))
    return join('Tree', parts, origin=(0, 0, 0))


def dead_tree(seed):
    random.seed(seed)
    clear()
    bark = mat('DryBark', '#6b5a45', 0.95)
    parts = [limb('Trunk', (0, 0, 0), (0.2, 0, 2.8), 0.22, 0.09, bark)]
    for k in range(4):
        ang = k * 1.6 + random.uniform(-0.3, 0.3)
        base = Vector((0.1, 0, random.uniform(1.2, 2.5)))
        tip = base + Vector((math.cos(ang) * 1.3, math.sin(ang) * 1.3, random.uniform(0.6, 1.4)))
        parts.append(limb('Branch', base, tip, 0.07, 0.02, bark, verts=5))
        tip2 = tip + Vector((math.cos(ang + 0.8) * 0.6, math.sin(ang + 0.8) * 0.6, 0.4))
        parts.append(limb('Twig', tip, tip2, 0.03, 0.01, bark, verts=4))
    return join('Tree', parts, origin=(0, 0, 0))


def save(name):
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + '.glb'), export_format='GLB', export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, name + '.blend'))


oak(1); save('oak1')
oak(7, light=True); save('oak2')
pine(3); save('pine1')
pine(9); save('pine2')
bush(4); save('bush1')
bush(5, dry=True); save('bush_dry')
dead_tree(2); save('dead_tree')

# hammasi bitta rasmda
clear()
for i, (f, x) in enumerate((('oak1', -9), ('oak2', -4.5), ('pine1', 0), ('pine2', 4), ('bush1', 7), ('bush_dry', 9), ('dead_tree', 11.5))):
    bpy.ops.import_scene.gltf(filepath=os.path.join(out, f + '.glb'))
    for o in bpy.context.selected_objects:
        o.location.x += x
render_preview(os.path.join(out, 'trees_preview.png'), target=(1.5, 0, 3), dist=26, views=((-90, 12),), size=(1200, 600))
