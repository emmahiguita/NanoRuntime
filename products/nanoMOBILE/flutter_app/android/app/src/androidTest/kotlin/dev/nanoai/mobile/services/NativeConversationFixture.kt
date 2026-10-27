package dev.nanoai.mobile.services

import android.content.Context
import dev.nanoai.mobile.runtime.MnnRuntimeSupervisor
import dev.nanoai.mobile.automation.AutomationRuntimeService
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.runBlocking
import java.io.File
import java.text.Normalizer

/** Prueba de inferencia real sobre pesos instalados. Solo usa datos sintéticos;
 * no lee chats ni invoca el transporte a WhatsApp. Comprueba memoria y contexto. */
internal object NativeConversationFixture {
    fun run(context: Context, instrumentation: android.app.Instrumentation, activityOnly: Boolean = false): String = runBlocking {
        val client = Any()
        val model = File(context.filesDir, "nano/models/Qwen2.5-Omni-3B-MNN")
        check(model.isDirectory) { "Modelo MNN real no instalado" }
        val report = StringBuilder("MNN synthetic conversation\n")
        val history = mutableListOf<Map<String, String>>()
        val turns = listOf(
            "Me llamo Lucas y estoy aprendiendo guitarra. Responde brevemente." to listOf("lucas", "guitarra"),
            "Perdon, me llamo Sara, no Lucas. Recuerda la correccion." to listOf("sara"),
            "Como me llamo y que estoy aprendiendo?" to listOf("sara", "guitarra"),
            "Responde brevemente que entendiste la conversacion." to emptyList(),
        )
        // Reclama el sink solo durante la prueba: el listener puede persistir
        // entradas en su inbox, pero no debe arrancar el runtime de envíos.
        val fixtureSinkOwner = Any()
        instrumentation.runOnMainSync {
            AutomationRuntimeService.onUiEngineAttached()
            NotificationAutomationBridge.setSink(fixtureSinkOwner, object : io.flutter.plugin.common.EventChannel.EventSink {
                override fun success(event: Any?) = Unit
                override fun error(code: String, message: String?, details: Any?) = Unit
                override fun endOfStream() = Unit
            })
        }
        try {
            MnnRuntimeSupervisor.handle(client, MethodCall("load", mapOf("modelPath" to model.path))) { _, _ -> }
            report.append("loaded pssKb=${android.os.Debug.getPss()}\n")
            for ((index, turn) in (if (activityOnly) emptyList() else turns).withIndex()) {
                val id = "synthetic-$index"
                val response = StringBuilder()
                MnnRuntimeSupervisor.admit(client, id)
                val metrics = MnnRuntimeSupervisor.handle(client, MethodCall("generate", mapOf(
                    "requestId" to id,
                    "sessionId" to if (index == 3) "different-session" else "synthetic-conversation",
                    "system" to "Conversa en español. Recuerda los datos del interlocutor y sus correcciones. No inventes datos. Responde en una frase breve.",
                    "history" to history.toList(), "prompt" to turn.first,
                    "maxTokens" to 48, "temperature" to 0.3, "topP" to 0.9,
                ))) { _, token -> response.append(token) }
                val text = response.toString()
                check(text.isNotBlank()) { "turn=$index empty output" }
                val folded = Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD)
                    .replace(Regex("\\p{M}"), "")
                val hits = turn.second.filter { folded.contains(it) }
                report.append("turn=$index chars=${text.length} facts=$hits metrics=$metrics pssKb=${android.os.Debug.getPss()}\n")
                val reused = (metrics as Map<*, *>)["cache_reused"]
                if (index == 1 || index == 2) check(reused == true) { "compatible session KV not reused; $report" }
                if (index == 3) check(reused == false) { "KV crossed sessions; $report" }
                history.add(mapOf("role" to "user", "content" to turn.first))
                history.add(mapOf("role" to "assistant", "content" to text))
                if (index == 2) check(hits.size == turn.second.size) { "correction/history not retained; $report" }
            }
            val cancelledId = "synthetic-cancelled-before-dispatch"
            MnnRuntimeSupervisor.admit(client, cancelledId)
            check(MnnRuntimeSupervisor.cancel(cancelledId, client))
            check(runCatching {
                MnnRuntimeSupervisor.handle(client, MethodCall("generate", mapOf("requestId" to cancelledId))) { _, _ -> }
            }.isFailure) { "cancelled request generated output" }
            check(MnnRuntimeSupervisor.status(client)["loaded"] == true)
            report.append("cancel-before-dispatch=PASS engine-retained=true\n")
            val activityId = "synthetic-activity"
            val activity = StringBuilder()
            MnnRuntimeSupervisor.admit(client, activityId)
            MnnRuntimeSupervisor.handle(client, MethodCall("generate", mapOf(
                "requestId" to activityId, "sessionId" to "synthetic-activity",
                "system" to "Escribe la respuesta que se enviará al mensaje del contacto. El dueño no ha informado su actividad actual. Expresa esa falta de información de forma breve, natural y honesta. El texto final debe dirigirse al contacto.",
                "prompt" to "qué haces", "history" to emptyList<Map<String, String>>(),
                "maxTokens" to 48, "temperature" to 0.3, "topP" to 0.9,
            ))) { _, token -> activity.append(token) }
            // Salida exclusivamente sintética, sin perfil ni mensajes privados.
            report.append("synthetic-activity-output=$activity\n")
            report.append("PASS\n")
        } finally {
            try { MnnRuntimeSupervisor.release(client) } finally {
                instrumentation.runOnMainSync { NotificationAutomationBridge.clearSink(fixtureSinkOwner) }
            }
        }
        report.toString()
    }
}
