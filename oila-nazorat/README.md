# Oila Nazorat — ota-ona nazorati ilovasi (v0.2)

GitHub o'zi APK yig'ib beradi — kompyuterda Android Studio shart emas.

## Telefonda sozlash (bir marta)

1. Ilovani o'rnating, tilni tanlang, ota-ona PIN kodini yarating.
2. Bosh ekran → **⚡ Tezkor yoqish** → **«Maxsus imkoniyatlar ruxsatini ochish»** → ro'yxatdan "Oila Nazorat"ni toping va yoqing. (Bu bo'lmasa bloklash va tugma ishlamaydi.)
3. Bosh ekran → **🚫 Bloklanadigan ilovalar** → bloklanadigan ilovalarni belgilang → Saqlash.
4. **⚡ Tezkor yoqish** da: qaysi ovoz tugmasi va necha soniya bosilishini tanlang. Xohlasangiz **O'chirishdan himoya**ni ham yoqing.
5. Tayyor. Endi tanlangan ovoz tugmasini N soniya bosib tursangiz — nazorat yonadi (telefon qaltiraydi). Yana bosib tursangiz — o'chadi.

## APK ni qanday olish (qadamma-qadam)

1. **github.com** da ro'yxatdan o'ting (bepul).
2. Yuqori o'ngdagi **+** → **New repository**. Nom: `oila-nazorat`. **Private** qilib qo'ying. **Create**.
3. Yangi repo sahifasida **uploading an existing file** havolasini bosing.
4. Shu papkadagi **hamma fayl va papkalarni** (`.github`, `app`, `gradle`, `build.gradle.kts`, `settings.gradle.kts` va boshqalar) tortib tashlang (drag & drop). **Commit changes**.
5. Yuqoridagi **Actions** bo'limiga o'ting. "APK yig'ish" degan jarayon o'zi ishga tushadi (2–4 daqiqa). Agar turib qolsa, **Run workflow** tugmasini bosing.
6. Yashil ✅ belgisi chiqqach, o'sha jarayonni oching va pastdagi **Artifacts** bo'limidan **oila-nazorat-apk** ni yuklab oling.
7. ZIP ichida `app-debug.apk` bo'ladi. Uni telefonga o'tkazib o'rnating (noma'lum manbaga ruxsat berasiz).

## Hozir nima ishlaydi (v0.2)

- 5 tilda interfeys: O'zbek (lotin / kril / yangi lotin ş ğ ö ç), Rus, Ingliz.
- Zamonaviy interfeys, ota-ona PIN kodi.
- **Ilovalarni haqiqiy bloklash** — tanlangan ilovalar ochilganda yopiladi (bola "bloklandi" yozuvini ko'rmaydi).
- **Tezkor yoqish** — ovoz tugmasini N soniya bosib turib nazoratni yoqish/o'chirish.
- **Tungi jadval** — belgilangan soatlarda avtomatik bloklash.
- **O'chirishdan himoya** — qurilma administratori.
- 15 kunlik bepul sinov + 6 oy / 1 yil tarif, oflayn kalit.

## Keyingi bosqichlarda qo'shiladi

- Internetdan uzish — Wi-Fi va mobil (lokal VPN).
- Saytlarni filtrlash.
- Haqiqiy foydalanish hisoboti (UsageStatsManager).
- Google xaritasida harakat tarixi.
- To'liq himoya (Device Owner — zavod sozlamalaridan ham himoya).
- Hosting + Telegram-bot: to'lovdan keyin kalit avtomatik yuboriladi.

## Kalit qanday yasaladi (siz uchun)

Ilova har telefonda **qurilma kodi** ko'rsatadi. Tarif kaliti:

    kalit = "<kunlar>-<imzo>"
    kunlar: 180 (6 oy) yoki 365 (1 yil)
    imzo   = SHA-256(qurilmaKodi + kunlar + SECRET) ning birinchi 10 belgisi (katta harf)

`SECRET` hozir `LicenseManager.kt` ichida. Keyin xuddi shu formulani hostingdagi
Telegram-bot ishlatadi: mijoz qurilma kodini yuboradi, to'lovdan keyin bot kalitni
avtomatik qaytaradi. Mustahkamroq himoya uchun bu keyin Ed25519 imzosiga o'tkaziladi.
