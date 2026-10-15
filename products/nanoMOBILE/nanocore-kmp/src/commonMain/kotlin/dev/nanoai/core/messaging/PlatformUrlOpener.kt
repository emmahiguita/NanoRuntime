// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.messaging · PlatformUrlOpener.kt
//
// expect object PlatformUrlOpener (commonMain)
// actual está en iosMain/IosNotificationBridge.kt (UIApplication) y en
// androidMain (Intent.ACTION_VIEW). En tests (commonTest) es un stub no-op.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

// La declaración `expect` ya está en IosNotificationBridge.kt para iosMain.
// Este archivo define el contrato visible en commonMain para que el código
// compartido pueda referenciarlo.
// (El compilador KMP resuelve la implementación desde androidMain / iosMain.)
