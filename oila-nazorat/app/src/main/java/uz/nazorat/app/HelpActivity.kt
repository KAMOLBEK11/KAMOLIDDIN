package uz.nazorat.app

import android.os.Bundle
import android.text.method.LinkMovementMethod
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/** Dastur qanday ishlashi — sodda tushuntirish. */
class HelpActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("help_title", lang)))

        val tv = TextView(this).apply {
            text = body(lang)
            setTextColor(Ui.TEXT)
            textSize = 15f
            setLineSpacing(Ui.dp(this@HelpActivity, 4).toFloat(), 1f)
            movementMethod = LinkMovementMethod.getInstance()
        }
        root.addView(tv)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun body(lang: String): String = when (lang) {
        "ru" -> """
            Это приложение помогает родителям контролировать телефон ребёнка. Все данные остаются в телефоне.

            🔐 Разрешения — откройте раздел «Разрешения» и включите по очереди. Самое важное: «Специальные возможности» (для блокировки) и отключение ограничения батареи и автозапуска, иначе система «убивает» защиту.

            🚫 Блокировка приложений — выберите приложения и режим: полностью / после N часов использования / в интервале времени / через N часов. Когда ребёнок открывает такое приложение, оно просто закрывается.

            📶 Отключение интернета (VPN) — включите и отметьте приложения. У них не будет интернета (Wi-Fi и моб.), остальные работают.

            🌐 Фильтр сайтов — блокирует вредные и 18+ сайты в браузере.

            ⚡ Быстрое включение — удерживайте кнопку громкости N секунд, чтобы включить/выключить контроль.

            📱 Play Market — чтобы разрешить загрузку, временно переключите режим или отключите блокировку интернета; после установки снова включите.

            🔑 PIN — запрашивается при каждом входе. Удалить приложение можно только по PIN.

            ⚠️ Контроль работает постоянно (значок «VPN» в шторке — это и есть защита, не выключайте её).
        """.trimIndent()
        "en" -> """
            This app helps parents control a child's phone. All data stays on the phone.

            🔐 Permissions — open «Permissions» and enable them one by one. Most important: Accessibility (for blocking) and turning off battery optimization and enabling autostart, otherwise the system kills the protection.

            🚫 App blocking — pick apps and a mode: fully / after N hours of use / within a time window / after N hours. When the child opens such an app, it just closes.

            📶 Internet cut (VPN) — turn it on and mark apps. They get no internet (Wi-Fi and mobile); others still work.

            🌐 Site filter — blocks harmful and 18+ sites in the browser.

            ⚡ Quick toggle — hold a volume button for N seconds to turn control on/off.

            📱 Play Market — to allow a download, temporarily switch the mode or turn off the internet cut; turn it back on after installing.

            🔑 PIN — asked on every entry. The app can be uninstalled only with the PIN.

            ⚠️ Control runs all the time (the «VPN» icon in the status bar IS the protection — don't turn it off).
        """.trimIndent()
        "uz_cyr" -> """
            Бу илова ота-оналарга фарзанд телефонини назорат қилишга ёрдам беради. Барча маълумот телефон ичида қолади.

            🔐 Рухсатлар — «Рухсатлар» бўлимини очиб, бирма-бир ёқинг. Энг муҳими: «Махсус имкониятлар» (блоклаш учун) ва батарея чеклови ҳамда автозапускни ёқиш, акс ҳолда тизим ҳимояни «ўлдиради».

            🚫 Иловаларни блоклаш — иловаларни ва режимни танланг: бутунлай / N соат фойдалангандан кейин / вақт оралиғида / N соатдан кейин. Бола очганда илова шунчаки ёпилади.

            📶 Интернетдан узиш (VPN) — ёқиб, иловаларни белгиланг. Уларда интернет бўлмайди (Wi-Fi ва моб.), қолгани ишлайди.

            🌐 Сайт филтри — браузерда зарарли ва 18+ сайтларни блоклайди.

            ⚡ Тезкор ёқиш — овоз тугмасини N сония босиб туринг.

            📱 Play Market — юклаб олишга рухсат бериш учун режимни вақтинча ўзгартиринг ёки интернет узишни ўчиринг; ўрнатгач қайта ёқинг.

            🔑 PIN — ҳар кирганда сўралади. Иловани фақат PIN билан ўчириш мумкин.

            ⚠️ Назорат доим ишлайди (пардадаги «VPN» белгиси — бу ҳимоя, уни ўчирманг).
        """.trimIndent()
        "uz_new" -> """
            Bu ilova ota-onalarga farzand telefonini nazorat qilişga yordam beradi. Barça maʼlumot telefon içida qoladi.

            🔐 Ruxsatlar — «Ruxsatlar» boʻlimini oçib, birma-bir yoqing. Eng muhimi: «Maxsus imkoniyatlar» (bloklaş uçun) va batareya çeklovi hamda avtozapuskni yoqiş.

            🚫 Ilovalarni bloklaş — ilovalar va rejimni tanlang: butunlay / N soat foydalangandan keyin / vaqt oraligʻida / N soatdan keyin.

            📶 Internetdan uziş (VPN) — yoqib, ilovalarni belgilang. Ularda internet boʻlmaydi.

            🌐 Sayt filtri — brauzerda zararli va 18+ saytlarni bloklaydi.

            ⚡ Tezkor yoqiş — ovoz tugmasini N soniya bosib turing.

            📱 Play Market — yuklab oliş uçun rejimni vaqtinça oʻzgartiring yoki internet uzişni oʻçiring; oʻrnatgaç qayta yoqing.

            🔑 PIN — har kirganda soʻraladi. Ilovani faqat PIN bilan oʻçiriş mumkin.

            ⚠️ Nazorat doim işlaydi (pardadagi «VPN» belgisi — bu himoya, uni oʻçirmang).
        """.trimIndent()
        else -> """
            Bu ilova ota-onalarga farzand telefonini nazorat qilishga yordam beradi. Barcha ma'lumot telefon ichida qoladi, tashqariga chiqmaydi.

            🔐 Ruxsatlar — «Ruxsatlar» bo'limini oching va birma-bir yoqing. Eng muhimi: «Maxsus imkoniyatlar» (bloklash uchun), hamda batareya cheklovini o'chirish va avtozapuskni yoqish. Bo'lmasa, tizim himoyani «o'ldiradi» va dastur ishlamay qoladi.

            🚫 Ilovalarni bloklash — ilovalarni tanlab, rejimni belgilang: butunlay / N soat foydalangandan keyin / vaqt oralig'ida / N soatdan keyin. Bola bloklangan ilovani ochsa, u shunchaki yopiladi (bola "bloklandi" yozuvini ko'rmaydi).

            📶 Internetdan uzish (VPN) — yoqib qo'ying va ilovalarni belgilang. O'sha ilovalarda internet ishlamaydi (Wi-Fi ham, mobil ham), qolgan ilovalar ishlab turadi. Yoqilgandan keyin siz o'chirmaguningizcha ishlab turadi.

            🌐 Saytlarni filtrlash — brauzerda zararli va kattalar (18+) saytlarini bloklaydi.

            ⚡ Tezkor yoqish — tanlangan ovoz tugmasini N soniya bosib tursangiz, nazorat yonadi yoki o'chadi.

            📱 Play Market — yangi ilova yuklab olishga ruxsat berish uchun «To'lov sozlamalari»dan emas, nazoratni yoki internet uzishni vaqtincha o'chiring; ilova o'rnatilgach, qayta yoqing.

            🔑 PIN kod — dasturga har kirganda so'raladi. Dasturni o'chirish ham faqat PIN bilan mumkin.

            ⚠️ Nazorat doim ishlab turishi kerak. Yuqoridagi pardada «VPN» belgisi ko'rinadi — bu himoyaning o'zi, uni o'chirmang. Telefonni "tozalash" (recent) tugmasi bilan tozalaganda ham dastur ishlab turadi.
        """.trimIndent()
    }
}
