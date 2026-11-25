package uz.nazorat.app

import android.os.Bundle
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity

/**
 * Hisobot ekrani (scaffold).
 * Keyingi bosqichda UsageStatsManager orqali haqiqiy ilova vaqtlari ulanadi:
 * bola qaysi ilovada qancha o'tirgani. Bu ma'lumot telefon ichida qoladi.
 */
class ReportsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("reports_title", lang)))
        root.addView(Ui.body(this, Lang.get("reports_hint", lang)))

        // Namuna qatorlar (keyin haqiqiy ma'lumot bilan almashtiriladi)
        val demo = listOf(
            "📱 YouTube" to "2 s 15 daq",
            "🎮 O‘yin" to "1 s 40 daq",
            "💬 Telegram" to "55 daq",
            "📸 Instagram" to "48 daq",
            "🏫 Maktab ilovasi" to "20 daq"
        )
        for ((name, dur) in demo) {
            val card = Ui.featureCard(this, name.substring(0, name.indexOf(' ')),
                name.substring(name.indexOf(' ') + 1) + "   —   " + dur) {}
            root.addView(card)
        }

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }
}
