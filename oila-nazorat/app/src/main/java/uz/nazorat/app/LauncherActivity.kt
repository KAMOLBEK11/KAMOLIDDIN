package uz.nazorat.app

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

/** Birinchi ishga tushishda nimadan boshlashni hal qiladi. */
class LauncherActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val next = when {
            Prefs.getLang(this).isEmpty() -> LanguageActivity::class.java
            !Prefs.hasPin(this) -> PinActivity::class.java
            else -> {
                // PIN bor — ota-ona kirishdan oldin PIN so'raladi
                PinActivity::class.java
            }
        }
        startActivity(Intent(this, next))
        finish()
    }
}
