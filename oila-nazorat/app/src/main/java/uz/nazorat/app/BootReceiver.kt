package uz.nazorat.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Telefon qayta yoqilganda nazoratni tiklaydi. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try { if (Prefs.vpnEnabled(context)) NetService.start(context) } catch (e: Exception) {}
        try { if (Prefs.locationOn(context)) LocationLogService.start(context) } catch (e: Exception) {}
        try {
            if (Prefs.cameraBlocked(context)) {
                val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
                val cn = android.content.ComponentName(context, AdminReceiver::class.java)
                if (dpm.isAdminActive(cn)) dpm.setCameraDisabled(cn, true)
            }
        } catch (e: Exception) {}
        // "Maxsus imkoniyatlar" xizmati tizim tomonidan avtomatik tiklanadi.
    }
}
