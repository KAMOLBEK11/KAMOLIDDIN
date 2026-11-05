"""Gulxan-mash'al (temir qozon uch oyoqda, ichida cho'g' va olov) - qal'ani yoritish uchun"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from lib import *
OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp'
clear()
iron = mat('Iron', '#2e2c2a', 0.55, 0.8)
coal = mat('Coal', '#3a1408', 0.9, 0.0, 2.0)
fire = mat('Fire', '#ffb040', 0.5, 0.0, 6.0)
p = [cyl('Bowl', 0.42, 0.32, (0, 0, 1.18), iron, axis='Z', verts=20, r2=0.55)]
p.append(cyl('Rim', 0.57, 0.06, (0, 0, 1.35), iron, axis='Z', verts=20))
p.append(cyl('Coal', 0.5, 0.06, (0, 0, 1.3), coal, axis='Z', verts=16))
for k in range(3):
    a = k * 2 * math.pi / 3
    p.append(sweep('Leg', [(0.42 * math.cos(a), 0.42 * math.sin(a), 1.1), (0.6 * math.cos(a), 0.6 * math.sin(a), 0.5), (0.7 * math.cos(a), 0.7 * math.sin(a), 0.0)], 0.035, iron, 6))
p.append(sweep('Ring', [(0.55 * math.cos(t), 0.55 * math.sin(t), 0.55) for t in [i / 16 * 2 * math.pi for i in range(16)]], 0.02, iron, 6, closed=True))


join('Torch', p, origin=(0, 0, 0))
smooth_all(40)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'torch.glb'), export_format='GLB', export_yup=True)
print('TORCH DONE')
