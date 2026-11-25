package uz.nazorat.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.card.MaterialCardView
import com.google.android.material.materialswitch.MaterialSwitch
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Joylashuv / harakat tarixi. */
class LocationActivity : AppCompatActivity() {

    private val REQ = 8001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("location_title", lang)))
        root.addView(Ui.body(this, Lang.get("location_hint2", lang)))

        val sw = MaterialSwitch(this).apply {
            text = Lang.get("loc_switch", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.locationOn(this@LocationActivity)
        }
        sw.setOnCheckedChangeListener { _, checked ->
            if (checked) {
                if (hasLoc()) LocationLogService.start(this)
                else ActivityCompat.requestPermissions(this,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), REQ)
            } else LocationLogService.stop(this)
        }
        root.addView(sw)

        val mapBtn = Ui.button(this, "🗺️ " + Lang.get("show_map", lang), Ui.BLUE)
        mapBtn.setOnClickListener { startActivity(Intent(this, MapActivity::class.java)) }
        root.addView(mapBtn)

        // Tarix
        val fmt = SimpleDateFormat("dd-MMM HH:mm", Locale.getDefault())
        val arr = try { JSONArray(Prefs.locHistory(this)) } catch (e: Exception) { JSONArray() }
        if (arr.length() == 0) root.addView(Ui.body(this, "—", Ui.MUTED))
        for (i in arr.length() - 1 downTo 0) {
            val o = arr.optJSONObject(i) ?: continue
            val lat = o.optDouble("lat"); val lng = o.optDouble("lng"); val t = o.optLong("t")
            val card = MaterialCardView(this).apply {
                radius = Ui.dp(this@LocationActivity, 12).toFloat(); setCardBackgroundColor(Ui.CARD); cardElevation = 0f
                val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                lp.topMargin = Ui.dp(this@LocationActivity, 6); layoutParams = lp
                isClickable = true
                setOnClickListener {
                    val uri = Uri.parse("geo:$lat,$lng?q=$lat,$lng(${fmt.format(Date(t))})")
                    try { startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (e: Exception) {}
                }
            }
            card.addView(TextView(this).apply {
                text = "📍 " + fmt.format(Date(t)) + "   " + String.format(Locale.US, "%.5f, %.5f", lat, lng)
                setTextColor(Ui.TEXT); textSize = 15f
                setPadding(Ui.dp(this@LocationActivity, 14), Ui.dp(this@LocationActivity, 12), Ui.dp(this@LocationActivity, 14), Ui.dp(this@LocationActivity, 12))
            })
            root.addView(card)
        }

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    private fun hasLoc(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            LocationLogService.start(this)
        }
    }
}
