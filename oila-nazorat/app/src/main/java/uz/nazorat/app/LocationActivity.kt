package uz.nazorat.app

import android.os.Bundle
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity

/**
 * Joylashuv / harakat tarixi (scaffold).
 * Keyingi bosqichda FusedLocationProvider + Google xaritasi ulanadi:
 * bola qayerdan qayerga borgani. Faqat ota-ona ko'radi.
 */
class LocationActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("location_title", lang)))
        root.addView(Ui.body(this, Lang.get("location_hint", lang)))

        val demo = listOf(
            "🏠 Uy" to "07:40",
            "🚌 Yo‘lda" to "07:55",
            "🏫 Maktab" to "08:10",
            "🏫 Maktab" to "13:30",
            "🏠 Uy" to "14:05"
        )
        for ((place, time) in demo) {
            root.addView(Ui.featureCard(this, place.substring(0, place.indexOf(' ')),
                place.substring(place.indexOf(' ') + 1) + "   —   " + time) {})
        }

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }
}
