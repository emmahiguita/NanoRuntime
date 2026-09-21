package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * NanoNativeAiChannel — Handoff de prompts a apps nativas de IA.
 *
 * QUÉ: Recibe sharePrompt(package, prompt) desde Flutter y lanza Intent.ACTION_SEND.
 * CÓMO: Verifica que package y prompt no sean vacíos antes de lanzar.
 *       Retorna true si el intent se disparó, false si la app no está instalada.
 * POR QUÉ: Es la única forma segura de "abrir ChatGPT con el contexto" sin
 *          leer datos privados de otra app — usa el mecanismo estándar de Android.
 *          No lee la respuesta de la app destino: solo handoff de entrada.
 *
 * REGISTRAR en MainActivity.configureFlutterEngine:
 *   NanoNativeAiChannel(this, messenger).also { nanoNativeAiChannel = it }
 */
class NanoNativeAiChannel(private val activity: Activity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "dev.nanoai/native_ai_apps")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "sharePrompt") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val pkg = call.argument<String>("package")
            val prompt = call.argument<String>("prompt")

            // Validación de entrada — error explícito para debugging.
            if (pkg.isNullOrBlank() || prompt.isNullOrBlank()) {
                result.error("invalid_argument", "App o consulta vacía", null)
                return@setMethodCallHandler
            }

            // Intent estándar de compartir texto: la app destino lo muestra en su UI.
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(pkg)           // Directo a la app destino sin chooser.
                putExtra(Intent.EXTRA_TEXT, prompt)
            }
            try {
                activity.startActivity(intent)
                result.success(true)  // Compartido. No significa que la IA respondió.
            } catch (_: ActivityNotFoundException) {
                result.success(false) // App no instalada — Flutter mostrará aviso.
            } catch (e: SecurityException) {
                result.error("not_allowed", e.message, null)
            }
        }
    }

    /** Llamar en cleanupFlutterEngine para evitar leaks de canal. */
    fun detach() = channel.setMethodCallHandler(null)
}
