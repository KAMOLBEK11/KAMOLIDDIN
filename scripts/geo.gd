class_name Geo
## Geografiya yordamchilari: xarita koordinatasi <-> kenglik/uzunlik, tog'lilik va cho'llik koeffitsientlari.

# xarita (world.json) chiziqli proyeksiya: Toshkent, Kobul, Pekin, Shanxay, Xaynan bo'yicha moslangan
const LON_A := 0.03251
const LON_B := 84.91
const LAT_A := -0.02495
const LAT_B := 39.98
const KM_PER_UNIT := 2.77

const MOUNT := {"TJK": 1.0, "KGZ": 0.95, "AFG": 0.75, "CHN": 0.5, "MNG": 0.35, "KAZ": 0.12, "UZB": 0.16, "TKM": 0.07}
const DESERT := {"TKM": 0.9, "UZB": 0.55, "AFG": 0.6, "KAZ": 0.35, "CHN": 0.5, "MNG": 0.45, "TJK": 0.2, "KGZ": 0.1}
const LOWLAND := ["Farg'ona", "Andijon", "Namangan", "Toshkent shahri", "Toshkent viloyati", "Sirdaryo", "Buxoro", "Navoiy",
	"Qoraqalpog'iston", "Xorazm", "Daşoguz", "Lebap", "Mary", "Balkan", "Surxondaryo", "Qashqadaryo", "Samarqand",
	"Jowzjan", "Balkh", "Kunduz", "Faryab", "Samangan", "Khatlon", "Herat", "Helmand", "Kandahar", "Nimruz", "Farah"]
const DISTRICTS := ["Yangiobod", "Oqtepa", "Bog'ishamol", "Qorasuv", "Olmazor", "Chinobod", "Do'stlik", "Navbahor",
	"Guliston", "Tinchlik", "Bahoriston", "Mustaqillik", "Oltinsoy", "Ko'kterak", "Sayxun", "Zarafshon", "Uchqo'rg'on", "Qumqo'rg'on"]


static func lonlat(p: Vector2) -> Vector2:
	return Vector2(p.x * LON_A + LON_B, LAT_B + p.y * LAT_A)


static func mountain(p: Dictionary) -> float:
	# 1400-yil xaritasida har viloyatning tog'liligi Yerning haqiqiy relyefidan hisoblangan
	if float(p.get("mount", -1.0)) >= 0.0:
		return float(p["mount"])
	var m: float = MOUNT.get(p["country"], 0.3)
	if p["name"] in LOWLAND:
		m *= 0.25
	return m


static func desert(p: Dictionary) -> float:
	return float(DESERT.get(p["country"], 0.3))
