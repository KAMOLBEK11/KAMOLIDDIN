package uz.nazorat.app

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor

/**
 * Internetdan uzish — lokal VPN. Hech qanday ma'lumot tashqariga ketmaydi:
 * cheklangan ilovalarning paketlari shu "tun"ga yo'naltiriladi va tashlab yuboriladi,
 * natijada ularda internet ishlamaydi. Qolgan ilovalar normal ishlaydi.
 *
 * Xizmat o'zi har 15 soniyada qoidalarni qayta hisoblaydi, shuning uchun
 * rejim vaqti kelganda yoki tezkor qulf yoqilganda avtomatik yangilanadi.
 */
class NetService : VpnService() {

    @Volatile private var running = false
    private var tun: ParcelFileDescriptor? = null
    private var lastSet: Set<String> = emptySet()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!running) {
            running = true
            Thread { loop() }.start()
        }
        return START_STICKY
    }

    private fun loop() {
        while (running) {
            try {
                val set = Rules.internetSet(this)
                if (set != lastSet) {
                    apply(set)
                    lastSet = set
                }
            } catch (e: Exception) { /* davom etamiz */ }
            try { Thread.sleep(15_000) } catch (e: InterruptedException) { break }
        }
    }

    private fun apply(set: Set<String>) {
        closeTun()
        if (set.isEmpty()) return
        val b = Builder()
            .setSession("VPN")
            .addAddress("10.0.0.2", 32)
            .addRoute("0.0.0.0", 0)
        for (p in set) {
            try { b.addAllowedApplication(p) } catch (e: Exception) { /* paket topilmadi */ }
        }
        tun = try { b.establish() } catch (e: Exception) { null }
    }

    private fun closeTun() {
        try { tun?.close() } catch (e: Exception) {}
        tun = null
    }

    override fun onDestroy() {
        running = false
        closeTun()
        super.onDestroy()
    }

    companion object {
        fun start(ctx: Context) {
            Prefs.setVpnEnabled(ctx, true)
            ctx.startService(Intent(ctx, NetService::class.java))
        }
        fun stop(ctx: Context) {
            Prefs.setVpnEnabled(ctx, false)
            ctx.stopService(Intent(ctx, NetService::class.java))
        }
    }
}
