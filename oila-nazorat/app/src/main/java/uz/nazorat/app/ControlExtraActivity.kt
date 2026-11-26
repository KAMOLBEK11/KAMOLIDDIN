package uz.nazorat.app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch

/** Kamera va Play Market boshqaruvi. */
class ControlExtraActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("extra_title", lang)))

        // Play Market bloklash
        val sPs = MaterialSwitch(this).apply {
            text = Lang.get("ps_block", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.playStoreBlocked(this@ControlExtraActivity)
            setOnCheckedChangeListener { _, c -> Prefs.setPlayStoreBlocked(this@ControlExtraActivity, c) }
        }
        root.addView(sPs)
        root.addView(Ui.body(this, Lang.get("ps_hint", lang)))

        // Kamerani butunlay bloklash (qurilma administratori orqali)
        root.addView(spacer())
        val sCam = MaterialSwitch(this).apply {
            text = Lang.get("cam_block", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.cameraBlocked(this@ControlExtraActivity)
        }
        sCam.setOnCheckedChangeListener { _, c ->
            if (!applyCamera(c)) {
                sCam.isChecked = false
                android.widget.Toast.makeText(this, Lang.get("cam_need_admin", lang), android.widget.Toast.LENGTH_LONG).show()
            } else {
                Prefs.setCameraBlocked(this, c)
            }
        }
        root.addView(sCam)
        root.addView(Ui.body(this, Lang.get("cam_hint", lang)))

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun applyCamera(disabled: Boolean): Boolean {
        return try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val cn = ComponentName(this, AdminReceiver::class.java)
            if (!dpm.isAdminActive(cn)) {
                // Administratorni so'raymiz
                startActivity(Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, cn))
                return false
            }
            dpm.setCameraDisabled(cn, disabled)
            true
        } catch (e: Exception) { false }
    }

    private fun spacer() = android.widget.TextView(this).apply {
        text = ""; setPadding(0, Ui.dp(this@ControlExtraActivity, 10), 0, 0)
    }
}
