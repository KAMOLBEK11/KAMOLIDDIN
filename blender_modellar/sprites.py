"""Xarita uchun kichik animatsion rasmlar (spritelar): yugurayotgan askar (8 kadr) va tank,
sariq (o'yinchi) va qizil (dushman) rangda. blender -b -P sprites.py -- <models_units> <chiqish>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import clear

args = sys.argv[sys.argv.index('--') + 1:]
units, out = args[0], args[1]
os.makedirs(out, exist_ok=True)
TEAMS = {'p': (0.85, 0.58, 0.08, 1), 'e': (0.75, 0.08, 0.06, 1)}


def setup(res, ortho, target):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    w = bpy.data.worlds.new('W'); w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.8
    sc.world = w
    ld = bpy.data.lights.new('Sun', 'SUN'); ld.energy = 4.0; ld.angle = 0.3
    lo = bpy.data.objects.new('Sun', ld); lo.rotation_euler = (math.radians(40), 0, math.radians(-30))
    sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new('Cam'); cd.type = 'ORTHO'; cd.ortho_scale = ortho
    cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    el = math.radians(30)
    t = Vector(target)
    cam.location = t + Vector((0, -math.cos(el), math.sin(el))) * 30
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()


def paint(team):
    for m in bpy.data.materials:
        if m.name.startswith('TeamColor') and m.node_tree:
            b = m.node_tree.nodes.get('Principled BSDF')
            if b:
                b.inputs['Base Color'].default_value = TEAMS[team]


for team in TEAMS:
    # askar
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(units, 'soldier_rig.glb'))
    paint(team)
    arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
    act = None
    for a in bpy.data.actions:
        if a.name.lower().startswith('run'):
            act = a
    arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    setup(96, 2.6, (0, 0, 0.95))
    sc = bpy.context.scene
    for i in range(8):
        sc.frame_set(int(f0 + (f1 - f0) * i / 8))
        sc.render.filepath = os.path.join(out, 'sold_%s_%d.png' % (team, i))
        bpy.ops.render.render(write_still=True)
    # tank
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(units, 'tank.glb'))
    paint(team)
    setup(128, 10.5, (0.6, 0, 1.2))
    bpy.context.scene.render.filepath = os.path.join(out, 'tank_%s.png' % team)
    bpy.ops.render.render(write_still=True)
print('SPRITES DONE')
