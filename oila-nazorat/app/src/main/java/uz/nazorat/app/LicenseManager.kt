package uz.nazorat.app

import android.annotation.SuppressLint
import android.content.Context
import android.provider.Settings
import java.security.MessageDigest

/**
 * SINOV + TARIF (litsenziya) tizimi — to'liq oflayn, internet kerak emas.
 *
 * - 15 kun bepul sinov (birinchi ishga tushgandan boshlab).
 * - Tariflar: 6 oy (180 kun) va 1 yil (365 kun).
 * - Faollashtirish kaliti shu telefonning kodiga bog'langan,
 *   boshqa telefonga ko'chirib bo'lmaydi.
 *
 * Kalit qanday tekshiriladi (oflayn):
 *   kalit = "<kunlar>-<imzo>"
 *   imzo  = SHA-256(qurilmaKodi + kunlar + SECRET) ning birinchi 10 belgisi
 * Ilova shu imzoni qayta hisoblab solishtiradi. Mos kelsa — faollashtiradi.
 *
 * MUHIM: hozir SECRET ilova ichida. Keyingi bosqichda hosting/Telegram-bot
 * xuddi shu imzoni yasaydi va to'lovdan keyin kalitni avtomatik yuboradi.
 * Mustahkamroq himoya uchun bu sxema Ed25519 raqamli imzosiga almashtiriladi.
 */
object LicenseManager {

    private const val TRIAL_DAYS = 15
    private const val SECRET = "OILA-NAZORAT-2026-MAXFIY-KALIT"
    private const val DAY_MS = 24L * 60 * 60 * 1000

    enum class State { TRIAL, LICENSED, EXPIRED }

    /** Shu telefonning noyob kodi (mijoz sizga shuni yuboradi). */
    @SuppressLint("HardwareIds")
    fun deviceCode(ctx: Context): String {
        val id = Settings.Secure.getString(
            ctx.contentResolver, Settings.Secure.ANDROID_ID
        ) ?: "0000"
        val h = sha256(id + SECRET).uppercase()
        // 8 belgi, o'qishga qulay: XXXX-XXXX
        return h.substring(0, 4) + "-" + h.substring(4, 8)
    }

    fun state(ctx: Context): State {
        val now = System.currentTimeMillis()
        val lic = Prefs.licenseUntil(ctx)
        if (lic > now) return State.LICENSED
        val trialEnd = Prefs.firstRun(ctx) + TRIAL_DAYS * DAY_MS
        if (now < trialEnd) return State.TRIAL
        return State.EXPIRED
    }

    /** Qolgan kunlar (sinov yoki tarif bo'yicha). */
    fun daysLeft(ctx: Context): Int {
        val now = System.currentTimeMillis()
        val lic = Prefs.licenseUntil(ctx)
        val end = if (lic > now) lic
        else Prefs.firstRun(ctx) + TRIAL_DAYS * DAY_MS
        val left = ((end - now) / DAY_MS).toInt()
        return if (left < 0) 0 else left
    }

    /** Kalitni tekshiradi va to'g'ri bo'lsa tarifni yoqadi. */
    fun activate(ctx: Context, rawKey: String): Boolean {
        val key = rawKey.trim().uppercase().replace(" ", "")
        val dash = key.lastIndexOf('-')
        if (dash <= 0) return false
        val daysPart = key.substring(0, dash)
        val sig = key.substring(dash + 1)
        val days = daysPart.toIntOrNull() ?: return false
        if (days !in listOf(180, 365)) return false

        val expected = expectedSig(deviceCode(ctx), days)
        if (!sig.equals(expected, ignoreCase = true)) return false

        val until = System.currentTimeMillis() + days * DAY_MS
        Prefs.setLicenseUntil(ctx, until)
        return true
    }

    /** Imzoni yasash — hosting ham xuddi shu formulani ishlatadi. */
    private fun expectedSig(deviceCode: String, days: Int): String {
        return sha256(deviceCode + days + SECRET).uppercase().substring(0, 10)
    }

    /** PIN reset kaliti (bot keyin faqat ro'yxatdagi ota-onaga yuboradi). */
    fun resetKeyExpected(ctx: Context): String =
        sha256(deviceCode(ctx) + "RESET" + SECRET).uppercase().substring(0, 10)

    fun verifyReset(ctx: Context, key: String): Boolean =
        key.trim().uppercase().replace(" ", "") == resetKeyExpected(ctx)

    private fun sha256(s: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        val b = md.digest(s.toByteArray(Charsets.UTF_8))
        return b.joinToString("") { "%02x".format(it) }
    }
}
