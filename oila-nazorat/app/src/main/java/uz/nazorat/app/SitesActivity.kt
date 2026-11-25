package uz.nazorat.app

import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import com.google.android.material.materialswitch.MaterialSwitch

/** Saytlarni filtrlash sozlamalari. */
class SitesActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("f_sites", lang)))
        root.addView(Ui.body(this, Lang.get("sites_hint", lang)))

        val swOn = MaterialSwitch(this).apply {
            text = Lang.get("site_filter_on", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.siteFilterOn(this@SitesActivity)
            setOnCheckedChangeListener { _, c -> Prefs.setSiteFilterOn(this@SitesActivity, c) }
        }
        root.addView(swOn)

        val swAdult = MaterialSwitch(this).apply {
            text = Lang.get("adult_block", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.adultBlockOn(this@SitesActivity)
            setOnCheckedChangeListener { _, c -> Prefs.setAdultBlockOn(this@SitesActivity, c) }
        }
        root.addView(swAdult)

        root.addView(gap())
        root.addView(Ui.body(this, Lang.get("add_domain", lang) + ":", Ui.MUTED))
        val field = EditText(this).apply {
            inputType = InputType.TYPE_TEXT_VARIATION_URI
            hint = "tiktok.com"; setHintTextColor(Ui.MUTED); setTextColor(Ui.TEXT); textSize = 18f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        root.addView(field)

        val listHolder = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }

        fun redraw() {
            listHolder.removeAllViews()
            for (d in Prefs.blockedDomains(this).sorted()) {
                val card = MaterialCardView(this).apply {
                    radius = Ui.dp(this@SitesActivity, 12).toFloat(); setCardBackgroundColor(Ui.CARD); cardElevation = 0f
                    val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    lp.topMargin = Ui.dp(this@SitesActivity, 6); layoutParams = lp
                }
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                    setPadding(Ui.dp(this@SitesActivity, 14), Ui.dp(this@SitesActivity, 10), Ui.dp(this@SitesActivity, 14), Ui.dp(this@SitesActivity, 10))
                }
                row.addView(TextView(this).apply {
                    text = d; setTextColor(Ui.TEXT); textSize = 16f
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                })
                row.addView(TextView(this).apply {
                    text = "❌"; textSize = 18f
                    setOnClickListener {
                        val s = Prefs.blockedDomains(this@SitesActivity).toMutableSet(); s.remove(d)
                        Prefs.setBlockedDomains(this@SitesActivity, s); redraw()
                    }
                })
                card.addView(row); listHolder.addView(card)
            }
        }

        val add = Ui.button(this, "➕ " + Lang.get("add_domain", lang), Ui.GREEN)
        add.setOnClickListener {
            val d = field.text.toString().trim().lowercase().removePrefix("www.")
            if (d.isNotEmpty()) {
                val s = Prefs.blockedDomains(this).toMutableSet(); s.add(d)
                Prefs.setBlockedDomains(this, s); field.setText(""); redraw()
                Toast.makeText(this, Lang.get("saved", lang), Toast.LENGTH_SHORT).show()
            }
        }
        root.addView(add)
        root.addView(listHolder)
        redraw()

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun gap(): TextView = TextView(this).apply { text = ""; setPadding(0, Ui.dp(this@SitesActivity, 10), 0, 0) }
}
