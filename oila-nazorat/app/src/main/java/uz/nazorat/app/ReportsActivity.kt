package uz.nazorat.app

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import java.util.Calendar

/** Haqiqiy foydalanish hisoboti (UsageStatsManager). */
class ReportsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("reports_title", lang)))
        root.addView(Ui.body(this, Lang.get("reports_hint", lang)))

        if (!Usage.hasAccess(this)) {
            root.addView(Ui.body(this, Lang.get("p_usage", lang) + " ❌", Ui.RED))
            val btn = Ui.button(this, Lang.get("open_acc", lang), Ui.BLUE)
            btn.setOnClickListener { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
            root.addView(btn)
        } else {
            val list = todayUsage()
            if (list.isEmpty()) root.addView(Ui.body(this, "—", Ui.MUTED))
            val pm = packageManager
            for ((pkg, ms) in list) {
                if (ms < 60_000) continue
                val card = MaterialCardView(this).apply {
                    radius = Ui.dp(this@ReportsActivity, 12).toFloat(); setCardBackgroundColor(Ui.CARD); cardElevation = 0f
                    val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    lp.topMargin = Ui.dp(this@ReportsActivity, 8); layoutParams = lp
                }
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                    setPadding(Ui.dp(this@ReportsActivity, 12), Ui.dp(this@ReportsActivity, 10), Ui.dp(this@ReportsActivity, 12), Ui.dp(this@ReportsActivity, 10))
                }
                row.addView(ImageView(this).apply {
                    try { setImageDrawable(pm.getApplicationIcon(pkg)) } catch (e: Exception) {}
                    val s = Ui.dp(this@ReportsActivity, 36)
                    layoutParams = LinearLayout.LayoutParams(s, s).also { it.rightMargin = Ui.dp(this@ReportsActivity, 12) }
                })
                row.addView(TextView(this).apply {
                    text = label(pkg); setTextColor(Ui.TEXT); textSize = 16f
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                })
                row.addView(TextView(this).apply {
                    text = fmt(ms); setTextColor(Ui.MUTED); textSize = 15f
                })
                card.addView(row); root.addView(card)
            }
        }

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun todayUsage(): List<Pair<String, Long>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return emptyList()
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, cal.timeInMillis, System.currentTimeMillis()) ?: return emptyList()
        val map = HashMap<String, Long>()
        for (s in stats) if (s.totalTimeInForeground > 0) map[s.packageName] = (map[s.packageName] ?: 0) + s.totalTimeInForeground
        return map.entries.sortedByDescending { it.value }.map { it.key to it.value }
    }

    private fun fmt(ms: Long): String {
        val min = ms / 60000; val h = min / 60; val m = min % 60
        return if (h > 0) "$h s $m daq" else "$m daq"
    }

    private fun label(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) { pkg }
}
