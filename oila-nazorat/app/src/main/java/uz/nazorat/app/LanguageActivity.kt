package uz.nazorat.app

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView

/** Birinchi ekran — til tanlash. */
class LanguageActivity : AppCompatActivity() {

    private var selected = "uz_lat"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("choose_language", "uz_lat") + " / Выберите язык"))

        val cards = mutableMapOf<String, MaterialCardView>()

        for (code in Lang.codes) {
            val card = MaterialCardView(this).apply {
                radius = Ui.dp(this@LanguageActivity, 14).toFloat()
                setCardBackgroundColor(Ui.CARD)
                cardElevation = 0f
                val lp = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                lp.topMargin = Ui.dp(this@LanguageActivity, 10)
                layoutParams = lp
                isClickable = true
            }
            val tv = TextView(this).apply {
                text = Lang.nativeName[code]
                textSize = 18f
                setTextColor(Ui.TEXT)
                gravity = Gravity.CENTER
                setPadding(0, Ui.dp(this@LanguageActivity, 18), 0, Ui.dp(this@LanguageActivity, 18))
            }
            card.addView(tv)
            card.setOnClickListener {
                selected = code
                cards.forEach { (c, mc) ->
                    mc.setCardBackgroundColor(if (c == code) Ui.BLUE else Ui.CARD)
                }
            }
            cards[code] = card
            root.addView(card)
        }
        cards["uz_lat"]?.setCardBackgroundColor(Ui.BLUE)

        val next = Ui.button(this, "Davom etish / Continue", Ui.GREEN)
        next.setOnClickListener {
            Prefs.setLang(this, selected)
            startActivity(Intent(this, PinActivity::class.java))
            finish()
        }
        root.addView(next)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }
}
