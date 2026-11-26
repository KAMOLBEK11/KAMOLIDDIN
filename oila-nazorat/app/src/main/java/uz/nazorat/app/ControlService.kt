package uz.nazorat.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Nazoratning yuragi — "Maxsus imkoniyatlar" (Accessibility) xizmati.
 *
 * Ikki vazifa:
 *  1) Ochilgan ilovani kuzatadi; agar u bloklangan bo'lsa, bosh ekranga qaytaradi.
 *  2) Tanlangan OVOZ tugmasi N soniya bosib turilsa, nazoratni yoqadi/o'chiradi
 *     (tezkor aktivlashtirish). O'chirish/power tugmasini Android bermaydi.
 */
class ControlService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var holdRunnable: Runnable? = null

    private var lastSiteCheck = 0L

    private var lastGuardCheck = 0L
    private val GUARD_PKGS = setOf(
        "com.android.settings",
        "com.miui.securitycenter",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller"
    )

    private val STORE_PKGS = setOf(
        "com.android.vending",                       // Google Play Market
        "com.google.android.packageinstaller",        // o'rnatuvchi
        "com.android.packageinstaller",
        "com.google.android.feedback",
        "com.xiaomi.market",                          // Xiaomi GetApps
        "com.huawei.appmarket"                        // Huawei AppGallery
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Doimiy xizmat — tizim (ayniqsa Xiaomi/Tecno) uni osonlikcha o'ldira olmaydi
        try { startForeground(Notif.ID_CTRL, Notif.build(this, "Ulangan")) } catch (e: Exception) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val type = event?.eventType ?: return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        // 1) Ilovani bloklash
        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && Rules.shouldBlockApp(this, pkg)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            return
        }

        // 1b) Play Market / ilova o'rnatishni bloklash
        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && Prefs.playStoreBlocked(this) && STORE_PKGS.contains(pkg)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            return
        }

        // 1c) Administratorni o'chirishdan himoya — bola "o'chirish" oynasini ochsa, orqaga qaytaramiz
        if (GUARD_PKGS.contains(pkg) &&
            (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)) {
            val now = System.currentTimeMillis()
            if (now - lastGuardCheck >= 500) {
                lastGuardCheck = now
                if (windowHasMarker(rootInActiveWindow, 0)) {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    return
                }
            }
        }

        // 2) Sayt filtri (brauzerlarda)
        if (Prefs.siteFilterOn(this) && SiteFilter.browsers.contains(pkg) &&
            (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)) {
            val now = System.currentTimeMillis()
            if (now - lastSiteCheck < 600) return
            lastSiteCheck = now
            checkBrowser()
        }
    }

    /** Oynada "nazorat himoyasi" (administratorni o'chirish ogohlantirishi) bormi? */
    private fun windowHasMarker(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        node ?: return false
        if (depth > 60) return false
        val s = ((node.text?.toString() ?: "") + " " + (node.contentDescription?.toString() ?: "")).lowercase()
        if (s.contains("nazorat himoyasi")) return true
        for (i in 0 until node.childCount) {
            if (windowHasMarker(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    private fun checkBrowser() {
        val root = rootInActiveWindow ?: return
        var url: String? = null
        for (id in SiteFilter.urlBarIds) {
            val nodes = try { root.findAccessibilityNodeInfosByViewId(id) } catch (e: Exception) { null }
            if (!nodes.isNullOrEmpty()) {
                val t = nodes[0].text?.toString()
                if (!t.isNullOrBlank()) { url = t; break }
            }
        }
        if (SiteFilter.isBlocked(this, url)) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        event ?: return false
        if (event.keyCode != Prefs.triggerKey(this)) return false

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (event.repeatCount == 0 && holdRunnable == null) {
                    holdRunnable = Runnable {
                        val now = !Prefs.controlActive(this)
                        Prefs.setControlActive(this, now)
                        vibrate(if (now) longArrayOf(0, 120, 80, 120) else longArrayOf(0, 250))
                        holdRunnable = null
                    }
                    handler.postDelayed(holdRunnable!!, Prefs.holdSeconds(this) * 1000L)
                }
            }
            KeyEvent.ACTION_UP -> {
                holdRunnable?.let { handler.removeCallbacks(it); holdRunnable = null }
            }
        }
        // false = ovoz tugmasi odatdagidek ham ishlayveradi (bola shubhalanmaydi)
        return false
    }

    override fun onInterrupt() {}

    @Suppress("DEPRECATION")
    private fun vibrate(pattern: LongArray) {
        val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            v.vibrate(pattern, -1)
        }
    }
}
