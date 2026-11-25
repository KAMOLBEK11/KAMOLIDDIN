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
        root.addView(Ui.featureCard(this, "🔐", Lang.get("perm_title", lang)) {
            startActivity(Intent(this, PermissionsActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "⚡", Lang.get("f_trigger", lang)) {
            startActivity(Intent(this, TriggerSettingsActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🚫", Lang.get("f_apps", lang)) {
            startActivity(Intent(this, AppListActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "📶", Lang.get("f_internet", lang)) {
            startActivity(Intent(this, InternetActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🌐", Lang.get("f_sites", lang)) {
            startActivity(Intent(this, SitesActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "📊", Lang.get("f_reports", lang)) {
            startActivity(Intent(this, ReportsActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🗺️", Lang.get("f_location", lang)) {
            startActivity(Intent(this, LocationActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🔑", Lang.get("change_pin", lang)) {
            startActivity(Intent(this, ChangePinActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "💳", Lang.get("f_license", lang)) {
            startActivity(Intent(this, LicenseActivity::class.java))
        })
        root.addView(Ui.featureCard(this, "🗑️", Lang.get("uninstall_title", lang)) {
            uninstallFlow(lang)
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

    private fun uninstallFlow(lang: String) {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = Lang.get("enter_pin", lang)
        }
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle(Lang.get("uninstall_title", lang))
            .setMessage(Lang.get("uninstall_pin", lang))
            .setView(input)
            .setPositiveButton(Lang.get("continue", lang)) { _, _ ->
                if (input.text.toString() == Prefs.getPin(this)) doUninstall()
                else android.widget.Toast.makeText(this, Lang.get("pin_wrong", lang), android.widget.Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun doUninstall() {
        try {
            val dpm = getSystemService(android.content.Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val cn = android.content.ComponentName(this, AdminReceiver::class.java)
            if (dpm.isAdminActive(cn)) dpm.removeActiveAdmin(cn)
        } catch (e: Exception) {}
        try {
            startActivity(Intent(Intent.ACTION_DELETE, android.net.Uri.parse("package:$packageName")))
        } catch (e: Exception) {}
    }
}
