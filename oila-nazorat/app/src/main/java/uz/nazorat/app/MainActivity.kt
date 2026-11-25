package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView

/** Bosh ekran — ota-ona boshqaruv paneli. */
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)

        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("dashboard", lang)))

        // Litsenziya holati — yuqorida chiroyli karta
        root.addView(statusCard(lang))

        // Funksiya bo'limlari
        root.addView(Ui.featureCard(this, "⚡", Lang.get("f_trigger", lang)) {
            startActivity(Intent(this, TriggerSettingsActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🚫", Lang.get("f_apps", lang)) {
            startActivity(Intent(this, AppListActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "⏰", Lang.get("f_schedule", lang)) {
            startActivity(Intent(this, ScheduleActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "📶", Lang.get("f_internet", lang)) { soon() })
        root.addView(Ui.featureCard(this, "🌐", Lang.get("f_sites", lang)) { soon() })
        root.addView(Ui.featureCard(this, "📊", Lang.get("f_reports", lang)) {
            startActivity(Intent(this, ReportsActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🗺️", Lang.get("f_location", lang)) {
            startActivity(Intent(this, LocationActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "💳", Lang.get("f_license", lang)) {
            startActivity(Intent(this, LicenseActivity::class.java))
        })

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }

    private fun statusCard(lang: String): MaterialCardView {
        val card = MaterialCardView(this).apply {
            radius = Ui.dp(this@MainActivity, 16).toFloat()
            cardElevation = 0f
        }
        val state = LicenseManager.state(this)
        val days = LicenseManager.daysLeft(this)
        val (bg, text) = when (state) {
            LicenseManager.State.TRIAL ->
                Ui.BLUE to String.format(Lang.get("trial_active", lang), days)
            LicenseManager.State.LICENSED ->
                Ui.GREEN to String.format(Lang.get("license_active", lang), days)
            LicenseManager.State.EXPIRED ->
                Ui.RED to Lang.get("expired", lang)
        }
        card.setCardBackgroundColor(bg)
        card.addView(TextView(this).apply {
            this.text = text
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            setPadding(
                Ui.dp(this@MainActivity, 18), Ui.dp(this@MainActivity, 18),
                Ui.dp(this@MainActivity, 18), Ui.dp(this@MainActivity, 18)
            )
        })
        card.setOnClickListener {
            startActivity(Intent(this, LicenseActivity::class.java))
        }
        return card
    }

    private fun soon() {
        android.widget.Toast.makeText(
            this, Lang.get("soon", Prefs.getLang(this)),
            android.widget.Toast.LENGTH_SHORT
        ).show()
    }
}
