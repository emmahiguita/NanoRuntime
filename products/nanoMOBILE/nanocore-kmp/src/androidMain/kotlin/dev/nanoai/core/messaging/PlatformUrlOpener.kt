// ─────────────────────────────────────────────────────────────────────────────
// androidMain · dev.nanoai.core.messaging · PlatformUrlOpener.kt
//
// `actual object PlatformUrlOpener` para Android.
// Abre la URL con Intent.ACTION_VIEW.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import android.content.Context
import android.content.Intent
import android.net.Uri

actual object PlatformUrlOpener {
    @Volatile private var appContext: Context? = null

    /** Llamado desde Application.onCreate(). */
    fun configure(ctx: Context) { appContext = ctx.applicationContext }

    actual fun open(url: String) {
        val ctx = appContext ?: return
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(intent)
    }
}
