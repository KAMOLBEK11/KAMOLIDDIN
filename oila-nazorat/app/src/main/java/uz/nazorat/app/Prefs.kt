package uz.nazorat.app

import android.content.Context
import android.content.SharedPreferences

/** Sozlamalarni telefon ichida saqlaydi. Internet kerak emas. */
object Prefs {
    private const val FILE = "oila_nazorat"

    private fun sp(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // Til
    var langSet = false
    fun getLang(ctx: Context): String = sp(ctx).getString("lang", "") ?: ""
    fun setLang(ctx: Context, code: String) =
        sp(ctx).edit().putString("lang", code).apply()

    // PIN
    fun getPin(ctx: Context): String = sp(ctx).getString("pin", "") ?: ""
    fun setPin(ctx: Context, pin: String) =
        sp(ctx).edit().putString("pin", pin).apply()
    fun hasPin(ctx: Context): Boolean = getPin(ctx).isNotEmpty()

    // Birinchi ishga tushgan vaqt (sinov hisobi uchun)
    fun firstRun(ctx: Context): Long {
        val s = sp(ctx)
        var t = s.getLong("first_run", 0L)
        if (t == 0L) {
            t = System.currentTimeMillis()
            s.edit().putLong("first_run", t).apply()
        }
        return t
    }

    // Litsenziya tugash vaqti (0 = yo'q)
    fun licenseUntil(ctx: Context): Long = sp(ctx).getLong("lic_until", 0L)
    fun setLicenseUntil(ctx: Context, t: Long) =
        sp(ctx).edit().putLong("lic_until", t).apply()

    // --- Nazorat (bloklash) ---

    // Nazorat hozir yoqilganmi (tezkor tugma yoki qo'lda o'zgartiradi)
    fun controlActive(ctx: Context): Boolean = sp(ctx).getBoolean("ctrl_active", false)
    fun setControlActive(ctx: Context, v: Boolean) =
        sp(ctx).edit().putBoolean("ctrl_active", v).apply()

    // Bloklanadigan ilovalar (paket nomlari)
    fun blockedApps(ctx: Context): Set<String> =
        HashSet(sp(ctx).getStringSet("blocked", emptySet()) ?: emptySet())
    fun setBlockedApps(ctx: Context, set: Set<String>) =
        sp(ctx).edit().putStringSet("blocked", set).apply()

    // Tezkor yoqish tugmasi: 24 = Ovoz+, 25 = Ovoz-  (default: Ovoz-)
    fun triggerKey(ctx: Context): Int = sp(ctx).getInt("trig_key", 25)
    fun setTriggerKey(ctx: Context, k: Int) =
        sp(ctx).edit().putInt("trig_key", k).apply()

    // Necha soniya bosib turiladi (default 3)
    fun holdSeconds(ctx: Context): Int = sp(ctx).getInt("hold_sec", 3)
    fun setHoldSeconds(ctx: Context, s: Int) =
        sp(ctx).edit().putInt("hold_sec", s).apply()

    // Tungi jadval
    fun scheduleEnabled(ctx: Context): Boolean = sp(ctx).getBoolean("sch_on", false)
    fun setScheduleEnabled(ctx: Context, v: Boolean) =
        sp(ctx).edit().putBoolean("sch_on", v).apply()
    fun scheduleFrom(ctx: Context): Int = sp(ctx).getInt("sch_from", 22)   // soat
    fun setScheduleFrom(ctx: Context, h: Int) = sp(ctx).edit().putInt("sch_from", h).apply()
    fun scheduleTo(ctx: Context): Int = sp(ctx).getInt("sch_to", 7)
    fun setScheduleTo(ctx: Context, h: Int) = sp(ctx).edit().putInt("sch_to", h).apply()
}
