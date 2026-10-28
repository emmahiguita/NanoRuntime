// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.messaging · PlatformUrlOpener.kt
//
// expect object PlatformUrlOpener (commonMain)
// actual está en iosMain/IosNotificationBridge.kt (UIApplication) y en
// androidMain (Intent.ACTION_VIEW). En tests (commonTest) es un stub no-op.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

/**
 * Contrato multiplataforma para invocar la apertura de URLs en el sistema operativo.
 */
expect object PlatformUrlOpener {
    fun open(url: String)
}
