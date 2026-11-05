"""Viloyat bazasi binolari (Generals uslubi). blender -b -P buildings.py -- <chiqish_papka>
Har bir bino alohida .glb: hokimiyat, zavodlar, kon, harbiy zavod, laboratoriyalar, aerodrom, aeroport,
kazarma, tank parki, kema zavodi, siyosiy markaz. Animatsiya qismlari nomlangan: Beam (neft nasosi),
Dish (radar), Crane (kran), Smoke* (tutun nuqtalari), Flag/TeamColor (jamoa rangi).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

out = sys.argv[sys.argv.index('--') + 1]
os.makedirs(out, exist_ok=True)


def M():
    return {
        'wall': mat('Wall', '#d9cdb4', 0.85), 'wall2': mat('Wall2', '#b9ab90', 0.85),
        'roof': mat('Roof', '#6b4a3a', 0.8), 'metal': mat('Metal', '#8b949b', 0.45, 0.4),
        'dark': mat('Dark', '#33373b', 0.7), 'conc': mat('Concrete', '#76766f', 0.95),
        'glass': mat('Glass', '#4f7fa6', 0.1, 0.3), 'green': mat('Olive', '#5f6e3d', 0.75),
        'olive2': mat('Olive2', '#4b5832', 0.8), 'red': mat('Brick', '#9a4a35', 0.85),
        'white': mat('White', '#d6d4cc', 0.7), 'team': mat('TeamColor', '#e8b73a', 0.5),
        'asphalt': mat('Asphalt', '#3d3f41', 0.95), 'line': mat('Line', '#f2f2f2', 0.7),
        'gold': mat('Gold', '#d8b04a', 0.3, 0.6), 'oil': mat('OilTank', '#cfcfc8', 0.5, 0.2),
        'yellow': mat('Yellow', '#e0b030', 0.6), 'water': mat('Water', '#2c5d7a', 0.1),
    }


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.collection.objects.link(e)
    return e


def ground_pad(m, sx, sy, mat_key='conc'):
    return box('Pad', (sx, sy, 0.3), (0, 0, 0.15), m[mat_key])


def flagpole(m, x, y, h=12):
    pole = cyl('Pole', 0.12, h, (x, y, h / 2), m['metal'], axis='Z', verts=8)
    flag = box('Flag', (2.6, 0.06, 1.6), (x + 1.4, y, h - 1.0), m['team'])
    flag.name = 'TeamColor'
    return pole, flag


def windows(m, x0, x1, y, z0, rows, cols, w=1.2, h=1.4, face=1):
    out_ = []
    for r in range(rows):
        for c in range(cols):
            x = x0 + (x1 - x0) * (c + 0.5) / cols
            out_.append(box('Win', (w, 0.1, h), (x, y + face * 0.05, z0 + r * 3.2), m['glass']))
    return out_


def finish(name, parts, extra=()):
    ob = join(name, parts, origin=(0, 0, 0))
    for e in extra:
        if e.type != 'EMPTY':
            pass
    export(os.path.join(out, name))


# ------------------------------------------------------------------ hokimiyat (markaz)
def hq():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 46, 40))
    p.append(box('Body', (30, 18, 12), (0, 0, 6.3), m['wall']))
    p.append(box('WingL', (10, 14, 9), (-19, 0, 4.8), m['wall2']))
    p.append(box('WingR', (10, 14, 9), (19, 0, 4.8), m['wall2']))
    p.append(box('Cornice', (31, 19, 0.8), (0, 0, 12.6), m['white']))
    # portik
    p.append(box('Steps', (16, 5, 1.2), (0, -11.5, 0.9), m['white']))
    p.append(box('Porch', (14, 4, 0.6), (0, -10.5, 1.6), m['white']))
    for i in range(6):
        p.append(cyl('Column', 0.55, 9.5, (-6 + i * 2.4, -10.8, 6.4), m['white'], axis='Z', verts=12))
    p.append(hull_points('Pediment', [(-7.5, -12.5, 11.2), (7.5, -12.5, 11.2), (0, -12.5, 14.5),
                                      (-7.5, -9, 11.2), (7.5, -9, 11.2), (0, -9, 14.5)], m['white']))
    # gumbaz
    p.append(cyl('Drum', 5.5, 3.5, (0, 0, 14.6), m['wall2'], axis='Z', verts=24))
    dome = []
    for k in range(9):
        a = k / 8 * math.pi / 2
        for j in range(16):
            t = j / 16 * math.tau
            dome.append((math.cos(t) * 5.6 * math.cos(a), math.sin(t) * 5.6 * math.cos(a), 16.3 + 5.0 * math.sin(a)))
    p.append(hull_points('Dome', dome, m['gold']))
    p.extend(windows(m, -13, 13, -9.05, 4, 3, 8, face=-1))
    p.extend(windows(m, -23, -15, -7.05, 3, 2, 3, face=-1))
    p.extend(windows(m, 15, 23, -7.05, 3, 2, 3, face=-1))
    pole, flag = flagpole(m, 0, 0, 26)
    p.append(pole)
    team = join('TeamColor', [flag])
    finish('hq', p)


# ------------------------------------------------------------------ siyosiy markaz
def politic():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 30, 26))
    p.append(box('Body', (22, 14, 10), (0, 0, 5.3), m['white']))
    p.append(box('Top', (18, 11, 3), (0, 0, 11.8), m['wall']))
    p.append(box('Steps', (12, 4, 1), (0, -9, 0.8), m['white']))
    for i in range(5):
        p.append(cyl('Column', 0.5, 8, (-5 + i * 2.5, -7.8, 5.3), m['wall'], axis='Z', verts=10))
    p.append(box('Roof', (23, 15, 0.8), (0, 0, 10.6), m['dark']))
    p.extend(windows(m, -9, 9, 7.05, 3, 2, 6))
    for x in (-8, 8):
        pole, flag = flagpole(m, x, -11, 10)
        p.append(pole); flag.name = 'TeamColor_f'
        p.append(flag)
    # antenna/sun'iy yo'ldosh
    p.append(cyl('Antenna', 0.1, 6, (6, 3, 16), m['metal'], axis='Z', verts=6))
    finish('politic', p)


# ------------------------------------------------------------------ fuqarolik zavodi
def civil():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 44, 32))
    # arra tishli tom (sawtooth)
    for i in range(5):
        x = -14 + i * 6.5
        p.append(box('Hall', (6.5, 22, 7), (x, 0, 3.8), m['red']))
        p.append(hull_points('Saw', [(x - 3.25, -11, 7.3), (x - 3.25, 11, 7.3), (x + 3.25, -11, 7.3), (x + 3.25, 11, 7.3),
                                     (x - 3.25, -11, 10), (x - 3.25, 11, 10)], m['metal']))
        p.append(box('SawGlass', (0.15, 21, 2.4), (x - 3.15, 0, 8.7), m['glass']))
    p.append(box('Office', (10, 8, 9), (19, -6, 4.8), m['wall']))
    p.extend(windows(m, 15, 23, -10.05, 3, 2, 3, face=-1))
    for k, (x, y) in enumerate(((10, 8), (14, 8))):
        p.append(cyl('Chimney', 1.1, 22, (x, y, 11), m['red'], axis='Z', verts=12, r2=0.8))
        p.append(cyl('Ring', 1.0, 0.8, (x, y, 19), m['white'], axis='Z', verts=12))
        empty('Smoke%d' % k, (x, y, 22.5))
    for i in range(3):
        p.append(box('Crate', (2, 2, 2), (-18 + i * 2.3, -14, 1.3), m['wall2']))
    p.append(box('Truck', (6, 2.4, 2.8), (6, -14, 1.7), m['dark']))
    finish('civil', p)


# ------------------------------------------------------------------ kon / neft bazasi
def mine():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 40, 34, 'conc'))
    # neft tanklari
    for i, (x, y) in enumerate(((-12, 8), (-4, 8), (-12, -2))):
        p.append(cyl('Tank', 3.6, 7, (x, y, 3.8), m['oil'], axis='Z', verts=20))
        p.append(cyl('TankTop', 3.7, 0.4, (x, y, 7.4), m['metal'], axis='Z', verts=20))
    p.append(box('Pipe', (20, 0.5, 0.5), (0, 3, 1.2), m['metal']))
    p.append(box('Shed', (8, 6, 4), (10, 10, 2.3), m['wall2']))
    # nasos tayanchi (Beam alohida - animatsiya uchun)
    for s in (-1, 1):
        p.append(hull_points('Samson', [(6, s * 1.2 - 8, 0.3), (10, s * 1.2 - 8, 0.3), (8, s * 0.3 - 8, 7)], m['yellow']))
    p.append(box('Base', (12, 3, 0.8), (8, -8, 0.6), m['dark']))
    p.append(box('Motor', (2, 2, 2), (11.5, -8, 1.6), m['dark']))
    p.append(cyl('Well', 0.4, 3, (2.5, -8, 1.8), m['metal'], axis='Z', verts=8))
    finish('mine', p)
    # Beam: alohida obyekt, pivot tayanch tepasida
    beam = [box('BeamBar', (9, 0.6, 0.8), (8, -8, 7.3), m['yellow']),
            hull_points('Head', [(3.0, -8.4, 5.5), (3.0, -7.6, 5.5), (3.6, -8.4, 8.6), (3.6, -7.6, 8.6), (4.2, -8.4, 7.3), (4.2, -7.6, 7.3)], m['yellow']),
            box('Counter', (1.6, 1.4, 1.6), (12.3, -8, 6.6), m['dark'])]
    bo = join('Beam', beam, origin=(8, -8, 7.2))
    bpy.ops.object.select_all(action='DESELECT')
    export(os.path.join(out, 'mine'))


# ------------------------------------------------------------------ harbiy zavod
def military():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 50, 40, 'conc'))
    # yarim dumaloq angar
    prof = [(math.cos(a) * 11, 0.3 + math.sin(a) * 10) for a in [i / 16 * math.pi for i in range(17)]]
    p.append(profile_y('Hangar', prof, -14, 14, m['green']))
    p.append(box('Door', (16, 0.4, 8.5), (0, -14.1, 4.6), m['dark']))
    p.append(box('DoorBack', (16, 0.4, 8.5), (0, 14.1, 4.6), m['olive2']))
    p.append(box('Workshop', (12, 22, 7), (18, 2, 3.8), m['olive2']))
    p.append(box('WRoof', (12.5, 22.5, 0.6), (18, 2, 7.5), m['dark']))
    # devor va qorovulxona
    for x in (-24.5, 24.5):
        p.append(box('Fence', (0.4, 39, 2.5), (x, 0, 1.5), m['conc']))
    p.append(box('FenceB', (49, 0.4, 2.5), (0, 19.5, 1.5), m['conc']))
    for x in (-15, 15):
        p.append(box('FenceF', (18, 0.4, 2.5), (x * 1.0 + (3 if x > 0 else -3), -19.5, 1.5), m['conc']))
    p.append(box('Guard', (3, 3, 3.5), (-6, -19, 2), m['wall2']))
    p.append(box('Barrier', (6, 0.3, 0.3), (0, -19.5, 1.2), m['red']))
    pole, flag = flagpole(m, 8, -17, 11)
    p += [pole, flag]
    p.append(cyl('Chimney', 0.8, 14, (22, 10, 7), m['metal'], axis='Z', verts=10))
    empty('Smoke0', (22, 10, 14.5))
    finish('military', p)


# ------------------------------------------------------------------ laboratoriyalar
def lab_civ():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 30, 30))
    p.append(box('Tower', (12, 12, 26), (0, 0, 13.3), m['glass']))
    for z in range(1, 8):
        p.append(box('Floor', (12.3, 12.3, 0.35), (0, 0, z * 3.4), m['white']))
    p.append(box('Base', (20, 16, 5), (0, -4, 2.8), m['white']))
    p.append(cyl('Disk', 4, 1, (0, 0, 27), m['white'], axis='Z', verts=20))
    finish('lab_civ', p)


def lab_mil():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 34, 30, 'conc'))
    p.append(hull_points('Bunker', [(-12, -9, 0.3), (12, -9, 0.3), (-12, 9, 0.3), (12, 9, 0.3),
                                    (-9, -6, 6), (9, -6, 6), (-9, 6, 6), (9, 6, 6)], m['olive2']))
    p.append(box('Door', (5, 0.3, 3.5), (0, -8.2, 2), m['dark']))
    p.append(cyl('Mast', 0.5, 8, (8, 5, 9), m['metal'], axis='Z', verts=8))
    finish('lab_mil', p)
    dish = [cyl('DishBowl', 3.4, 0.6, (8, 5, 13.5), m['white'], axis='Y', verts=20, r2=1.0),
            cyl('Feed', 0.12, 2.5, (8, 3.8, 13.5), m['metal'], axis='Y', verts=6)]
    join('Dish', dish, origin=(8, 5, 13))
    export(os.path.join(out, 'lab_mil'))


# ------------------------------------------------------------------ aerodrom / aeroport
def runway(m, length, width, p):
    p.append(box('Runway', (length, width, 0.25), (0, 0, 0.13), m['asphalt']))
    for i in range(int(length / 10)):
        p.append(box('Mark', (4, 0.5, 0.05), (-length / 2 + 5 + i * 10, 0, 0.28), m['line']))
    for s in (-1, 1):
        p.append(box('Edge', (length, 0.3, 0.05), (0, s * (width / 2 - 0.5), 0.28), m['line']))


def airbase():
    clear(); m = M(); p = []
    p.append(box('Ground', (110, 50, 0.2), (0, 0, 0.1), m['conc']))
    runway(m, 100, 12, p)
    for i in range(3):
        x = -30 + i * 22
        prof = [(math.cos(a) * 8, 0.2 + math.sin(a) * 6) for a in [k / 12 * math.pi for k in range(13)]]
        h = profile_y('Shelter', prof, 12, 26, m['olive2'])
        h.location.x = x
        p.append(h)
    p.append(box('Tower', (4, 4, 14), (40, 18, 7), m['wall']))
    p.append(box('Cab', (6, 6, 3.5), (40, 18, 15.5), m['glass']))
    p.append(box('CabRoof', (6.5, 6.5, 0.4), (40, 18, 17.4), m['dark']))
    finish('airbase', p)


def airport():
    clear(); m = M(); p = []
    p.append(box('Ground', (110, 56, 0.2), (0, 0, 0.1), m['conc']))
    runway(m, 100, 14, p)
    p.append(box('Terminal', (46, 12, 9), (-12, 21, 4.6), m['glass']))
    p.append(box('TRoof', (48, 14, 1), (-12, 21, 9.6), m['white']))
    p.append(box('Tower', (4, 4, 18), (22, 21, 9), m['white']))
    p.append(box('Cab', (7, 7, 4), (22, 21, 20), m['glass']))
    # yo'lovchi samolyoti
    plane = []
    plane.append(cyl('Fus', 1.6, 26, (-8, 10, 3.2), m['white'], axis='X', verts=14))
    plane.append(cyl('Nose', 1.6, 3, (6.5, 10, 3.2), m['white'], axis='X', verts=14, r2=0.4))
    plane.append(hull_points('WingP', [(-6, 10, 3), (-11, 10, 3), (-13, 24, 3.4), (-11, 24, 3.4), (-6, -4, 3), (-11, -4, 3), (-13, -4 + 0.0, 3.4)], m['white']))
    plane.append(hull_points('Fin', [(-19, 10, 4), (-23, 10, 4), (-24, 10, 10), (-21.5, 10, 10), (-19, 9.8, 4), (-23, 10.2, 4)], m['team']))
    plane.append(box('StabP', (3, 10, 0.3), (-21.5, 10, 4.2), m['white']))
    p += plane
    finish('airport', p)


# ------------------------------------------------------------------ kazarma, tank parki, kema zavodi
def barracks():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 44, 36, 'conc'))
    for i, y in enumerate((-10, 0, 10)):
        p.append(box('Block', (24, 7, 4.5), (-6, y, 2.6), m['wall2']))
        p.append(hull_points('BRoof', [(-18.3, y - 3.8, 4.8), (6.3, y - 3.8, 4.8), (-18.3, y + 3.8, 4.8), (6.3, y + 3.8, 4.8),
                                       (-18.3, y, 6.6), (6.3, y, 6.6)], m['olive2']))
        p.extend(windows(m, -17, 5, y - 3.55, 2.2, 1, 7, w=1.2, h=1.2, face=-1))
    # mashq maydoni
    p.append(box('Yard', (14, 30, 0.1), (14, 0, 0.35), m['wall2']))
    pole, flag = flagpole(m, 14, -12, 12)
    p += [pole, flag]
    finish('barracks', p)


def depot():
    clear(); m = M(); p = []
    p.append(ground_pad(m, 46, 34, 'conc'))
    p.append(box('Back', (40, 1, 7), (0, 10, 3.8), m['olive2']))
    for i in range(6):
        p.append(box('Div', (0.6, 12, 7), (-20 + i * 8, 4.5, 3.8), m['olive2']))
    p.append(box('ShedRoof', (41, 13, 0.6), (0, 4.5, 7.6), m['dark']))
    p.append(box('Fuel', (5, 2.5, 2.5), (18, -12, 1.6), m['oil']))
    finish('depot', p)


def shipyard():
    clear(); m = M(); p = []
    p.append(box('Dock', (50, 40, 0.3), (0, 0, 0.15), m['conc']))
    p.append(box('Water', (40, 14, 0.1), (0, -8, 0.32), m['water']))
    p.append(box('Hull', (28, 6, 4), (0, -8, 2.3), m['olive2']))
    p.append(box('Deck', (12, 4, 3), (-4, -8, 5.5), m['wall2']))
    p.append(box('Shop', (30, 10, 10), (0, 13, 5.2), m['metal']))
    finish('shipyard', p)
    crane = [box('Leg', (1, 1, 22), (18, 0, 11), m['yellow']), box('Jib', (24, 1, 1), (10, 0, 22.5), m['yellow']),
             box('Cab', (2.5, 2, 2), (18.5, 0, 20.5), m['yellow'])]
    join('Crane', crane, origin=(18, 0, 0))
    export(os.path.join(out, 'shipyard'))


for f in (hq, politic, civil, mine, military, lab_civ, lab_mil, airbase, airport, barracks, depot, shipyard):
    f()
    print('OK', f.__name__)

# barchasi bitta rasmda
clear()
names = ['hq', 'politic', 'civil', 'mine', 'military', 'lab_civ', 'lab_mil', 'barracks', 'depot', 'shipyard']
for i, n in enumerate(names):
    bpy.ops.import_scene.gltf(filepath=os.path.join(out, n + '.glb'))
    for o in bpy.context.selected_objects:
        if o.parent is None:
            o.location.x += (i % 5) * 60
            o.location.y += (i // 5) * 60
render_preview(os.path.join(out, 'buildings.png'), target=(120, 30, 5), dist=230, views=((-60, 35),), size=(1600, 900))
print('ALL DONE')
