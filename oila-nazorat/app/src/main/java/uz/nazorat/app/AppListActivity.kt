package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView

/** Bloklanadigan/internetdan uziladigan ilovalarni tanlash + rejim. */
class AppListActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("block_title", lang)))
        root.addView(Ui.body(this, Lang.get("block_hint", lang)))

        // Global qoida tugmasi
        val gBtn = Ui.button(this, "⚙ " + Lang.get("global_rule", lang), Ui.CARD)
        gBtn.setOnClickListener {
            startActivity(Intent(this, RuleActivity::class.java).putExtra("global", true))
        }
        root.addView(gBtn)

        val pm = packageManager
        val main = Intent(Intent.ACTION_MAIN, null).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        val apps = pm.queryIntentActivities(main, 0)
            .mapNotNull { it.activityInfo?.packageName }
            .filter { it != packageName }
            .distinct()
            .sortedBy { label(it).lowercase() }

        val included = Rules.includedApps(this)

        for (pkg in apps) {
            val card = MaterialCardView(this).apply {
                radius = Ui.dp(this@AppListActivity, 14).toFloat()
                setCardBackgroundColor(Ui.CARD); cardElevation = 0f
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                lp.topMargin = Ui.dp(this@AppListActivity, 8); layoutParams = lp
            }
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                setPadding(Ui.dp(this@AppListActivity, 12), Ui.dp(this@AppListActivity, 10),
                    Ui.dp(this@AppListActivity, 12), Ui.dp(this@AppListActivity, 10))
            }
            val icon = ImageView(this).apply {
                try { setImageDrawable(pm.getApplicationIcon(pkg)) } catch (e: Exception) {}
                val s = Ui.dp(this@AppListActivity, 40)
                layoutParams = LinearLayout.LayoutParams(s, s).also { it.rightMargin = Ui.dp(this@AppListActivity, 12) }
            }
            val name = TextView(this).apply {
                text = label(pkg); setTextColor(Ui.TEXT); textSize = 16f
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val gear = TextView(this).apply {
                text = "⚙"; textSize = 22f; setPadding(Ui.dp(this@AppListActivity, 8), 0, Ui.dp(this@AppListActivity, 8), 0)
                setOnClickListener {
                    startActivity(Intent(this@AppListActivity, RuleActivity::class.java).putExtra("pkg", pkg))
                }
            }
            val cb = CheckBox(this).apply {
                isChecked = included.contains(pkg)
                setOnCheckedChangeListener { _, checked ->
                    if (checked) Rules.addApp(this@AppListActivity, pkg) else Rules.removeApp(this@AppListActivity, pkg)
                }
            }
            row.addView(icon); row.addView(name); row.addView(gear); row.addView(cb)
            card.addView(row)
            root.addView(card)
        }

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun label(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) { pkg }
}
