package dev.nanoai.mobile.channels

import android.content.Context
import dev.nanoai.mobile.NanoApplication
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** WA-PROD-02 — puente Dart ↔ AutomationStoreDb (estado durable del
 *  pipeline: dedupe, rate limiter, memoria conversacional). Se registra en
 *  el engine de la UI Y en el headless: la base es única por proceso y el
 *  escritor (Kotlin) serializa las secciones entre isolates. */
class AutomationStoreChannelHandler(
    context: Context,
) : MethodChannel.MethodCallHandler {

    private val db = NanoApplication.from(context).automationStoreDb

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            handle(call, result)
        } catch (error: Exception) {
            result.error("AUTOMATION_STORE_FAILED", error.message, null)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadAll" -> result.success(db.loadAll())

            "get" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("BAD_ARG", "key requerido", null)
                    return
                }
                result.success(db.section(key))
            }

            "put" -> {
                val key = call.argument<String>("key")
                val json = call.argument<String>("json")
                if (key == null || json == null) {
                    result.error("BAD_ARG", "key y json requeridos", null)
                    return
                }
                result.success(db.putSection(key, json))
            }

            // WA-EVLOG-01 — bitácora append-only del pipeline.
            "appendEvent" -> {
                val convId = call.argument<String>("convId").orEmpty()
                val kind = call.argument<String>("kind").orEmpty()
                val detail = call.argument<String>("detail").orEmpty()
                if (kind.isEmpty()) {
                    result.error("BAD_ARG", "kind requerido", null)
                    return
                }
                result.success(db.appendEvent(convId, kind, detail))
            }

            // PERSONA-PROFILE-05 — perfiles del agente personal. Datos
            // tipados SOLO; el SQL se compone en Kotlin (whitelist).
            "personaUpsert" -> {
                val personaKey = call.argument<String>("personaKey").orEmpty()
                val displayName = call.argument<String>("displayName").orEmpty()
                val factsJson = call.argument<String>("factsJson").orEmpty()
                if (personaKey.isEmpty()) {
                    result.error("BAD_ARG", "personaKey requerido", null)
                    return
                }
                result.success(db.upsertPersona(personaKey, displayName, factsJson))
            }

            "personaList" -> result.success(db.listPersonas())

            "relationshipUpsert" -> {
                val relationshipKey = call.argument<String>("relationshipKey").orEmpty()
                val displayName = call.argument<String>("displayName").orEmpty()
                val factsJson = call.argument<String>("factsJson").orEmpty()
                if (relationshipKey.isEmpty()) {
                    result.error("BAD_ARG", "relationshipKey requerido", null)
                    return
                }
                result.success(
                    db.upsertRelationship(relationshipKey, displayName, factsJson),
                )
            }

            "relationshipList" -> result.success(db.listRelationships())

            "relationshipDelete" -> {
                val relationshipKey = call.argument<String>("relationshipKey").orEmpty()
                if (relationshipKey.isEmpty()) {
                    result.error("BAD_ARG", "relationshipKey requerido", null)
                    return
                }
                result.success(db.deleteRelationship(relationshipKey))
            }

            // PERSONA-DATASET-06 — ejemplos del estilo del dueño.
            "exampleAdd" -> {
                val personaKey = call.argument<String>("personaKey").orEmpty()
                val body = call.argument<String>("body").orEmpty()
                val toneJson = call.argument<String>("toneJson").orEmpty()
                val source = call.argument<String>("source").orEmpty()
                // R5-03 — par condicionado: entrada de cliente parecida
                // (opcional; vacío = ejemplo legacy de estilo).
                val incomingText = call.argument<String>("incomingText").orEmpty()
                if (body.isEmpty()) {
                    result.error("BAD_ARG", "body requerido", null)
                    return
                }
                result.success(db.addExample(personaKey, body, toneJson, source, incomingText))
            }

            "exampleList" -> result.success(db.listExamples(call.argument<Number>("limit")?.toInt() ?: 200, call.argument<Number>("offset")?.toInt() ?: 0, call.argument<String>("scopeKey")))

            "exampleDelete" -> {
                val id = call.argument<Number>("id")?.toLong() ?: -1L
                result.success(db.deleteExample(id))
            }

            // PERSONA-RETRIEVAL-07 — búsqueda FTS4 de ejemplos de estilo.
            "exampleSearch" -> {
                val query = call.argument<String>("query").orEmpty()
                val limit = call.argument<Number>("limit")?.toInt() ?: 4
                result.success(db.searchExamples(query, limit, call.argument<String>("scopeKey") ?: "owner", call.argument<String>("roleKey") ?: "role:personal"))
            }

            "relationshipBindScope" -> result.success(db.bindRelationshipScope(call.argument<String>("oldKey").orEmpty(), call.argument<String>("newKey").orEmpty(), call.argument<String>("conversationId").orEmpty()))
            "personalizationImport" -> result.success(db.importPersonalization(call.argument<String>("json").orEmpty()))
            "personalizationSummary" -> result.success(db.personalizationSummary())
            "personalizationDeleteBatch" -> result.success(db.deleteImportBatch(call.argument<String>("batchId").orEmpty()))
            "personalizationHistory" -> result.success(db.importHistory(call.argument<Number>("id")?.toLong() ?: -1))
            "personalMemorySave" -> result.success(db.savePersonalMemory(org.json.JSONObject(call.argument<String>("json").orEmpty())))
            "personalMemoryDelete" -> result.success(db.deletePersonalMemory(call.argument<Number>("id")?.toLong() ?: -1))
            "personalMemoryList" -> result.success(db.listPersonalMemories(call.argument<String>("scopeKey"),
                call.argument<Number>("limit")?.toInt() ?: 100, call.argument<Number>("offset")?.toInt() ?: 0))
            "exampleUpdate" -> result.success(db.updateExample(call.argument<Number>("id")?.toLong() ?: -1,
                call.argument<String>("body").orEmpty(), call.argument<String>("incomingText").orEmpty(), call.argument<String>("toneJson") ?: "{}", call.argument<String>("scopeKey")))

            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/automation_store"
    }
}
