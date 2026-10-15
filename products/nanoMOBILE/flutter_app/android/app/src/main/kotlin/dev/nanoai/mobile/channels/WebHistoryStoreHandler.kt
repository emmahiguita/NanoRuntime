package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.automation.AutomationStoreDb
import dev.nanoai.mobile.automation.WebHistorySqlStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * QUÉ HACE:
 * Gestiona peticiones MethodChannel para historial web persistente, garantizando
 * que 'canonical_messages' sea la fuente primaria de consulta y escritura unificada.
 *
 * CÓMO FUNCIONA:
 * 1. Escritura: Inserta en 'canonical_messages' (a través de AutomationStoreDb) y replica
 *    en 'WebHistorySqlStore' para compatibilidad retroactiva sin pérdida de datos.
 * 2. Lectura: Consulta primero 'canonical_messages'. Si no hay registros (chats previos a migración),
 *    hace fallback a 'WebHistorySqlStore'.
 *
 * POR QUÉ:
 * Cumple con el objetivo de unificar todas las fuentes de mensajería (Web, notificaciones, Meta Cloud)
 * en un único almacén canónico ('canonical_messages'), eliminando silos de datos y permitiendo
 * que el modelo de IA y la UI lean de una sola verdad.
 */
internal class WebHistoryStoreHandler(
    context: Context,
    private val db: AutomationStoreDb,
) {
    private val store = WebHistorySqlStore(context)

    init {
        // Migración asíncrona no bloqueante de historial previo al almacén canónico
        worker.execute {
            try {
                db.migrateWebHistory(context)
            } catch (_: Exception) {}
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method !in setOf("webHistoryAppend", "webHistoryPage")) return false
        worker.execute {
            try {
                val account = call.argument<String>("account").orEmpty()
                val alias = call.argument<String>("alias").orEmpty()
                require(account.length in 1..100 && alias.length in 1..300)
                val value: Any = when (call.method) {
                    "webHistoryAppend" -> {
                        val chat = call.argument<String>("chat").orEmpty()
                        val rows = call.argument<List<Map<String, Any?>>>("rows").orEmpty()
                        // 1. Escritura primaria en almacén canónico único
                        db.appendWebCanonicalMessages(account, chat, alias, rows)
                        // 2. Mantiene compatibilidad con el almacén heredado
                        store.append(account, chat, alias, rows)
                    }
                    else -> {
                        val beforeMs = call.argument<Number>("beforeMs")?.toLong()
                        val beforeId = call.argument<String>("beforeId")
                        // 1. Lectura de fuente única canónica
                        val convIds = buildList {
                            if (alias.isNotBlank()) add(alias)
                            val extractedChat = alias.substringAfterLast('/', "")
                            if (extractedChat.isNotBlank() && extractedChat != alias) add(extractedChat)
                        }
                        val canonicalPage = db.pageCanonicalMessages(convIds, "whatsapp_web", beforeMs, beforeId)
                        val rows = canonicalPage["rows"] as? List<*>
                        if (rows != null && rows.isNotEmpty()) {
                            canonicalPage
                        } else {
                            // 2. Fallback a tabla heredada si aún no migrada
                            store.page(account, alias, beforeMs, beforeId)
                        }
                    }
                }
                main.post { result.success(value) }
            } catch (error: Exception) {
                // El error visible es técnico; nunca incluye cuerpos de mensajes.
                main.post { result.error("WEB_HISTORY_FAILED", error.javaClass.simpleName, null) }
            }
        }
        return true
    }

    companion object {
        private val worker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "NanoWebHistory").apply { isDaemon = true }
        }
        private val main = Handler(Looper.getMainLooper())
    }
}
