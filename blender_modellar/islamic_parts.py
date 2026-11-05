"""O'rta Osiyo (Temuriylar) uslubidagi qal'a binolari: gumbazlar, peshtoqlar, ayvonlar, ko'k koshinlar.
blender -b -P islamic_parts.py -- <chiqish_papka> [preview]
Binolar castle_parts.py dagi bilan bir xil o'lchamda (o'yindagi joy egallashi - FOOT - o'zgarmaydi).
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from lib import *
from lib import _obj_from_bm

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[0] if ARGS else '/home/claude/work/islamic_out'
PREVIEW = 'preview' in ARGS
TMP = '/home/claude/work/islamic_blend'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)


def M():
    return {
        'brick': mat('Brick', '#c9a97c', 0.92), 'brick2': mat('BrickDark', '#a88a62', 0.92), 'mud': mat('Mud', '#b89a72', 0.97),
        'base': mat('StoneBase', '#8f8577', 0.95), 'wood': mat('Wood', '#6e4a2c', 0.8), 'wood2': mat('WoodDark', '#4a3220', 0.8),
        'tile': mat('Tile', '#2468b0', 0.3), 'tile2': mat('TileTurq', '#36b0b8', 0.3), 'tile3': mat('TileWhite', '#e8e2d0', 0.4),
        'gold': mat('Gold', '#c9a03a', 0.35, 0.8), 'iron': mat('Iron', '#3a3a3e', 0.5, 0.7), 'team': mat('TeamColor', '#2f7d4a', 0.7),
        'water': mat('Water', '#2c5a6a', 0.1), 'dark': mat('Dark', '#1c1a18', 0.9), 'straw': mat('Straw', '#c8a85a', 0.95),
        'soil': mat('Soil', '#6b5236', 0.95), 'wheat': mat('Wheat', '#d0b050', 0.9), 'carpet': mat('Carpet', '#8a2a2a', 0.9),
    }


def exp(name):
    import shutil
    p = os.path.join(TMP, name)
    export(p)
    shutil.copy(p + '.glb', os.path.join(OUT, name + '.glb'))


def dome(name, r, loc, m, hz=1.0, ribs=False, segs=24):
    """yarim shar gumbaz (pastki yarmi kesilgan); ribs - qovurg'ali (Temur maqbarasi kabi)"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=12, radius=r)
    for v in list(bm.verts):
        if v.co.z < -0.01:
            v.co.z = 0.0
        if ribs:
            a = math.atan2(v.co.y, v.co.x)
            k = 1.0 + 0.045 * abs(math.cos(a * segs / 2)) * (v.co.z / r)
            v.co.x *= k
            v.co.y *= k
    o = _obj_from_bm(name, bm, m)
    o.location = loc
    o.scale = (1, 1, hz)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def arch(name, w, h, loc, m, depth=0.3, axis='Y'):
    """uchli ravoq (o'yiq): to'g'ri qism + tepasi uchli; loc - pastki markaz; axis - devorga perpendikulyar"""
    x, y, z = loc
    hw = w / 2.0
    rect_h = h - hw * 1.1
    pts = []
    for d in (-depth / 2, depth / 2):
        for px, pz in ((-hw, 0), (hw, 0), (-hw, rect_h), (hw, rect_h), (0, h)):
            if axis == 'Y':
                pts.append((x + px, y + d, z + pz))
            else:
                pts.append((x + d, y + px, z + pz))
    return hull_points(name, pts, m)


def pishtaq(m, w, h, loc, depth=1.2, face=-1, axis='Y'):
    """peshtoq: baland to'rtburchak portal, ichida chuqur uchli ravoq, ustida koshin hoshiyalar"""
    x, y, z = loc
    out = []
    if axis == 'Y':
        out.append(box('Pishtaq', (w, depth, h), (x, y, z + h / 2), m['brick2']))
        out.append(arch('PishArch', w * 0.62, h * 0.78, (x, y + face * depth * 0.42, z), m['dark'], depth * 0.3))
        out.append(arch('PishArchTile', w * 0.72, h * 0.84, (x, y + face * depth * 0.36, z), m['tile'], depth * 0.2))
        out.append(box('PishBand', (w + 0.1, depth + 0.1, 0.5), (x, y, z + h - 0.6), m['tile2']))
        out.append(box('PishFrameL', (0.35, depth + 0.06, h * 0.9), (x - w / 2 + 0.3, y, z + h * 0.45), m['tile']))
        out.append(box('PishFrameR', (0.35, depth + 0.06, h * 0.9), (x + w / 2 - 0.3, y, z + h * 0.45), m['tile']))
    else:
        out.append(box('Pishtaq', (depth, w, h), (x, y, z + h / 2), m['brick2']))
        out.append(arch('PishArch', w * 0.62, h * 0.78, (x + face * depth * 0.42, y, z), m['dark'], depth * 0.3, axis='X'))
        out.append(arch('PishArchTile', w * 0.72, h * 0.84, (x + face * depth * 0.36, y, z), m['tile'], depth * 0.2, axis='X'))
        out.append(box('PishBand', (depth + 0.1, w + 0.1, 0.5), (x, y, z + h - 0.6), m['tile2']))
    return out


def parapet(m, sx, sy, z, mat_key='brick2'):
    out = []
    for s in (-1, 1):
        out.append(box('Para', (sx, 0.35, 0.6), (0, s * (sy / 2 - 0.17), z + 0.3), m[mat_key]))
        out.append(box('Para', (0.35, sy, 0.6), (s * (sx / 2 - 0.17), 0, z + 0.3), m[mat_key]))
    return out


def barracks():
    """kazarma - karvonsaroy uslubida: uzun paxsa bino, tomida qator kichik gumbazlar, o'rtada peshtoq, yonlarida ravoqli tokchalar"""
    clear(); m = M()
    L, D, H = 16.0, 8.0, 4.4
    p = [box('Base', (L + 0.6, D + 0.6, 0.5), (0, 0, 0.25), m['base']), box('Body', (L, D, H), (0, 0, 0.5 + H / 2), m['brick'])]
    p += parapet(m, L, D, 0.5 + H)
    for x in (-6.0, -2.4, 2.4, 6.0):
        p.append(cyl('Drum', 1.5, 0.6, (x, 0, 0.5 + H + 0.3), m['brick2'], axis='Z', verts=16))
        p.append(dome('Dome', 1.5, (x, 0, 0.5 + H + 0.6), m['mud'], 0.8))
    for x in (-6.0, -4.0, 4.0, 6.0):
        p.append(arch('Niche', 1.3, 2.6, (x, -D / 2 - 0.05, 0.9), m['dark'], 0.25))
    p += pishtaq(m, 4.4, 7.2, (0, -D / 2 - 0.4, 0.5), 1.4)
    for x in (-2.8, 2.8):
        p.append(box('Rack', (1.2, 0.3, 1.8), (x + (0.0), -D / 2 - 1.4, 1.4), m['wood2']))
        p.append(cyl('Spear', 0.03, 2.6, (x, -D / 2 - 1.5, 1.8), m['wood'], axis='Z', verts=5))
    join('Barracks', p, origin=(0, 0, 0))
    exp('barracks')


def granary():
    """ombor - katta gumbazli don ombori (paxsa), kichik eshik, oldida qoplar"""
    clear(); m = M()
    p = [box('Base', (10.5, 8.5, 0.6), (0, 0, 0.3), m['base']), box('Body', (10, 8, 3.4), (0, 0, 2.3), m['mud'])]
    p += parapet(m, 10, 8, 4.0, 'mud')
    p.append(cyl('Drum', 3.4, 0.8, (0, 0, 4.4), m['brick2'], axis='Z', verts=20))
    p.append(dome('Dome', 3.4, (0, 0, 4.8), m['mud'], 0.75))
    p.append(cyl('Vent', 0.5, 0.9, (0, 0, 7.3), m['brick2'], axis='Z', verts=8))
    p.append(arch('Door', 2.2, 3.0, (0, -4.05, 0.6), m['wood2'], 0.25))
    for k in range(5):
        p.append(box('Sack', (0.9, 0.7, 0.6), (-3 + k * 1.5, -5.0, 0.9), m['straw']))
    join('Granary', p, origin=(0, 0, 0))
    exp('granary')


def well():
    """sardoba - gumbaz bilan yopilgan suv havzasi (O'rta Osiyo cho'llaridagi kabi)"""
    clear(); m = M()
    p = [cyl('Ring', 1.7, 0.9, (0, 0, 0.45), m['brick2'], axis='Z', verts=20),
         dome('Dome', 1.65, (0, 0, 0.9), m['brick'], 0.95),
         box('Entrance', (1.0, 1.0, 1.9), (0, -1.6, 0.95), m['brick2']),
         arch('Door', 0.7, 1.5, (0, -2.12, 0.1), m['dark'], 0.15),
         cyl('Water', 1.0, 0.08, (1.2, 1.0, 0.04), m['water'], axis='Z', verts=12)]
    join('Well', p, origin=(0, 0, 0))
    exp('well')


def smithy():
    """temirchi - kichik gumbazli ustaxona, ochiq ravoq, o'choq va sandon, mo'ri"""
    clear(); m = M()
    p = [box('Base', (8.5, 6.5, 0.4), (0, 0, 0.2), m['base']), box('Body', (8, 6, 3.6), (0, 0, 2.2), m['mud'])]
    p += parapet(m, 8, 6, 4.0, 'mud')
    p.append(dome('Dome', 2.2, (-1.4, 0.4, 4.0), m['mud'], 0.8))
    p.append(box('Chimney', (1.0, 1.0, 2.6), (2.6, 1.6, 5.3), m['brick2']))
    p.append(arch('Open', 2.8, 3.0, (1.2, -3.05, 0.4), m['dark'], 0.25))
    p.append(box('Anvil', (0.8, 0.4, 0.8), (1.2, -4.2, 0.6), m['iron']))
    p.append(cyl('Forge', 0.6, 0.5, (-1.0, -4.0, 0.45), m['brick2'], axis='Z', verts=10))
    join('Smithy', p, origin=(0, 0, 0))
    exp('smithy')


def stable():
    """otxona - ayvon: tekis tom o'ymakor yog'och ustunlarda, orqa devor paxsa, ichida oxurlar"""
    clear(); m = M()
    p = [box('Floor', (14.5, 7.5, 0.3), (0, 0, 0.15), m['straw']), box('Back', (14.4, 0.8, 4.0), (0, 3.4, 2.0), m['mud']),
         box('SideL', (0.8, 7.2, 4.0), (-7.0, 0, 2.0), m['mud']), box('SideR', (0.8, 7.2, 4.0), (7.0, 0, 2.0), m['mud']),
         box('Roof', (15.0, 8.0, 0.45), (0, 0, 4.2), m['mud']), box('RoofEdge', (15.2, 0.3, 0.3), (0, -4.0, 4.0), m['wood2'])]
    for k in range(6):
        x = -6.2 + k * 2.48
        p.append(cyl('Column', 0.16, 3.6, (x, -3.6, 1.95), m['wood'], axis='Z', verts=10))
        p.append(box('Capital', (0.7, 0.5, 0.35), (x, -3.6, 3.85), m['wood2']))
        p.append(cyl('ColBase', 0.26, 0.3, (x, -3.6, 0.3), m['base'], axis='Z', verts=10))
        if k < 5:
            p.append(box('Stall', (0.15, 5.5, 1.4), (x + 1.24, 0.5, 0.85), m['wood']))
    p.append(box('Trough', (12, 0.7, 0.6), (0, 2.6, 0.6), m['wood2']))
    join('Stable', p, origin=(0, 0, 0))
    exp('stable')


def farm():
    """bug'doy maydoni - ariqlar bilan, chetida kichik gumbazli dehqon uyi"""
    clear(); m = M()
    p = [box('Field', (20, 14, 0.15), (0, 0, 0.08), m['soil'])]
    for k in range(9):
        p.append(box('Row', (19, 0.8, 0.7), (0, -6 + k * 1.5, 0.45), m['wheat']))
    p.append(box('Ariq', (20, 0.6, 0.06), (0, -6.9, 0.17), m['water']))
    p.append(box('Hut', (4, 3.6, 2.6), (12.5, 4, 1.3), m['mud']))
    p.append(dome('HutDome', 1.6, (12.5, 4, 2.6), m['mud'], 0.75))
    p.append(arch('HutDoor', 0.9, 1.7, (12.5, 2.15, 0.05), m['dark'], 0.15))
    p.append(cyl('Tree', 0.18, 2.4, (11.0, 6.4, 1.2), m['wood2'], axis='Z', verts=6))
    p.append(dome('Crown', 1.3, (11.0, 6.4, 2.2), mat('Leaf', '#4a6a2a', 0.9), 1.1))
    join('Farm', p, origin=(0, 0, 0))
    exp('farm')


def market():
    """bozor - chorsu: o'rtada gumbazli toq (to'rt tomonida ravoq), atrofida soyabonli rastalar"""
    clear(); m = M()
    cloths = [mat('Awning1', '#b8462e', 0.9), mat('Awning2', '#2e6fb8', 0.9), mat('Awning3', '#d8b040', 0.9)]
    p = [box('Plaza', (16, 12, 0.15), (0, 0, 0.08), m['base']), box('Toq', (6, 6, 4.2), (0, 0, 2.25), m['brick'])]
    for ax, f in (('Y', -1), ('Y', 1), ('X', -1), ('X', 1)):
        if ax == 'Y':
            p.append(arch('ToqArch', 2.4, 3.4, (0, f * 3.02, 0.15), m['dark'], 0.2))
        else:
            p.append(arch('ToqArch', 2.4, 3.4, (f * 3.02, 0, 0.15), m['dark'], 0.2, axis='X'))
    p.append(cyl('Drum', 2.4, 0.8, (0, 0, 4.75), m['brick2'], axis='Z', verts=20))
    p.append(dome('Dome', 2.4, (0, 0, 5.15), m['tile2'], 0.9, ribs=True))
    for i in range(4):
        x = -6.0 if i % 2 == 0 else 6.0
        y = -3.5 if i < 2 else 3.5
        p.append(box('Counter', (2.8, 1.4, 1.0), (x, y, 0.5), m['wood']))
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(box('Pole', (0.12, 0.12, 2.6), (x + sx * 1.4, y + sy * 0.9, 1.3), m['wood2']))
        p.append(box('Awning', (3.2, 2.2, 0.08), (x, y, 2.65), cloths[i % 3], (math.radians(8), 0, 0)))
        p.append(box('Goods', (0.6, 0.5, 0.5), (x - 0.6, y, 1.25), cloths[(i + 1) % 3]))
        p.append(box('Goods2', (0.6, 0.5, 0.4), (x + 0.6, y, 1.2), m['straw']))
    join('Market', p, origin=(0, 0, 0))
    exp('market')


def mint():
    """zarbxona - feruza gumbazli kvadrat bino, peshtoq bilan"""
    clear(); m = M()
    p = [box('Base', (10.5, 10.5, 0.5), (0, 0, 0.25), m['base']), box('Body', (10, 10, 5), (0, 0, 3.0), m['brick'])]
    p += parapet(m, 10, 10, 5.5)
    p.append(cyl('Drum', 3.2, 1.2, (0, 0, 6.1), m['brick2'], axis='Z', verts=20))
    p.append(cyl('DrumTile', 3.25, 0.4, (0, 0, 6.4), m['tile'], axis='Z', verts=20))
    p.append(dome('Dome', 3.2, (0, 0, 6.7), m['tile2'], 1.05, ribs=True))
    p += pishtaq(m, 4.6, 7.0, (0, -5.4, 0.5), 1.0)
    for k in range(3):
        p.append(cyl('Coins', 0.4, 0.3 + k * 0.1, (-3 + k * 0.9, -6.6, 0.2 + k * 0.05), m['gold'], axis='Z', verts=12))
    join('Mint', p, origin=(0, 0, 0))
    exp('mint')


def mosque():
    """masjid - peshtoq, ko'k qovurg'ali gumbaz, minora (minorat) va kichik burchak gumbazlari"""
    clear(); m = M()
    p = [box('Base', (15, 11, 0.6), (0, 1.0, 0.3), m['base']), box('Hall', (13, 9, 6.0), (0, 1.5, 3.6), m['brick'])]
    p += [o for o in parapet(m, 13, 9, 6.6)]
    for o in p[-4:]:
        o.location.y += 1.5
    p.append(cyl('Drum', 4.0, 2.2, (0, 1.5, 7.7), m['brick2'], axis='Z', verts=28))
    p.append(cyl('DrumTile', 4.05, 0.8, (0, 1.5, 8.2), m['tile'], axis='Z', verts=28))
    p.append(dome('Dome', 4.1, (0, 1.5, 8.8), m['tile'], 1.25, ribs=True, segs=32))
    p.append(cyl('Finial', 0.12, 2.0, (0, 1.5, 14.8), m['gold'], axis='Z', verts=8))
    p.append(sph_('Crescent', 0.35, (0, 1.5, 16.0), m['gold']))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(dome('Small', 1.1, (sx * 4.8, 1.5 + sy * 3.0, 6.6), m['tile2'], 0.9))
    p += pishtaq(m, 7.5, 10.5, (0, -3.6, 0.6), 1.6)
    # minorat
    mx, my = 6.8, -3.4
    p.append(cyl('MinBase', 1.4, 2.0, (mx, my, 1.0), m['base'], axis='Z', verts=16))
    p.append(cyl('Minaret', 1.25, 17.0, (mx, my, 10.5), m['brick'], axis='Z', verts=16, r2=0.95))
    for z in (6.0, 11.0, 15.0):
        p.append(cyl('MinBand', 1.3 - (z - 2) * 0.018, 0.8, (mx, my, z), m['tile'], axis='Z', verts=16))
    p.append(cyl('Balcony', 1.6, 0.4, (mx, my, 19.2), m['brick2'], axis='Z', verts=16))
    p.append(cyl('Lantern', 1.0, 1.8, (mx, my, 20.3), m['tile2'], axis='Z', verts=16))
    p.append(dome('MinDome', 1.0, (mx, my, 21.2), m['tile'], 1.2))
    p.append(cyl('Carpet', 0.01, 1.0, (0, -5.5, 0.62), m['carpet'], axis='Z', verts=4))
    join('Mosque', p, origin=(0, 0, 0))
    exp('mosque')


def house():
    """oddiy uy - paxsa devorlar, kichik gumbaz, yog'och eshik, tomida supa"""
    clear(); m = M()
    p = [box('Base', (6.2, 6.2, 0.3), (0, 0, 0.15), m['base']), box('Body', (5.6, 5.6, 3.0), (0, 0, 1.8), m['mud'])]
    p += parapet(m, 5.6, 5.6, 3.3, 'mud')
    p.append(dome('Dome', 2.0, (0.6, 0.6, 3.3), m['mud'], 0.7))
    p.append(arch('Door', 1.1, 2.0, (-0.8, -2.85, 0.3), m['wood2'], 0.2))
    p.append(box('Window', (0.6, 0.15, 0.6), (1.4, -2.85, 2.0), m['dark']))
    p.append(box('Supa', (2.2, 1.4, 0.5), (-1.4, -3.6, 0.25), m['wood']))
    p.append(box('Kilim', (2.0, 1.2, 0.04), (-1.4, -3.6, 0.52), m['carpet']))
    join('House', p, origin=(0, 0, 0))
    exp('house')


def sph_(name, r, loc, material, segs=10, rings=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    o = _obj_from_bm(name, bm, material)
    o.location = loc
    return o


ALL = [barracks, granary, well, smithy, stable, farm, market, mint, mosque, house]
for f in ALL:
    f()

if PREVIEW:
    clear()
    names = [f.__name__ for f in ALL]
    for i, n in enumerate(names):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, n + '.glb'))
        for o in bpy.context.selected_objects:
            o.location = ((i % 5) * 26 - 52, (i // 5) * 28 - 14, 0)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    cd = bpy.data.cameras.new('C'); cd.lens = 32
    cam = bpy.data.objects.new('C', cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (40, -95, 65)
    cam.rotation_euler = (Vector((0, 0, 3)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, 'prev_islamic.png')
    bpy.ops.render.render(write_still=True)
print('ISLAMIC DONE')
