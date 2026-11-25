package uz.nazorat.app

import android.content.Context
import java.util.Calendar

/** Bloklash qoidasi — bitta joyda. */
object Blocker {

    /** Hozir nazorat kuchdami? (tezkor tugma yoki tungi jadval) */
    fun enforcingNow(ctx: Context): Boolean {
        if (Prefs.controlActive(ctx)) return true
        if (Prefs.scheduleEnabled(ctx) && inNightWindow(ctx)) return true
        return false
    }

    /** Shu paketni bloklash kerakmi? */
    fun shouldBlock(ctx: Context, pkg: String): Boolean {
        if (!enforcingNow(ctx)) return false
        return Prefs.blockedApps(ctx).contains(pkg)
    }

    private fun inNightWindow(ctx: Context): Boolean {
        val from = Prefs.scheduleFrom(ctx)
        val to = Prefs.scheduleTo(ctx)
        val now = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return if (from <= to) now in from until to
        else now >= from || now < to   // yarim tundan oshadigan oraliq
    }
}
