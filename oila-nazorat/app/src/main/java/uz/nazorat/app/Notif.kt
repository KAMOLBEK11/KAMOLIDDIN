package uz.nazorat.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

/** Doimiy (foreground) xizmatlar uchun bildirishnoma. Nom neytral: "VPN". */
object Notif {
    const val CH = "vpn_svc"
    const val ID_CTRL = 11
    const val ID_NET = 12
    const val ID_LOC = 5

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CH) == null) {
                val ch = NotificationChannel(CH, "VPN", NotificationManager.IMPORTANCE_MIN)
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
        }
    }

    fun build(ctx: Context, text: String): Notification {
        ensureChannel(ctx)
        return NotificationCompat.Builder(ctx, CH)
            .setContentTitle("VPN")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
