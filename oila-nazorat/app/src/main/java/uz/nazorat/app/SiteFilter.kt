package uz.nazorat.app

import android.content.Context

/** Sayt filtri: brauzer manzilidagi URL'ni tekshiradi. */
object SiteFilter {

    // Taniqli brauzerlar
    val browsers = setOf(
        "com.android.chrome", "com.chrome.beta", "com.chrome.dev",
        "org.mozilla.firefox", "org.mozilla.focus",
        "com.opera.browser", "com.opera.mini.native", "com.opera.gx",
        "com.brave.browser", "com.sec.android.app.sbrowser",
        "com.microsoft.emmx", "com.yandex.browser", "com.UCMobile.intl",
        "com.android.browser", "com.duckduckgo.mobile.android", "com.kiwibrowser.browser"
    )

    // Brauzerlardagi manzil maydonining id'lari
    val urlBarIds = listOf(
        "com.android.chrome:id/url_bar",
        "com.chrome.beta:id/url_bar",
        "com.microsoft.emmx:id/url_bar",
        "com.brave.browser:id/url_bar",
        "com.sec.android.app.sbrowser:id/location_bar_edit_text",
        "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
        "com.yandex.browser:id/bro_omnibar_address_title_text",
        "com.opera.browser:id/url_field",
        "com.duckduckgo.mobile.android:id/omnibarTextInput"
    )

    // Kattalar toifasi uchun kalit so'z va domenlar (qisqa ro'yxat; kengaytiriladi)
    private val adultHints = listOf(
        "porn", "xxx", "sex", "xvideos", "xnxx", "pornhub", "redtube",
        "brazzers", "onlyfans", "hentai", "erotic", "camgirl", "nsfw", "18+"
    )

    fun isBlocked(ctx: Context, raw: String?): Boolean {
        if (raw.isNullOrBlank()) return false
        val url = raw.trim().lowercase()
        val host = hostOf(url)

        for (d in Prefs.blockedDomains(ctx)) {
            val dd = d.trim().lowercase()
            if (dd.isNotEmpty() && (host == dd || host.endsWith(".$dd") || url.contains(dd))) return true
        }
        if (Prefs.adultBlockOn(ctx)) {
            for (k in adultHints) if (url.contains(k)) return true
        }
        return false
    }

    private fun hostOf(url: String): String {
        var s = url
        val i = s.indexOf("://"); if (i >= 0) s = s.substring(i + 3)
        s = s.substringBefore('/').substringBefore('?').substringBefore(' ')
        if (s.startsWith("www.")) s = s.substring(4)
        return s
    }
}
