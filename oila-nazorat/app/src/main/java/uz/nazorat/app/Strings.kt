package uz.nazorat.app

/**
 * Ilovaning hamma matnlari shu yerda, 5 tilda.
 * Android locale tizimiga bog'liq emas — shuning uchun "yangi lotin" kabi
 * nostandart variantlarni ham erkin qo'shish mumkin.
 *
 * Tillar:
 *   uz_lat  - O'zbek (lotin)
 *   uz_cyr  - Ўзбек (крил)
 *   uz_new  - Oʻzbek (yangi lotin: ş ğ ö ç)
 *   ru      - Русский
 *   en      - English
 */
object Lang {

    val codes = listOf("uz_lat", "uz_cyr", "uz_new", "ru", "en")

    val nativeName = mapOf(
        "uz_lat" to "O‘zbek (lotin)",
        "uz_cyr" to "Ўзбек (крил)",
        "uz_new" to "Oʻzbek (yangi lotin)",
        "ru" to "Русский",
        "en" to "English"
    )

    private val T: Map<String, Map<String, String>> = mapOf(

        "choose_language" to mapOf(
            "uz_lat" to "Tilni tanlang",
            "uz_cyr" to "Тилни танланг",
            "uz_new" to "Tilni tanlang",
            "ru" to "Выберите язык",
            "en" to "Choose language"
        ),
        "continue" to mapOf(
            "uz_lat" to "Davom etish",
            "uz_cyr" to "Давом этиш",
            "uz_new" to "Davom etiş",
            "ru" to "Продолжить",
            "en" to "Continue"
        ),
        "create_pin" to mapOf(
            "uz_lat" to "Ota-ona PIN kodini yarating",
            "uz_cyr" to "Ота-она PIN кодини яратинг",
            "uz_new" to "Ota-ona PIN kodini yarating",
            "ru" to "Создайте родительский PIN-код",
            "en" to "Create parent PIN code"
        ),
        "enter_pin" to mapOf(
            "uz_lat" to "PIN kodni kiriting",
            "uz_cyr" to "PIN кодни киритинг",
            "uz_new" to "PIN kodni kiriting",
            "ru" to "Введите PIN-код",
            "en" to "Enter PIN code"
        ),
        "repeat_pin" to mapOf(
            "uz_lat" to "PIN kodni takrorlang",
            "uz_cyr" to "PIN кодни такрорланг",
            "uz_new" to "PIN kodni takrorlang",
            "ru" to "Повторите PIN-код",
            "en" to "Repeat PIN code"
        ),
        "pin_mismatch" to mapOf(
            "uz_lat" to "PIN kodlar mos kelmadi",
            "uz_cyr" to "PIN кодлар мос келмади",
            "uz_new" to "PIN kodlar mos kelmadi",
            "ru" to "PIN-коды не совпадают",
            "en" to "PIN codes do not match"
        ),
        "pin_wrong" to mapOf(
            "uz_lat" to "PIN kod noto‘g‘ri",
            "uz_cyr" to "PIN код нотўғри",
            "uz_new" to "PIN kod notoʻgʻri",
            "ru" to "Неверный PIN-код",
            "en" to "Wrong PIN code"
        ),
        "save" to mapOf(
            "uz_lat" to "Saqlash",
            "uz_cyr" to "Сақлаш",
            "uz_new" to "Saqlaş",
            "ru" to "Сохранить",
            "en" to "Save"
        ),
        "dashboard" to mapOf(
            "uz_lat" to "Boshqaruv paneli",
            "uz_cyr" to "Бошқарув панели",
            "uz_new" to "Boşqaruv paneli",
            "ru" to "Панель управления",
            "en" to "Dashboard"
        ),
        "f_apps" to mapOf(
            "uz_lat" to "Ilovalarni bloklash",
            "uz_cyr" to "Иловаларни блоклаш",
            "uz_new" to "Ilovalarni bloklaş",
            "ru" to "Блокировка приложений",
            "en" to "App blocking"
        ),
        "f_internet" to mapOf(
            "uz_lat" to "Internetdan cheklash",
            "uz_cyr" to "Интернетдан чеклаш",
            "uz_new" to "Internetdan çeklaş",
            "ru" to "Ограничение интернета",
            "en" to "Internet restriction"
        ),
        "f_schedule" to mapOf(
            "uz_lat" to "Vaqt jadvali",
            "uz_cyr" to "Вақт жадвали",
            "uz_new" to "Vaqt jadvali",
            "ru" to "Расписание",
            "en" to "Time schedule"
        ),
        "f_sites" to mapOf(
            "uz_lat" to "Saytlarni filtrlash",
            "uz_cyr" to "Сайтларни филтрлаш",
            "uz_new" to "Saytlarni filtrlaş",
            "ru" to "Фильтр сайтов",
            "en" to "Website filter"
        ),
        "f_reports" to mapOf(
            "uz_lat" to "Hisobot",
            "uz_cyr" to "Ҳисобот",
            "uz_new" to "Hisobot",
            "ru" to "Отчёт",
            "en" to "Reports"
        ),
        "f_location" to mapOf(
            "uz_lat" to "Joylashuv (xarita)",
            "uz_cyr" to "Жойлашув (харита)",
            "uz_new" to "Joylaşuv (xarita)",
            "ru" to "Местоположение (карта)",
            "en" to "Location (map)"
        ),
        "f_license" to mapOf(
            "uz_lat" to "Tarif va litsenziya",
            "uz_cyr" to "Тариф ва лицензия",
            "uz_new" to "Tarif va litsenziya",
            "ru" to "Тариф и лицензия",
            "en" to "Plan & license"
        ),
        "reports_title" to mapOf(
            "uz_lat" to "Foydalanish hisoboti",
            "uz_cyr" to "Фойдаланиш ҳисоботи",
            "uz_new" to "Foydalaniş hisoboti",
            "ru" to "Отчёт об использовании",
            "en" to "Usage report"
        ),
        "reports_hint" to mapOf(
            "uz_lat" to "Bola qaysi ilovada qancha vaqt o‘tkazgani shu yerda ko‘rinadi. Bu ma’lumot faqat ota-onaga ko‘rinadi va telefon ichida qoladi.",
            "uz_cyr" to "Бола қайси иловада қанча вақт ўтказгани шу ерда кўринади. Бу маълумот фақат ота-онага кўринади ва телефон ичида қолади.",
            "uz_new" to "Bola qaysi ilovada qança vaqt oʻtkazgani şu yerda koʻrinadi. Bu maʼlumot faqat ota-onaga koʻrinadi va telefon içida qoladi.",
            "ru" to "Здесь видно, сколько времени ребёнок провёл в каждом приложении. Эти данные видит только родитель и они хранятся на телефоне.",
            "en" to "Here you can see how long the child spent in each app. Only the parent sees this, and it stays on the phone."
        ),
        "location_title" to mapOf(
            "uz_lat" to "Harakat tarixi",
            "uz_cyr" to "Ҳаракат тарихи",
            "uz_new" to "Harakat tarixi",
            "ru" to "История перемещений",
            "en" to "Movement history"
        ),
        "location_hint" to mapOf(
            "uz_lat" to "Bola qayerdan qayerga borgani xarita bo‘yicha shu yerda ko‘rsatiladi. Keyingi bosqichda Google xaritasi ulanadi.",
            "uz_cyr" to "Бола қаердан қаерга боргани харита бўйича шу ерда кўрсатилади. Кейинги босқичда Google харитаси уланади.",
            "uz_new" to "Bola qayerdan qayerga borgani xarita boʻyiça şu yerda koʻrsatiladi. Keyingi bosqiçda Google xaritasi ulanadi.",
            "ru" to "Здесь на карте показывается, откуда и куда ходил ребёнок. На следующем этапе подключится карта Google.",
            "en" to "The child's route is shown here on a map. Google Maps will be connected in the next stage."
        ),
        "trial_active" to mapOf(
            "uz_lat" to "Bepul sinov: %d kun qoldi",
            "uz_cyr" to "Бепул синов: %d кун қолди",
            "uz_new" to "Bepul sinov: %d kun qoldi",
            "ru" to "Бесплатный период: осталось %d дн.",
            "en" to "Free trial: %d days left"
        ),
        "license_active" to mapOf(
            "uz_lat" to "Tarif faol: %d kun qoldi",
            "uz_cyr" to "Тариф фаол: %d кун қолди",
            "uz_new" to "Tarif faol: %d kun qoldi",
            "ru" to "Тариф активен: осталось %d дн.",
            "en" to "Plan active: %d days left"
        ),
        "expired" to mapOf(
            "uz_lat" to "Muddat tugadi. Davom etish uchun tarifni faollashtiring.",
            "uz_cyr" to "Муддат тугади. Давом этиш учун тарифни фаоллаштиринг.",
            "uz_new" to "Muddat tugadi. Davom etiş uçun tarifni faollaştiring.",
            "ru" to "Срок истёк. Активируйте тариф, чтобы продолжить.",
            "en" to "Period ended. Activate a plan to continue."
        ),
        "plan_6" to mapOf(
            "uz_lat" to "6 oylik tarif",
            "uz_cyr" to "6 ойлик тариф",
            "uz_new" to "6 oylik tarif",
            "ru" to "Тариф на 6 месяцев",
            "en" to "6-month plan"
        ),
        "plan_12" to mapOf(
            "uz_lat" to "1 yillik tarif",
            "uz_cyr" to "1 йиллик тариф",
            "uz_new" to "1 yillik tarif",
            "ru" to "Тариф на 1 год",
            "en" to "1-year plan"
        ),
        "device_code" to mapOf(
            "uz_lat" to "Qurilma kodi",
            "uz_cyr" to "Қурилма коди",
            "uz_new" to "Qurilma kodi",
            "ru" to "Код устройства",
            "en" to "Device code"
        ),
        "enter_key" to mapOf(
            "uz_lat" to "Faollashtirish kalitini kiriting",
            "uz_cyr" to "Фаоллаштириш калитини киритинг",
            "uz_new" to "Faollaştiriş kalitini kiriting",
            "ru" to "Введите ключ активации",
            "en" to "Enter activation key"
        ),
        "activate" to mapOf(
            "uz_lat" to "Faollashtirish",
            "uz_cyr" to "Фаоллаштириш",
            "uz_new" to "Faollaştiriş",
            "ru" to "Активировать",
            "en" to "Activate"
        ),
        "key_ok" to mapOf(
            "uz_lat" to "Tarif faollashtirildi ✅",
            "uz_cyr" to "Тариф фаоллаштирилди ✅",
            "uz_new" to "Tarif faollaştirildi ✅",
            "ru" to "Тариф активирован ✅",
            "en" to "Plan activated ✅"
        ),
        "key_bad" to mapOf(
            "uz_lat" to "Kalit noto‘g‘ri yoki bu telefonga mos emas ❌",
            "uz_cyr" to "Калит нотўғри ёки бу телефонга мос эмас ❌",
            "uz_new" to "Kalit notoʻgʻri yoki bu telefonga mos emas ❌",
            "ru" to "Ключ неверный или не подходит этому телефону ❌",
            "en" to "Key is invalid or not for this phone ❌"
        ),
        "soon" to mapOf(
            "uz_lat" to "Bu bo‘lim keyingi bosqichda ulanadi.",
            "uz_cyr" to "Бу бўлим кейинги босқичда уланади.",
            "uz_new" to "Bu boʻlim keyingi bosqiçda ulanadi.",
            "ru" to "Этот раздел подключится на следующем этапе.",
            "en" to "This section will be added in the next stage."
        ),
        "f_trigger" to mapOf(
            "uz_lat" to "Tezkor yoqish (tugma)",
            "uz_cyr" to "Тезкор ёқиш (тугма)",
            "uz_new" to "Tezkor yoqiş (tugma)",
            "ru" to "Быстрое включение (кнопка)",
            "en" to "Quick toggle (button)"
        ),
        "block_title" to mapOf(
            "uz_lat" to "Bloklanadigan ilovalar",
            "uz_cyr" to "Блокланадиган иловалар",
            "uz_new" to "Bloklanadigan ilovalar",
            "ru" to "Блокируемые приложения",
            "en" to "Blocked apps"
        ),
        "block_hint" to mapOf(
            "uz_lat" to "Belgilangan ilovalar nazorat yoqilganda ochilmaydi.",
            "uz_cyr" to "Белгиланган иловалар назорат ёқилганда очилмайди.",
            "uz_new" to "Belgilangan ilovalar nazorat yoqilganda oçilmaydi.",
            "ru" to "Отмеченные приложения не откроются, когда контроль включён.",
            "en" to "Checked apps won't open when control is on."
        ),
        "trigger_title" to mapOf(
            "uz_lat" to "Tezkor yoqish sozlamasi",
            "uz_cyr" to "Тезкор ёқиш созламаси",
            "uz_new" to "Tezkor yoqiş sozlamasi",
            "ru" to "Настройка быстрого включения",
            "en" to "Quick toggle settings"
        ),
        "choose_button" to mapOf(
            "uz_lat" to "Qaysi tugma bilan yoqiladi",
            "uz_cyr" to "Қайси тугма билан ёқилади",
            "uz_new" to "Qaysi tugma bilan yoqiladi",
            "ru" to "Какой кнопкой включать",
            "en" to "Which button toggles it"
        ),
        "vol_down" to mapOf(
            "uz_lat" to "Ovozni pasaytirish tugmasi",
            "uz_cyr" to "Овозни пасайтириш тугмаси",
            "uz_new" to "Ovozni pasaytiriş tugmasi",
            "ru" to "Кнопка уменьшения громкости",
            "en" to "Volume Down button"
        ),
        "vol_up" to mapOf(
            "uz_lat" to "Ovozni balandlatish tugmasi",
            "uz_cyr" to "Овозни баландлатиш тугмаси",
            "uz_new" to "Ovozni balandlatiş tugmasi",
            "ru" to "Кнопка увеличения громкости",
            "en" to "Volume Up button"
        ),
        "hold_seconds" to mapOf(
            "uz_lat" to "Necha soniya bosib turiladi",
            "uz_cyr" to "Неча сония босиб турилади",
            "uz_new" to "Neça soniya bosib turiladi",
            "ru" to "Сколько секунд удерживать",
            "en" to "Hold duration (seconds)"
        ),
        "power_note" to mapOf(
            "uz_lat" to "Eslatma: o‘chirish (power) tugmasini Android ilovalarga bermaydi, shuning uchun ovoz tugmasi ishlatiladi.",
            "uz_cyr" to "Эслатма: ўчириш (power) тугмасини Android иловаларга бермайди, шунинг учун овоз тугмаси ишлатилади.",
            "uz_new" to "Eslatma: oʻçiriş (power) tugmasini Android ilovalarga bermaydi, şuning uçun ovoz tugmasi işlatiladi.",
            "ru" to "Примечание: кнопку питания Android не передаёт приложениям, поэтому используется кнопка громкости.",
            "en" to "Note: Android doesn't give the power button to apps, so a volume button is used."
        ),
        "control_status" to mapOf(
            "uz_lat" to "Nazorat holati",
            "uz_cyr" to "Назорат ҳолати",
            "uz_new" to "Nazorat holati",
            "ru" to "Состояние контроля",
            "en" to "Control status"
        ),
        "on" to mapOf(
            "uz_lat" to "Yoqilgan",
            "uz_cyr" to "Ёқилган",
            "uz_new" to "Yoqilgan",
            "ru" to "Включено",
            "en" to "On"
        ),
        "off" to mapOf(
            "uz_lat" to "O‘chiq",
            "uz_cyr" to "Ўчиқ",
            "uz_new" to "Oʻçiq",
            "ru" to "Выключено",
            "en" to "Off"
        ),
        "open_acc" to mapOf(
            "uz_lat" to "Maxsus imkoniyatlar ruxsatini ochish",
            "uz_cyr" to "Махсус имкониятлар рухсатини очиш",
            "uz_new" to "Maxsus imkoniyatlar ruxsatini oçiş",
            "ru" to "Открыть разрешение «Специальные возможности»",
            "en" to "Open Accessibility permission"
        ),
        "acc_needed" to mapOf(
            "uz_lat" to "Ishlashi uchun «Maxsus imkoniyatlar»da shu ilovani yoqing.",
            "uz_cyr" to "Ишлаши учун «Махсус имкониятлар»да шу иловани ёқинг.",
            "uz_new" to "İşlaşi uçun «Maxsus imkoniyatlar»da şu ilovani yoqing.",
            "ru" to "Чтобы работало, включите это приложение в «Специальных возможностях».",
            "en" to "To make it work, enable this app in Accessibility settings."
        ),
        "uninstall_protect" to mapOf(
            "uz_lat" to "O‘chirishdan himoya (administrator)",
            "uz_cyr" to "Ўчиришдан ҳимоя (администратор)",
            "uz_new" to "Oʻçirişdan himoya (administrator)",
            "ru" to "Защита от удаления (администратор)",
            "en" to "Uninstall protection (admin)"
        ),
        "schedule_title" to mapOf(
            "uz_lat" to "Vaqt jadvali (tungi bloklash)",
            "uz_cyr" to "Вақт жадвали (тунги блоклаш)",
            "uz_new" to "Vaqt jadvali (tungi bloklaş)",
            "ru" to "Расписание (ночная блокировка)",
            "en" to "Schedule (night blocking)"
        ),
        "sched_enable" to mapOf(
            "uz_lat" to "Tungi bloklashni yoqish",
            "uz_cyr" to "Тунги блоклашни ёқиш",
            "uz_new" to "Tungi bloklaşni yoqiş",
            "ru" to "Включить ночную блокировку",
            "en" to "Enable night blocking"
        ),
        "sched_from" to mapOf(
            "uz_lat" to "Dan (soat)",
            "uz_cyr" to "Дан (соат)",
            "uz_new" to "Dan (soat)",
            "ru" to "С (час)",
            "en" to "From (hour)"
        ),
        "sched_to" to mapOf(
            "uz_lat" to "Gacha (soat)",
            "uz_cyr" to "Гача (соат)",
            "uz_new" to "Gaça (soat)",
            "ru" to "До (час)",
            "en" to "To (hour)"
        ),
        "saved" to mapOf(
            "uz_lat" to "Saqlandi ✅",
            "uz_cyr" to "Сақланди ✅",
            "uz_new" to "Saqlandi ✅",
            "ru" to "Сохранено ✅",
            "en" to "Saved ✅"
        )
    )

    fun get(key: String, lang: String): String {
        return T[key]?.get(lang) ?: T[key]?.get("uz_lat") ?: key
    }
}
