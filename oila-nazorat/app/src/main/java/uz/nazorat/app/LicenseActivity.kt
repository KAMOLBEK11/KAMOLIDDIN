package uz.nazorat.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/** Tarif va litsenziya ekrani. */
class LicenseActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)

        root.addView(Ui.title(this, Lang.get("f_license", lang)))

        // Holat
        val state = LicenseManager.state(this)
        val days = LicenseManager.daysLeft(this)
        val statusText = when (state) {
            LicenseManager.State.TRIAL -> String.format(Lang.get("trial_active", lang), days)
            LicenseManager.State.LICENSED -> String.format(Lang.get("license_active", lang), days)
            LicenseManager.State.EXPIRED -> Lang.get("expired", lang)
        }
        root.addView(Ui.body(this, statusText, Ui.TEXT))

        // Tariflar
        root.addView(spacer())
        root.addView(Ui.body(this, Lang.get("plan_6", lang) + "  •  " + Lang.get("plan_12", lang)))

        // Qurilma kodi
        root.addView(spacer())
        root.addView(Ui.body(this, Lang.get("device_code", lang) + ":", Ui.MUTED))
        val code = LicenseManager.deviceCode(this)
        val codeView = TextView(this).apply {
            text = code
            textSize = 26f
            setTextColor(Ui.TEXT)
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(0, Ui.dp(this@LicenseActivity, 6), 0, 0)
        }
        root.addView(codeView)

        val copyBtn = Ui.button(this, "📋 Kodni nusxalash", Ui.CARD)
        copyBtn.setOnClickListener {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("code", code))
            toast("✅")
        }
        root.addView(copyBtn)

        // Kalit kiritish
        root.addView(spacer())
        root.addView(Ui.body(this, Lang.get("enter_key", lang) + ":", Ui.MUTED))
        val keyField = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            setTextColor(Ui.TEXT)
            setHintTextColor(Ui.MUTED)
            hint = "180-XXXXXXXXXX"
            textSize = 18f
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = Ui.dp(this@LicenseActivity, 8)
            layoutParams = lp
        }
        root.addView(keyField)

        val activateBtn = Ui.button(this, Lang.get("activate", lang), Ui.GREEN)
        activateBtn.setOnClickListener {
            val ok = LicenseManager.activate(this, keyField.text.toString())
            toast(Lang.get(if (ok) "key_ok" else "key_bad", lang))
            if (ok) finish()
        }
        root.addView(activateBtn)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }

    private fun spacer(): TextView = TextView(this).apply {
        text = ""
        setPadding(0, Ui.dp(this@LicenseActivity, 10), 0, 0)
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
