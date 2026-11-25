package uz.nazorat.app

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONArray

/** Harakat tarixini xaritada ko'rsatadi (OpenStreetMap + Leaflet). */
class MapActivity : AppCompatActivity() {

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val web = WebView(this)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        setContentView(web)

        val pts = StringBuilder("[")
        try {
            val arr = JSONArray(Prefs.locHistory(this))
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (i > 0) pts.append(",")
                pts.append("[").append(o.optDouble("lat")).append(",").append(o.optDouble("lng")).append("]")
            }
        } catch (e: Exception) {}
        pts.append("]")

        val html = """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>html,body,#m{height:100%;margin:0}</style></head>
            <body><div id="m"></div><script>
            var pts=$pts;
            var map=L.map('m');
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19}).addTo(map);
            if(pts.length>0){
              L.polyline(pts,{color:'#1E88E5'}).addTo(map);
              L.marker(pts[0]).addTo(map).bindPopup('Boshi');
              L.marker(pts[pts.length-1]).addTo(map).bindPopup('Oxiri');
              map.fitBounds(pts);
            } else { map.setView([41.31,69.24],11); }
            </script></body></html>
        """.trimIndent()

        web.loadDataWithBaseURL("https://tile.openstreetmap.org/", html, "text/html", "utf-8", null)
    }
}
