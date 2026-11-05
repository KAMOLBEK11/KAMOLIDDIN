"""6x6 raketa mashinasi (rasm bo'yicha). Launcher - ko'tariladigan qism."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from lib import *
out = sys.argv[sys.argv.index('--') + 1]
clear()
GN = mat('Green', '#3f5e32', 0.8)
GN2 = mat('GreenDark', '#2f4626', 0.8)
TY = mat('Tyre', '#1f1f1d', 0.95)
MT = mat('Metal', '#2e2f2b', 0.5, 0.3)
GL = mat('Glass', '#4a6a7a', 0.2, 0.0, 0.5)
WH = mat('MissileWhite', '#e6e6e0', 0.5)
RD = mat('MissileRed', '#c0322b', 0.5)
TEAM = mat('TeamColor', '#e8b73a', 0.6)
truck = []
truck.append(box('Chassis', (7.2, 1.3, 0.35), (-0.3, 0, 1.0), MT))
truck.append(hull_points('Cab', [(2.3, -1.25, 1.0), (2.3, 1.25, 1.0), (3.75, -1.25, 1.0), (3.75, 1.25, 1.0),
                                 (2.3, -1.2, 2.75), (2.3, 1.2, 2.75), (3.2, -1.2, 2.75), (3.2, 1.2, 2.75), (3.75, -1.2, 2.0), (3.75, 1.2, 2.0)], GN))
truck.append(box('Windshield', (0.05, 2.1, 0.6), (3.5, 0, 2.35), GL, rot=(0, -0.55, 0)))
for s in (-1, 1):
    truck.append(box('SideWindow', (0.8, 0.05, 0.5), (2.85, s * 1.24, 2.3), GL))
    truck.append(box('Mirror', (0.06, 0.2, 0.35), (3.6, s * 1.4, 2.4), MT))
    truck.append(box('Fender', (1.2, 0.5, 0.15), (3.0, s * 1.05, 1.55), GN2))
truck.append(box('Grille', (0.05, 1.4, 0.5), (3.78, 0, 1.35), MT))
truck.append(box('Bumper', (0.2, 2.4, 0.25), (3.85, 0, 0.95), MT))
truck.append(box('Platform', (4.8, 2.4, 0.3), (-0.85, 0, 1.35), GN))
truck.append(box('Box1', (1.0, 0.6, 0.6), (1.4, 0.8, 1.8), GN2))
truck.append(box('Box2', (1.0, 0.6, 0.6), (1.4, -0.8, 1.8), GN2))
truck.append(box('Spare', (0.3, 0.9, 0.9), (1.85, 0, 1.95), TY))
for x in (2.85, -1.25, -2.6):
    for s in (-1, 1):
        truck.append(cyl('Tyre', 0.58, 0.42, (x, s * 1.05, 0.58), TY, verts=14))
        truck.append(cyl('Rim', 0.28, 0.46, (x, s * 1.05, 0.58), GN2, verts=10))
for s in (-1, 1):
    truck.append(box('RearLamp', (0.05, 0.25, 0.12), (-3.27, s * 0.95, 1.3), RD))
truck.append(box('Hydraulic', (1.6, 0.2, 0.2), (-1.2, 0, 1.75), MT, rot=(0, -0.45, 0)))
truck_ob = join('Hull', truck, origin=(0, 0, 0))
# Launcher: pivot - orqa tayanchda, 0 burchakda gorizontal, oldinga qaragan
PX, PZ = -2.9, 1.6
ln = [box('Rail', (6.0, 0.5, 0.25), (PX + 3.0, 0, PZ + 0.15), GN2)]
ln.append(cyl('MissileBody', 0.32, 5.2, (PX + 2.9, 0, PZ + 0.62), WH, axis='X', verts=12))
ln.append(cyl('MissileNose', 0.32, 1.2, (PX + 6.1, 0, PZ + 0.62), RD, axis='X', verts=12, r2=0.0))
for a in range(4):
    ang = a * math.pi / 2 + math.pi / 4
    f = box('Fin', (0.7, 0.04, 0.55), (PX + 0.55, math.cos(ang) * 0.45, PZ + 0.62 + math.sin(ang) * 0.45), WH, rot=(ang - math.pi / 2, 0, 0))
    ln.append(f)
ln.append(box('Cradle1', (0.3, 0.8, 0.5), (PX + 1.5, 0, PZ + 0.35), MT))
ln.append(box('Cradle2', (0.3, 0.8, 0.5), (PX + 4.0, 0, PZ + 0.35), MT))
ln_ob = join('Launcher', ln, origin=(PX, 0, PZ))
ln_ob.rotation_euler = (0, -math.radians(28), 0)
team_ob = join('TeamColor', [box('TeamDoor1', (0.7, 0.04, 0.35), (2.8, 1.27, 1.6), TEAM),
                             box('TeamDoor2', (0.7, 0.04, 0.35), (2.8, -1.27, 1.6), TEAM),
                             box('TeamRoof', (0.7, 1.6, 0.04), (2.7, 0, 2.77), TEAM)], origin=(0, 0, 0))
parent(ln_ob, truck_ob)
parent(team_ob, truck_ob)
os.makedirs(out, exist_ok=True)
export(os.path.join(out, 'missile_truck'))
render_preview(os.path.join(out, 'missile_preview.png'), target=(0.3, 0, 1.8), dist=17, views=((-35, 25), (-90, 0)))
