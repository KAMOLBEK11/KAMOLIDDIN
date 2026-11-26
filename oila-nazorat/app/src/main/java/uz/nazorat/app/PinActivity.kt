package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/**
 * PIN ekrani.
 * - Agar PIN hali yo'q bo'lsa: yangi PIN yaratish (ikki marta).
 * - Agar PIN bor bo'lsa: ota-ona kirishi uchun PIN so'raladi.
 */
class PinActivity : AppCompatActivity() {

    private var gate = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        gate = intent.getBooleanExtra("gate", false)
        val creating = !gate && !Prefs.hasPin(this)

        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get(if (creating) "create_pin" else "enter_pin", lang)))

        val pin1 = pinField(Lang.get("enter_pin", lang))
        root.addView(pin1)

        val pin2 = if (creating) pinField(Lang.get("repeat_pin", lang)) else null
        if (pin2 != null) root.addView(pin2)

        val btn = Ui.button(this, Lang.get(if (creating) "save" else "continue", lang), Ui.GREEN)
        btn.setOnClickListener {
            val p1 = pin1.text.toString().trim()
            if (p1.length < 4) {
                toast("PIN: kamida 4 raqam"); return@setOnClickListener
            }
            if (creating) {
                val p2 = pin2!!.text.toString().trim()
                if (p1 != p2) {
                    toast(Lang.get("pin_mismatch", lang)); return@setOnClickListener
                }
                Prefs.setPin(this, p1)
                go()
            } else {
                if (p1 == Prefs.getPin(this)) go()
                else toast(Lang.get("pin_wrong", lang))
            }
        }
        root.addView(btn)

        if (!creating) {
            val forgot = android.widget.TextView(this).apply {
                text = Lang.get("forgot_pin", lang)
                setTextColor(Ui.BLUE); textSize = 15f
                setPadding(0, Ui.dp(this@PinActivity, 18), 0, 0)
                setOnClickListener {
                    startActivity(Intent(this@PinActivity, ForgotPinActivity::class.java))
                }
            }
            root.addView(forgot)
        }
        setContentView(root)
    }

    private fun pinField(hint: String): EditText {
        return EditText(this).apply {
            this.hint = hint
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            setTextColor(Ui.TEXT)
            setHintTextColor(Ui.MUTED)
            textSize = 18f
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = Ui.dp(this@PinActivity, 12)
            layoutParams = lp
        }
    }

    private fun go() {
        if (gate) { finish(); return }
        startActivity(Intent(this, MainActivity::class.java))
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (gate) {
            // PIN'ni aylanib o'tib bo'lmaydi — bosh ekranga chiqaramiz
            val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try { startActivity(i) } catch (e: Exception) {}
        } else {
            super.onBackPressed()
        }
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
