"""8x8 BTR (rasm bo'yicha)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from lib import *
out = sys.argv[sys.argv.index('--') + 1]
clear()
SD = mat('Sand', '#c4a66c', 0.8)
SD2 = mat('SandDark', '#a88d58', 0.8)
TY = mat('Tyre', '#1f1f1d', 0.95)
MT = mat('Metal', '#2e2f2b', 0.5, 0.3)
GL = mat('Glass', '#3b6f8a', 0.2, 0.0, 0.6)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
RED = mat('RearLamp', '#c4302b', 0.3, 0.0, 1.5)
hull = []
hull.append(hull_points('Body', [
    (-3.8, -1.15, 0.6), (-3.8, 1.15, 0.6), (3.2, -1.0, 0.6), (3.2, 1.0, 0.6),
    (-3.9, -1.5, 1.25), (-3.9, 1.5, 1.25), (3.95, -1.35, 1.3), (3.95, 1.35, 1.3),
    (-3.85, -1.45, 2.15), (-3.85, 1.45, 2.15), (3.1, -1.4, 2.15), (3.1, 1.4, 2.15), (3.95, -1.1, 1.75), (3.95, 1.1, 1.75)], SD))
for x in (-2.75, -1.35, 0.95, 2.35):
    for s in (-1, 1):
        hull.append(cyl('Tyre', 0.62, 0.48, (x, s * 1.3, 0.62), TY, verts=14))
        hull.append(cyl('Rim', 0.32, 0.52, (x, s * 1.3, 0.62), SD2, verts=10))
for s in (-1, 1):
    hull.append(box('Door', (1.3, 0.05, 0.9), (-0.9 + (0.0 if s > 0 else 1.6), s * 1.47, 1.65), SD2))
    hull.append(box('Mirror', (0.06, 0.22, 0.3), (3.55, s * 1.68, 2.05), MT))
    hull.append(box('MirrorArm', (0.05, 0.35, 0.05), (3.55, s * 1.48, 1.95), MT))
    hull.append(box('Light', (0.05, 0.3, 0.12), (3.96, s * 0.95, 1.55), GL))
    hull.append(box('RearLamp', (0.05, 0.25, 0.35), (-3.9, s * 1.15, 1.6), RED))
hull.append(box('RearDoor', (0.05, 1.3, 0.9), (-3.88, 0, 1.45), SD2))
hull.append(box('Grille', (0.9, 0.05, 0.4), (-3.2, 1.47, 1.75), MT))
hull.append(box('Grille2', (0.6, 0.9, 0.04), (-2.6, 0.5, 2.17), MT))
hull.append(cyl('Antenna', 0.015, 2.0, (-3.5, -1.1, 3.15), MT, axis='Z', verts=5))
hull_ob = join('Hull', hull, origin=(0, 0, 0))
TX, TZ = 0.4, 2.15
tur = [hull_points('TurretBody', [(1.0, -0.6, 0), (1.0, 0.6, 0), (0.3, -1.0, 0), (0.3, 1.0, 0), (-1.0, -1.0, 0), (-1.0, 1.0, 0),
                                  (0.8, -0.5, 0.55), (0.8, 0.5, 0.55), (0.2, -0.85, 0.6), (0.2, 0.85, 0.6), (-0.9, -0.85, 0.6), (-0.9, 0.85, 0.6)], SD, loc=(TX, 0, TZ))]
tur.append(box('GunMount', (0.5, 0.35, 0.3), (TX + 1.05, 0, TZ + 0.3), SD2))
tur.append(cyl('Gun', 0.07, 2.3, (TX + 2.35, 0, TZ + 0.3), MT, axis='X', verts=8))
tur.append(cyl('GunTip', 0.1, 0.3, (TX + 3.4, 0, TZ + 0.3), MT, axis='X', verts=8))
tur.append(box('Sight', (0.35, 0.3, 0.35), (TX + 0.4, 0.55, TZ + 0.75), SD2))
tur.append(box('SightGlass', (0.04, 0.2, 0.18), (TX + 0.58, 0.55, TZ + 0.78), GL))
tur_ob = join('Turret', tur, origin=(TX, 0, TZ))
team_ob = join('TeamColor', [box('TeamTop', (0.7, 0.9, 0.04), (TX - 0.4, 0, TZ + 0.62), TEAM),
                             box('TeamSide1', (1.0, 0.04, 0.25), (-2.4, 1.5, 1.9), TEAM),
                             box('TeamSide2', (1.0, 0.04, 0.25), (-2.4, -1.5, 1.9), TEAM)], origin=(TX, 0, TZ))
parent(tur_ob, hull_ob)
parent(team_ob, hull_ob)
os.makedirs(out, exist_ok=True)
export(os.path.join(out, 'apc'))
render_preview(os.path.join(out, 'apc_preview.png'), target=(0.3, 0, 1.4), dist=16, views=((-35, 28), (-90, 0)))
