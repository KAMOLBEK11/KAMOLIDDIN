package uz.nazorat.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView

/**
 * Ruxsatlar bo'limi — har bir tugma to'g'ridan-to'g'ri kerakli sozlamaga olib boradi.
 * Ota-ona nastroykani qidirib yurmaydi.
 */
class PermissionsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("perm_title", lang)))
        root.addView(Ui.body(this, Lang.get("perm_hint", lang)))

        root.addView(permCard("♿", "p_acc", accessibilityOn(), lang) {
            open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        })
        root.addView(permCard("📊", "p_usage", Usage.hasAccess(this), lang) {
            open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        })
        root.addView(permCard("🔌", "p_vpn", android.net.VpnService.prepare(this) == null, lang) {
            val i = android.net.VpnService.prepare(this)
            if (i != null) startActivity(i)
        })
        root.addView(permCard("🔋", "p_battery", null, lang) {
            try { open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"))) }
            catch (e: Exception) { open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
        })
        root.addView(permCard("🛡️", "p_admin", null, lang) {
            val cn = ComponentName(this, AdminReceiver::class.java)
            open(Intent(android.app.admin.DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(android.app.admin.DevicePolicyManager.EXTRA_DEVICE_ADMIN, cn)
                .putExtra(android.app.admin.DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    Lang.get("uninstall_protect", lang)))
        })
        root.addView(permCard("⚙️", "p_details", null, lang) {
            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        })

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun permCard(emoji: String, key: String, granted: Boolean?, lang: String, onClick: () -> Unit): MaterialCardView {
        val mark = when (granted) { true -> "  ✅"; false -> "  ❌"; else -> "" }
        return Ui.featureCard(this, emoji, Lang.get(key, lang) + mark, onClick)
    }

    private fun open(i: Intent) {
        try { startActivity(i) } catch (e: Exception) {
            try { startActivity(Intent(Settings.ACTION_SETTINGS)) } catch (e2: Exception) {}
        }
    }

    private fun accessibilityOn(): Boolean {
        val s = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return s.contains(packageName + "/" + ControlService::class.java.name)
    }
}
