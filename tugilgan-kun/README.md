# Tugʻilgan kun taqvimi (Android)

Tugʻilgan sanani milodiy va hijriy taqvimda koʻrsatadigan Android ilova:
hafta kuni, hijriy sana (oʻzbekcha va arabcha), muchal yili, burj, yosh,
keyingi tugʻilgan kun, koʻrilgan Ramazonlar soni va hijriydan milodiyga oʻgirgich.

Ilovada 4 ta boʻlim bor:
- **Hisob** — tugʻilgan sana boʻyicha hamma maʼlumot, taqvim varagʻi rasmini yasash va ulashish
- **Roʻyxat** — yaqinlarning tugʻilgan kunlari, har kuni soat 9:00 atrofida eslatma
- **Bayramlar** — Islomiy muborak kunlar va ularga necha kun qolgani
- **Taqvim** — hijriy sanalar yonma-yon koʻrinadigan oylik taqvim, oʻgirgich, muchal charxi

## APK qanday olinadi

Bu papkadagi biror fayl oʻzgartirilib GitHub'ga yuklansa, GitHub Actions
avtomatik ravishda APK yigʻadi va uni **Releases** boʻlimiga joylaydi.

1. Repozitoriyning **Releases** boʻlimini oching.
2. Eng yangi "Tugʻilgan kun taqvimi" relizidagi `TugilganKun.apk` faylini yuklab oling.
3. Telefonda oching. Telefon soʻrasa, "Nomaʼlum manbalardan oʻrnatish"ga ruxsat bering.

Qoʻlda qayta yigʻish: **Actions → Tugilgan kun APK → Run workflow**.

## Tuzilishi

- `app/src/main/assets/index.html` — butun dastur (HTML + JavaScript). Oʻzgartirishlar shu yerda.
- `app/src/main/java/.../MainActivity.java` — sahifani ochadigan WebView, nusxalash, rasm ulashish va saqlash.
- `app/src/main/java/.../Reminder.java` — kunlik eslatma bildirishnomalari.
- `.gdignore` — Godot muharriri bu papkaga tegmasligi uchun.

## Play Market uchun imzo kaliti

Repozitoriy **Settings → Secrets and variables → Actions** boʻlimiga 4 ta secret qoʻshing:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
Shundan keyin har yigʻishda Releases'ga imzolangan `TugilganKun-PlayMarket.aab` ham qoʻyiladi.
Kalit qoʻshilmagan boʻlsa, faqat sinov (debug) APK yigʻiladi.

Doʻkon matni, rasmlar va savollarga javoblar: `play-market/PLAY_MARKET.md`.
Maxfiylik siyosati: `MAXFIYLIK.md`.

## Eslatma
- Hijriy sana Umm al-Quro taqvimi boʻyicha. Oʻzbekistonda 1 kun farq boʻlishi mumkin.
