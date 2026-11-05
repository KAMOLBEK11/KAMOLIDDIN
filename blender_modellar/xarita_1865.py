"""2-zamon (1865-yil) dunyo xaritasi: data/world_1865.json
Chegaralar: aourednik/historical-basemaps (GPL-3.0) world_1880, 1865-yilga moslab O'rta Osiyo qayta chizilgan:
Buxoro amirligi, Xiva va Qo'qon xonliklari, turkman qabilalari; Qashqariya (Yoqubbek).
"""
import json, math, random, os
from shapely.geometry import shape, Polygon, MultiPolygon, Point, box
from shapely.ops import unary_union, voronoi_diagram
from shapely.validation import make_valid
from PIL import Image

HB = '/home/claude/data_dl/hb/geojson/'
OUT = '/home/claude/work/game/data/world_1865.json'
NORMAL = '/home/claude/data_dl/tx/earth_normal_2048.jpg'
K = 40.0; LON0 = 85.0; LAT0 = 40.0; C = math.cos(math.radians(LAT0))


def proj(lon, lat):
    return [round((lon - LON0) * K * C, 1), round(-(lat - LAT0) * K, 1)]


def load(year):
    d = json.load(open(HB + 'world_%s.geojson' % year))
    out = {}
    for f in d['features']:
        n = f['properties'].get('NAME')
        if not n:
            continue
        g = make_valid(shape(f['geometry'])).buffer(0)
        out[n] = unary_union([out[n], g]) if n in out else g
    return out


W = load('1880')
G = {}
def take(name):
    return W.pop(name, None)

# --- O'rta Osiyo 1865 ---------------------------------------------------
rus = take('Russian Empire')
ca_box = box(52.5, 35.0, 82.0, 45.6)
ca = unary_union([rus.intersection(ca_box), take('Bokhara Khanate'), take('central Asian khanates')])
G['KHI'] = ca.intersection(box(55.0, 38.6, 62.3, 45.6))
G['KOK'] = ca.intersection(unary_union([box(67.6, 39.0, 80.6, 42.6), box(69.5, 42.6, 76.0, 43.6)])).difference(G['KHI'])
G['BUK'] = ca.intersection(box(61.0, 36.8, 70.6, 41.4)).difference(G['KHI']).difference(G['KOK'])
G['TRK'] = ca.intersection(box(52.0, 35.0, 62.5, 41.0)).difference(G['KHI']).difference(G['BUK'])
G['RUS'] = rus.difference(unary_union([G['KHI'], G['KOK'], G['BUK'], G['TRK']]))
qng = take('Manchu Empire')
G['YAK'] = qng.intersection(box(73.0, 35.5, 90.0, 43.4))
G['QNG'] = qng.difference(G['YAK'])
G['OTT'] = unary_union([take('Ottoman Empire'), take('Bulgaria'), take('Bosnia-Herzegovina')])
G['FRA'] = unary_union([take('France'), take('Algeria (FR)')])
G['GBR'] = take('United Kingdom of Great Britain and Ireland')
G['IND'] = unary_union([take('British Raj'), take('Ceylon')])
SIMPLE = {'Afghanistan': 'AFG', 'Persia': 'PER', 'Germany': 'PRU', 'Austria Hungary': 'AUS', 'Italy': 'ITA', 'Spain': 'SPA',
    'Portugal': 'POR', 'Sweden–Norway': 'SWE', 'Denmark': 'DEN', 'Netherlands': 'NED', 'Belgium': 'BEL', 'Switzerland': 'SWI',
    'Greece': 'GRE', 'Romania': 'ROM', 'Serbia': 'SER', 'Montenegro': 'MON', 'Egypt': 'EGY', 'Arabia': 'ARA', 'Oman': 'OMA',
    'Trucial Oman': 'OMA', 'Qatar': 'OMA', 'Morocco': 'MOR', 'Imperial Japan': 'JAP', 'Korea': 'KOR', 'Rattanakosin Kingdom': 'SIA',
    'Annam': 'ANN', 'French Indochina': 'ANN', 'Nepal': 'NEP', 'Bhutan': 'NEP', 'Ethiopia': 'ETH', 'Harer (Egypt)': 'EGY',
    'Sokoto Caliphate': 'SOK', 'Sultanate of Zanzibar': 'ZAN', 'Malaya': 'MLY', 'Taiwan': 'QNG', 'Wadai Empire': 'WAD',
    'Kanem-Bornu': 'KAN', 'Tukular Caliphate': 'TUK', 'Netherlands Indies': 'NIN'}
for n, c in SIMPLE.items():
    g = take(n)
    if g is None:
        continue
    G[c] = unary_union([G[c], g]) if c in G else g

# Kavkaz (Tiflis, Boku, Yerevan) 1865-yilda Rossiya tarkibida
cauc = G['PER'].intersection(box(38.0, 38.85, 50.6, 44.6))
G['PER'] = G['PER'].difference(cauc)
G['RUS'] = unary_union([G['RUS'], cauc])

# culture -> 2-zamon askar modellari: ozbek, rus, ingliz, yevropa, usmonli, xitoy, boshqa
COUNTRIES = {
    'BUK': ("Buxoro amirligi", "#3f8f5a", 'ozbek'), 'KHI': ("Xiva xonligi", "#6aa05a", 'ozbek'), 'KOK': ("Qo'qon xonligi", "#2f7a6a", 'ozbek'),
    'TRK': ("Turkman qabilalari", "#a89a5a", 'ozbek'), 'AFG': ("Afg'oniston amirligi", "#7a8a4a", 'ozbek'),
    'RUS': ("Rossiya imperiyasi", "#3a7a3a", 'rus'), 'YAK': ("Qashqariya (Yoqubbek)", "#5aa08a", 'ozbek'),
    'QNG': ("Tsin imperiyasi (Xitoy)", "#c8a03a", 'xitoy'), 'KOR': ("Koreya (Joseon)", "#5a8ab0", 'xitoy'), 'JAP': ("Yaponiya", "#e0e0e0", 'xitoy'),
    'GBR': ("Britaniya", "#c0303a", 'ingliz'), 'IND': ("Britaniya Hindistoni", "#d05a5a", 'ingliz'),
    'PER': ("Eron (Qojorlar)", "#4a9a8a", 'usmonli'), 'OTT': ("Usmonlilar imperiyasi", "#b84a3a", 'usmonli'), 'EGY': ("Misr (Xediv)", "#d1b04a", 'usmonli'),
    'ARA': ("Arabiston amirliklari", "#c8a86a", 'usmonli'), 'OMA': ("Ummon", "#988a6a", 'usmonli'), 'MOR': ("Marokash", "#b07a4a", 'usmonli'),
    'FRA': ("Fransiya", "#3a6ab8", 'yevropa'), 'PRU': ("Prussiya va German yerlari", "#4a4a5a", 'yevropa'), 'AUS': ("Avstriya imperiyasi", "#d0c070", 'yevropa'),
    'ITA': ("Italiya qirolligi", "#4ab0a0", 'yevropa'), 'SPA': ("Ispaniya", "#c8a03a", 'yevropa'), 'POR': ("Portugaliya", "#4a8a5a", 'yevropa'),
    'SWE': ("Shvetsiya-Norvegiya", "#6a8ac0", 'yevropa'), 'DEN': ("Daniya", "#c06a6a", 'yevropa'), 'NED': ("Niderlandiya", "#e08a3a", 'yevropa'),
    'BEL': ("Belgiya", "#d0b04a", 'yevropa'), 'SWI': ("Shveytsariya", "#d04a4a", 'yevropa'), 'GRE': ("Gretsiya", "#5a8ad0", 'yevropa'),
    'ROM': ("Ruminiya", "#8a6a5a", 'yevropa'), 'SER': ("Serbiya", "#a05a5a", 'yevropa'), 'MON': ("Chernogoriya", "#9a7a5a", 'yevropa'),
    'SIA': ("Siam", "#c0a05a", 'boshqa'), 'ANN': ("Annam (Vyetnam)", "#b05a4a", 'boshqa'), 'NEP': ("Nepal", "#a06a5a", 'boshqa'),
    'ETH': ("Habashiston", "#6a9a4a", 'boshqa'), 'SOK': ("Sokoto xalifaligi", "#b09050", 'boshqa'), 'ZAN': ("Zanzibar", "#5aa08a", 'boshqa'),
    'MLY': ("Malay sultonliklari", "#a06a3a", 'boshqa'), 'WAD': ("Vaday", "#9a8a6a", 'boshqa'), 'KAN': ("Kanem-Bornu", "#b0905a", 'boshqa'),
    'TUK': ("Tukulor xalifaligi", "#a07a4a", 'boshqa'), 'NIN': ("Gollandiya Sharqiy Hindistoni", "#d0903a", 'boshqa'),
}

CITIES = """
Buxoro 64.42 39.77|Samarqand 66.96 39.65|Qarshi 65.79 38.86|Shahrisabz 66.83 39.06|Kattaqo'rg'on 66.26 39.90|Karmana 65.36 40.14|Termiz 67.28 37.22
Hisor 68.55 38.53|Dushanbe 68.78 38.56|Ko'lob 69.78 37.91|Chorjo'y 63.58 39.08|Kerki 65.22 37.83|Jizzax 67.84 40.12|O'ratepa 69.0 39.92
Xiva 60.36 41.38|Urganch 60.63 41.55|Xazorasp 61.07 41.32|Qo'ng'irot 58.87 43.07|Xo'jayli 59.45 42.40|Chimboy 59.78 42.94|To'rtko'l 61.0 41.55
Qo'qon 70.94 40.53|Toshkent 69.24 41.30|Andijon 72.34 40.78|Namangan 71.67 41.0|Marg'ilon 71.72 40.47|O'sh 72.80 40.53|Xo'jand 69.62 40.28
Chust 71.24 41.0|Pishpek 74.59 42.87|Avliyoota 71.37 42.90|Chirchiq 69.58 41.47|To'qmoq 75.29 42.84
Marv 61.83 37.60|Ashxobod 58.38 37.95|Qizilarvat 56.27 38.98|Tajan 60.52 37.38|Sarax 61.17 36.53|Balkanobod 54.35 39.51
Turkiston 68.25 43.30|Chimkent 69.60 42.32|Avliyo-ota-Shim 70.5 44.0|Perovsk 65.51 44.85|Kazalinsk 62.10 45.76|Verniy 76.95 43.24|Kopal 79.06 45.12
Semipalatinsk 80.23 50.41|Omsk 73.37 54.98|Orenburg 55.10 51.77|Orsk 58.57 51.20|Uralsk 51.37 51.23|Akmola 71.43 51.17|Turgay 63.6 49.6|Irgiz 61.27 48.62
Krasnovodsk 52.97 40.0|Guryev 51.88 47.11|Barnaul 83.78 53.35|Tomsk 84.95 56.49|Tobolsk 68.25 58.20|Yekaterinburg 60.60 56.84|Ufa 55.97 54.74
Qozon 49.12 55.79|Samara 50.10 53.20|Saratov 46.03 51.53|Astraxan 48.03 46.35|Tsaritsin 44.51 48.71|Stavropol 41.97 45.04|Tiflis 44.79 41.72
Boku 49.87 40.41|Yerevan 44.51 40.18|Moskva 37.62 55.76|Sankt-Peterburg 30.31 59.94|Kiyev 30.52 50.45|Odessa 30.73 46.48|Xarkov 36.23 49.99
Varshava 21.01 52.23|Vilna 25.28 54.69|Riga 24.11 56.95|Minsk 27.56 53.90|Smolensk 32.05 54.78|Voronej 39.20 51.66|Nijniy Novgorod 44.00 56.33
Vologda 39.89 59.22|Arxangelsk 40.52 64.54|Perm 56.25 58.01|Vyatka 49.67 58.60|Penza 45.0 53.2|Simferopol 34.10 44.95|Kishinyov 28.86 47.01
Irkutsk 104.28 52.29|Krasnoyarsk 92.87 56.01|Yakutsk 129.73 62.03|Chita 113.50 52.03|Blagoveshchensk 127.53 50.29|Xabarovsk 135.07 48.48
Vladivostok 131.89 43.12|Okhotsk 143.24 59.36|Yeniseysk 92.17 58.45|Turuxansk 87.98 65.79|Berezov 65.06 63.93|Obdorsk 66.6 66.53
Qashqar 75.99 39.47|Yorkent 77.24 38.42|Xo'tan 79.92 37.11|Oqsu 80.26 41.17|Kucha 82.96 41.72|Qorashahar 86.57 42.06|Turfon 89.19 42.95
Pekin 116.40 39.90|Nankin 118.80 32.06|Shanxay 121.47 31.23|Guanchjou 113.26 23.13|Chengdu 104.07 30.67|Sian 108.94 34.34|Vuchan 114.31 30.59
Changsha 112.94 28.23|Futszyan 119.30 26.08|Tszinan 117.12 36.65|Taiyuan 112.55 37.87|Lanchjou 103.83 36.06|Kunmin 102.71 25.04|Guyyan 106.71 26.58
Nanchan 115.86 28.68|Mukden 123.43 41.80|Jirin 126.55 43.84|Tsitsikar 123.92 47.35|Urga 106.90 47.92|Kobdo 91.64 48.00|Uliastay 96.84 47.74
Lxasa 91.17 29.65|Shigatse 88.88 29.27|Xining 101.78 36.62|Guylin 110.29 25.27|Kulja 81.32 43.91|Urumchi 87.62 43.83|Xami 93.51 42.83|Tayvan 120.68 24.14
Xanson 126.98 37.57|Pxenyan 125.75 39.02|Edo 139.69 35.68|Kioto 135.77 35.01|Osaka 135.50 34.69|Nagasaki 129.87 32.75|Sendai 140.87 38.27|Hakodate 140.73 41.77
Kobul 69.17 34.53|Qandahor 65.71 31.61|Hirot 62.20 34.35|Balx 66.90 36.76|Mozori-Sharif 67.11 36.70|G'azna 68.42 33.55|Jalolobod 70.45 34.43|Badaxshon 70.8 37.1
Maymana 64.78 35.92|Qunduz 68.86 36.73|Farah 62.11 32.37
Tehron 51.39 35.69|Isfahon 51.67 32.65|Sheroz 52.53 29.59|Tabriz 46.29 38.08|Mashhad 59.60 36.30|Kirmon 57.08 30.28|Yazd 54.36 31.90|Hamadon 48.51 34.80
Rasht 49.58 37.28|Astrobod 54.43 36.84|Kermonshoh 47.06 34.31|Bandar-Abbos 56.27 27.18|Ahvoz 48.67 31.32|Zohidon 60.86 29.50|Nishopur 58.80 36.21
Istanbul 28.97 41.01|Edirne 26.55 41.68|Sofiya 23.32 42.70|Salonika 22.94 40.64|Ankara 32.86 39.93|Konya 32.49 37.87|Izmir 27.14 38.42|Trabzon 39.72 41.0
Erzurum 41.27 39.91|Sivas 37.02 39.75|Diyarbakir 40.23 37.91|Bag'dod 44.36 33.31|Mosul 43.13 36.34|Basra 47.78 30.51|Halab 37.16 36.20|Damashq 36.29 33.51
Quddus 35.21 31.77|Beyrut 35.50 33.89|Tripoli 13.19 32.89|Bengazi 20.07 32.12|Sarayevo 18.41 43.86|Ruschuk 25.95 43.84|Varna 27.91 43.21|Adana 35.32 37.0
Makka 39.83 21.42|Madina 39.61 24.47|San'o 44.21 15.37|Jidda 39.17 21.49|Riyoz 46.72 24.69|Hail 41.69 27.52|Hasa 49.59 25.38|Masqat 58.41 23.59|Doha 51.53 25.29
Qohira 31.24 30.04|Iskandariya 29.92 31.20|Asyut 31.18 27.18|Asvan 32.90 24.09|Xartum 32.53 15.50|Dongola 30.48 19.17|El-Obeid 30.22 13.18|Sennar 33.63 13.55
Harar 42.12 9.31|Massava 39.45 15.61|Fes -5.00 34.03|Marokash -7.98 31.63|Rabat -6.84 34.02|Jazoir 3.06 36.75|Oran -0.64 35.70|Qusantina 6.61 36.36|Tunis 10.18 36.81
Parij 2.35 48.86|Lion 4.84 45.76|Marsel 5.37 43.30|Bordo -0.58 44.84|Tuluza 1.44 43.60|Nant -1.55 47.22|Lill 3.06 50.63|Strasburg 7.75 48.58|Ruan 1.10 49.44
Berlin 13.40 52.52|Kyoln 6.96 50.94|Myunxen 11.58 48.14|Gamburg 9.99 53.55|Frankfurt 8.68 50.11|Drezden 13.74 51.05|Breslau 17.04 51.11|Kenigsberg 20.51 54.71
Gannover 9.73 52.37|Shtutgart 9.18 48.78|Dansig 18.65 54.35|Poznan 16.93 52.41|Vena 16.37 48.21|Budapesht 19.04 47.50|Praga 14.42 50.08|Krakov 19.94 50.06
Lvov 24.03 49.84|Triyest 13.77 45.65|Zagreb 15.98 45.81|Venetsiya 12.33 45.44|Insbruk 11.40 47.27|Kolojvar 23.59 46.77|Temeshvar 21.23 45.75|Chernovtsi 25.94 48.29
Turin 7.69 45.07|Milan 9.19 45.46|Florensiya 11.26 43.77|Rim 12.50 41.90|Neapol 14.27 40.85|Palermo 13.36 38.12|Bari 16.87 41.12|Kalyari 9.12 39.22
Madrid -3.70 40.42|Barselona 2.17 41.39|Sevilya -5.98 37.39|Valensiya -0.38 39.47|Bilbao -2.93 43.26|Saragosa -0.89 41.65|Lissabon -9.14 38.72|Porto -8.61 41.15
London -0.12 51.51|Manchester -2.24 53.48|Edinburg -3.19 55.95|Dublin -6.26 53.35|Bristol -2.59 51.45|Glazgo -4.25 55.86|Belfast -5.93 54.60|Kork -8.47 51.90
Stokgolm 18.07 59.33|Oslo 10.75 59.91|Bergen 5.32 60.39|Trondxeym 10.40 63.43|Tromso 18.96 69.65|Gyoteborg 11.97 57.71|Lulea 22.15 65.58|Kopengagen 12.57 55.68
Amsterdam 4.90 52.37|Bryussel 4.35 50.85|Bern 7.45 46.95|Afina 23.73 37.98|Buxarest 26.10 44.43|Yassi 27.58 47.16|Belgrad 20.46 44.82|Setinye 18.92 42.39
Dehli 77.21 28.61|Kalkutta 88.36 22.57|Bombay 72.88 19.08|Madras 80.27 13.08|Lahor 74.35 31.55|Peshovar 71.57 34.01|Karachi 67.01 24.86|Lakxnau 80.95 26.85
Haydarobod 78.49 17.39|Agra 78.01 27.18|Patna 85.14 25.59|Nagpur 79.09 21.15|Ahmadobod 72.57 23.02|Srinagar 74.80 34.08|Rangun 96.16 16.84|Mandalay 96.08 21.98
Kolombo 79.86 6.93|Multon 71.47 30.20|Benares 82.97 25.32|Dakka 90.41 23.81|Bangalor 77.59 12.97|Indor 75.86 22.72|Kvetta 67.0 30.18
Katmandu 85.32 27.71|Bangkok 100.50 13.76|Chiangmay 98.99 18.79|Xue 107.59 16.46|Hanoy 105.85 21.03|Saygon 106.66 10.76|Pnompen 104.92 11.56
Gondar 37.47 12.60|Addis 38.74 9.03|Sokoto 5.24 13.06|Kano 8.52 12.00|Zanzibar 39.20 -6.16|Mombasa 39.67 -4.04|Abeshe 20.83 13.83|Kuka 13.55 12.9
Segu -6.27 13.43|Timbuktu -3.00 16.77|Kuala-Lumpur 101.69 3.14|Malakka 102.25 2.19|Batavia 106.85 -6.21|Surabaya 112.75 -7.25|Padang 100.35 -0.95|Makassar 119.42 -5.15
"""
cities = []
for chunk in CITIES.replace('\n', '|').split('|'):
    chunk = chunk.strip()
    if not chunk:
        continue
    parts = chunk.split()
    lat = float(parts[-1]); lon = float(parts[-2]); name = ' '.join(parts[:-2])
    name = name.replace('Avliyo-ota-Shim', 'Sozoq')
    cities.append((name, lon, lat))

# --- relyef: Yerning normal xaritasidan tog'lilik --------------------------
nimg = Image.open(NORMAL).convert('RGB')
NW, NH = nimg.size
npx = nimg.load()

def rough(lon, lat):
    x = int((lon + 180) / 360 * NW) % NW
    y = min(NH - 1, max(0, int((90 - lat) / 180 * NH)))
    r, g, b = npx[x, y]
    nx = r / 127.5 - 1; ny = g / 127.5 - 1
    return math.sqrt(nx * nx + ny * ny)

def mountain(poly):
    minx, miny, maxx, maxy = poly.bounds
    vals = []
    rnd = random.Random(7)
    tries = 0
    while len(vals) < 60 and tries < 600:
        tries += 1
        lon = rnd.uniform(minx, maxx); lat = rnd.uniform(miny, maxy)
        if poly.contains(Point(lon, lat)):
            vals.append(rough(lon, lat))
    if not vals:
        return 0.2
    vals.sort()
    v = vals[len(vals) // 2]
    return round(min(1.0, max(0.03, (v - 0.04) * 1.9)), 2)

RES = ['bugdoy', 'bugdoy', 'temir', 'oltin', 'tosh', 'yogoch', 'ot', 'ipak', 'paxta', 'kumir']
random.seed(1865)
# har bir shahar faqat bitta davlatga tegishli: o'zi ichida turgan yoki eng yaqin davlat
city_owner = {}
for n, lo, la in cities:
    pt = Point(lo, la)
    best = None; bd = 0.35
    for code, g in G.items():
        if code not in COUNTRIES or g is None or g.is_empty:
            continue
        dd = 0.0 if g.contains(pt) else g.distance(pt)
        if dd < bd:
            best, bd = code, dd
    if best:
        city_owner[n] = best
provs = []; geoms = []
for code, g in G.items():
    if code not in COUNTRIES or g is None or g.is_empty:
        continue
    g = make_valid(g).buffer(0)
    inside = [(n, lo, la) for n, lo, la in cities if city_owner.get(n) == code]
    if not inside:
        rp = g.representative_point()
        inside = [(COUNTRIES[code][0], rp.x, rp.y)]
    if len(inside) == 1:
        cells = [(inside[0], g)]
    else:
        pts = MultiPoint = unary_union([Point(lo, la) for _, lo, la in inside])
        vd = voronoi_diagram(pts, envelope=g.envelope.buffer(5))
        cells = []
        for (n, lo, la) in inside:
            pt = Point(lo, la)
            for cell in vd.geoms:
                if cell.contains(pt) or cell.distance(pt) < 1e-9:
                    cells.append(((n, lo, la), cell.intersection(g)))
                    break
    for (n, lo, la), cg in cells:
        cg = make_valid(cg)
        polys = [cg] if isinstance(cg, Polygon) else [x for x in getattr(cg, 'geoms', []) if isinstance(x, Polygon)]
        polys = [x.simplify(0.05, preserve_topology=True) for x in polys]
        polys = [x for x in polys if x.area > 0.02] or sorted(polys, key=lambda x: -x.area)[:1]
        if not polys:
            continue
        rings = []
        for poly in polys:
            pts = [proj(x, y) for x, y in list(poly.exterior.coords)[:-1]]
            if len(pts) >= 3:
                rings.append(pts)
        if not rings:
            continue
        cg = unary_union(polys)
        res = {random.choice(RES): random.randint(1, 5)}
        pop = int(max(30, random.lognormvariate(math.log(250), 0.6)))  # ming kishi
        cpt = Point(lo, la) if cg.buffer(0.05).contains(Point(lo, la)) else cg.representative_point()
        provs.append({'id': '%s-%d' % (code, len(provs)), 'name': n, 'country': code, 'center': proj(cpt.x, cpt.y),
                      'polys': rings, 'population': pop, 'resources': res, 'mount': mountain(cg)})
        geoms.append(cg)

for i, a in enumerate(geoms):
    ab = a.buffer(0.08)
    provs[i]['neighbors'] = [provs[j]['id'] for j, b in enumerate(geoms) if j != i and ab.intersects(b)]

used = sorted(set(p['country'] for p in provs))
out = {'era': 2, 'year': 1865, 'source': 'Chegaralar: aourednik/historical-basemaps (GPL-3.0)',
       'countries': {k: {'name': COUNTRIES[k][0], 'color': COUNTRIES[k][1], 'culture': COUNTRIES[k][2]} for k in used},
       'provinces': provs}
json.dump(out, open(OUT, 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(used), 'davlat', len(provs), 'viloyat', os.path.getsize(OUT) // 1024, 'KB',
      sum(len(r) for p in provs for r in p['polys']), 'nuqta')
for k in ['BUK', 'KHI', 'KOK', 'RUS', 'QNG', 'GBR', 'IND', 'OTT', 'PER', 'AFG']:
    print(k, [p['name'] for p in provs if p['country'] == k][:14], [p['mount'] for p in provs if p['country'] == k][:8])
