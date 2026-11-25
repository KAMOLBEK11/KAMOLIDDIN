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

    // --- Qoidalar (4 rejim) ---
    // rules: JSON obyekt { "paket": {"a":0,"m":0,"p1":0,"p2":0,"arm":0} }
    fun rulesJson(ctx: Context): String = sp(ctx).getString("rules", "{}") ?: "{}"
    fun setRulesJson(ctx: Context, s: String) = sp(ctx).edit().putString("rules", s).apply()

    // Global qoida (hamma tanlangan ilovaga bitta)
    fun globalOn(ctx: Context): Boolean = sp(ctx).getBoolean("g_on", false)
    fun setGlobalOn(ctx: Context, v: Boolean) = sp(ctx).edit().putBoolean("g_on", v).apply()
    fun globalRuleJson(ctx: Context): String =
        sp(ctx).getString("g_rule", """{"a":0,"m":0,"p1":3,"p2":0,"arm":0}""") ?: """{"a":0,"m":0,"p1":3,"p2":0,"arm":0}"""
    fun setGlobalRuleJson(ctx: Context, s: String) = sp(ctx).edit().putString("g_rule", s).apply()

    // Internet (VPN) umumiy kalit
    fun vpnEnabled(ctx: Context): Boolean = sp(ctx).getBoolean("vpn_on", false)
    fun setVpnEnabled(ctx: Context, v: Boolean) = sp(ctx).edit().putBoolean("vpn_on", v).apply()

    // --- Sayt filtri ---
    fun siteFilterOn(ctx: Context): Boolean = sp(ctx).getBoolean("sf_on", false)
    fun setSiteFilterOn(ctx: Context, v: Boolean) = sp(ctx).edit().putBoolean("sf_on", v).apply()
    fun adultBlockOn(ctx: Context): Boolean = sp(ctx).getBoolean("sf_adult", true)
    fun setAdultBlockOn(ctx: Context, v: Boolean) = sp(ctx).edit().putBoolean("sf_adult", v).apply()
    fun blockedDomains(ctx: Context): Set<String> =
        HashSet(sp(ctx).getStringSet("sf_domains", emptySet()) ?: emptySet())
    fun setBlockedDomains(ctx: Context, s: Set<String>) =
        sp(ctx).edit().putStringSet("sf_domains", s).apply()

    // --- Joylashuv ---
    fun locationOn(ctx: Context): Boolean = sp(ctx).getBoolean("loc_on", false)
    fun setLocationOn(ctx: Context, v: Boolean) = sp(ctx).edit().putBoolean("loc_on", v).apply()
    fun locHistory(ctx: Context): String = sp(ctx).getString("loc_hist", "[]") ?: "[]"
    fun setLocHistory(ctx: Context, s: String) = sp(ctx).edit().putString("loc_hist", s).apply()
}
