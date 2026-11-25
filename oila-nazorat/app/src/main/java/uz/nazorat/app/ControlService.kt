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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        if (Blocker.shouldBlock(this, pkg)) {
            // Bola "bloklandi" yozuvini ko'rmaydi — ilova shunchaki yopiladi.
            performGlobalAction(GLOBAL_ACTION_HOME)
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
