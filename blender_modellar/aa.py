"""Gusenitsali PVO (rasm bo'yicha): qo'sh to'plar, raketa quvurlari, aylanadigan radar."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from lib import *
out = sys.argv[sys.argv.index('--') + 1]
clear()
OL = mat('Olive', '#5f6e3d', 0.75)
OL2 = mat('OliveDark', '#4b5832', 0.8)
DK = mat('Track', '#2a2b28', 0.9)
MT = mat('Metal', '#2e2f2b', 0.5, 0.3)
GR = mat('Grille', '#1e1f1c', 0.9)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
L, W = 7.4, 3.4
hull = tracked_chassis('', L, W, OL, DK, n_wheels=7, wheel_r=0.34)
hull.append(profile_y('LowerHull', [(-3.6, 0.4), (3.0, 0.4), (3.8, 1.0), (-3.6, 1.0)], -1.1, 1.1, OL2))
hull.append(profile_y('UpperHull', [(-3.7, 0.72), (3.4, 0.72), (3.9, 1.15), (3.3, 1.55), (-3.7, 1.55)], -1.7, 1.7, OL))
for i in range(4):
    hull.append(box('Grille', (0.3, 1.2, 0.05), (-3.3 + i * 0.4, 0.0, 1.57), GR))
hull_ob = join('Hull', hull, origin=(0, 0, 0))
TX, TZ = 0.2, 1.55
tur = [hull_points('TurretBody', [(1.4, -0.9, 0), (1.4, 0.9, 0), (-1.5, -1.1, 0), (-1.5, 1.1, 0),
                                  (1.2, -0.8, 0.95), (1.2, 0.8, 0.95), (-1.4, -1.0, 0.95), (-1.4, 1.0, 0.95)], OL, loc=(TX, 0, TZ))]
for s in (-1, 1):
    y = s * 1.25
    tur.append(box('GunPod', (1.0, 0.45, 0.55), (TX + 0.9, y, TZ + 0.6), OL2))
    for k in (-1, 1):
        tur.append(cyl('Gun', 0.06, 2.4, (TX + 2.5, y + k * 0.12, TZ + 0.62), MT, axis='X', verts=8))
        tur.append(cyl('Muzzle', 0.09, 0.3, (TX + 3.6, y + k * 0.12, TZ + 0.62), MT, axis='X', verts=8))
    for j in range(3):
        tur.append(cyl('MissileTube', 0.16, 1.6, (TX - 0.4, s * 1.3, TZ + 0.25 + j * 0.33), OL2, axis='X', verts=10))
        tur.append(cyl('TubeCap', 0.12, 0.05, (TX + 0.42, s * 1.3, TZ + 0.25 + j * 0.33), GR, axis='X', verts=10))
tur.append(cyl('RadarMast', 0.1, 0.7, (TX - 0.6, 0, TZ + 1.3), MT, axis='Z', verts=8))
tur_ob = join('Turret', tur, origin=(TX, 0, TZ))
radar_ob = join('Radar', [box('RadarDish', (0.25, 1.9, 1.0), (TX - 0.6, 0, TZ + 2.05), OL2),
                          box('RadarFace', (0.05, 1.7, 0.85), (TX - 0.45, 0, TZ + 2.05), OL)], origin=(TX - 0.6, 0, TZ + 1.7))
team_ob = join('TeamColor', [box('TeamTop', (1.2, 1.2, 0.04), (TX - 0.2, 0, TZ + 0.97), TEAM)], origin=(TX, 0, TZ))
parent(tur_ob, hull_ob)
parent(radar_ob, tur_ob)
parent(team_ob, tur_ob)
os.makedirs(out, exist_ok=True)
export(os.path.join(out, 'aa'))
render_preview(os.path.join(out, 'aa_preview.png'), target=(0.3, 0, 1.6), dist=17, views=((-35, 28), (-90, 0)))
