package uz.nazorat.app

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle

/** Ilova fonga chiqib qaytganda PIN so'ralishi kerakligini belgilaydi. */
object AppLock { @JvmField var unlockNeeded = false }

/**
 * Ilova darajasidagi hayot sikli:
 *  - Ilova fonga ketib, qaytib ochilsa va PIN o'rnatilgan bo'lsa — PIN so'raladi.
 *  - Ilova ichidagi ekranlar orasida yurishda PIN so'ramaydi.
 */
class App : Application(), Application.ActivityLifecycleCallbacks {

    private var started = 0
    private var wentBackground = false

    override fun onCreate() {
        super.onCreate()
        Notif.ensureChannel(this)
        registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityStarted(a: Activity) {
        if (started == 0) {
            if (wentBackground && Prefs.hasPin(this)) AppLock.unlockNeeded = true
            wentBackground = false
        }
        started++
    }

    override fun onActivityResumed(a: Activity) {
        if (AppLock.unlockNeeded && a !is PinActivity) {
            AppLock.unlockNeeded = false
            a.startActivity(Intent(a, PinActivity::class.java).putExtra("gate", true))
        }
    }

    override fun onActivityStopped(a: Activity) {
        started--
        if (started <= 0) { started = 0; wentBackground = true }
    }

    override fun onActivityCreated(a: Activity, b: Bundle?) {}
    override fun onActivityPaused(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
    override fun onActivityDestroyed(a: Activity) {}
}
