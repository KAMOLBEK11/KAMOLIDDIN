package uz.nazorat.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView

/**
 * Ruxsatlar bo'limi — har bir tugma to'g'ridan-to'g'ri kerakli sozlamaga olib boradi.
 * Qaytib kelganda belgilar (✅/❌) avtomatik yangilanadi.
 */
class PermissionsActivity : AppCompatActivity() {

    private lateinit var root: LinearLayout
    private lateinit var lang: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lang = Prefs.getLang(this)
        root = Ui.screen(this)
        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
        render()
    }

    override fun onResume() {
        super.onResume()
        render() // qaytib kelganda belgilarni yangilaymiz
    }

    private fun render() {
        root.removeAllViews()
        root.addView(Ui.title(this, Lang.get("perm_title", lang)))
        root.addView(Ui.body(this, Lang.get("perm_hint", lang)))

        root.addView(permCard("♿", "p_acc", accessibilityOn()) {
            open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        })
        root.addView(permCard("📊", "p_usage", Usage.hasAccess(this)) {
            open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        })
        root.addView(permCard("🔌", "p_vpn", android.net.VpnService.prepare(this) == null) {
            // VPN ruxsati "Internetdan cheklash" bo'limidagi kalit orqali beriladi (to'g'ri oqim)
            startActivity(Intent(this, InternetActivity::class.java))
        })
        root.addView(permCard("📍", "p_location", locGranted()) {
            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        })
        root.addView(permCard("🔋", "p_battery", batteryOk()) {
            try { open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))) }
            catch (e: Exception) { open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
        })
        root.addView(permCard("🚀", "p_autostart", null) { openAutostart() })
        root.addView(permCard("🛡️", "p_admin", adminOn()) {
            val cn = ComponentName(this, AdminReceiver::class.java)
            open(Intent(android.app.admin.DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(android.app.admin.DevicePolicyManager.EXTRA_DEVICE_ADMIN, cn)
                .putExtra(android.app.admin.DevicePolicyManager.EXTRA_ADD_EXPLANATION, Lang.get("uninstall_protect", lang)))
        })
        root.addView(permCard("⚙️", "p_details", null) {
            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        })
    }

    private fun permCard(emoji: String, key: String, granted: Boolean?, onClick: () -> Unit): MaterialCardView {
        val mark = when (granted) { true -> "  ✅"; false -> "  ❌"; else -> "" }
        return Ui.featureCard(this, emoji, Lang.get(key, lang) + mark, onClick)
    }

    private fun open(i: Intent) {
        try { startActivity(i) } catch (e: Exception) {
            try { startActivity(Intent(Settings.ACTION_SETTINGS)) } catch (e2: Exception) {}
        }
    }

    /** OEM avtozapusk ekranlari — bir nechta ma'lum variantni sinab ko'ramiz. */
    private fun openAutostart() {
        val intents = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.transsion.phonemanager", "com.itel.autobootmanager.activity.AutoBootMgrActivity")
        )
        for (cn in intents) {
            val i = Intent().setComponent(cn).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try { startActivity(i); return } catch (e: Exception) {}
        }
        open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    private fun locGranted(): Boolean =
        androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun batteryOk(): Boolean {
        return try {
            val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M)
                pm.isIgnoringBatteryOptimizations(packageName) else true
        } catch (e: Exception) { false }
    }

    private fun adminOn(): Boolean {
        return try {
            val dpm = getSystemService(android.content.Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            dpm.isAdminActive(ComponentName(this, AdminReceiver::class.java))
        } catch (e: Exception) { false }
    }

    private fun accessibilityOn(): Boolean {
        val s = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return s.contains(packageName + "/" + ControlService::class.java.name) || s.contains("$packageName/.ControlService")
    }
}
