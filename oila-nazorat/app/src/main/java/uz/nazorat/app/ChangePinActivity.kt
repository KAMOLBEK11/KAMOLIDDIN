package uz.nazorat.app

import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/** PIN kodni o'zgartirish. */
class ChangePinActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("change_pin", lang)))

        val old = pinField(Lang.get("old_pin", lang)); root.addView(old)
        val n1 = pinField(Lang.get("new_pin", lang)); root.addView(n1)
        val n2 = pinField(Lang.get("repeat_pin", lang)); root.addView(n2)

        val save = Ui.button(this, Lang.get("save", lang), Ui.GREEN)
        save.setOnClickListener {
            if (old.text.toString() != Prefs.getPin(this)) { toast(Lang.get("pin_wrong", lang)); return@setOnClickListener }
            val a = n1.text.toString().trim()
            if (a.length < 4) { toast("PIN: kamida 4 raqam"); return@setOnClickListener }
            if (a != n2.text.toString().trim()) { toast(Lang.get("pin_mismatch", lang)); return@setOnClickListener }
            Prefs.setPin(this, a)
            toast(Lang.get("saved", lang)); finish()
        }
        root.addView(save)
        setContentView(root)
    }

    private fun pinField(hint: String): EditText = EditText(this).apply {
        this.hint = hint; setHintTextColor(Ui.MUTED); setTextColor(Ui.TEXT); textSize = 18f
        inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = Ui.dp(this@ChangePinActivity, 12); layoutParams = lp
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
