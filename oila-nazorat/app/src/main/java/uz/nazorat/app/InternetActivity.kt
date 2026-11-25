package uz.nazorat.app

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch

/** Internetdan uzish (VPN) bosh kaliti. */
class InternetActivity : AppCompatActivity() {

    private val REQ = 7001
    private var pendingSwitch: MaterialSwitch? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val lang = Prefs.getLang(this)
        val root = Ui.screen(this)
        root.addView(Ui.title(this, Lang.get("f_internet", lang)))
        root.addView(Ui.body(this, Lang.get("internet_hint", lang)))

        val sw = MaterialSwitch(this).apply {
            text = Lang.get("vpn_switch", lang); setTextColor(Ui.TEXT); textSize = 17f
            isChecked = Prefs.vpnEnabled(this@InternetActivity)
        }
        sw.setOnCheckedChangeListener { _, checked ->
            if (checked) {
                val prep = VpnService.prepare(this)
                if (prep != null) { pendingSwitch = sw; startActivityForResult(prep, REQ) }
                else NetService.start(this)
            } else NetService.stop(this)
        }
        root.addView(sw)

        val pick = Ui.button(this, "📱 " + Lang.get("block_title", lang), Ui.BLUE)
        pick.setOnClickListener { startActivity(Intent(this, AppListActivity::class.java)) }
        root.addView(pick)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Ui.BG); scroll.addView(root)
        setContentView(scroll)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ) {
            if (resultCode == RESULT_OK) NetService.start(this)
            else pendingSwitch?.isChecked = false
        }
    }
}
