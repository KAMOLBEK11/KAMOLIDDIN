package uz.nazorat.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/**
 * PIN esdan chiqdi. Ilova qurilma reset-kodini ko'rsatadi.
 * Ota-ona bu kodni botga/bizga yuboradi; reset kaliti FAQAT ro'yxatdan o'tgan
 * (to'lov qilgan) ota-onaning akkauntiga qaytariladi — shuning uchun bola undan
 * foydalana olmaydi. Kalit to'g'ri bo'lsa, faqat yangi PIN o'rnatiladi.
 */
class ForgotPinActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("forgot_pin", lang)))
        root.addView(Ui.body(this, Lang.get("forgot_hint", lang)))

        root.addView(Ui.body(this, Lang.get("reset_code", lang) + ":", Ui.MUTED))
        val code = LicenseManager.deviceCode(this)
        root.addView(TextView(this).apply {
            text = code; textSize = 26f; setTextColor(Ui.TEXT)
            typeface = android.graphics.Typeface.MONOSPACE
        })
        val copy = Ui.button(this, "📋", Ui.CARD)
        copy.setOnClickListener {
            (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                .setPrimaryClip(ClipData.newPlainText("code", code))
            toast("✅")
        }
        root.addView(copy)

        root.addView(Ui.body(this, Lang.get("reset_key", lang) + ":", Ui.MUTED))
        val keyField = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            setTextColor(Ui.TEXT); textSize = 18f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        root.addView(keyField)

        // Yangi PIN maydonlari (kalit to'g'ri bo'lsa ko'rsatiladi)
        val newPin = EditText(this).apply {
            hint = Lang.get("new_pin", lang); setHintTextColor(Ui.MUTED); setTextColor(Ui.TEXT); textSize = 18f
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        root.addView(newPin)

        val check = Ui.button(this, Lang.get("activate", lang), Ui.GREEN)
        check.setOnClickListener {
            if (newPin.visibility == View.GONE) {
                if (LicenseManager.verifyReset(this, keyField.text.toString())) {
                    newPin.visibility = View.VISIBLE
                    check.text = Lang.get("save", lang)
                    toast(Lang.get("key_ok", lang))
                } else toast(Lang.get("key_bad", lang))
            } else {
                val p = newPin.text.toString().trim()
                if (p.length < 4) { toast("PIN: kamida 4 raqam"); return@setOnClickListener }
                Prefs.setPin(this, p)
                toast(Lang.get("saved", lang)); finish()
            }
        }
        root.addView(check)
        setContentView(root)
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
