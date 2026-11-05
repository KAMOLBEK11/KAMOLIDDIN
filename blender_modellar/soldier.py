"""Low-poly askar (rasm bo'yicha). O'yin uchun avtomatni ushlab turgan holatda (T-poza emas)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from lib import *
out = sys.argv[sys.argv.index('--') + 1]
clear()
UN = mat('Uniform', '#55683a', 0.85)
VS = mat('Vest', '#46542f', 0.85)
SK = mat('Skin', '#d6ad86', 0.7)
BT = mat('Boots', '#6b4a2e', 0.8)
BK = mat('Black', '#1c1c1c', 0.6, 0.2)
HL = mat('Helmet', '#4f5d36', 0.7)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
p = []
# oyoqlar (X - oldinga, Y - yon)
for s in (-1, 1):
    y = s * 0.12
    p.append(box('Boot', (0.3, 0.14, 0.14), (0.05, y, 0.07), BT))
    p.append(hull_points('Shin', [(-0.08, y - 0.07, 0.12), (0.08, y - 0.07, 0.12), (-0.08, y + 0.07, 0.12), (0.08, y + 0.07, 0.12),
                                  (-0.09, y - 0.08, 0.5), (0.09, y - 0.08, 0.5), (-0.09, y + 0.08, 0.5), (0.09, y + 0.08, 0.5)], UN))
    p.append(hull_points('Thigh', [(-0.09, y - 0.08, 0.48), (0.09, y - 0.08, 0.48), (-0.09, y + 0.08, 0.48), (0.09, y + 0.08, 0.48),
                                   (-0.11, y - 0.1, 0.9), (0.11, y - 0.1, 0.9), (-0.11, y + 0.1, 0.9), (0.11, y + 0.1, 0.9)], UN))
    p.append(box('Pocket', (0.04, 0.1, 0.12), (0.1, y + s * 0.03, 0.7), VS))
p.append(box('Belt', (0.26, 0.42, 0.08), (0, 0, 0.92), BK))
p.append(hull_points('Torso', [(-0.12, -0.2, 0.9), (0.12, -0.2, 0.9), (-0.12, 0.2, 0.9), (0.12, 0.2, 0.9),
                               (-0.13, -0.24, 1.42), (0.13, -0.24, 1.42), (-0.13, 0.24, 1.42), (0.13, 0.24, 1.42)], UN))
p.append(hull_points('Vest', [(-0.15, -0.21, 0.98), (0.16, -0.21, 0.98), (-0.15, 0.21, 0.98), (0.16, 0.21, 0.98),
                              (-0.15, -0.22, 1.38), (0.16, -0.22, 1.38), (-0.15, 0.22, 1.38), (0.16, 0.22, 1.38)], VS))
for i, yy in enumerate((-0.12, 0.0, 0.12)):
    p.append(box('Pouch', (0.06, 0.1, 0.13), (0.19, yy, 1.08), VS))
p.append(box('Backpack', (0.18, 0.36, 0.42), (-0.24, 0, 1.18), VS))
p.append(box('Bedroll', (0.12, 0.34, 0.1), (-0.24, 0, 1.43), UN))
p.append(box('Neck', (0.1, 0.1, 0.08), (0, 0, 1.46), SK))
p.append(hull_points('Head', [(-0.1, -0.09, 1.49), (0.11, -0.09, 1.49), (-0.1, 0.09, 1.49), (0.11, 0.09, 1.49),
                              (-0.1, -0.1, 1.7), (0.11, -0.1, 1.7), (-0.1, 0.1, 1.7), (0.11, 0.1, 1.7)], SK))
p.append(cyl('Helmet', 0.15, 0.12, (0.0, 0, 1.73), HL, axis='Z', verts=10, r2=0.12))
p.append(cyl('HelmetTop', 0.12, 0.06, (0.0, 0, 1.82), HL, axis='Z', verts=10, r2=0.05))
p.append(box('ChinStrap', (0.02, 0.2, 0.03), (0.06, 0, 1.52), BK))
# qo'llar: yelka -> tirsak oldinga -> avtomat ushlagan
for s in (-1, 1):
    sy = s * 0.28
    p.append(hull_points('UpperArm', [(-0.05, sy - 0.05, 1.4), (0.05, sy - 0.05, 1.4), (-0.05, sy + 0.05, 1.4), (0.05, sy + 0.05, 1.4),
                                      (0.08, sy * 0.85 - 0.05, 1.12), (0.18, sy * 0.85 - 0.05, 1.12), (0.08, sy * 0.85 + 0.05, 1.12), (0.18, sy * 0.85 + 0.05, 1.12)], UN))
    hy = 0.05 if s > 0 else -0.08
    p.append(hull_points('Forearm', [(0.1, sy * 0.85 - 0.045, 1.1), (0.18, sy * 0.85 - 0.045, 1.1), (0.1, sy * 0.85 + 0.045, 1.16), (0.18, sy * 0.85 + 0.045, 1.16),
                                     (0.36 if s > 0 else 0.2, hy - 0.04, 1.14), (0.42 if s > 0 else 0.27, hy - 0.04, 1.14),
                                     (0.36 if s > 0 else 0.2, hy + 0.04, 1.2), (0.42 if s > 0 else 0.27, hy + 0.04, 1.2)], UN))
    p.append(box('Hand', (0.08, 0.07, 0.08), ((0.44 if s > 0 else 0.28), hy, 1.17), SK))
# avtomat (oldinga qaragan)
p.append(box('RifleBody', (0.5, 0.05, 0.1), (0.35, 0.0, 1.22), BK))
p.append(box('Stock', (0.22, 0.05, 0.12), (0.03, -0.02, 1.2), BK))
p.append(box('Mag', (0.06, 0.04, 0.16), (0.34, 0.0, 1.11), BK))
p.append(cyl('RifleBarrel', 0.015, 0.35, (0.77, 0.0, 1.24), BK, axis='X', verts=6))
p.append(box('Grip', (0.05, 0.04, 0.1), (0.22, 0.0, 1.13), BK))
body = join('Soldier', p, origin=(0, 0, 0))
team = join('TeamColor', [box('Armband1', (0.11, 0.02, 0.07), (0.03, 0.335, 1.3), TEAM),
                          box('Armband2', (0.11, 0.02, 0.07), (0.03, -0.335, 1.3), TEAM),
                          cyl('HelmetBand', 0.152, 0.035, (0.0, 0, 1.71), TEAM, axis='Z', verts=10)], origin=(0, 0, 0))
parent(team, body)
os.makedirs(out, exist_ok=True)
export(os.path.join(out, 'soldier'))
render_preview(os.path.join(out, 'soldier_preview.png'), target=(0.1, 0, 0.95), dist=3.6, views=((-30, 15), (160, 15), (-90, 0)))
