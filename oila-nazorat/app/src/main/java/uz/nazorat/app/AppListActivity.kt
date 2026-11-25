package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity

/** Bloklanadigan ilovalarni tanlash. */
class AppListActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("block_title", lang)))
        root.addView(Ui.body(this, Lang.get("block_hint", lang)))

        val pm = packageManager
        val main = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val apps = pm.queryIntentActivities(main, 0)
            .mapNotNull { it.activityInfo?.packageName }
            .filter { it != packageName }
            .distinct()
            .sortedBy { pkg ->
                try { pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString().lowercase() }
                catch (e: Exception) { pkg }
            }

        val blocked = Prefs.blockedApps(this).toMutableSet()
        val boxes = mutableListOf<Pair<String, CheckBox>>()

        for (pkg in apps) {
            val label = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) { pkg }
            val cb = CheckBox(this).apply {
                text = label
                setTextColor(Ui.TEXT)
                textSize = 16f
                isChecked = blocked.contains(pkg)
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                lp.topMargin = Ui.dp(this@AppListActivity, 6)
                layoutParams = lp
            }
            boxes.add(pkg to cb)
            root.addView(cb)
        }

        val save = Ui.button(this, Lang.get("save", lang), Ui.GREEN)
        save.setOnClickListener {
            val set = boxes.filter { it.second.isChecked }.map { it.first }.toSet()
            Prefs.setBlockedApps(this, set)
            android.widget.Toast.makeText(this, Lang.get("saved", lang), android.widget.Toast.LENGTH_SHORT).show()
            finish()
        }
        root.addView(save)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }
}
