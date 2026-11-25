package uz.nazorat.app

import android.content.Context
import org.json.JSONObject
import java.util.Calendar

/**
 * Qoida mexanizmi.
 * action (a): 0 = BLOKLASH, 1 = INTERNETDAN UZISH
 * mode   (m): 0 = BUTUNLAY, 1 = FOYDALANISHDAN KEYIN (p1 soat),
 *             2 = VAQT ORALIG'I (p1..p2 soat), 3 = N SOATDAN KEYIN (p1 soat, arm=boshlanish)
 */
object Rules {

    const val A_BLOCK = 0
    const val A_NET = 1
    const val M_FULL = 0
    const val M_USAGE = 1
    const val M_WINDOW = 2
    const val M_COUNTDOWN = 3

    data class Rule(val a: Int, val m: Int, val p1: Int, val p2: Int, val arm: Long)

    private fun parse(o: JSONObject): Rule =
        Rule(o.optInt("a", 0), o.optInt("m", 0), o.optInt("p1", 3), o.optInt("p2", 0), o.optLong("arm", 0))

    fun toJson(r: Rule): JSONObject = JSONObject()
        .put("a", r.a).put("m", r.m).put("p1", r.p1).put("p2", r.p2).put("arm", r.arm)

    private fun map(ctx: Context): JSONObject = try { JSONObject(Prefs.rulesJson(ctx)) } catch (e: Exception) { JSONObject() }

    fun includedApps(ctx: Context): Set<String> {
        val m = map(ctx); val s = HashSet<String>()
        val it = m.keys(); while (it.hasNext()) s.add(it.next()); return s
    }

    fun ruleForApp(ctx: Context, pkg: String): Rule? {
        if (Prefs.globalOn(ctx)) {
            if (!map(ctx).has(pkg)) return null
            return try { parse(JSONObject(Prefs.globalRuleJson(ctx))) } catch (e: Exception) { null }
        }
        val m = map(ctx)
        if (!m.has(pkg)) return null
        return parse(m.getJSONObject(pkg))
    }

    fun setAppRule(ctx: Context, pkg: String, r: Rule) {
        val m = map(ctx); m.put(pkg, toJson(r)); Prefs.setRulesJson(ctx, m.toString())
    }

    fun addApp(ctx: Context, pkg: String) {
        val m = map(ctx)
        if (!m.has(pkg)) m.put(pkg, toJson(Rule(A_BLOCK, M_FULL, 3, 0, System.currentTimeMillis())))
        Prefs.setRulesJson(ctx, m.toString())
    }

    fun removeApp(ctx: Context, pkg: String) {
        val m = map(ctx); m.remove(pkg); Prefs.setRulesJson(ctx, m.toString())
    }

    fun restrictedNow(ctx: Context, pkg: String, r: Rule): Boolean {
        if (Prefs.controlActive(ctx)) return true   // tezkor qulf
        return when (r.m) {
            M_FULL -> true
            M_USAGE -> Usage.todayMs(ctx, pkg) >= r.p1 * 3600_000L
            M_WINDOW -> {
                val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                if (r.p1 <= r.p2) h in r.p1 until r.p2 else h >= r.p1 || h < r.p2
            }
            M_COUNTDOWN -> System.currentTimeMillis() >= r.arm + r.p1 * 3600_000L
            else -> false
        }
    }

    /** Shu ilovani (ochilganda) bloklash kerakmi? */
    fun shouldBlockApp(ctx: Context, pkg: String): Boolean {
        val r = ruleForApp(ctx, pkg) ?: return false
        return r.a == A_BLOCK && restrictedNow(ctx, pkg, r)
    }

    /** Hozir interneti kesiladigan ilovalar. */
    fun internetSet(ctx: Context): Set<String> {
        val out = HashSet<String>()
        for (pkg in includedApps(ctx)) {
            val r = ruleForApp(ctx, pkg) ?: continue
            if (r.a == A_NET && restrictedNow(ctx, pkg, r)) out.add(pkg)
        }
        return out
    }

    fun modeName(ctx: Context, m: Int): String = when (m) {
        M_FULL -> Lang.get("m_full", Prefs.getLang(ctx))
        M_USAGE -> Lang.get("m_usage", Prefs.getLang(ctx))
        M_WINDOW -> Lang.get("m_window", Prefs.getLang(ctx))
        else -> Lang.get("m_countdown", Prefs.getLang(ctx))
    }
}
