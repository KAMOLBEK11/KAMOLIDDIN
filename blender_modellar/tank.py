"""Asosiy jang tanki (rasm bo'yicha). blender -b -P tank.py -- <chiqish_papka>"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from lib import *

out = sys.argv[sys.argv.index('--') + 1]
clear()
OL = mat('Olive', '#5f6e3d', 0.75)
OL2 = mat('OliveDark', '#4b5832', 0.8)
DK = mat('Track', '#2a2b28', 0.9)
MT = mat('Metal', '#3a3d36', 0.5, 0.3)
GR = mat('Grille', '#1e1f1c', 0.9)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
LAMP = mat('Lamp', '#d9d9c8', 0.3, 0.0, 1.5)
REAR = mat('RearLamp', '#d9772a', 0.3, 0.0, 1.5)

L, W = 7.6, 3.6
hull = []
hull += tracked_chassis('', L, W, OL, DK, n_wheels=7, wheel_r=0.34)
# pastki korpus (gusenitsalar orasida)
hull.append(profile_y('LowerHull', [(-3.7, 0.4), (3.1, 0.4), (3.9, 1.0), (-3.7, 1.0)], -1.15, 1.15, OL2))
# yuqori korpus + yon ekranlar
hull.append(profile_y('UpperHull', [(-3.8, 0.72), (3.45, 0.72), (4.0, 1.05), (2.7, 1.62), (-3.8, 1.62)], -1.8, 1.8, OL))
# orqa radiator panjaralari
for i in range(3):
    hull.append(box('Grille', (0.35, 1.0, 0.05), (-3.35 + i * 0.45, 0.6, 1.6), GR))
hull.append(box('Grille2', (1.2, 0.5, 0.05), (-2.9, -1.0, 1.6), GR))
# chiroqlar va ilgaklar
for s in (-1, 1):
    hull.append(box('Lamp', (0.06, 0.25, 0.12), (3.72, s * 1.45, 1.22), LAMP))
    hull.append(box('RearLamp', (0.06, 0.25, 0.14), (-3.82, s * 1.45, 1.35), REAR))
    hull.append(box('Hook', (0.12, 0.12, 0.2), (3.55, s * 0.7, 0.9), MT))
    hull.append(box('Hook', (0.12, 0.12, 0.2), (-3.8, s * 0.7, 0.9), MT))
hull_ob = join('Hull', hull, origin=(0, 0, 0))

# --- minora (pivot - minora halqasi markazida)
TX, TZ = 0.25, 1.58
tur = []
tur.append(hull_points('TurretBody', [
    (2.15, -0.95, 0.05), (2.15, 0.95, 0.05), (1.2, -1.6, 0.05), (1.2, 1.6, 0.05),
    (-1.5, -1.6, 0.05), (-1.5, 1.6, 0.05), (-2.0, -1.2, 0.05), (-2.0, 1.2, 0.05),
    (1.85, -0.8, 0.62), (1.85, 0.8, 0.62), (1.0, -1.45, 0.72), (1.0, 1.45, 0.72),
    (-1.4, -1.45, 0.72), (-1.4, 1.45, 0.72), (-1.9, -1.1, 0.65), (-1.9, 1.1, 0.65)], OL, loc=(TX, 0, TZ)))
# stvol niqobi va stvol
tur.append(box('Mantlet', (0.5, 0.75, 0.45), (TX + 2.35, 0, TZ + 0.35), OL2))
tur.append(cyl('Barrel', 0.11, 4.4, (TX + 4.6, 0, TZ + 0.36), OL2, axis='X', verts=10))
tur.append(cyl('Evacuator', 0.17, 0.7, (TX + 4.2, 0, TZ + 0.36), OL2, axis='X', verts=10))
tur.append(cyl('Muzzle', 0.15, 0.35, (TX + 6.65, 0, TZ + 0.36), OL2, axis='X', verts=10))
# komandir lyuki, pulemyot, priborlar, antenna
tur.append(cyl('Cupola', 0.38, 0.14, (TX - 0.1, 0.25, TZ + 0.79), OL2, axis='Z', verts=10))
tur.append(box('MGBase', (0.35, 0.3, 0.25), (TX + 0.3, -0.45, TZ + 0.85), MT))
tur.append(box('MGBody', (0.5, 0.12, 0.12), (TX + 0.55, -0.45, TZ + 1.02), MT))
tur.append(cyl('MGBarrel', 0.03, 0.7, (TX + 1.1, -0.45, TZ + 1.02), MT, axis='X', verts=6))
tur.append(box('Sight', (0.35, 0.3, 0.3), (TX + 0.9, 0.7, TZ + 0.85), OL2))
tur.append(box('SightGlass', (0.04, 0.22, 0.14), (TX + 1.08, 0.7, TZ + 0.88), GR))
tur.append(cyl('Antenna', 0.015, 1.7, (TX - 1.6, -1.15, TZ + 1.55), MT, axis='Z', verts=5))
tur.append(box('Basket', (0.5, 2.0, 0.35), (TX - 2.15, 0, TZ + 0.4), OL2))
tur.append(box('Vent', (0.25, 0.35, 0.05), (TX - 0.9, 1.2, TZ + 0.74), GR))
tur_ob = join('Turret', tur, origin=(TX, 0, TZ))
# jamoa rangi (o'yinda sariq yoki qizilga bo'yaladi)
team = [box('TeamTop', (0.9, 1.4, 0.04), (TX - 0.9, 0, TZ + 0.74), TEAM)]
for s in (-1, 1):
    team.append(hull_points('TeamSide', [(0.6, s * 1.48, 0.25), (-0.6, s * 1.48, 0.25), (0.6, s * 1.48, 0.5), (-0.6, s * 1.48, 0.5),
                                          (0.6, s * 1.53, 0.25), (-0.6, s * 1.53, 0.25), (0.6, s * 1.53, 0.5), (-0.6, s * 1.53, 0.5)], TEAM, loc=(TX - 0.2, 0, TZ)))
team_ob = join('TeamColor', team, origin=(TX, 0, TZ))
parent(tur_ob, hull_ob)
parent(team_ob, tur_ob)

os.makedirs(out, exist_ok=True)
export(os.path.join(out, 'tank'))
render_preview(os.path.join(out, 'tank_preview.png'), target=(0.6, 0, 1.3), dist=17,
               views=((-35, 28), (145, 30), (-90, 0), (0, 89)))
print('TRIS', sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'))
