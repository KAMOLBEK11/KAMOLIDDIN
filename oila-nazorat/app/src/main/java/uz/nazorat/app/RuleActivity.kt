package uz.nazorat.app

import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch
import org.json.JSONObject

/** Bitta ilova yoki global uchun: amal + rejim + parametrlar. */
class RuleActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val isGlobal = intent.getBooleanExtra("global", false)
        val pkg = intent.getStringExtra("pkg") ?: ""

        val root = Ui.screen(this)
        val headTitle = if (isGlobal) Lang.get("global_rule", lang) else appLabel(pkg)
        root.addView(Ui.title(this, headTitle))

        // Mavjud qoidani o'qish
        val cur: Rules.Rule = if (isGlobal) {
            try { JSONObject(Prefs.globalRuleJson(this)).let { Rules.Rule(it.optInt("a"), it.optInt("m"), it.optInt("p1",3), it.optInt("p2",0), it.optLong("arm")) } }
            catch (e: Exception) { Rules.Rule(0,0,3,0,0) }
        } else Rules.ruleForApp(this, pkg) ?: Rules.Rule(0,0,3,0,System.currentTimeMillis())

        var globalSwitch: MaterialSwitch? = null
        if (isGlobal) {
            val sw = MaterialSwitch(this).apply {
                text = Lang.get("global_use", lang); setTextColor(Ui.TEXT); textSize = 16f
                isChecked = Prefs.globalOn(this@RuleActivity)
            }
            globalSwitch = sw
            root.addView(sw)
        }

        // Amal
        root.addView(gap()); root.addView(Ui.body(this, Lang.get("action", lang) + ":", Ui.MUTED))
        val agrp = RadioGroup(this)
        val aBlock = RadioButton(this).apply { text = Lang.get("a_block", lang); setTextColor(Ui.TEXT); id = 10 }
        val aNet = RadioButton(this).apply { text = Lang.get("a_net", lang); setTextColor(Ui.TEXT); id = 11 }
        agrp.addView(aBlock); agrp.addView(aNet)
        agrp.check(if (cur.a == Rules.A_NET) 11 else 10)
        root.addView(agrp)

        // Rejim
        root.addView(gap()); root.addView(Ui.body(this, Lang.get("mode", lang) + ":", Ui.MUTED))
        val mgrp = RadioGroup(this)
        val mFull = RadioButton(this).apply { text = Lang.get("m_full", lang); setTextColor(Ui.TEXT); id = 20 }
        val mUsage = RadioButton(this).apply { text = Lang.get("m_usage", lang); setTextColor(Ui.TEXT); id = 21 }
        val mWin = RadioButton(this).apply { text = Lang.get("m_window", lang); setTextColor(Ui.TEXT); id = 22 }
        val mCount = RadioButton(this).apply { text = Lang.get("m_countdown", lang); setTextColor(Ui.TEXT); id = 23 }
        mgrp.addView(mFull); mgrp.addView(mUsage); mgrp.addView(mWin); mgrp.addView(mCount)
        mgrp.check(20 + cur.m)
        root.addView(mgrp)

        // Parametrlar
        root.addView(gap()); root.addView(Ui.body(this, Lang.get("p_hours", lang), Ui.MUTED))
        val p1 = numField(if (cur.p1 == 0) 3 else cur.p1)
        root.addView(p1)
        root.addView(Ui.body(this, Lang.get("p_to", lang), Ui.MUTED))
        val p2 = numField(if (cur.p2 == 0) 7 else cur.p2)
        root.addView(p2)
        root.addView(Ui.body(this, Lang.get("rule_note", lang), Ui.MUTED))

        val save = Ui.button(this, Lang.get("save", lang), Ui.GREEN)
        save.setOnClickListener {
            val a = if (agrp.checkedRadioButtonId == 11) Rules.A_NET else Rules.A_BLOCK
            val m = mgrp.checkedRadioButtonId - 20
            val v1 = p1.text.toString().toIntOrNull() ?: 3
            val v2 = p2.text.toString().toIntOrNull() ?: 7
            val rule = Rules.Rule(a, m, v1.coerceIn(0, 23), v2.coerceIn(0, 23), System.currentTimeMillis())
            if (isGlobal) {
                Prefs.setGlobalRuleJson(this, Rules.toJson(rule).toString())
                Prefs.setGlobalOn(this, globalSwitch?.isChecked ?: true)
            } else {
                Rules.setAppRule(this, pkg, rule)
            }
            Toast.makeText(this, Lang.get("saved", lang), Toast.LENGTH_SHORT).show()
            finish()
        }
        root.addView(save)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun numField(v: Int): EditText = EditText(this).apply {
        inputType = InputType.TYPE_CLASS_NUMBER; setText(v.toString())
        setTextColor(Ui.TEXT); textSize = 18f
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    private fun gap(): TextView = TextView(this).apply { text = ""; setPadding(0, Ui.dp(this@RuleActivity, 8), 0, 0) }

    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) { pkg }
}
