"""1-zamon qal'a qismlari (O'rta Osiyo uslubi: paxsa/g'isht devorlar, dumaloq minoralar, ko'k gumbazli ark).
blender -b -P castle_parts.py -- <chiqish_papka> [preview]
Barcha o'lchamlar metrda. Devor moduli X bo'ylab 4 m, qalinligi Y bo'ylab, balandligi Z.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/castle_out'
PREVIEW = 'preview' in ARGS
TMP = '/home/claude/work/castle_blend'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

WALL_H = 7.0
WALL_T = 3.0


def M():
    return {
        'brick': mat('Brick', '#c9a97c', 0.92), 'brick2': mat('BrickDark', '#a88a62', 0.92),
        'base': mat('StoneBase', '#8f8577', 0.95), 'wood': mat('Wood', '#6e4a2c', 0.8), 'wood2': mat('WoodDark', '#4a3220', 0.8),
        'tile': mat('Tile', '#2e78b8', 0.35), 'tile2': mat('TileTurq', '#3fb0b8', 0.35), 'gold': mat('Gold', '#c9a03a', 0.35, 0.8),
        'roof': mat('Roof', '#7a5a3a', 0.85), 'iron': mat('Iron', '#3a3a3e', 0.5, 0.7), 'team': mat('TeamColor', '#2f7d4a', 0.7),
        'water': mat('Water', '#2c5a6a', 0.1), 'dark': mat('Dark', '#1c1a18', 0.9), 'straw': mat('Straw', '#c8a85a', 0.95),
    }


def merlons_line(m, x0, x1, y, z, step=1.4, w=0.8, h=1.1, t=0.5):
    out = []
    n = max(1, int((x1 - x0) / step))
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        out.append(box('Merlon', (w, t, h), (x, y, z + h / 2), m))
    return out


def merlons_ring(m, r, z, n=12, w=0.9, h=1.1, t=0.5, cx=0.0, cy=0.0):
    out = []
    for i in range(n):
        a = i / n * 2 * math.pi
        out.append(box('Merlon', (t, w, h), (cx + math.cos(a) * r, cy + math.sin(a) * r, z + h / 2), m, (0, 0, a)))
    return out


def exp(name):
    import shutil
    p = os.path.join(TMP, name)
    export(p)
    shutil.copy(p + '.glb', os.path.join(OUT, name + '.glb'))


def wall():
    clear(); m = M()
    p = [box('Base', (4.0, WALL_T + 0.6, 1.2), (0, 0, 0.6), m['base']),
         box('Body', (4.0, WALL_T, WALL_H - 1.2), (0, 0, 1.2 + (WALL_H - 1.2) / 2), m['brick']),
         box('Walk', (4.0, WALL_T - 0.9, 0.12), (0, 0, WALL_H + 0.06), m['wood'])]
    # paxsa qatlamlari (gorizontal chiziqlar)
    for k in range(3):
        for sy in (-1, 1):
            p.append(box('Band', (4.0, 0.06, 0.12), (0, sy * (WALL_T / 2 + 0.01), 2.4 + k * 1.5), m['brick2']))
    p += merlons_line(m['brick'], -2.0, 2.0, -WALL_T / 2 + 0.25, WALL_H, 1.33)
    p.append(box('Parapet', (4.0, 0.4, 0.6), (0, WALL_T / 2 - 0.2, WALL_H + 0.3), m['brick']))
    join('Wall', p, origin=(0, 0, 0))
    exp('wall')


def tower():
    clear(); m = M()
    H = 11.0
    p = [cyl('Base', 4.0, 1.4, (0, 0, 0.7), m['base'], axis='Z', verts=20),
         cyl('Body', 3.4, H - 1.4, (0, 0, 1.4 + (H - 1.4) / 2), m['brick'], axis='Z', verts=20, r2=3.1),
         cyl('Top', 3.6, 0.5, (0, 0, H + 0.25), m['brick2'], axis='Z', verts=20),
         cyl('Floor', 3.3, 0.15, (0, 0, H + 0.55), m['wood'], axis='Z', verts=20)]
    p += merlons_ring(m['brick'], 3.35, H + 0.5, 14)
    for k in range(3):
        a = k * 2.1
        p.append(box('Slit', (0.3, 0.15, 1.2), (math.cos(a) * 3.25, math.sin(a) * 3.25, 6 + k * 1.2), m['dark'], (0, 0, a)))
    p.append(cyl('Band', 3.3, 0.25, (0, 0, 5.0), m['tile'], axis='Z', verts=20, r2=3.27))
    p.append(cyl('Pole', 0.07, 4.0, (0, 0, H + 2.5), m['wood2'], axis='Z', verts=6))
    p.append(box('Flag', (1.6, 0.05, 1.0), (0.85, 0, H + 3.9), m['team']))
    join('Tower', p, origin=(0, 0, 0))
    exp('tower')


def gate():
    clear(); m = M()
    L = 10.0
    p = []
    # ikki yon minora (peshtoq) va o'rtada ravoq
    for sx in (-1, 1):
        p.append(cyl('GT', 2.4, 10.0, (sx * 3.6, 0, 5.0), m['brick'], axis='Z', verts=16, r2=2.2))
        p += merlons_ring(m['brick'], 2.3, 10.0, 10, cx=sx * 3.6)
    p.append(box('Arch', (2.6, WALL_T + 0.6, 3.0), (0, 0, 7.5), m['brick']))
    p.append(box('Portal', (5.2, 0.5, 9.0), (0, -WALL_T / 2 - 0.3, 4.5), m['brick2']))
    p.append(box('PortalTile', (4.4, 0.55, 1.0), (0, -WALL_T / 2 - 0.32, 8.2), m['tile']))
    p.append(box('PortalTile2', (0.5, 0.55, 7.0), (-2.2, -WALL_T / 2 - 0.32, 3.8), m['tile2']))
    p.append(box('PortalTile3', (0.5, 0.55, 7.0), (2.2, -WALL_T / 2 - 0.32, 3.8), m['tile2']))
    # darvoza tavaqalari
    for sx in (-1, 1):
        p.append(box('Door', (1.25, 0.3, 5.6), (sx * 0.66, -WALL_T / 2 - 0.45, 2.8), m['wood']))
        for k in range(4):
            p.append(box('Strip', (1.2, 0.06, 0.1), (sx * 0.66, -WALL_T / 2 - 0.62, 0.8 + k * 1.4), m['iron']))
    p.append(box('Walk', (L - 1, WALL_T - 0.9, 0.12), (0, 0, 9.06), m['wood']))
    p += merlons_line(m['brick'], -1.4, 1.4, -WALL_T / 2 + 0.25, 9.0, 1.0)
    join('Gate', p, origin=(0, 0, 0))
    exp('gate')


def keep():
    clear(); m = M()
    S = 18.0; H = 13.0
    p = [box('Base', (S + 1, S + 1, 2.0), (0, 0, 1.0), m['base']),
         box('Body', (S, S, H - 2), (0, 0, 2 + (H - 2) / 2), m['brick']),
         box('Roof', (S - 1.2, S - 1.2, 0.2), (0, 0, H + 0.1), m['wood'])]
    for sy in (-1, 1):
        p += merlons_line(m['brick'], -S / 2, S / 2, sy * (S / 2 - 0.25), H, 1.5)
    for sx in (-1, 1):
        p += [box('Mx', (0.5, 0.8, 1.1), (sx * (S / 2 - 0.25), -S / 2 + 1.5 + k * 1.5, H + 0.55), m['brick']) for k in range(int(S / 1.5) - 1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(cyl('CT', 2.6, H + 3, (sx * S / 2, sy * S / 2, (H + 3) / 2), m['brick'], axis='Z', verts=16, r2=2.3))
            p += merlons_ring(m['brick'], 2.4, H + 3, 10, cx=sx * S / 2, cy=sy * S / 2)
            p.append(cyl('CTBand', 2.5, 0.4, (sx * S / 2, sy * S / 2, H - 1), m['tile'], axis='Z', verts=16))
    # ko'k gumbaz (Temuriylar uslubi)
    p.append(cyl('Drum', 4.5, 3.0, (0, 0, H + 1.5), m['brick2'], axis='Z', verts=24))
    p.append(cyl('DrumTile', 4.55, 1.0, (0, 0, H + 2.2), m['tile2'], axis='Z', verts=24))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=4.6)
    dome = _obj_from_bm('Dome', bm, m['tile'])
    dome.location = (0, 0, H + 3.0)
    dome.scale = (1, 1, 1.25)
    for f in dome.data.polygons:
        f.use_smooth = True
    p.append(dome)
    p.append(cyl('Finial', 0.15, 2.0, (0, 0, H + 9.5), m['gold'], axis='Z', verts=8))
    # kirish peshtoqi
    p.append(box('Pishtaq', (7.0, 1.0, 10.0), (0, -S / 2 - 0.5, 5.0), m['brick2']))
    p.append(box('PishtaqTile', (6.0, 1.05, 1.0), (0, -S / 2 - 0.5, 9.0), m['tile']))
    p.append(box('Door', (2.6, 0.3, 4.2), (0, -S / 2 - 1.05, 2.1), m['wood']))
    p.append(cyl('Pole', 0.1, 6.0, (0, 0, H + 12.5), m['wood2'], axis='Z', verts=6))
    p.append(box('Flag', (2.6, 0.05, 1.6), (1.35, 0, H + 14.6), m['team']))
    join('Keep', p, origin=(0, 0, 0))
    exp('keep')


def barracks():
    clear(); m = M()
    p = [box('Base', (16.6, 8.6, 0.5), (0, 0, 0.25), m['base']), box('Body', (16, 8, 4.0), (0, 0, 2.5), m['brick']),
         box('RoofSlab', (16.8, 8.8, 0.35), (0, 0, 4.65), m['roof']), box('Door', (1.8, 0.2, 2.6), (0, -4.05, 1.8), m['wood'])]
    for x in (-5.5, -2.8, 2.8, 5.5):
        p.append(box('Window', (0.9, 0.2, 0.9), (x, -4.05, 3.0), m['dark']))
    for x in (-6, -2, 2, 6):
        p.append(box('Rack', (1.4, 0.3, 1.8), (x, -4.6, 1.4), m['wood2']))
        p.append(cyl('Spear', 0.03, 2.6, (x, -4.7, 1.8), m['wood'], axis='Z', verts=5))
    join('Barracks', p, origin=(0, 0, 0))
    exp('barracks')


def granary():
    clear(); m = M()
    p = [box('Base', (10.5, 8.5, 0.6), (0, 0, 0.3), m['base']), box('Body', (10, 8, 3.6), (0, 0, 2.4), m['brick2']),
         hull_points('Roof', [(-5.3, -4.3, 4.2), (5.3, -4.3, 4.2), (-5.3, 4.3, 4.2), (5.3, 4.3, 4.2), (-5.3, 0, 6.2), (5.3, 0, 6.2)], m['straw']),
         box('Door', (2.4, 0.2, 2.8), (0, -4.05, 2.0), m['wood'])]
    for k in range(5):
        p.append(box('Sack', (0.9, 0.7, 0.6), (-3 + k * 1.5, -5.0, 0.9), m['straw']))
    join('Granary', p, origin=(0, 0, 0))
    exp('granary')


def well():
    clear(); m = M()
    p = [cyl('Ring', 1.4, 1.0, (0, 0, 0.5), m['base'], axis='Z', verts=16), cyl('Water', 1.1, 0.1, (0, 0, 0.9), m['water'], axis='Z', verts=16)]
    for sx in (-1, 1):
        p.append(box('Post', (0.2, 0.2, 2.6), (sx * 1.3, 0, 1.3), m['wood2']))
    p.append(cyl('Beam', 0.1, 2.8, (0, 0, 2.5), m['wood'], axis='X', verts=8))
    p.append(hull_points('Roof', [(-1.7, -1.1, 2.7), (1.7, -1.1, 2.7), (-1.7, 1.1, 2.7), (1.7, 1.1, 2.7), (-1.7, 0, 3.4), (1.7, 0, 3.4)], m['roof']))
    join('Well', p, origin=(0, 0, 0))
    exp('well')


def smithy():
    clear(); m = M()
    p = [box('Base', (8.5, 6.5, 0.4), (0, 0, 0.2), m['base']), box('Body', (8, 6, 3.4), (0, 0, 2.1), m['brick']),
         box('Roof', (8.6, 6.6, 0.3), (0, 0, 3.95), m['roof']), box('Chimney', (1.2, 1.2, 3.0), (2.6, 1.6, 5.2), m['brick2']),
         box('Open', (3.0, 0.2, 2.4), (-1.5, -3.05, 1.6), m['dark']), box('Anvil', (0.8, 0.4, 0.8), (-1.5, -4.2, 0.6), m['iron']),
         cyl('Forge', 0.6, 0.5, (0.5, -4.0, 0.45), m['brick2'], axis='Z', verts=10)]
    join('Smithy', p, origin=(0, 0, 0))
    exp('smithy')


def stable():
    clear(); m = M()
    p = [box('Floor', (14.5, 7.5, 0.3), (0, 0, 0.15), m['straw']), box('Back', (14, 0.5, 3.2), (0, 3.4, 1.6), m['wood2']),
         hull_points('Roof', [(-7.3, -3.9, 3.0), (7.3, -3.9, 3.0), (-7.3, 3.8, 3.8), (7.3, 3.8, 3.8), (-7.3, -3.9, 3.2), (7.3, -3.9, 3.2)], m['roof'])]
    for k in range(6):
        x = -7 + k * 2.8
        p.append(box('Post', (0.25, 0.25, 3.0), (x, -3.6, 1.5), m['wood']))
        if k < 5:
            p.append(box('Stall', (0.15, 5.5, 1.4), (x + 1.4, 0.5, 0.85), m['wood']))
    p.append(box('Trough', (12, 0.7, 0.6), (0, 2.7, 0.6), m['wood2']))
    join('Stable', p, origin=(0, 0, 0))
    exp('stable')


def moat():
    clear(); m = M()
    # suv yer sathida (yerni kesib bo'lmaydi), ikki yonida qazilgan tuproq uyumi
    dirt = mat('Dirt', '#6e5a3e', 0.95)
    p = [box('Water', (4.0, 6.0, 0.12), (0, 0, 0.06), m['water'])]
    for sy in (-1, 1):
        p.append(hull_points('Bank', [(-2.0, sy * 3.0, 0.0), (2.0, sy * 3.0, 0.0), (-2.0, sy * 4.6, 0.0), (2.0, sy * 4.6, 0.0),
                                      (-2.0, sy * 3.5, 0.7), (2.0, sy * 3.5, 0.7)], dirt))
    join('Moat', p, origin=(0, 0, 0))
    exp('moat')


def farm():
    clear(); m = M()
    soil = mat('Soil', '#6b5236', 0.95)
    wheat = mat('Wheat', '#d0b050', 0.9)
    p = [box('Field', (20, 14, 0.15), (0, 0, 0.08), soil)]
    for k in range(9):
        p.append(box('Row', (19, 0.8, 0.7), (0, -6 + k * 1.5, 0.45), wheat))
    p.append(box('Hut', (4, 3.5, 2.6), (12.5, 4, 1.3), m['brick2']))
    p.append(hull_points('HutRoof', [(10.3, 2.0, 2.6), (14.7, 2.0, 2.6), (10.3, 6.0, 2.6), (14.7, 6.0, 2.6), (10.3, 4, 3.6), (14.7, 4, 3.6)], m['straw']))
    for k in range(6):
        p.append(box('Fence', (0.15, 0.15, 1.0), (-10.2, -7 + k * 2.8, 0.5), m['wood2']))
    p.append(box('Rail', (0.1, 14, 0.12), (-10.2, 0, 0.85), m['wood']))
    join('Farm', p, origin=(0, 0, 0))
    exp('farm')


def lumber():
    clear(); m = M()
    p = [box('Yard', (12, 10, 0.15), (0, 0, 0.08), mat('Dirt', '#6e5a3e', 0.95)),
         box('Shed', (6, 4, 0.2), (-2, 3, 3.0), m['roof'])]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box('Post', (0.25, 0.25, 3.0), (-2 + sx * 2.8, 3 + sy * 1.8, 1.5), m['wood2']))
    for k in range(6):
        p.append(cyl('Log', 0.35, 5.0, (2.5, -3 + (k % 3) * 0.75, 0.35 + (k // 3) * 0.6), m['wood'], axis='X', verts=10))
    p.append(box('Block', (1.0, 1.0, 0.8), (-3, -2.5, 0.4), m['wood']))
    p.append(box('Axe', (0.08, 0.6, 0.08), (-3, -2.5, 1.1), m['iron']))
    join('Lumber', p, origin=(0, 0, 0))
    exp('lumber')


def quarry():
    clear(); m = M()
    rock = mat('Rock', '#9a9286', 0.95)
    p = [box('Pit', (14, 12, 0.15), (0, 0, 0.08), mat('Gravel', '#8a8070', 0.95))]
    random.seed(3)
    for k in range(7):
        r = random.uniform(1.2, 2.6)
        p.append(hull_points('Rock', [(random.uniform(-5, 5) + dx * r, 3.5 + random.uniform(-1, 2) + dy * r, dz * r * 1.4)
                                      for dx, dy, dz in ((-1, -1, 0), (1, -1, 0), (-1, 1, 0), (1, 1, 0), (0, 0, 1), (0.4, -0.3, 0.8))], rock))
    for k in range(8):
        p.append(box('Block', (1.2, 0.8, 0.7), (-4 + (k % 4) * 1.5, -3.5 + (k // 4) * 1.0, 0.35), m['base']))
    p.append(box('Cart', (2.2, 1.4, 0.9), (4, -3.5, 0.8), m['wood']))
    for sy in (-1, 1):
        p.append(cyl('Wheel', 0.5, 0.15, (4, -3.5 + sy * 0.8, 0.5), m['wood2'], axis='Y', verts=10))
    join('Quarry', p, origin=(0, 0, 0))
    exp('quarry')


def market():
    clear(); m = M()
    cloths = [mat('Awning1', '#b8462e', 0.9), mat('Awning2', '#2e6fb8', 0.9), mat('Awning3', '#d8b040', 0.9)]
    p = [box('Plaza', (16, 12, 0.15), (0, 0, 0.08), m['base'])]
    for i in range(6):
        x = -5.5 + (i % 3) * 5.5
        y = -3 if i < 3 else 3
        p.append(box('Counter', (3.2, 1.4, 1.0), (x, y, 0.5), m['wood']))
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(box('Pole', (0.12, 0.12, 2.6), (x + sx * 1.6, y + sy * 0.9, 1.3), m['wood2']))
        p.append(box('Awning', (3.6, 2.2, 0.08), (x, y, 2.65), cloths[i % 3], (math.radians(8), 0, 0)))
        p.append(sph('Goods', 0.35, (x - 0.6, y, 1.15), cloths[(i + 1) % 3], segs=8, rings=6))
        p.append(sph('Goods', 0.3, (x + 0.6, y, 1.12), m['straw'], segs=8, rings=6))
    join('Market', p, origin=(0, 0, 0))
    exp('market')


def mint():
    clear(); m = M()
    p = [box('Base', (10.5, 10.5, 0.5), (0, 0, 0.25), m['base']), box('Body', (10, 10, 5), (0, 0, 3.0), m['brick'])]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=3.2)
    d = _obj_from_bm('Dome', bm, m['tile2'])
    d.location = (0, 0, 5.5)
    p.append(d)
    p.append(box('Portal', (4, 0.6, 6), (0, -5.2, 3), m['brick2']))
    p.append(box('PortalTile', (3.2, 0.65, 0.7), (0, -5.25, 5.4), m['tile']))
    p.append(box('Door', (1.6, 0.2, 2.6), (0, -5.55, 1.3), m['wood']))
    for k in range(3):
        p.append(cyl('Coins', 0.4, 0.3 + k * 0.1, (-3 + k * 0.9, -6.2, 0.2 + k * 0.05), m['gold'], axis='Z', verts=12))
    join('Mint', p, origin=(0, 0, 0))
    exp('mint')


def sph(name, r, loc, material, segs=10, rings=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    o = _obj_from_bm(name, bm, material)
    o.location = loc
    return o


for f in (farm, lumber, quarry, market, mint) if 'eco' in ARGS else (wall, tower, gate, keep, barracks, granary, well, smithy, stable, moat):
    f()

if PREVIEW:
    clear()
    for i, n in enumerate(['farm', 'lumber', 'quarry', 'market', 'mint'] if 'eco' in ARGS else ['wall', 'tower', 'gate', 'keep', 'barracks', 'granary', 'well', 'smithy', 'stable']):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            o.location = ((i % 3) * 28 - 28, (i // 3) * 28 - 28, 0)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 1200, 900
    cd = bpy.data.cameras.new('C'); cd.lens = 35
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (70, -80, 70)
    cam.rotation_euler = (Vector((0, 0, 3)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_castle.png')
    bpy.ops.render.render(write_still=True)
print('CASTLE DONE')
