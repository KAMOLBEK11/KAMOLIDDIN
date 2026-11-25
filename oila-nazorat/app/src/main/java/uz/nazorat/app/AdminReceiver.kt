package uz.nazorat.app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Qurilma administratori — o'chirishdan himoya.
 * Administrator yoqilgan bo'lsa, ilovani o'chirish uchun avval administratorni
 * o'chirish kerak bo'ladi. To'liq (zavod sozlamalariga qaytarishdan ham) himoya
 * Device Owner rejimida bo'ladi — u keyingi bosqichda qo'shiladi.
 */
class AdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Diqqat: nazorat himoyasi o‘chadi."
    }
}
