package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.KeyEvent
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch

/** Tezkor yoqish (ovoz tugmasi) sozlamalari. */
class TriggerSettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("trigger_title", lang)))

        // Nazorat holati (qo'lda ham yoqish mumkin)
        val sw = MaterialSwitch(this).apply {
            text = Lang.get("control_status", lang) + ": " +
                Lang.get(if (Prefs.controlActive(this@TriggerSettingsActivity)) "on" else "off", lang)
            setTextColor(Ui.TEXT)
            textSize = 17f
            isChecked = Prefs.controlActive(this@TriggerSettingsActivity)
        }
        sw.setOnCheckedChangeListener { _, checked ->
            Prefs.setControlActive(this, checked)
            sw.text = Lang.get("control_status", lang) + ": " + Lang.get(if (checked) "on" else "off", lang)
        }
        root.addView(sw)

        // Tugma tanlash
        root.addView(gap())
        root.addView(Ui.body(this, Lang.get("choose_button", lang) + ":", Ui.MUTED))
        val group = RadioGroup(this)
        val rbDown = RadioButton(this).apply {
            text = Lang.get("vol_down", lang); setTextColor(Ui.TEXT); textSize = 16f; id = 1
        }
        val rbUp = RadioButton(this).apply {
            text = Lang.get("vol_up", lang); setTextColor(Ui.TEXT); textSize = 16f; id = 2
        }
        group.addView(rbDown); group.addView(rbUp)
        group.check(if (Prefs.triggerKey(this) == KeyEvent.KEYCODE_VOLUME_UP) 2 else 1)
        root.addView(group)

        // Soniya
        root.addView(gap())
        root.addView(Ui.body(this, Lang.get("hold_seconds", lang) + ":", Ui.MUTED))
        val secField = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setText(Prefs.holdSeconds(this@TriggerSettingsActivity).toString())
            setTextColor(Ui.TEXT); textSize = 18f
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            layoutParams = lp
        }
        root.addView(secField)

        root.addView(gap())
        root.addView(Ui.body(this, Lang.get("power_note", lang), Ui.MUTED))

        // Saqlash
        val save = Ui.button(this, Lang.get("save", lang), Ui.GREEN)
        save.setOnClickListener {
            Prefs.setTriggerKey(this,
                if (group.checkedRadioButtonId == 2) KeyEvent.KEYCODE_VOLUME_UP else KeyEvent.KEYCODE_VOLUME_DOWN)
            val s = secField.text.toString().toIntOrNull() ?: 3
            Prefs.setHoldSeconds(this, s.coerceIn(1, 15))
            Toast.makeText(this, Lang.get("saved", lang), Toast.LENGTH_SHORT).show()
        }
        root.addView(save)

        // Ruxsatlar
        root.addView(gap())
        root.addView(Ui.body(this, Lang.get("acc_needed", lang), Ui.MUTED))
        val accBtn = Ui.button(this, Lang.get("open_acc", lang), Ui.BLUE)
        accBtn.setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        root.addView(accBtn)

        val admBtn = Ui.button(this, Lang.get("uninstall_protect", lang), Ui.CARD)
        admBtn.setOnClickListener {
            val cn = android.content.ComponentName(this, AdminReceiver::class.java)
            val i = Intent(android.app.admin.DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            i.putExtra(android.app.admin.DevicePolicyManager.EXTRA_DEVICE_ADMIN, cn)
            i.putExtra(android.app.admin.DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                Lang.get("uninstall_protect", lang))
            startActivity(i)
        }
        root.addView(admBtn)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }

    private fun gap(): TextView = TextView(this).apply {
        text = ""; setPadding(0, Ui.dp(this@TriggerSettingsActivity, 10), 0, 0)
    }
}
