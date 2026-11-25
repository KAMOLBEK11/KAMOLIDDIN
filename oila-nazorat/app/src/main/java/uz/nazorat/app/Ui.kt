package uz.nazorat.app

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView

/** Zamonaviy ko'rinish uchun kichik yordamchi. */
object Ui {
    val BG = Color.parseColor("#0B1E2D")
    val CARD = Color.parseColor("#132A3C")
    val TEXT = Color.parseColor("#EAF4FB")
    val MUTED = Color.parseColor("#9FB8CC")
    val BLUE = Color.parseColor("#1E88E5")
    val GREEN = Color.parseColor("#2E7D32")
    val RED = Color.parseColor("#E53935")

    fun dp(ctx: Context, v: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(),
            ctx.resources.displayMetrics
        ).toInt()

    fun title(ctx: Context, text: String): TextView {
        return TextView(ctx).apply {
            this.text = text
            textSize = 22f
            setTextColor(TEXT)
            setPadding(0, dp(ctx, 8), 0, dp(ctx, 16))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
    }

    fun body(ctx: Context, text: String, color: Int = MUTED): TextView {
        return TextView(ctx).apply {
            this.text = text
            textSize = 15f
            setTextColor(color)
        }
    }

    fun button(ctx: Context, text: String, bg: Int = BLUE): MaterialButton {
        return MaterialButton(ctx).apply {
            this.text = text
            textSize = 16f
            setBackgroundColor(bg)
            setTextColor(Color.WHITE)
            cornerRadius = dp(ctx, 14)
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = dp(ctx, 8)
            layoutParams = lp
        }
    }

    /** Bosiladigan karta — bosh paneldagi bo'limlar uchun. */
    fun featureCard(ctx: Context, emoji: String, text: String, onClick: () -> Unit): MaterialCardView {
        val card = MaterialCardView(ctx).apply {
            radius = dp(ctx, 16).toFloat()
            setCardBackgroundColor(CARD)
            cardElevation = 0f
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = dp(ctx, 10)
            layoutParams = lp
            isClickable = true
            setOnClickListener { onClick() }
        }
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(ctx, 18), dp(ctx, 20), dp(ctx, 18), dp(ctx, 20))
        }
        row.addView(TextView(ctx).apply {
            this.text = emoji
            textSize = 26f
            setPadding(0, 0, dp(ctx, 16), 0)
        })
        row.addView(TextView(ctx).apply {
            this.text = text
            textSize = 17f
            setTextColor(TEXT)
        })
        card.addView(row)
        return card
    }

    fun screen(ctx: Context): LinearLayout {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BG)
            setPadding(dp(ctx, 20), dp(ctx, 24), dp(ctx, 20), dp(ctx, 24))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
    }
}
