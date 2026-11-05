"""Shahar uylari (zamonaviy, real ko'rinishda): hovli uylari, 2 qavatli uy, ko'p qavatli uylar, do'kon, ombor,
poyezd (lokomotiv + vagonlar). blender -b -P houses.py -- <models_papka>
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

out = sys.argv[sys.argv.index('--') + 1]
tmp = '/home/claude/work/houses_out'
os.makedirs(tmp, exist_ok=True)
os.makedirs(os.path.join(out, 'houses'), exist_ok=True)


def exp(name, sub='houses'):
    import shutil
    p = os.path.join(tmp, name)
    export(p)
    shutil.copy(p + '.glb', os.path.join(out, sub, name + '.glb'))


def roof_gable(name, w, l, z, h, m, over=0.4):
    """Ikki nishabli tom: w - kenglik (Y), l - uzunlik (X)."""
    return hull_points(name, [(-l / 2 - over, -w / 2 - over, z), (l / 2 + over, -w / 2 - over, z),
                              (-l / 2 - over, w / 2 + over, z), (l / 2 + over, w / 2 + over, z),
                              (-l / 2 - over, 0, z + h), (l / 2 + over, 0, z + h)], m)


def roof_hip(name, w, l, z, h, m, over=0.4):
    return hull_points(name, [(-l / 2 - over, -w / 2 - over, z), (l / 2 + over, -w / 2 - over, z),
                              (-l / 2 - over, w / 2 + over, z), (l / 2 + over, w / 2 + over, z),
                              (-l / 2 + w * 0.4, 0, z + h), (l / 2 - w * 0.4, 0, z + h)], m)


def win_row(m, frame, x0, x1, y, z, n, w=1.0, h=1.3, face=-1):
    p = []
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        p.append(box('Frame', (w + 0.2, 0.12, h + 0.2), (x, y + face * 0.04, z), frame))
        p.append(box('Win', (w, 0.14, h), (x, y + face * 0.07, z), m))
    return p


def house(name, seed, two=False):
    random.seed(seed)
    clear()
    walls = random.choice(['#e9e1cf', '#d9c7a6', '#efe9dd', '#cdb894', '#e4d3b8'])
    wall = mat('Wall', walls, 0.85)
    roofc = random.choice(['#8a3f2c', '#5b6168', '#7a5a3a', '#4d5a46'])
    roof = mat('Roof', roofc, 0.7)
    glass = mat('Glass', '#3a5a78', 0.08, 0.3)
    frame = mat('WinFrame', '#f4f4f0', 0.6)
    door = mat('Door', '#5a3a24', 0.7)
    base = mat('Concrete', '#8d8a82', 0.9)
    L, W = random.uniform(9, 12), random.uniform(7, 9)
    H = 6.0 if two else 3.4
    p = [box('Plinth', (L + 0.4, W + 0.4, 0.5), (0, 0, 0.25), base),
         box('Body', (L, W, H), (0, 0, 0.5 + H / 2), wall)]
    rows = 2 if two else 1
    for r in range(rows):
        z = 2.1 + r * 2.8
        p += win_row(glass, frame, -L / 2 + 0.8, L / 2 - 0.8, -W / 2, z, 3)
        p += win_row(glass, frame, -L / 2 + 0.8, L / 2 - 0.8, W / 2, z, 3, face=1)
    p.append(box('Door', (1.1, 0.15, 2.1), (L * 0.25, -W / 2 - 0.05, 1.55), door))
    p.append(box('Step', (1.8, 1.0, 0.3), (L * 0.25, -W / 2 - 0.5, 0.15), base))
    if random.random() < 0.5:
        p.append(roof_gable('Roof', W, L, 0.5 + H, 2.6, roof))
    else:
        p.append(roof_hip('Roof', W, L, 0.5 + H, 2.4, roof))
    p.append(box('Chimney', (0.7, 0.7, 2.0), (-L * 0.25, W * 0.15, H + 2.6), mat('Brick', '#8e4b38', 0.85)))
    # hovli devori va darvoza
    fence = mat('Fence', '#b8ab92', 0.9)
    for s in (-1, 1):
        p.append(box('Fence', (0.25, W + 6, 1.6), (s * (L / 2 + 3), 0, 0.8), fence))
    p.append(box('FenceB', (L + 6, 0.25, 1.6), (0, W / 2 + 3, 0.8), fence))
    p.append(box('Gate', (2.5, 0.2, 1.8), (-L * 0.25, -W / 2 - 3, 0.9), mat('Gate', '#3d5a6b', 0.5, 0.5)))
    for s in (-1, 1):
        p.append(box('FenceF', (L / 2 + 1.0, 0.25, 1.6), (s * (L / 4 + 2.0) + (0.5 if s > 0 else -1.2), -W / 2 - 3, 0.8), fence))
    join('House', p, origin=(0, 0, 0))
    exp(name)


def apartment(name, floors, seed):
    random.seed(seed)
    clear()
    wall = mat('Wall', random.choice(['#e3ddd2', '#cfc6b6', '#d8d2c6', '#c2b8a5']), 0.85)
    accent = mat('Accent', random.choice(['#8a4a3a', '#3f6c8a', '#6b7a52', '#a07a3a']), 0.7)
    glass = mat('Glass', '#2f4a63', 0.06, 0.4)
    frame = mat('WinFrame', '#f0f0ea', 0.6)
    base = mat('Concrete', '#7d7a72', 0.9)
    L, W = 26.0, 11.0
    fh = 3.0
    H = floors * fh
    p = [box('Plinth', (L + 0.6, W + 0.6, 1.0), (0, 0, 0.5), base),
         box('Body', (L, W, H), (0, 0, 1.0 + H / 2), wall)]
    for f in range(floors):
        z = 1.0 + f * fh + 1.6
        p += win_row(glass, frame, -L / 2 + 1, L / 2 - 1, -W / 2, z, 8, 1.4, 1.5)
        p += win_row(glass, frame, -L / 2 + 1, L / 2 - 1, W / 2, z, 8, 1.4, 1.5, face=1)
        if f > 0:
            for i in (1, 3, 4, 6):
                x = -L / 2 + 1 + (L - 2) * (i + 0.5) / 8
                p.append(box('Balcony', (2.4, 1.2, 0.15), (x, -W / 2 - 0.6, z - 1.0), base))
                p.append(box('BalRail', (2.4, 0.08, 1.0), (x, -W / 2 - 1.15, z - 0.45), accent))
    # zinapoya bloklari (vertikal chiziq)
    for x in (-L / 4, L / 4):
        p.append(box('Stair', (2.6, 0.3, H), (x, -W / 2 - 0.1, 1.0 + H / 2), accent))
        p.append(box('Entrance', (2.4, 1.8, 0.2), (x, -W / 2 - 0.9, 3.3), base))
    p.append(box('RoofTop', (L + 0.4, W + 0.4, 0.5), (0, 0, 1.0 + H + 0.25), base))
    p.append(box('RoofBox', (4, 3, 2), (L * 0.3, 0, 1.0 + H + 1.5), wall))
    join('Apartment', p, origin=(0, 0, 0))
    exp(name)


def shop():
    clear()
    wall = mat('Wall', '#e8e4dc', 0.8)
    glass = mat('Glass', '#3a6488', 0.05, 0.4)
    sign = mat('TeamColor', '#2f7d4a', 0.5)
    base = mat('Concrete', '#7d7a72', 0.9)
    p = [box('Pad', (20, 16, 0.3), (0, -2, 0.15), mat('Asphalt', '#4a4c4f', 0.95)),
         box('Body', (16, 10, 4.5), (0, 2, 2.55), wall),
         box('Front', (15, 0.2, 3.0), (0, -3.05, 2.0), glass),
         box('Sign', (10, 0.3, 1.0), (0, -3.2, 4.2), sign),
         box('Canopy', (16.5, 2.5, 0.25), (0, -4.2, 3.6), base)]
    for i in range(3):
        p.append(box('Car', (4.2, 1.8, 1.3), (-5 + i * 5, -7.5, 0.95), mat('Car%d' % i, ['#9c2f2f', '#2f4f7c', '#d8d8d2'][i], 0.25, 0.6)))
    join('Shop', p, origin=(0, 0, 0))
    exp('shop')


def warehouse():
    clear()
    m = mat('Metal', '#8b949b', 0.45, 0.4)
    wall = mat('Wall', '#b9b3a5', 0.85)
    prof = [(math.cos(a) * 9, 0.3 + math.sin(a) * 6) for a in [i / 14 * math.pi for i in range(15)]]
    p = [box('Pad', (24, 20, 0.3), (0, 0, 0.15), mat('Concrete', '#7d7a72', 0.9)),
         profile_y('Shed', prof, -8, 8, m),
         box('Door', (7, 0.3, 5), (0, -8.05, 2.8), mat('Dark', '#33373b', 0.6))]
    for i in range(4):
        p.append(box('Pallet', (1.6, 1.4, 1.2), (-9 + i * 1.9, -10, 0.9), wall))
    join('Warehouse', p, origin=(0, 0, 0))
    exp('warehouse')


def train():
    clear()
    body = mat('Loco', '#2f5d3a', 0.45, 0.4)
    stripe = mat('Stripe', '#e0b030', 0.5)
    dark = mat('Dark', '#222428', 0.7)
    glass = mat('Glass', '#2a3a4a', 0.05, 0.4)
    p = [box('Body', (16, 3.0, 3.6), (0, 0, 2.6), body),
         box('Stripe', (16.1, 3.1, 0.35), (0, 0, 2.0), stripe),
         box('Cab', (3, 3.0, 1.0), (6.2, 0, 4.9), body),
         box('Glass', (0.15, 2.4, 1.0), (7.75, 0, 3.6), glass),
         box('Chassis', (15, 2.6, 0.8), (0, 0, 0.8), dark)]
    for x in (-5.5, -3.8, 3.8, 5.5):
        for s in (-1, 1):
            p.append(cyl('Wheel', 0.5, 0.3, (x, s * 1.2, 0.5), dark, axis='Y', verts=12))
    join('Locomotive', p, origin=(0, 0, 0))
    exp('locomotive', 'units')
    clear()
    tank = mat('Tanker', '#3d4248', 0.4, 0.5)
    dark = mat('Dark', '#222428', 0.7)
    p = [cyl('Tank', 1.5, 13, (0, 0, 2.4), tank, axis='X', verts=16),
         box('Chassis', (14, 2.4, 0.6), (0, 0, 0.8), dark)]
    for x in (-5, -3.6, 3.6, 5):
        for s in (-1, 1):
            p.append(cyl('Wheel', 0.5, 0.3, (x, s * 1.1, 0.5), dark, axis='Y', verts=12))
    join('Wagon', p, origin=(0, 0, 0))
    exp('wagon', 'units')


for i in range(4):
    house('house%d' % i, 10 + i, two=(i % 2 == 1))
apartment('apt5', 5, 3)
apartment('apt9', 9, 4)
shop()
warehouse()
train()
print('HOUSES DONE')
