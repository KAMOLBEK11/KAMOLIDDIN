package uz.nazorat.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Telefon qayta yoqilganda nazoratni tiklaydi. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try { if (Prefs.vpnEnabled(context)) NetService.start(context) } catch (e: Exception) {}
        try { if (Prefs.locationOn(context)) LocationLogService.start(context) } catch (e: Exception) {}
        // "Maxsus imkoniyatlar" xizmati tizim tomonidan avtomatik tiklanadi.
    }
}
