package uz.nazorat.app

import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch

/** Tungi bloklash jadvali. */
class ScheduleActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("schedule_title", lang)))

        val sw = MaterialSwitch(this).apply {
            text = Lang.get("sched_enable", lang)
            setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.scheduleEnabled(this@ScheduleActivity)
        }
        root.addView(sw)

        root.addView(Ui.body(this, Lang.get("sched_from", lang) + ":", Ui.MUTED))
        val fromF = hourField(Prefs.scheduleFrom(this))
        root.addView(fromF)

        root.addView(Ui.body(this, Lang.get("sched_to", lang) + ":", Ui.MUTED))
        val toF = hourField(Prefs.scheduleTo(this))
        root.addView(toF)

        val save = Ui.button(this, Lang.get("save", lang), Ui.GREEN)
        save.setOnClickListener {
            Prefs.setScheduleEnabled(this, sw.isChecked)
            Prefs.setScheduleFrom(this, (fromF.text.toString().toIntOrNull() ?: 22).coerceIn(0, 23))
            Prefs.setScheduleTo(this, (toF.text.toString().toIntOrNull() ?: 7).coerceIn(0, 23))
            Toast.makeText(this, Lang.get("saved", lang), Toast.LENGTH_SHORT).show()
            finish()
        }
        root.addView(save)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG)
        scroll.addView(root)
        setContentView(scroll)
    }

    private fun hourField(value: Int): EditText = EditText(this).apply {
        inputType = InputType.TYPE_CLASS_NUMBER
        setText(value.toString())
        setTextColor(Ui.TEXT); textSize = 18f
        val lp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        layoutParams = lp
    }
}
