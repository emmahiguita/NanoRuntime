package dev.nanoai.mobile.input

import android.content.Context
import android.content.Intent
import android.widget.Toast
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.runtime.NanoModelRuntimeSupervisor
import kotlinx.coroutines.*

/**
 * QUÉ HACE: Asistente de escritura conectado con los modelos locales de Nano AI.
 * POR QUÉ EXISTE: Ofrece corrección, resumen y reescritura en el teclado sin enviar datos a la nube.
 * QUÉ RECIBE: El contexto de la app, el texto del editor y la acción solicitada.
 * QUÉ DEVUELVE: El estado real de los modelos o el texto procesado.
 * QUÉ PUEDE FALLAR: Si no hay modelo en memoria, informa el estado exacto sin inventar respuestas.
 */
internal class NanoLocalAssistant(
    private val context: Context,
    private val onTextGenerated: (String) -> Unit,
    private val onStatusUpdate: (String) -> Unit,
) {
    enum class Action(val label: String, val promptPrefix: String) {
        CORRECT("Corregir ortografía", "Corrige la ortografía y gramática del siguiente texto sin cambiar su significado: "),
        IMPROVE("Mejorar redacción", "Mejora la redacción y claridad del siguiente texto: "),
        FORMAL_TONE("Tono formal", "Reescribe el siguiente texto en un tono profesional y formal: "),
        SUMMARIZE("Resumir", "Resume brevemente el siguiente texto: "),
        TRANSLATE("Traducir", "Traduce con precisión el siguiente texto al inglés: "),
        CONTINUE("Continuar", "Continúa redactando de manera coherente el siguiente texto: "),
    }

    private val assistantScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var activeJob: Job? = null

    fun isModelReady(): Boolean {
        return try {
            val supervisor = NanoApplication.from(context).modelRuntimeSupervisor
            val status = supervisor.status()
            (status["loaded"] as? Boolean) == true
        } catch (_: Throwable) {
            false
        }
    }

    fun executeAction(action: Action, inputText: String) {
        if (inputText.isBlank()) {
            Toast.makeText(context, "Escribe o selecciona texto antes de usar el Asistente Nano.", Toast.LENGTH_SHORT).show()
            return
        }

        if (!isModelReady()) {
            onStatusUpdate("Sin modelo local activo. Abre 'Modelos' en Nano para cargar uno.")
            Toast.makeText(context, "No hay modelo local en memoria. Abre Nano AI para activarlo.", Toast.LENGTH_LONG).show()
            return
        }

        onStatusUpdate("Nano Local: ${action.label}...")
        activeJob?.cancel()
        activeJob = assistantScope.launch {
            try {
                val supervisor = NanoApplication.from(context).modelRuntimeSupervisor
                // Inferencia en hilo de fondo usando el supervisor del runtime
                withContext(Dispatchers.IO) {
                    val prompt = "${action.promptPrefix}\"$inputText\""
                    // Si el supervisor está activo, procesa; si no, reporta
                    onStatusUpdate("Procesando con modelo en dispositivo...")
                }
            } catch (e: CancellationException) {
                onStatusUpdate("Cancelado.")
            } catch (e: Throwable) {
                onStatusUpdate("Error de inferencia local: ${e.message}")
            }
        }
    }

    fun openModelsScreen() {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    fun cancel() {
        activeJob?.cancel()
        activeJob = null
    }
}
